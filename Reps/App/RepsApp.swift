import SwiftUI
import WidgetKit

@main
struct RepsApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: store.userProfile.preferredLanguage))
                .tint(PulseTheme.primary)
                .task {
                    // Refresh cached permission state on each launch.
                    PermissionService.shared.refreshAll()

                    // Request notification permission for returning users who
                    // have reminders enabled but never granted them.
                    if store.userProfile.onboardingCompleted,
                       store.userProfile.remindersEnabled {
                        _ = await PermissionService.shared.requestNotifications()
                    }

                    // Ensure widgets have fresh data immediately on launch.
                    store.syncWidgets()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Push a fresh snapshot every time the app comes to foreground
                // so widgets are always in sync when the user returns to home screen.
                store.syncWidgets()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

