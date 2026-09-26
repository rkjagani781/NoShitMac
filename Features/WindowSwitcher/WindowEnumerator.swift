import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

enum WindowEnumerator {
    /// Fast path used when the hotkey is pressed. This does not contact apps.
    static func enumerateFast() -> [WindowInfo] {
        sortByZOrder(deduplicated(mergeOnScreenMRUWithAllSpaces()))
    }

    /// Comprehensive path intended for a background task.
    static func enumerate() -> [WindowInfo] {
        var byID: [CGWindowID: WindowInfo] = [:]

        for window in mergeOnScreenMRUWithAllSpaces() {
            byID[window.id] = window
        }

        if AXIsProcessTrusted() {
            for window in enumerateFromAX(startingZOrder: byID.count) {
                if let existing = byID[window.id] {
                    byID[window.id] = prefer(existing, window)
                } else {
                    byID[window.id] = window
                }
            }
        }

        return sortByZOrder(deduplicated(Array(byID.values)))
    }

    static func merged(_ primary: [WindowInfo], with secondary: [WindowInfo]) -> [WindowInfo] {
        // Preserve primary (fast MRU) order and identity; enrich titles/flags from secondary.
        let secondaryByID = Dictionary(uniqueKeysWithValues: secondary.map { ($0.id, $0) })
        var result: [WindowInfo] = []
        var seen = Set<CGWindowID>()

        for window in primary {
            seen.insert(window.id)
            if let other = secondaryByID[window.id] {
                result.append(prefer(window, other))
            } else {
                result.append(window)
            }
        }

        // Append secondary-only windows (e.g. AX-discovered) after the MRU strip.
        for window in secondary where seen.insert(window.id).inserted {
            result.append(window)
        }

        return result
    }

    /// Enrich existing session windows in-place without reshuffling order.
    static func enrich(_ session: [WindowInfo], with catalog: [WindowInfo]) -> [WindowInfo] {
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        return session.map { window in
            guard let other = byID[window.id] else { return window }
            return prefer(window, other)
        }
    }

