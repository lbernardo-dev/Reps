import CloudKit
import Combine
import RevenueCat
import SwiftUI
import UserNotifications

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@MainActor
private enum FirebaseBootstrap {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              ProcessInfo.processInfo.environment["REPS_DISABLE_TELEMETRY"] != "1" else {
            return
        }

        #if canImport(FirebaseCore)
        if !didConfigure {
            FirebaseApp.configure()
            didConfigure = true
        }
        #endif
    }
}

private enum RevenueCatBootstrap {
    static func configureIfNeeded() {
        guard !Purchases.isConfigured,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfiguration.apiKey)
    }
}

@MainActor
final class RepsApplicationDelegate: NSObject, UIApplicationDelegate {
    override init() {
        FirebaseBootstrap.configureIfNeeded()
        RevenueCatBootstrap.configureIfNeeded()
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
        MetricsDiagnosticsService.shared.start()
        RevenueCatBootstrap.configureIfNeeded()
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
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              let subscriptionID = ckNotification.subscriptionID else {
            completionHandler(.noData)
            return
        }
        NotificationService.postCloudKitSocialNotification(subscriptionID: subscriptionID)

        // The banner above is transient (system notification center only) — also
        // resolve who actually followed/liked and persist a durable in-app
        // activity entry so it still shows up in the Notifications tab after
        // the banner is dismissed, with a working link to their profile.
        guard let queryNotification = ckNotification as? CKQueryNotification,
              let recordID = queryNotification.recordID else {
            completionHandler(.noData)
            return
        }
        Task {
            if let actor = await SocialService.shared.resolveActivityActor(recordID: recordID) {
                let event: NotificationEvent = switch actor.kind {
                case "follow":
                    NotificationEvent(
                        icon: "person.badge.plus",
                        colorName: "primaryBright",
                        title: localizedString("notif_new_follower_title"),
                        subtitle: "@\(actor.username)",
                        date: .now,
                        destination: .socialProfile(username: actor.username)
                    )
                case "comment":
                    NotificationEvent(
                        icon: "bubble.left.fill",
                        colorName: "primaryBright",
                        title: localizedString("notif_new_comment_title"),
                        subtitle: "@\(actor.username)",
                        date: .now,
                        destination: .socialProfile(username: actor.username)
                    )
                default: // "like"
                    NotificationEvent(
                        icon: "heart.fill",
                        colorName: "orange",
                        title: localizedString("notif_new_like_title"),
                        subtitle: "@\(actor.username)",
                        date: .now,
                        destination: .socialProfile(username: actor.username)
                    )
                }
                AppStore.persistActivityEventFromBackground(event)
            }
            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

@main
struct RepsApp: App {
    @UIApplicationDelegateAdaptor(RepsApplicationDelegate.self) private var appDelegate
    @State private var store: AppStore
    @State private var didRunStartupTask = false
    @State private var didHandleInitialActivePhase = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseBootstrap.configureIfNeeded()
        RevenueCatBootstrap.configureIfNeeded()
        TelemetryService.shared.configure()
        MetricsDiagnosticsService.shared.start()
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        _store = State(initialValue: AppStore(startsBackgroundServices: false))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: store.userProfile.preferredLanguage))
                .tint(PulseTheme.accent)
                .task {
                    guard !didRunStartupTask else { return }
                    didRunStartupTask = true

                    #if DEBUG || targetEnvironment(simulator)
                    if ProcessInfo.processInfo.arguments.contains("-loadPremiumDemoData") {
                        store.loadPremiumDemoDataForDebug()
                    }
                    if let demoLanguage = Self.demoLanguageFromLaunchArguments() {
                        store.userProfile.preferredLanguage = demoLanguage
                    }
                    #endif

                    RepsLocalization.use(store.userProfile.preferredLanguage)
                    PermissionService.shared.refreshAll()
                    await Task.yield()
                    store.startBackgroundServicesIfNeeded()

                    if store.userProfile.onboardingCompleted,
                       store.userProfile.remindersEnabled {
                        _ = await PermissionService.shared.requestNotifications()
                        store.refreshNotificationSchedule()
                    }

                    store.syncWidgets()
                    store.refreshHealthKitDataIfNeeded(reason: "app_task")
                    drainNotificationTargets()
                    TelemetryService.shared.updateUserProperties(store.userProfile)
                    TelemetryService.shared.log(.appOpen, parameters: [
                        "onboarding_completed": store.userProfile.onboardingCompleted,
                        "has_active_plan": !store.activePlan.days.isEmpty,
                        "session_count": store.workoutSessions.count,
                        "plan_count": store.plans.count
                    ])
                }
                .onReceive(NotificationCenter.default.publisher(for: .repsNotificationTargetReady)) { _ in
                    drainNotificationTargets()
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
                guard didHandleInitialActivePhase else {
                    didHandleInitialActivePhase = true
                    return
                }
                store.handleForegroundActivation(drainNotificationTargets: drainNotificationTargets)
            }
        }
    }

    @MainActor
    private func drainNotificationTargets() {
        let targets = NotificationRouter.shared.drainPendingTargets()
        for target in targets {
            TelemetryService.shared.breadcrumb("notif.drain_target", [
                "kind": target.kind.rawValue,
                "action": String(describing: target.action)
            ])
            store.handleNotificationTarget(target)
        }
    }

    #if DEBUG || targetEnvironment(simulator)
    private static func demoLanguageFromLaunchArguments() -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoLanguage"),
              arguments.indices.contains(arguments.index(after: index))
        else {
            return nil
        }
        let value = arguments[arguments.index(after: index)].lowercased()
        switch value {
        case "en", "en-us":
            return "en"
        case "es", "es-es":
            return "es"
        default:
            return nil
        }
    }
    #endif
}
