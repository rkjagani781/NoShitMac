import AppKit
import CoreGraphics

enum WindowEnumerator {
    static func enumerate() -> [WindowInfo] {
        guard let rawList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
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

            if bounds.width < 40 || bounds.height < 40 { continue }

            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            if alpha < 0.01 { continue }

            let isOnScreen = entry[kCGWindowIsOnscreen as String] as? Bool ?? true

            windows.append(WindowInfo(
                id: windowID,
                ownerPID: ownerPID,
                ownerName: ownerName,
                title: title.isEmpty ? ownerName : title,
                bounds: bounds,
                layer: layer,
                isOnScreen: isOnScreen
            ))
        }

        return deduplicated(windows)
    }

    static func thumbnail(for windowID: CGWindowID, maxSize: NSSize = NSSize(width: 200, height: 120)) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else { return nil }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return image.resized(toFit: maxSize)
    }

    private static func shouldSkipOwner(_ name: String) -> Bool {
        let blocked = ["Window Server", "Dock", "Control Center", "Notification Center", "SystemUIServer", "NoShitMac"]
        return blocked.contains(name)
    }

    private static func deduplicated(_ windows: [WindowInfo]) -> [WindowInfo] {
        var seen = Set<CGWindowID>()
        return windows.filter { seen.insert($0.id).inserted }
    }
}

private extension NSImage {
    func resized(toFit maxSize: NSSize) -> NSImage {
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height, 1)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        let img = NSImage(size: newSize)
        img.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1)
        img.unlockFocus()
        return img
    }
}
