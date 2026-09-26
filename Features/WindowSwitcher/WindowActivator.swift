import AppKit
import ApplicationServices

enum WindowActivator {
    private static let focusQueue = DispatchQueue(label: "com.rkjagani781.NoShitMac.windowFocus", qos: .userInitiated)

    static func close(_ window: WindowInfo) -> Bool {
        guard let axWindow = findAXWindow(for: window) else { return false }
        AXUIElementSetMessagingTimeout(axWindow, 0.25)

        if performClose(axWindow) { return true }

        unminimize(axWindow)
        if performClose(axWindow) { return true }
        raiseAndFocus(axWindow)
        return performClose(axWindow)
    }

    /// Activate like AltTab: target a specific CGWindowID across Spaces / displays,
    /// then raise via Accessibility. Serialized so rapid switches don't race.
    static func activate(_ window: WindowInfo) {
        focusQueue.async {
            _ = PrivateFocusAPIs.focusWindow(pid: window.ownerPID, windowID: window.id)

            // Small settle so WindowServer commits the Space/display change.
            usleep(30_000)

            DispatchQueue.main.sync {
                if let axWindow = findAXWindow(for: window) {
                    AXUIElementSetMessagingTimeout(axWindow, 0.35)
                    unminimize(axWindow)
                    raiseAndFocus(axWindow)
                } else if let app = NSRunningApplication(processIdentifier: window.ownerPID) {
                    // Last resort — may raise the wrong window of a multi-window app.
                    app.activate(options: [.activateAllWindows])
                    _ = PrivateFocusAPIs.focusWindow(pid: window.ownerPID, windowID: window.id)
                }
            }

            // Second AX pass after the Space animation begins.
            usleep(50_000)
            DispatchQueue.main.sync {
                if let axWindow = findAXWindow(for: window) {
                    raiseAndFocus(axWindow)
                }
            }
        }
    }

    private static func performClose(_ axWindow: AXUIElement) -> Bool {
        if AXUIElementPerformAction(axWindow, "AXClose" as CFString) == .success {
            return true
        }

        var closeButtonRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXCloseButtonAttribute as CFString, &closeButtonRef) == .success,
              let closeButtonRef else {
            return false
        }

        let closeButton = closeButtonRef as! AXUIElement
        if AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == .success {
            return true
        }

        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        return AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == .success
    }

    private static func findAXWindow(for window: WindowInfo) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(window.ownerPID)
        AXUIElementSetMessagingTimeout(appElement, 0.35)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let axWindows = value as? [AXUIElement] else {
            return nil
        }

        for axWindow in axWindows {
            if matchesWindowID(axWindow, target: window.id) { return axWindow }
        }

        for axWindow in axWindows {
            if matchesTitle(axWindow, target: window.title) { return axWindow }
        }

        return nil
    }

    private static func matchesWindowID(_ axWindow: AXUIElement, target: CGWindowID) -> Bool {
        var windowIDRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, "_AXWindowNumber" as CFString, &windowIDRef) == .success,
              let number = windowIDRef as? Int else {
            return false
        }
        return CGWindowID(number) == target
    }

    private static func matchesTitle(_ axWindow: AXUIElement, target: String) -> Bool {
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef as? String else {
            return false
        }
        return title == target
    }

    private static func unminimize(_ window: AXUIElement) {
        var minimizedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
              let isMinimized = minimizedValue as? Bool, isMinimized else {
            return
        }
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    private static func raiseAndFocus(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }
}
