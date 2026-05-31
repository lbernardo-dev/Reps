import SwiftUI

@main
struct RepsApp: App {
    @StateObject private var store = AppStore()

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
                }
        }
    }
}
