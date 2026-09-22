import AppKit

enum WindowCleanupService {
    struct CleanupPreview {
        let candidates: [WindowInfo]
        let protectedAppName: String?
    }

    struct CleanupResult {
        let closedCount: Int
        let failedCount: Int
    }

    /// Windows eligible for cleanup: every window from background apps.
    /// The frontmost app (when cleanup starts) is fully protected.
    static func previewInactiveWindows() -> CleanupPreview {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostPID = frontmost?.processIdentifier
        let protectedName = frontmost?.localizedName

        let candidates = WindowEnumerator.enumerate().filter { window in
            isInactiveCandidate(window, frontmostPID: frontmostPID)
        }

        return CleanupPreview(candidates: candidates, protectedAppName: protectedName)
    }

    static func cleanup(_ candidates: [WindowInfo]) -> CleanupResult {
        var closedCount = 0
        var failedCount = 0

        // Close off-screen/minimized first so visible windows are easier to resolve.
        let ordered = candidates.sorted { lhs, rhs in
            if lhs.isMinimized != rhs.isMinimized { return lhs.isMinimized && !rhs.isMinimized }
            if lhs.isOnScreen != rhs.isOnScreen { return !lhs.isOnScreen && rhs.isOnScreen }
            return lhs.ownerName < rhs.ownerName
        }

        for window in ordered {
            if WindowActivator.close(window) {
                closedCount += 1
            } else {
                failedCount += 1
            }
        }

        return CleanupResult(closedCount: closedCount, failedCount: failedCount)
    }

    private static func isInactiveCandidate(_ window: WindowInfo, frontmostPID: pid_t?) -> Bool {
        if window.ownerName == "NoShitMac" { return false }

        guard let frontmostPID else { return true }

        if window.ownerPID == frontmostPID {
            let frontmost = NSRunningApplication(processIdentifier: frontmostPID)
            // When the menu-bar panel is frontmost, don't block cleanup for every other app.
            if frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
                return true
            }
            return false
        }

        return true
    }
}
