import AppKit

enum WindowCleanupService {
    struct CleanupPreview {
        let candidates: [WindowInfo]
    }

    struct CleanupResult {
        let closedCount: Int
        let failedCount: Int
    }

    /// Windows eligible for cleanup: minimized or hidden windows from background apps.
    static func previewInactiveWindows() -> CleanupPreview {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let candidates = WindowEnumerator.enumerate().filter { window in
            isInactiveCandidate(window, frontmostPID: frontmostPID)
        }
        return CleanupPreview(candidates: candidates)
    }

    static func cleanup(_ candidates: [WindowInfo]) -> CleanupResult {
        var closedCount = 0
        var failedCount = 0

        for window in candidates {
            if WindowActivator.close(window) {
                closedCount += 1
            } else {
                failedCount += 1
            }
        }

        return CleanupResult(closedCount: closedCount, failedCount: failedCount)
    }

    private static func isInactiveCandidate(_ window: WindowInfo, frontmostPID: pid_t?) -> Bool {
        if let frontmostPID, window.ownerPID == frontmostPID {
            return false
        }

        // Background clutter: minimized windows and windows on other Spaces.
        return window.isMinimized || !window.isOnScreen
    }
}
