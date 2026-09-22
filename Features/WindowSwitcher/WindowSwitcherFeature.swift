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
    private var lastModifierFlags: NSEvent.ModifierFlags = []
    private var binding = HotkeyBinding.windowSwitcherDefault
    private var cachedWindows: [WindowInfo] = []
    private var catalogTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?

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
        refreshWindowCatalog(updateActiveSession: false)
    }

    func stop() {
        catalogTask?.cancel()
        thumbnailTask?.cancel()
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
                    beginSwitching(modifiers: modifiers)
                } else {
                    cycleForward()
                }
            } else if isActive && keyCode == UInt16(kVK_Tab) && binding.allModifiersHeld(modifiers) {
                if modifiers.contains(.shift) {
                    cycleBackward()
                } else {
                    cycleForward()
                }
            }
            lastModifierFlags = modifiers

        case .flagsChanged(let modifiers):
            if isActive, !binding.allModifiersHeld(modifiers) {
                confirmSelection()
            }
            lastModifierFlags = modifiers

        case .keyUp(let keyCode, _):
            if isActive, binding.modifiers.isEmpty, keyCode == binding.keyCode {
                confirmSelection()
            }
        }
    }

    private func beginSwitching(modifiers: NSEvent.ModifierFlags) {
        isActive = true
        lastModifierFlags = modifiers
        // AX catalog contains logical application windows. The CG snapshot is only a
        // first-launch fallback because it also exposes browser compositor surfaces.
        windows = cachedWindows.isEmpty ? WindowEnumerator.enumerateFast() : cachedWindows
        selectedIndex = 0
        thumbnails.removeAll(keepingCapacity: true)
        showOverlay()
        requestSelectedThumbnail()
        refreshWindowCatalog(updateActiveSession: true)
    }

    private func cycleForward() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        refreshOverlay()
        requestSelectedThumbnail()
    }

    private func cycleBackward() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
        refreshOverlay()
        requestSelectedThumbnail()
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

    private func refreshWindowCatalog(updateActiveSession: Bool) {
        catalogTask?.cancel()
        catalogTask = Task { [weak self] in
            let refreshed = await Task.detached(priority: .userInitiated) {
                WindowEnumerator.enumerate()
            }.value
            guard !Task.isCancelled, let self else { return }

            self.cachedWindows = refreshed
            guard updateActiveSession, self.isActive else { return }

            let selectedID = self.windows.indices.contains(self.selectedIndex)
                ? self.windows[self.selectedIndex].id
                : nil
            self.windows = refreshed.isEmpty ? WindowEnumerator.enumerateFast() : refreshed
            if let selectedID,
               let newIndex = self.windows.firstIndex(where: { $0.id == selectedID }) {
                self.selectedIndex = newIndex
            } else {
                self.selectedIndex = min(self.selectedIndex, max(self.windows.count - 1, 0))
            }
            self.refreshOverlay()
            self.requestSelectedThumbnail()
        }
    }

    private func requestSelectedThumbnail() {
        guard windows.indices.contains(selectedIndex) else { return }
        let window = windows[selectedIndex]
        guard thumbnails[window.id] == nil else { return }

        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self] in
            let thumbnail = await WindowEnumerator.thumbnail(for: window)
            guard !Task.isCancelled, let self, self.isActive else { return }
            self.thumbnails[window.id] = thumbnail
            self.refreshOverlay()
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
        thumbnailTask?.cancel()
        isActive = false
        lastModifierFlags = []
        services?.overlay.dismiss()
    }
}

extension Notification.Name {
    static let featureConfigChanged = Notification.Name("NoShitMac.featureConfigChanged")
}
