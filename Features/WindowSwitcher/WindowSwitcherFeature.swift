import AppKit
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
    private var binding = HotkeyBinding.windowSwitcherDefault
    private var cachedWindows: [WindowInfo] = []
    private var catalogTask: Task<Void, Never>?
    private var thumbnailTasks: [CGWindowID: Task<Void, Never>] = [:]

    private let escapeKeyCode: UInt16 = 53
    private let leftArrow: UInt16 = 123
    private let rightArrow: UInt16 = 124
    private let upArrow: UInt16 = 126
    private let downArrow: UInt16 = 125

    func requiredPermissions() -> [PermissionType] {
        [.accessibility, .screenRecording, .inputMonitoring]
    }

    func start(services: FeatureServices) {
        self.services = services
        binding = services.config.config.windowSwitcher
        isEnabled = services.config.config.windowSwitcherEnabled
        services.hotkeys.register(id: id) { [weak self] event in
            self?.handleHotkey(event) ?? false
        }
        refreshWindowCatalog(updateActiveSession: false)
    }

    func stop() {
        catalogTask?.cancel()
        cancelThumbnailTasks()
        dismissOverlay(activate: false)
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
                Text("Default: ⌥ Tab — hold to browse, release to switch, Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        )
    }

    /// Returns true when the event should be swallowed (not delivered to the focused app).
    @discardableResult
    private func handleHotkey(_ event: HotkeyEvent) -> Bool {
        guard isEnabled else { return false }
        guard let services else { return false }
        binding = services.config.config.windowSwitcher

        switch event {
        case .keyDown(let keyCode, let modifiers, let isRepeat):
            if isActive {
                if keyCode == escapeKeyCode {
                    dismissOverlay(activate: false)
                    return true
                }
                if keyCode == leftArrow || keyCode == upArrow {
                    if !isRepeat { cycleBackward() }
                    return true
                }
                if keyCode == rightArrow || keyCode == downArrow {
                    if !isRepeat { cycleForward() }
                    return true
                }
            }

            if HotkeyMatcher.matchesAllowingShift(binding: binding, keyCode: keyCode, modifiers: modifiers) {
                let reverse = modifiers.contains(.shift)
                if !isActive {
                    beginSwitching(reverse: reverse)
                } else if !isRepeat {
                    if reverse { cycleBackward() } else { cycleForward() }
                }
                return true
            }

            return false

        case .flagsChanged(let modifiers):
            if isActive, !binding.allModifiersHeld(modifiers) {
                confirmSelection()
                return true
            }
            return false

        case .keyUp(let keyCode, _):
            if isActive, binding.modifiers.isEmpty, keyCode == binding.keyCode {
                confirmSelection()
                return true
            }
            return false
        }
    }

    private func beginSwitching(reverse: Bool) {
        isActive = true
        let snapshot = WindowEnumerator.enumerateFast()
        windows = cachedWindows.isEmpty
            ? snapshot
            : WindowEnumerator.merged(snapshot, with: cachedWindows)

        if windows.count > 1 {
            selectedIndex = reverse ? windows.count - 1 : 1
        } else {
            selectedIndex = 0
        }

        thumbnails.removeAll(keepingCapacity: true)
        showOverlay()
        prefetchThumbnails()
        refreshWindowCatalog(updateActiveSession: true)
    }

    private func cycleForward() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        refreshOverlay()
        prefetchThumbnails()
    }

    private func cycleBackward() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
        refreshOverlay()
        prefetchThumbnails()
    }

    private func selectIndex(_ index: Int, activateImmediately: Bool) {
        guard windows.indices.contains(index) else { return }
        selectedIndex = index
        refreshOverlay()
        prefetchThumbnails()
        if activateImmediately {
            confirmSelection()
        }
    }

    private func confirmSelection() {
        guard isActive, windows.indices.contains(selectedIndex) else {
            dismissOverlay(activate: false)
            return
        }
        let window = windows[selectedIndex]
        dismissOverlay(activate: false)
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

            // Enrich titles/flags only — never reshuffle the live session order.
            self.windows = WindowEnumerator.enrich(self.windows, with: refreshed)
            self.refreshOverlay()
            self.prefetchThumbnails()
        }
    }

    private func prefetchThumbnails() {
        guard !windows.isEmpty else { return }
        let radius = 4
        let indices = ((selectedIndex - radius)...(selectedIndex + radius))
            .map { ($0 + windows.count * 4) % windows.count }

        var needed = Set<CGWindowID>()
        for index in indices {
            let id = windows[index].id
            needed.insert(id)
            guard thumbnails[id] == nil, thumbnailTasks[id] == nil else { continue }
            let window = windows[index]
            thumbnailTasks[id] = Task { [weak self] in
                let thumbnail = await WindowEnumerator.thumbnail(for: window)
                guard !Task.isCancelled, let self, self.isActive else { return }
                self.thumbnails[window.id] = thumbnail
                self.thumbnailTasks[window.id] = nil
                self.refreshOverlay()
            }
        }

        // Cancel work for tiles that scrolled far away.
        for (id, task) in thumbnailTasks where !needed.contains(id) {
            task.cancel()
            thumbnailTasks[id] = nil
        }
    }

    private func cancelThumbnailTasks() {
        for task in thumbnailTasks.values { task.cancel() }
        thumbnailTasks.removeAll()
    }

    private func overlaySize(for count: Int) -> NSSize {
        let tiles = max(count, 1)
        let tileWidth: CGFloat = 176
        let visible = min(CGFloat(tiles), 6)
        let width = min(max(320, visible * tileWidth + 80), 1100)
        let rows = tiles > 6 ? 2 : 1
        let height: CGFloat = rows == 2 ? 420 : 260
        return NSSize(width: width, height: height)
    }

    private func showOverlay() {
        services?.overlay.show(
            content: makeOverlayView(),
            size: overlaySize(for: windows.count),
            on: ScreenGeometry.screenUnderMouse()
        )
    }

    private func refreshOverlay() {
        services?.overlay.update(content: makeOverlayView())
    }

    private func makeOverlayView() -> SwitcherOverlayView {
        SwitcherOverlayView(
            windows: windows,
            selectedIndex: selectedIndex,
            thumbnails: thumbnails,
            onHover: { [weak self] index in
                self?.selectIndex(index, activateImmediately: false)
            },
            onSelect: { [weak self] index in
                self?.selectIndex(index, activateImmediately: true)
            }
        )
    }

    private func dismissOverlay(activate: Bool) {
        _ = activate
        cancelThumbnailTasks()
        isActive = false
        services?.overlay.dismiss()
    }
}

extension Notification.Name {
    static let featureConfigChanged = Notification.Name("NoShitMac.featureConfigChanged")
}
