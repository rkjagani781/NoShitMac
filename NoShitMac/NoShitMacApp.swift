import SwiftUI

@main
struct NoShitMacApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("NoShitMac", systemImage: "bolt.fill") {
            MenuBarView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.configStore)
                .environmentObject(coordinator.permissionService)
                .environmentObject(coordinator.featureRegistry)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.configStore)
                .environmentObject(coordinator.permissionService)
                .environmentObject(coordinator.featureRegistry)
        }
    }

    init() {
        // Coordinator starts after first frame
        DispatchQueue.main.async {
            // Handled via onAppear in MenuBarView
        }
    }
}
