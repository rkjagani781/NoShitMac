import NoShitMacCore
import ServiceManagement
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    let configStore = ConfigStore()
    let permissionService = PermissionService()
    let hotkeyService = HotkeyService()
    let overlayManager = OverlayWindowManager()
    let featureRegistry: FeatureRegistry

    private let windowSwitcher = WindowSwitcherFeature()
    private let screenshot = ScreenshotFeature()

    init() {
        let services = FeatureServices(
            hotkeys: hotkeyService,
            config: configStore,
            permissions: permissionService,
            overlay: overlayManager
        )
        featureRegistry = FeatureRegistry(services: services)
        featureRegistry.register(windowSwitcher)
        featureRegistry.register(screenshot)

        NotificationCenter.default.addObserver(
            forName: .featureConfigChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.featureRegistry.restartAll()
            }
        }
    }

    func launch() {
        permissionService.refresh()
        featureRegistry.startAll()
        applyLaunchAtLogin(configStore.config.launchAtLogin)
    }

    func shutdown() {
        featureRegistry.stopAll()
        hotkeyService.stop()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        configStore.update { $0.launchAtLogin = enabled }
        applyLaunchAtLogin(enabled)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("NoShitMac: launch at login — \(error.localizedDescription)")
        }
    }
}
