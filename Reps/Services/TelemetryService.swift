import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

@MainActor
final class TelemetryService {
    static let shared = TelemetryService()

    private(set) var isConfigured = false
    private var didApplyFirebaseRuntimeSettings = false

    private init() {}

    func configure() {
        guard !Self.isDisabledForCurrentProcess else {
            isConfigured = false
            return
        }

        #if canImport(FirebaseCore)
        if !isConfigured, FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = FirebaseApp.app() != nil
        #else
        isConfigured = false
        #endif

        applyFirebaseRuntimeSettingsIfNeeded()

        #if canImport(FirebaseCrashlytics)
        if isConfigured {
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            Crashlytics.crashlytics().sendUnsentReports()
        }
        #endif
    }

    func updateUserProperties(_ profile: UserProfile) {
        ensureConfigured()
        guard isConfigured else { return }

        let properties: [String: String] = [
            "preferred_language": profile.preferredLanguage,
            "units": profile.units.rawValue,
            "main_goal": profile.mainGoal.rawValue,
            "training_location": profile.trainingLocation.rawValue,
            "theme_mode": profile.activeThemeMode.rawValue
        ]

        #if canImport(FirebaseAnalytics)
        properties.forEach { key, value in
            Analytics.setUserProperty(value, forName: key)
        }
        #endif

        #if canImport(FirebaseCrashlytics)
        properties.forEach { key, value in
            Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        }
        #endif
    }

    func log(_ event: TelemetryEvent, parameters: [String: Any?] = [:]) {
        ensureConfigured()
        guard isConfigured else { return }

        let sanitized = sanitize(parameters)

        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: sanitized)
        #endif

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(event.rawValue)
        sanitized.forEach { key, value in
            Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        }
        #endif
    }

    /// Writes a Crashlytics-only breadcrumb (no Analytics event). Use to trace
    /// fragile launch paths — the trail is attached to the next crash report,
    /// so a silent termination still tells us exactly how far execution got.
    func breadcrumb(_ message: String, _ values: [String: Any?] = [:]) {
        ensureConfigured()
        guard isConfigured else { return }

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        sanitize(values).forEach { key, value in
            Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        }
        #endif
    }

    /// Pins a long-lived custom key onto crash reports (e.g. launch_source).
    func setCrashKey(_ value: String, forKey key: String) {
        ensureConfigured()
        guard isConfigured else { return }

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }

    func record(_ error: Error, context: String, parameters: [String: Any?] = [:]) {
        ensureConfigured()
        guard isConfigured else { return }

        var sanitized = sanitize(parameters)
        sanitized["context"] = context

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error, userInfo: sanitized)
        #endif
    }

    func triggerTestCrash() -> Never {
        ensureConfigured()

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("debug_test_crash")
        #endif
        fatalError("Crashlytics debug test crash")
    }

    private func ensureConfigured() {
        guard !isConfigured else { return }
        configure()
    }

    private func applyFirebaseRuntimeSettingsIfNeeded() {
        guard isConfigured, !didApplyFirebaseRuntimeSettings else { return }
        didApplyFirebaseRuntimeSettings = true

        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let bundleID = bundle.bundleIdentifier ?? "unknown"

        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(true)
        Analytics.setDefaultEventParameters([
            "app_version": appVersion,
            "build_number": buildNumber,
            "bundle_id": bundleID
        ])
        #endif

        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(true)
        crashlytics.setCustomValue(appVersion, forKey: "app_version")
        crashlytics.setCustomValue(buildNumber, forKey: "build_number")
        crashlytics.setCustomValue(bundleID, forKey: "bundle_id")
        crashlytics.setCustomValue("reps-241f8", forKey: "firebase_project_id")
        #endif
    }

    private static var isDisabledForCurrentProcess: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["REPS_DISABLE_TELEMETRY"] == "1"
    }

    private func sanitize(_ parameters: [String: Any?]) -> [String: Any] {
        parameters.reduce(into: [:]) { result, item in
            guard !Self.isSensitiveParameterKey(item.key) else {
                return
            }
            guard let value = item.value else {
                return
            }

            switch value {
            case let string as String:
                result[item.key] = String(string.prefix(80))
            case let integer as Int:
                result[item.key] = integer
            case let double as Double:
                result[item.key] = double
            case let bool as Bool:
                result[item.key] = bool
            case let date as Date:
                result[item.key] = date.timeIntervalSince1970
            default:
                result[item.key] = String(describing: value).prefix(80).description
            }
        }
    }

    private static func isSensitiveParameterKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return [
            "email",
            "user_email",
            "display_name",
            "full_name",
            "alias",
            "username",
            "social_username"
        ].contains(normalized)
    }
}

enum TelemetryEvent: String {
    case appOpen = "app_open"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case planCreated = "plan_created"
    case planActivated = "plan_activated"
    case workoutStarted = "workout_started"
    case workoutFinished = "workout_finished"
    case workoutScheduled = "workout_scheduled"
    case bodyMetricSaved = "body_metric_saved"
    case goalCreated = "goal_created"
    case progressPhotoAdded = "progress_photo_added"
    case gymPassAdded = "gym_pass_added"
    case cardioLogAdded = "cardio_log_added"
    case backupExported = "backup_exported"
    case backupImported = "backup_imported"
    case csvExported = "csv_exported"
    case csvImported = "csv_imported"
    case allDataReset = "all_data_reset"
    case nonFatalError = "non_fatal_error"
    case mainTabSelected = "main_tab_selected"
    case quickMenuToggled = "quick_menu_toggled"
    case quickActionOpened = "quick_action_opened"
    case receiptDeepLinkImported = "receipt_deep_link_imported"
    case supportSheetOpened = "support_sheet_opened"
    case reviewPromptRequested = "review_prompt_requested"
    case feedbackSent = "feedback_sent"
    case paywallPresented = "paywall_presented"
    case paywallDismissed = "paywall_dismissed"
    case paywallCTASelected = "paywall_cta_selected"
    case paywallPlanSelected = "paywall_plan_selected"
    case paywallFeatureGateHit = "paywall_feature_gate_hit"
}
