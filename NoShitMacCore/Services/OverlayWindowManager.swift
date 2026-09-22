import AppKit
import SwiftUI

@MainActor
public final class OverlayWindowManager {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    public init() {}

    public func show<Content: View>(
        content: Content,
        size: NSSize = NSSize(width: 720, height: 480),
        centered: Bool = true
    ) {
        dismiss()

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting

        if centered, let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
            panel.setFrameOrigin(origin)
        }

        panel.orderFrontRegardless()
        self.panel = panel
        self.hostingView = hosting
    }

    public func showFullscreen<Content: View>(content: Content) {
        dismiss()
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = hosting
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        self.panel = panel
        self.hostingView = hosting
    }

    public func update<Content: View>(content: Content) {
        hostingView?.rootView = AnyView(content)
    }

    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
