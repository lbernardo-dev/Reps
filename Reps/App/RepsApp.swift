import CloudKit
import Combine
import SwiftUI
import UserNotifications

#if canImport(FirebaseCore)
import FirebaseCore
#endif

private enum FirebaseBootstrap {
    static func configureIfNeeded() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              ProcessInfo.processInfo.environment["REPS_DISABLE_TELEMETRY"] != "1" else {
            return
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }
}

@MainActor
final class RepsApplicationDelegate: NSObject, UIApplicationDelegate {
    override init() {
        FirebaseBootstrap.configureIfNeeded()
        super.init()
    }

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        TelemetryService.shared.configure()
        TelemetryService.shared.breadcrumb("app.did_finish_launching")
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        NotificationService.registerCategories()
        // Required for CloudKit subscription (silent) push delivery. This does
        // not prompt the user — the alert prompt is the separate authorization
        // request — it only obtains the APNs token CloudKit needs to route pushes.
        application.registerForRemoteNotifications()
        return true
    }

    // CloudKit silent-push / CKSubscription delivery — must be implemented or
    // the OS will throttle push delivery and may terminate the app on repeated failure.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // CloudKit subscriptions fire content-available (silent) pushes, which
        // show no banner on their own. Convert the recognised ones into a visible
        // local notification so the user actually sees "new follower" / "new like".
        TelemetryService.shared.breadcrumb("notif.did_receive_remote")
        if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo),
           let subscriptionID = ckNotification.subscriptionID {
            NotificationService.postCloudKitSocialNotification(subscriptionID: subscriptionID)
        }
        completionHandler(.newData)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

@main
struct RepsApp: App {
    @UIApplicationDelegateAdaptor(RepsApplicationDelegate.self) private var appDelegate
    @State private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseBootstrap.configureIfNeeded()
        TelemetryService.shared.configure()
        _store = State(initialValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: store.userProfile.preferredLanguage))
                .tint(PulseTheme.accent)
                .task {
                    RepsLocalization.use(store.userProfile.preferredLanguage)
                    PermissionService.shared.refreshAll()

                    if store.userProfile.onboardingCompleted,
                       store.userProfile.remindersEnabled {
                        _ = await PermissionService.shared.requestNotifications()
                        store.refreshNotificationSchedule()
                    }

                    store.syncWidgets()
                    store.refreshHealthKitDataIfNeeded(reason: "app_task")
                    TelemetryService.shared.updateUserProperties(store.userProfile)
                    TelemetryService.shared.log(.appOpen, parameters: [
                        "onboarding_completed": store.userProfile.onboardingCompleted,
                        "has_active_plan": !store.activePlan.days.isEmpty,
                        "session_count": store.workoutSessions.count,
                        "plan_count": store.plans.count
                    ])
                }
                .onReceive(NotificationRouter.shared.$latestTarget.compactMap { $0 }) { target in
                    TelemetryService.shared.breadcrumb("notif.on_receive_target", [
                        "kind": target.kind.rawValue,
                        "action": String(describing: target.action)
                    ])
                    store.handleNotificationTarget(target)
                    NotificationRouter.shared.consumeLatestTarget()
                }
                .onOpenURL { url in
                    if store.handleSocialDeepLink(url) { return }
                    _ = store.handleReceiptDeepLink(url)
                }
                .onChange(of: store.userProfile.preferredLanguage) { _, language in
                    RepsLocalization.use(language)
                    store.syncWidgets()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                store.flushPendingSave()
            }
            if newPhase == .active {
                store.syncWidgets()
                store.refreshNotificationSchedule()
                store.refreshHealthKitDataIfNeeded(reason: "foreground")
                Task {
                    store.runEngagementChecks()
                    await store.refreshStoreKitEntitlements()
                    await store.refreshICloudProEntitlement()
                    if let uname = store.userProfile.socialUsername, store.userProfile.socialEnabled {
                        await SocialService.shared.pingActivity(myUsername: uname)
                        await store.flushPendingComments()
                    }
                }
            }
        }
    }
}
