import SwiftUI

@main
struct ClaudeWindowApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            if appState.settings.onboardingComplete {
                DropdownView()
                    .environmentObject(appState)
            } else {
                OnboardingView()
                    .environmentObject(appState)
            }
        } label: {
            MenuBarIconView(state: appState.primaryScore?.state ?? .unknown)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
