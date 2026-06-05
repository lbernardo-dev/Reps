import Combine
import SwiftUI
import UserNotifications

@MainActor
final class RepsApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        TelemetryService.shared.configure()
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        return true
    }
}

@main
struct RepsApp: App {
    @UIApplicationDelegateAdaptor(RepsApplicationDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        TelemetryService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: store.userProfile.preferredLanguage))
                .tint(PulseTheme.accent)
                .task {
                    PermissionService.shared.refreshAll()

                    if store.userProfile.onboardingCompleted,
                       store.userProfile.remindersEnabled {
                        _ = await PermissionService.shared.requestNotifications()
                        store.refreshNotificationSchedule()
                    }

                    store.syncWidgets()
                    TelemetryService.shared.updateUserProperties(store.userProfile)
                    TelemetryService.shared.log(.appOpen, parameters: [
                        "onboarding_completed": store.userProfile.onboardingCompleted,
                        "has_active_plan": !store.activePlan.days.isEmpty,
                        "session_count": store.workoutSessions.count,
                        "plan_count": store.plans.count
                    ])
                }
                .onReceive(NotificationRouter.shared.$latestTarget.compactMap { $0 }) { target in
                    store.handleNotificationTarget(target)
                    NotificationRouter.shared.consumeLatestTarget()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.syncWidgets()
                store.refreshNotificationSchedule()
            }
        }
    }
}
