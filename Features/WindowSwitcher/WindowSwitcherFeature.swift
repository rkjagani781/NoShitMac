import AppKit
import Carbon.HIToolbox
import NoShitMacCore
import SwiftUI

@MainActor
final class WindowSwitcherFeature: FeatureModule, ObservableObject {
    let id = "windowSwitcher"
    let displayName = "Window Switcher"
    var isEnabled = true

    private var services: FeatureServices?
    private var windows: [WindowInfo] = []
    private var selectedIndex = 0
    private var thumbnails: [CGWindowID: NSImage] = [:]
    private var isActive = false
    private var modifierHeld = false
    private var binding = HotkeyBinding.windowSwitcherDefault

    func requiredPermissions() -> [PermissionType] {
        [.accessibility, .screenRecording, .inputMonitoring]
    }

    func start(services: FeatureServices) {
        self.services = services
        binding = services.config.config.windowSwitcher
        isEnabled = services.config.config.windowSwitcherEnabled
        services.hotkeys.register(id: id) { [weak self] event in
            Task { @MainActor in
                self?.handleHotkey(event)
            }
        }
    }

    func stop() {
        dismissOverlay()
        services?.hotkeys.unregister(id: id)
    }

    func settingsView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enabled", isOn: Binding(
                    get: { self.isEnabled },
                    set: { newValue in
                        self.isEnabled = newValue
                        self.services?.config.update { $0.windowSwitcherEnabled = newValue }
                        NotificationCenter.default.post(name: .featureConfigChanged, object: nil)
                    }
                ))
                Text("Default: ⌥ Tab — Windows-style window switching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        )
    }

    private func handleHotkey(_ event: HotkeyEvent) {
        guard isEnabled, let services else { return }
        binding = services.config.config.windowSwitcher

        switch event {
        case .keyDown(let keyCode, let modifiers):
            if HotkeyMatcher.matches(binding: binding, keyCode: keyCode, modifiers: modifiers) {
                if !isActive {
                    beginSwitching()
                } else {
                    cycleForward()
                }
            } else if isActive && keyCode == UInt16(kVK_Tab) {
                if modifiers.contains(.shift) {
                    cycleBackward()
                } else {
                    cycleForward()
                }
            }

        case .flagsChanged(let modifiers):
            let optionHeld = modifiers.contains(.option)
            if isActive && modifierHeld && !optionHeld {
                confirmSelection()
            }
            modifierHeld = optionHeld

        case .keyUp:
            break
        }
    }

    private func beginSwitching() {
        isActive = true
        modifierHeld = true
        windows = WindowEnumerator.enumerate()
        selectedIndex = 0
        loadThumbnails()
        showOverlay()
    }

    private func cycleForward() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        refreshOverlay()
    }

    private func cycleBackward() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
        refreshOverlay()
    }

    private func confirmSelection() {
        guard isActive, windows.indices.contains(selectedIndex) else {
            dismissOverlay()
            return
        }
        let window = windows[selectedIndex]
        dismissOverlay()
        WindowActivator.activate(window)
    }

    private func loadThumbnails() {
        thumbnails.removeAll()
        for window in windows.prefix(20) {
            thumbnails[window.id] = WindowEnumerator.thumbnail(for: window.id)
        }
    }

    private func showOverlay() {
        services?.overlay.show(
            content: SwitcherOverlayView(
                windows: windows,
                selectedIndex: selectedIndex,
                thumbnails: thumbnails
            ),
            size: NSSize(width: 800, height: 260)
        )
    }

    private func refreshOverlay() {
        services?.overlay.update(
            content: SwitcherOverlayView(
                windows: windows,
                selectedIndex: selectedIndex,
                thumbnails: thumbnails
            )
        )
    }

    private func dismissOverlay() {
        isActive = false
        modifierHeld = false
        services?.overlay.dismiss()
    }
}

extension Notification.Name {
    static let featureConfigChanged = Notification.Name("NoShitMac.featureConfigChanged")
}
