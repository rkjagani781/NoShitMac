import SwiftUI

public enum PermissionType: String, CaseIterable, Sendable {
    case accessibility
    case screenRecording
    case inputMonitoring

    public var displayName: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .inputMonitoring: return "Input Monitoring"
        }
    }
}

@MainActor
public protocol FeatureModule: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var isEnabled: Bool { get set }

    func start(services: FeatureServices)
    func stop()
    func settingsView() -> AnyView
    func requiredPermissions() -> [PermissionType]
}

@MainActor
public struct FeatureServices {
    public let hotkeys: HotkeyService
    public let config: ConfigStore
    public let permissions: PermissionService
    public let overlay: OverlayWindowManager

    public init(
        hotkeys: HotkeyService,
        config: ConfigStore,
        permissions: PermissionService,
        overlay: OverlayWindowManager
    ) {
        self.hotkeys = hotkeys
        self.config = config
        self.permissions = permissions
        self.overlay = overlay
    }
}
