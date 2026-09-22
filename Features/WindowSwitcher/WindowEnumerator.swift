import AppKit
import CoreGraphics

enum WindowEnumerator {
    /// Lists user windows across all Spaces (including fullscreen and minimized).
    static func enumerate() -> [WindowInfo] {
        guard let rawList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var windows: [WindowInfo] = []

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

            // Include minimized windows (often 0×0 bounds) — restore on activate.
            let isOnScreen = entry[kCGWindowIsOnscreen as String] as? Bool ?? false
            let isMinimized = !isOnScreen && bounds.width <= 1 && bounds.height <= 1
            if !isMinimized && (bounds.width < 40 || bounds.height < 40) { continue }

            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            if alpha < 0.01 { continue }

            windows.append(WindowInfo(
                id: windowID,
                ownerPID: ownerPID,
                ownerName: ownerName,
                title: title.isEmpty ? ownerName : title,
                bounds: bounds,
                layer: layer,
                isOnScreen: isOnScreen,
                isMinimized: isMinimized
            ))
        }

        return sortWindows(deduplicated(windows))
    }

    static func thumbnail(for window: WindowInfo, maxSize: NSSize = NSSize(width: 200, height: 120)) -> NSImage? {
        if window.isMinimized, let icon = window.appIcon {
            return icon
        }

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            window.id,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return window.appIcon
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return image.resized(toFit: maxSize)
    }

    private static func shouldSkipOwner(_ name: String) -> Bool {
        let blocked = [
            "Window Server", "Dock", "Control Center", "Notification Center",
            "SystemUIServer", "Wallpaper", "NoShitMac"
        ]
        return blocked.contains(name)
    }

    private static func deduplicated(_ windows: [WindowInfo]) -> [WindowInfo] {
        var seen = Set<CGWindowID>()
        return windows.filter { seen.insert($0.id).inserted }
    }

    /// On-screen windows first, then minimized / other Spaces.
    private static func sortWindows(_ windows: [WindowInfo]) -> [WindowInfo] {
        windows.sorted { lhs, rhs in
            if lhs.isOnScreen != rhs.isOnScreen { return lhs.isOnScreen && !rhs.isOnScreen }
            if lhs.isMinimized != rhs.isMinimized { return !lhs.isMinimized && rhs.isMinimized }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension NSImage {
    func resized(toFit maxSize: NSSize) -> NSImage {
        guard size.width > 0, size.height > 0 else { return self }
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height, 1)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        let img = NSImage(size: newSize)
        img.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1)
        img.unlockFocus()
        return img
    }
}