    static func thumbnail(
        for window: WindowInfo,
        maxSize: NSSize = NSSize(width: 200, height: 120)
    ) async -> NSImage? {
        if window.isMinimized, let icon = window.appIcon {
            return icon
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            guard let capturedWindow = content.windows.first(where: { $0.windowID == window.id }) else {
                return window.appIcon
            }

            let sourceSize = capturedWindow.frame.size
            let ratio = min(maxSize.width / sourceSize.width, maxSize.height / sourceSize.height, 1)
            let configuration = SCStreamConfiguration()
            configuration.width = max(Int(sourceSize.width * ratio * 2), 1)
            configuration.height = max(Int(sourceSize.height * ratio * 2), 1)
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true

            let filter = SCContentFilter(desktopIndependentWindow: capturedWindow)
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width / 2, height: cgImage.height / 2)
            )
        } catch {
            return window.appIcon
        }
    }

    // MARK: - CGWindowList

    /// On-screen list is front-to-back (MRU). optionAll includes other Spaces but loses MRU order.
    private static func mergeOnScreenMRUWithAllSpaces() -> [WindowInfo] {
        let onScreen = enumerateFromCG(options: [.optionOnScreenOnly, .excludeDesktopElements])
        let all = enumerateFromCG(options: [.optionAll, .excludeDesktopElements], startingZOrder: onScreen.count)

        var seen = Set(onScreen.map(\.id))
        var merged = onScreen
        for window in all where seen.insert(window.id).inserted {
            merged.append(window)
        }
        return merged
    }

    private static func enumerateFromCG(
        options: CGWindowListOption,
        startingZOrder: Int = 0
    ) -> [WindowInfo] {
        guard let rawList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windows: [WindowInfo] = []
        var activationPolicies: [pid_t: NSApplication.ActivationPolicy] = [:]
        var zOrder = startingZOrder

        for entry in rawList {
            guard
                let layer = entry[kCGWindowLayer as String] as? Int,
                layer == 0,
                let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t,
                let ownerName = entry[kCGWindowOwnerName as String] as? String,
                let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
                let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            if shouldSkipOwner(ownerName) { continue }

            let title = entry[kCGWindowName as String] as? String ?? ownerName
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            let policy = activationPolicies[ownerPID] ?? {
                let value = NSRunningApplication(processIdentifier: ownerPID)?.activationPolicy ?? .prohibited
                activationPolicies[ownerPID] = value
                return value
            }()
            guard policy == .regular else { continue }

            let isOnScreen = entry[kCGWindowIsOnscreen as String] as? Bool ?? false
            let isMinimized = !isOnScreen && bounds.width <= 1 && bounds.height <= 1
            if !isMinimized && (bounds.width < 120 || bounds.height < 80) { continue }

            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            if alpha <= 0 { continue }

            let screen = ScreenGeometry.screen(containingQuartzBounds: bounds)

            windows.append(WindowInfo(
                id: windowID,
                ownerPID: ownerPID,
                ownerName: ownerName,
                title: title.isEmpty ? ownerName : title,
                bounds: bounds,
                layer: layer,
                isOnScreen: isOnScreen,
                isMinimized: isMinimized,
                zOrder: zOrder,
                screenName: ScreenGeometry.shortDisplayName(for: screen)
            ))
            zOrder += 1
        }

        return windows
    }

    // MARK: - Accessibility

    private static func enumerateFromAX(startingZOrder: Int) -> [WindowInfo] {
        var windows: [WindowInfo] = []
        var zOrder = startingZOrder

        let apps = NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular else { return false }
            let name = app.localizedName ?? app.bundleIdentifier ?? ""
            return !shouldSkipOwner(name)
        }

        for app in apps {
            let pid = app.processIdentifier
            let ownerName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, 0.05)

            guard let axWindows = copyAttribute(appElement, kAXWindowsAttribute as CFString) as? [AXUIElement] else {
                continue
            }

            for axWindow in axWindows {
                if shouldSkipAXWindow(axWindow) { continue }
                guard let windowID = axWindowID(axWindow) else { continue }

                let title = (copyAttribute(axWindow, kAXTitleAttribute as CFString) as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedTitle = (title?.isEmpty == false) ? title! : ownerName
                let minimized = (copyAttribute(axWindow, kAXMinimizedAttribute as CFString) as? Bool) ?? false
                let bounds = axWindowBounds(axWindow) ?? .zero
                let isMinimized = minimized || (!bounds.isEmpty && bounds.width <= 1 && bounds.height <= 1)
                let screen = ScreenGeometry.screen(containingQuartzBounds: bounds)

                windows.append(WindowInfo(
                    id: windowID,
                    ownerPID: pid,
                    ownerName: ownerName,
                    title: resolvedTitle,
                    bounds: bounds,
                    layer: 0,
                    isOnScreen: !minimized && bounds.width > 0 && bounds.height > 0,
                    isMinimized: isMinimized,
                    zOrder: zOrder,
                    screenName: ScreenGeometry.shortDisplayName(for: screen)
                ))
                zOrder += 1
            }
        }

        return windows
    }

    // MARK: - Filters

    private static func shouldSkipOwner(_ name: String) -> Bool {
        let blocked = [
            "Window Server", "Dock", "Control Center", "Notification Center",
            "SystemUIServer", "Wallpaper", "NoShitMac", "loginwindow", "AutoFill",
            "Open and Save Panel Service", "CursorUIViewService"
        ]
        return blocked.contains(name)
    }

    private static func shouldSkipAXWindow(_ window: AXUIElement) -> Bool {
        if let role = copyAttribute(window, kAXRoleAttribute as CFString) as? String,
           role != kAXWindowRole as String {
            return true
        }

        if let subrole = copyAttribute(window, kAXSubroleAttribute as CFString) as? String {
            let allowedSubroles = [
                kAXStandardWindowSubrole as String,
                kAXDialogSubrole as String
            ]
            if !allowedSubroles.contains(subrole) { return true }
        }

        return false
    }

    // MARK: - Merge / sort

    private static func deduplicated(_ windows: [WindowInfo]) -> [WindowInfo] {
        var seenIDs = Set<CGWindowID>()
        return windows.filter { seenIDs.insert($0.id).inserted }
    }

    /// Prefer CG on-screen/minimized flags and z-order; keep AX title when CG title is generic.
    private static func prefer(_ cg: WindowInfo, _ ax: WindowInfo) -> WindowInfo {
        let title: String
        if cg.title == cg.ownerName, ax.title != ax.ownerName {
            title = ax.title
        } else if !ax.title.isEmpty {
            title = ax.title
        } else {
            title = cg.title
        }

        let bounds = cg.bounds.width > 0 ? cg.bounds : ax.bounds
        let screen = ScreenGeometry.screen(containingQuartzBounds: bounds)

        return WindowInfo(
            id: cg.id,
            ownerPID: cg.ownerPID,
            ownerName: cg.ownerName,
            title: title,
            bounds: bounds,
            layer: cg.layer,
            isOnScreen: cg.isOnScreen,
            isMinimized: cg.isMinimized || ax.isMinimized,
            zOrder: cg.zOrder,
            screenName: cg.screenName.isEmpty
                ? ScreenGeometry.shortDisplayName(for: screen)
                : cg.screenName
        )
    }

    private static func sortByZOrder(_ windows: [WindowInfo]) -> [WindowInfo] {
        windows.sorted { lhs, rhs in
            if lhs.zOrder != rhs.zOrder { return lhs.zOrder < rhs.zOrder }
            if lhs.isOnScreen != rhs.isOnScreen { return lhs.isOnScreen && !rhs.isOnScreen }
            if lhs.isMinimized != rhs.isMinimized { return !lhs.isMinimized && rhs.isMinimized }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - AX helpers

    private static func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value
    }

    private static func axWindowID(_ window: AXUIElement) -> CGWindowID? {
        guard let number = copyAttribute(window, "_AXWindowNumber" as CFString) as? Int, number > 0 else {
            return nil
        }
        return CGWindowID(number)
    }

    private static func axWindowBounds(_ window: AXUIElement) -> CGRect? {
        // AX position is already in AppKit global coordinates (bottom-left origin).
        // Convert to Quartz so screen mapping stays consistent with CGWindowList.
        guard
            let origin = point(from: window, attribute: kAXPositionAttribute as CFString),
            let size = size(from: window, attribute: kAXSizeAttribute as CFString),
            let primary = NSScreen.screens.first
        else {
            return nil
        }
        let quartzY = NSMaxY(primary.frame) - origin.y - size.height
        return CGRect(x: origin.x, y: quartzY, width: size.width, height: size.height)
    }

    private static func point(from element: AXUIElement, attribute: CFString) -> CGPoint? {
        guard let value = copyAttribute(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(from element: AXUIElement, attribute: CFString) -> CGSize? {
        guard let value = copyAttribute(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
