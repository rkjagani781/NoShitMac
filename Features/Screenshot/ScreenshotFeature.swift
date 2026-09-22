import AppKit
import NoShitMacCore
import SwiftUI

@MainActor
final class ScreenshotFeature: FeatureModule, ObservableObject {
    let id = "screenshot"
    let displayName = "Screenshot"
    var isEnabled = true

    private var services: FeatureServices?
    private var binding = HotkeyBinding.screenshotDefault

    func requiredPermissions() -> [PermissionType] {
        [.screenRecording, .inputMonitoring]
    }

    func start(services: FeatureServices) {
        self.services = services
        binding = services.config.config.screenshot
        isEnabled = services.config.config.screenshotEnabled
        services.hotkeys.register(id: id) { [weak self] event in
            Task { @MainActor in
                self?.handleHotkey(event)
            }
        }
    }

    func stop() {
        services?.hotkeys.unregister(id: id)
    }

    func settingsView() -> AnyView {
        AnyView(ScreenshotFeatureSettings(feature: self))
    }

    fileprivate var captureMode: ScreenshotCaptureMode {
        services?.config.config.screenshotCaptureMode ?? .region
    }

    fileprivate func setCaptureMode(_ mode: ScreenshotCaptureMode) {
        services?.config.update { $0.screenshotCaptureMode = mode }
    }

    private func handleHotkey(_ event: HotkeyEvent) {
        guard isEnabled, let services else { return }
        binding = services.config.config.screenshot

        if case .keyDown(let keyCode, let modifiers) = event,
           HotkeyMatcher.matches(binding: binding, keyCode: keyCode, modifiers: modifiers) {
            if captureMode == .fullScreen {
                Task { await captureFullScreen() }
            } else {
                beginRegionSelection()
            }
        }
    }

    private func beginRegionSelection() {
        guard let screen = NSScreen.main else { return }
        services?.overlay.showFullscreen(
            content: RegionSelectionView(
                screen: screen,
                onSelect: { [weak self] rect in
                    self?.services?.overlay.dismiss()
                    Task { await self?.captureRegion(rect) }
                },
                onCancel: { [weak self] in
                    self?.services?.overlay.dismiss()
                }
            )
        )
    }

    private func captureFullScreen() async {
        do {
            let image = try await CaptureService.captureFullScreen()
            presentEditor(with: image)
        } catch {
            NSLog("NoShitMac: screenshot failed — \(error.localizedDescription)")
        }
    }

    private func captureRegion(_ rect: CGRect) async {
        do {
            let image = try await CaptureService.captureRegion(rect)
            presentEditor(with: image)
        } catch {
            NSLog("NoShitMac: region capture failed — \(error.localizedDescription)")
        }
    }

    private func presentEditor(with image: NSImage) {
        CaptureService.copyToClipboard(image)
        services?.overlay.show(
            content: ScreenshotEditorView(
                sourceImage: image,
                onDone: { final in
                    CaptureService.copyToClipboard(final)
                    self.services?.overlay.dismiss()
                },
                onCancel: { [weak self] in
                    self?.services?.overlay.dismiss()
                }
            ),
            size: NSSize(width: 860, height: 620)
        )
    }
}

private struct ScreenshotFeatureSettings: View {
    @ObservedObject var feature: ScreenshotFeature
    @EnvironmentObject private var config: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enabled", isOn: Binding(
                get: { feature.isEnabled },
                set: { newValue in
                    feature.isEnabled = newValue
                    config.update { $0.screenshotEnabled = newValue }
                    NotificationCenter.default.post(name: .featureConfigChanged, object: nil)
                }
            ))
            Picker("Default mode", selection: Binding(
                get: { config.config.screenshotCaptureMode },
                set: { newValue in
                    config.update { $0.screenshotCaptureMode = newValue }
                }
            )) {
                ForEach(ScreenshotCaptureMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text("Default: ⌥⇧4 · Auto-copy to clipboard")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
