import AppKit
import ApplicationServices
import AVFoundation
import Foundation

@MainActor
public final class PermissionService: ObservableObject {
    @Published public private(set) var accessibilityGranted = false
    @Published public private(set) var screenRecordingGranted = false
    @Published public private(set) var inputMonitoringGranted = false

    public init() {
        refresh()
    }

    public func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
        inputMonitoringGranted = checkInputMonitoring()
    }

    public func isGranted(_ permission: PermissionType) -> Bool {
        switch permission {
        case .accessibility: return accessibilityGranted
        case .screenRecording: return screenRecordingGranted
        case .inputMonitoring: return inputMonitoringGranted
        }
    }

    public func request(_ permission: PermissionType) {
        switch permission {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .screenRecording:
            CGRequestScreenCaptureAccess()
        case .inputMonitoring:
            openSystemSettings(for: permission)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    public func openSystemSettings(for permission: PermissionType) {
        let urlString: String
        switch permission {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkInputMonitoring() -> Bool {
        // Probe: a listen-only tap can be created when Input Monitoring is granted.
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }
        CFMachPortInvalidate(tap)
        return true
    }
}
