import NoShitMacCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var config: ConfigStore
    @EnvironmentObject private var registry: FeatureRegistry

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environmentObject(coordinator)
                .environmentObject(config)
                .tabItem { Label("General", systemImage: "gearshape") }

            HotkeysSettingsTab()
                .environmentObject(config)
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }

            FeaturesSettingsTab()
                .environmentObject(registry)
                .tabItem { Label("Features", systemImage: "square.grid.2x2") }
        }
        .frame(width: 480, height: 360)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var config: ConfigStore

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: Binding(
                get: { config.config.launchAtLogin },
                set: { coordinator.setLaunchAtLogin($0) }
            ))
            Text("NoShitMac runs from the menu bar. Grant all permissions for full functionality.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct HotkeysSettingsTab: View {
    @EnvironmentObject private var config: ConfigStore

    var body: some View {
        Form {
            HotkeyRecorderView(label: "Window Switcher", binding: Binding(
                get: { config.config.windowSwitcher },
                set: { newValue in
                    config.update { $0.windowSwitcher = newValue }
                    NotificationCenter.default.post(name: .featureConfigChanged, object: nil)
                }
            ))
            HotkeyRecorderView(label: "Screenshot", binding: Binding(
                get: { config.config.screenshot },
                set: { newValue in
                    config.update { $0.screenshot = newValue }
                    NotificationCenter.default.post(name: .featureConfigChanged, object: nil)
                }
            ))
            Text("Avoid conflicts with macOS system shortcuts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct FeaturesSettingsTab: View {
    @EnvironmentObject private var registry: FeatureRegistry

    var body: some View {
        Form {
            ForEach(Array(registry.features.enumerated()), id: \.offset) { _, feature in
                Section(feature.displayName) {
                    feature.settingsView()
                }
            }
        }
        .padding()
    }
}
