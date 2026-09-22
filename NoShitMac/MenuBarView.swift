import NoShitMacCore
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var permissions: PermissionService
    @EnvironmentObject private var config: ConfigStore

    @State private var didLaunch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NoShitMac")
                .font(.headline)

            PermissionSummaryView()

            Divider()

            Button {
                coordinator.cleanupInactiveWindows()
            } label: {
                Label("Clean Up Windows", systemImage: "xmark.bin")
            }
            .help("Close minimized and hidden windows from background apps")

            Button("Settings…") {
                coordinator.openSettings(using: openSettings)
            }
            .keyboardShortcut(",", modifiers: .command)

            Toggle("Launch at Login", isOn: Binding(
                get: { config.config.launchAtLogin },
                set: { coordinator.setLaunchAtLogin($0) }
            ))

            Divider()

            Button("Quit NoShitMac") {
                coordinator.shutdown()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            guard !didLaunch else { return }
            didLaunch = true
            coordinator.launch()
            permissions.refresh()
        }
    }
}

struct PermissionSummaryView: View {
    @EnvironmentObject private var permissions: PermissionService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Permissions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            PermissionRow(name: "Accessibility", granted: permissions.accessibilityGranted) {
                permissions.request(.accessibility)
            }
            PermissionRow(name: "Screen Recording", granted: permissions.screenRecordingGranted) {
                permissions.request(.screenRecording)
            }
            PermissionRow(name: "Input Monitoring", granted: permissions.inputMonitoringGranted) {
                permissions.openSystemSettings(for: .inputMonitoring)
            }
        }
    }
}

private struct PermissionRow: View {
    let name: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(name)
                .font(.caption)
            Spacer()
            if !granted {
                Button("Grant") { action() }
                    .font(.caption)
            }
        }
    }
}
