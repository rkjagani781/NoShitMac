import AppKit
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

    /// LSUIElement apps stay `.accessory` and won't show Settings unless activated first.
    func openSettings(using openSettings: OpenSettingsAction) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    func cleanupInactiveWindows() {
        guard permissionService.accessibilityGranted else {
            permissionService.request(.accessibility)
            return
        }

        let preview = WindowCleanupService.previewInactiveWindows()
        presentUserAlert(
            title: preview.candidates.isEmpty ? "Nothing to Clean" : "Clean Up Inactive Windows",
            message: cleanupPrompt(for: preview),
            confirmTitle: preview.candidates.isEmpty ? nil : "Clean Up"
        ) { [self] confirmed in
            guard confirmed else { return }
            let result = WindowCleanupService.cleanup(preview.candidates)
            presentUserAlert(
                title: "Cleanup Complete",
                message: cleanupSummary(for: result),
                confirmTitle: nil
            ) { _ in }
        }
    }

    private func cleanupPrompt(for preview: WindowCleanupService.CleanupPreview) -> String {
        if preview.candidates.isEmpty {
            return "No minimized or hidden background windows were found."
        }

        let lines = preview.candidates.prefix(8).map { "• \($0.ownerName): \($0.title)" }
        var message = "Close \(preview.candidates.count) inactive window(s) from background apps?\n\n"
        message += lines.joined(separator: "\n")
        if preview.candidates.count > 8 {
            message += "\n• and \(preview.candidates.count - 8) more…"
        }
        message += "\n\nYour frontmost app will not be affected."
        return message
    }

    private func cleanupSummary(for result: WindowCleanupService.CleanupResult) -> String {
        if result.closedCount == 0 && result.failedCount == 0 {
            return "No windows were closed."
        }
        if result.failedCount == 0 {
            return "Closed \(result.closedCount) window(s)."
        }
        return "Closed \(result.closedCount) window(s). \(result.failedCount) could not be closed."
    }

    private func presentUserAlert(
        title: String,
        message: String,
        confirmTitle: String?,
        onComplete: @escaping (Bool) -> Void
    ) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = confirmTitle == nil ? .informational : .warning

        if let confirmTitle {
            alert.addButton(withTitle: confirmTitle)
            alert.addButton(withTitle: "Cancel")
            onComplete(alert.runModal() == .alertFirstButtonReturn)
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
            onComplete(false)
        }
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
