import AppKit
import CoreGraphics

struct WindowInfo: Identifiable, Equatable {
    let id: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let title: String
    let bounds: CGRect
    let layer: Int
    let isOnScreen: Bool
    let isMinimized: Bool
    /// Front-to-back order from CGWindowList (lower = more recently front).
    let zOrder: Int
    let screenName: String

    var appIcon: NSImage? {
        guard let app = NSRunningApplication(processIdentifier: ownerPID) else { return nil }
        return app.icon
    }
}
