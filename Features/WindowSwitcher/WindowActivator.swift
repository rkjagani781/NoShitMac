import AppKit
import ApplicationServices

enum WindowActivator {
    static func activate(_ window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else { return }

        app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])

        guard let axWindow = findAXWindow(for: window) else {
            // Fallback: activating the app may switch Spaces to its key window.
            return
        }

        unminimize(axWindow)
        raiseAndFocus(axWindow)

        // Second pass after unminimize animation settles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            raiseAndFocus(axWindow)
        }
    }

    private static func findAXWindow(for window: WindowInfo) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(window.ownerPID)
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

        return axWindows.first
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
