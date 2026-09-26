# NoShitMac Architecture

## Design Goals

- **Scalable** — new features plug in via `FeatureModule` protocol
- **Fast** — native Swift/AppKit; overlays only when active
- **Lightweight** — single app bundle, no Electron, minimal dependencies

## Module Layout

```
NoShitMacApp (menu bar)
    └── NoShitMacCore (framework)
            ├── FeatureRegistry
            ├── HotkeyService      ← single CGEventTap, multiplexed handlers
            ├── ConfigStore        ← JSON in Application Support
            ├── PermissionService
            └── OverlayWindowManager
    └── Features/
            ├── WindowSwitcher/   ← AltTab-style focus via SkyLight + MRU z-order
            ├── Screenshot/
            └── WindowCleanup/
```

## FeatureModule Contract

Every feature implements:

```swift
protocol FeatureModule: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var isEnabled: Bool { get set }
    func start(services: FeatureServices)
    func stop()
    func settingsView() -> AnyView
    func requiredPermissions() -> [PermissionType]
}
```

Register in `AppCoordinator.init()`:

```swift
featureRegistry.register(windowSwitcher)
featureRegistry.register(screenshot)
```

## Adding a Phase 2 Feature

1. Create `Features/MyFeature/MyFeature.swift` implementing `FeatureModule`
2. Register in `AppCoordinator`
3. Add hotkey binding to `AppConfig` if needed
4. Add Settings section via `settingsView()`

No changes to core services required unless the feature needs a new shared capability.

## Hotkey Routing

One `CGEventTap` in `HotkeyService` dispatches events to all registered handlers. Features filter by their configured binding via `HotkeyMatcher`.

## Overlay System

`OverlayWindowManager` creates borderless `NSPanel` windows at `.floating` or `.screenSaver` level with `canJoinAllSpaces` for fullscreen Space compatibility.

## Agent Stub

`NoShitMacAgent/` is reserved for a login-item helper (Phase 1.5) if hotkeys require a separate process.
