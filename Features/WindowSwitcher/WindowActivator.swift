import AppKit
import ApplicationServices

enum WindowActivator {
    static func activate(_ window: WindowInfo) {
        if let app = NSRunningApplication(processIdentifier: window.ownerPID) {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        let appElement = AXUIElementCreateApplication(window.ownerPID)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

        if result == .success, let axWindows = value as? [AXUIElement] {
            for axWindow in axWindows {
                var windowIDRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWindow, "_AXWindowNumber" as CFString, &windowIDRef) == .success,
                   let number = windowIDRef as? Int,
                   CGWindowID(number) == window.id {
                    raiseAndFocus(axWindow)
                    return
                }

                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String,
                   title == window.title {
                    raiseAndFocus(axWindow)
                    return
                }
            }

            if let first = axWindows.first {
                raiseAndFocus(first)
            }
        }
    }

    private static func raiseAndFocus(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }
}
