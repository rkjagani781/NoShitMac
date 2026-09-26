import AppKit
import CoreGraphics

enum ScreenGeometry {
    /// Screen under the mouse cursor — where AltTab shows the switcher.
    static func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Convert CGWindowList bounds (Quartz, top-left origin) into AppKit global coords.
    static func appKitRect(fromQuartzBounds quartz: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return quartz }
        let flippedY = NSMaxY(primary.frame) - quartz.origin.y - quartz.height
        return CGRect(x: quartz.origin.x, y: flippedY, width: quartz.width, height: quartz.height)
    }

    /// Quartz frame of an NSScreen (same coordinate space as CGWindow bounds).
    static func quartzFrame(of screen: NSScreen) -> CGRect {
        guard let primary = NSScreen.screens.first else { return screen.frame }
        var frame = screen.frame
        frame.origin.y = NSMaxY(primary.frame) - NSMaxY(screen.frame)
        return frame
    }

    static func screen(containingQuartzBounds bounds: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let hit = screens.first(where: { quartzFrame(of: $0).contains(center) }) {
            return hit
        }

        // Prefer largest intersection area for windows straddling displays.
        return screens.max(by: {
            quartzFrame(of: $0).intersection(bounds).area
                < quartzFrame(of: $1).intersection(bounds).area
        })
    }

    static func shortDisplayName(for screen: NSScreen?) -> String {
        guard let screen else { return "" }
        if screen == NSScreen.main { return "Main" }
        if let index = NSScreen.screens.firstIndex(of: screen) {
            return "Display \(index + 1)"
        }
        return screen.localizedName
    }
}

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
