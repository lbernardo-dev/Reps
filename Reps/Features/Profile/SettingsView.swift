import SwiftUI
import StoreKit
import UIKit

private enum SettingsLegalLinks {
    static var privacyPolicy: String { RepsLegalUrls.privacyPolicy }
    static var termsOfService: String { RepsLegalUrls.termsOfService }
    static var subscriptionTerms: String { RepsLegalUrls.subscriptionTerms }
    static var support: String { RepsLegalUrls.support }
    static var faq: String { RepsLegalUrls.faq }
}

private enum SettingsTypography {
    static let appTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 19, weight: .bold, design: .rounded)
    static let rowTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let rowSubtitle = Font.system(size: 14, weight: .regular, design: .rounded)
    static let metadataLabel = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let metadataValue = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let pill = Font.system(size: 12, weight: .bold, design: .rounded)
    static let buttonTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let footerTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    static let footerBody = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let footerCaption = Font.system(size: 13, weight: .regular, design: .rounded)
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(AppStore.self) private var store

    @State private var activeDestination: SettingsDestination?
    @State private var activeSheet: SettingsSheet?
    @State private var localPaywall: PaywallPresentation?
    @State private var hasCopiedUserID = false

    var body: some View {
        StickyHeaderScaffold(
            title: "settings",
            subtitle: "app_training_and_permissions",
            bottomContentPadding: 8,
            showsGlobalActions: false,
            accessory: {
                HStack(spacing: 10) {
                    SettingsTodayHeaderButton()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PulseTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .destructiveGlassCircle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizedString("close_settings"))
                }
            }
        ) {
            appSummaryCard
                .stickyHeaderTitle("StreakReps")
            licenseCard
                .stickyHeaderTitle(localizedString("subscription"))
            settingsSection("health_data", systemImage: "heart.fill") {
                SettingsNavigationRow(
                    title: "apple_health",
                    subtitle: store.health.isAuthorized ? "connected_to_apple_health" : "not_connected_to_apple_health",
                    systemImage: "heart.fill",
                    tint: .red
                ) { activeDestination = .appleHealth }
            }
            .stickyHeaderTitle(localizedString("apple_health"))
            settingsSection("personalization", systemImage: "slider.horizontal.3") {
                SettingsNavigationRow(
                    title: "app_preferences",
                    subtitle: "language_theme_and_interface",
                    systemImage: "paintbrush.fill",
                    tint: PulseTheme.accent
                ) { activeDestination = .appPreferences }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "measurement",
                    subtitle: "units_distance_and_training_defaults",
                    systemImage: "ruler.fill",
                    tint: .green
                ) { activeDestination = .measurement }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "workout_session",
                    subtitle: "confirmations_advanced_logging_and_equipment",
                    systemImage: "figure.strengthtraining.traditional",
                    tint: .orange
                ) { activeDestination = .workoutSession }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "widgets",
                    subtitle: "home_screen_watch_and_live_activity_style",
                    systemImage: "square.grid.2x2.fill",
                    tint: .blue
                ) { activeDestination = .widgets }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "workout_reminders",
                    subtitle: "alerts_for_scheduled_sessions_and_consistency",
                    systemImage: "bell.badge.fill",
                    tint: .purple
                ) { activeDestination = .reminders }
            }
            .stickyHeaderTitle(settingsDisplayText("personalization"))

            settingsSection("feedback", systemImage: "bubble.left.and.text.bubble.right.fill") {
                SettingsNavigationRow(
                    title: "send_feedback",
                    subtitle: "tell_us_what_to_improve",
                    systemImage: "envelope.fill",
                    tint: PulseTheme.accent
                ) { activeSheet = .feedback }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "rate_app",
                    subtitle: "request_review",
                    systemImage: "star.fill",
                    tint: .yellow
                ) {
                    TelemetryService.shared.log(.reviewPromptRequested)
                    requestReview()
                }
            }
            .stickyHeaderTitle(localizedString("feedback"))

            settingsSection("about", systemImage: "info.circle.fill") {
                SettingsNavigationRow(
                    title: "information_disclaimer",
                    subtitle: "how_reps_uses_data_permissions_and_health_context",
                    systemImage: "info.circle.fill",
                    tint: PulseTheme.accent
                ) { activeDestination = .information }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "whats_new",
                    subtitle: "included_improvements",
                    systemImage: "sparkles",
                    tint: .teal
                ) { activeDestination = .whatsNew }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "privacy_policy",
                    subtitle: "privacy_policy_subtitle",
                    systemImage: "hand.raised.fill",
                    tint: .indigo
                ) { openLegalURL(SettingsLegalLinks.privacyPolicy, event: "privacy_policy") }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "terms_of_service",
                    subtitle: "terms_of_service_subtitle",
                    systemImage: "doc.text.fill",
                    tint: .gray
                ) { openLegalURL(SettingsLegalLinks.termsOfService, event: "terms_of_service") }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "subscription_terms",
                    subtitle: "subscription_terms_subtitle",
                    systemImage: "doc.badge.gearshape.fill",
                    tint: .gray
                ) { openLegalURL(SettingsLegalLinks.subscriptionTerms, event: "subscription_terms") }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "support",
                    subtitle: "support_subtitle",
                    systemImage: "questionmark.bubble.fill",
                    tint: .blue
                ) { openLegalURL(SettingsLegalLinks.support, event: "support") }
                SettingsDivider()
                SettingsNavigationRow(
                    title: "faq",
                    subtitle: "faq_subtitle",
                    systemImage: "questionmark.circle.fill",
                    tint: .orange
                ) { openLegalURL(SettingsLegalLinks.faq, event: "faq") }
            }
            .stickyHeaderTitle(settingsDisplayText("about"))

            #if DEBUG && targetEnvironment(simulator)
            settingsSection("advanced", systemImage: "wrench.and.screwdriver.fill") {
                SettingsNavigationRow(
                    title: "developer_tools",
                    subtitle: "dev_menu_subtitle",
                    systemImage: "hammer.fill",
                    tint: PulseTheme.secondaryText
                ) { activeDestination = .developerMenu }
            }
            .stickyHeaderTitle(settingsDisplayText("advanced"))
            #endif

            settingsSignature
                .stickyHeaderTitle(localizedString("version_label"))
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .quickActionAccessoryHidden()
        .navigationDestination(item: $activeDestination) { destination in
            settingsDestination(destination)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .feedback:
                SettingsFeedbackSheet { message in
                    sendFeedback(message)
                }
                .repsSheetPresentation()
            case .subscription:
                SubscriptionCenterView()
                    .environment(store)
                    .repsSheetPresentation()
            }
        }
        .fullScreenCover(item: $localPaywall) { presentation in
            PaywallView(presentation: presentation) { reason in
                store.trackPaywallDismissal(presentation, reason: reason)
                localPaywall = nil
            }
            .environment(store)
        }
    }

    private var appSummaryCard: some View {
        PulseCard(contentPadding: 0, backgroundColor: PulseTheme.card) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image("StreakRepHeroIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: PulseTheme.surfaceShadow, radius: 10, x: 0, y: 5)

                    VStack(alignment: .leading, spacing: 6) {
                        SettingsPill(title: settingsFormatText("settings_version_value_format", appVersion), systemImage: "info.circle.fill", tint: PulseTheme.accent)
                        SettingsPill(title: settingsFormatText("settings_build_value_format", buildNumber), systemImage: "hammer.fill", tint: PulseTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)

                Divider()
                    .overlay(PulseTheme.separator)
                    .padding(.horizontal, 18)

                HStack(spacing: 0) {
                    SettingsSummaryMetric(
                        title: "member_since",
                        value: formattedDate(memberSinceDate),
                        systemImage: "calendar",
                        tint: .green
                    )
                    Divider()
                        .overlay(PulseTheme.separator)
                        .frame(height: 54)
                    SettingsSummaryMetric(
                        title: "last_active",
                        value: formattedDate(lastActiveDate),
                        systemImage: "clock.fill",
                        tint: PulseTheme.accent
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                HStack(spacing: 12) {
                        Image(systemName: "person.text.rectangle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(settingsDisplayText("user_id_label"))
                        .font(SettingsTypography.rowSubtitle.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(shortUserID)
                        .font(SettingsTypography.rowSubtitle.monospaced())
                        .foregroundStyle(PulseTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Button {
                        UIPasteboard.general.string = userID
                        HapticService.notification(.success)
                        withAnimation(.snappy(duration: 0.25)) {
                            hasCopiedUserID = true
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(.snappy(duration: 0.25)) {
                                hasCopiedUserID = false
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if hasCopiedUserID {
                                Text(settingsDisplayText("user_id_copied"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                            Image(systemName: hasCopiedUserID ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(hasCopiedUserID ? .green : PulseTheme.accent)
                                .scaleEffect(hasCopiedUserID ? 1.18 : 1.0)
                        }
                        .padding(.horizontal, hasCopiedUserID ? 10 : 8)
                        .padding(.vertical, 6)
                        .background(hasCopiedUserID ? Color.green.opacity(0.15) : Color.clear, in: Capsule())
                        .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(PulseTheme.grouped.opacity(0.72))
            }
        }
    }

    private var licenseCard: some View {
        PulseCard(contentPadding: 18, backgroundColor: PulseTheme.card) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    PulseIconBadge(systemImage: "crown.fill", tint: store.monetization.hasProAccess ? PulseTheme.accent : .orange, size: 52, radius: 16, isFilled: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.monetization.hasProAccess ? store.monetization.statusLabel : settingsDisplayText("unlock_premium"))
                            .font(SettingsTypography.cardTitle)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(store.monetization.hasProAccess ? localizedString("pro_access_active_on_device") : settingsDisplayText("unlock_pro_features_and_advanced_data"))
                            .font(SettingsTypography.rowSubtitle)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    if store.monetization.hasProAccess {
                        activeSheet = .subscription
                    } else {
                        localPaywall = store.makePaywallPresentation(source: .profileSubscription, feature: nil)
                    }
                } label: {
                    Text(settingsDisplayText(store.monetization.hasProAccess ? "manage_subscription" : "view_options"))
                        .font(SettingsTypography.buttonTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var settingsSignature: some View {
        VStack(spacing: 8) {
            Text(settingsFormatText("settings_app_version_format", "StreakReps", appVersion))
                .font(SettingsTypography.footerTitle)
                .foregroundStyle(PulseTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(settingsFormatText("settings_app_build_format", buildNumber))
                .font(SettingsTypography.footerBody)
                .foregroundStyle(PulseTheme.secondaryText)
                .multilineTextAlignment(.center)
            Text(settingsDisplayText("designed_and_developed_by_romerodev"))
                .font(SettingsTypography.footerBody)
                .foregroundStyle(PulseTheme.secondaryText)
                .multilineTextAlignment(.center)
            Text(settingsDisplayText("all_rights_reserved"))
                .font(SettingsTypography.footerCaption)
                .foregroundStyle(PulseTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 0)
    }

    private func settingsSection<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(settingsDisplayText(title).uppercased(with: RepsLocalization.locale))
            } icon: {
                Image(systemName: systemImage)
            }
            .font(SettingsTypography.sectionTitle)
            .foregroundStyle(PulseTheme.secondaryText)
            .padding(.horizontal, 20)
            .accessibilityAddTraits(.isHeader)

            PulseCard(contentPadding: 0, backgroundColor: PulseTheme.card) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    @ViewBuilder
    private func settingsDestination(_ destination: SettingsDestination) -> some View {
        switch destination {
        case .appPreferences:
            AppPreferencesSettingsScreen()
        case .measurement:
            MeasurementSettingsScreen()
        case .workoutSession:
            WorkoutSessionSettingsScreen { presentation in
                localPaywall = presentation
            }
        case .widgets:
            WidgetSettingsScreen()
        case .reminders:
            ReminderSettingsScreen()
        case .appleHealth:
            AppleHealthSettingsScreen()
        case .information:
            SettingsInfoScreen(
                title: "information_disclaimer",
                systemImage: "info.circle.fill",
                sections: [
                    SettingsInfoSection(title: "data", rows: [
                        "reps_stores_workouts_routines_metrics_photos_and_cards_locally",
                        "apple_health_only_used_if_connected",
                        "photos_camera_music_notifications_and_location_requested_when_used"
                    ]),
                    SettingsInfoSection(title: "permissions", rows: [
                        "widgets_read_minimum_summary_from_app_group",
                        "app_records_minimum_product_events_for_stability",
                        "no_workout_names_notes_photos_or_health_data_sent_to_analytics"
                    ])
                ]
            )
        case .whatsNew:
            SettingsInfoScreen(
                title: "whats_new",
                systemImage: "sparkles",
                sections: [
                    SettingsInfoSection(title: "training", rows: [
                        "ready_routines_with_days_exercises_sets_rests_and_progression",
                        "free_log_with_notes_photos_water_rpe_rir_tempo_and_rests",
                        "final_summary_with_volume_records_and_visual_receipts"
                    ]),
                    SettingsInfoSection(title: "integrations", rows: [
                        "apple_health_imports_metrics_and_saves_workouts_with_permission",
                        "widgets_watch_and_live_activities_follow_session_outside_app",
                        "apple_music_plays_playlists_during_workouts"
                    ])
                ]
            )
        #if DEBUG && targetEnvironment(simulator)
        case .developerMenu:
            DeveloperMenuView()
        #endif
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var appVersionText: String {
        "\(appVersion) (\(buildNumber))"
    }

    private var userID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? Bundle.main.bundleIdentifier ?? "com.romerodev.repsfitness"
    }

    private var shortUserID: String {
        guard userID.count > 18 else { return userID }
        return "\(userID.prefix(8))...\(userID.suffix(10))"
    }

    private var memberSinceDate: Date {
        let dates = store.workoutSessions.map(\.date)
            + store.cardioLogs.map(\.date)
            + store.bodyMetrics.map(\.date)
            + store.progressPhotos.map(\.date)
            + store.gymVisits.map(\.date)
            + store.gymPasses.compactMap(\.startDate)
        return dates.min() ?? .now
    }

    private var lastActiveDate: Date {
        let dates = store.workoutSessions.map { $0.endedAt ?? $0.startedAt ?? $0.date }
            + store.cardioLogs.map(\.date)
            + store.bodyMetrics.map(\.date)
            + store.progressPhotos.map(\.date)
            + store.gymVisits.map(\.date)
        return dates.max() ?? .now
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
                .hour()
                .minute()
                .locale(RepsLocalization.locale)
        )
    }

    private func openLegalURL(_ urlString: String, event: String) {
        TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": event])
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private func sendFeedback(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            store.health.message = localizedString("feedback_empty_error")
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "romerodev.app+streakreps@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Feedback StreakReps \(appVersionText)"),
            URLQueryItem(name: "body", value: trimmed)
        ]

        if let url = components.url {
            TelemetryService.shared.log(.feedbackSent, parameters: [
                "length_bucket": min(trimmed.count / 100, 9)
            ])
            openURL(url)
            activeSheet = nil
        } else {
            store.health.message = localizedString("feedback_prepare_error")
        }
    }
}

private enum SettingsDestination: String, Identifiable {
    case appPreferences
    case measurement
    case workoutSession
    case widgets
    case reminders
    case appleHealth
    case information
    case whatsNew
    #if DEBUG && targetEnvironment(simulator)
    case developerMenu
    #endif

    var id: String { rawValue }
}

private enum SettingsSheet: String, Identifiable {
    case feedback
    case subscription
    var id: String { rawValue }
}

private struct AppPreferencesSettingsScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        return SettingsDetailScaffold(title: "app_preferences", systemImage: "paintbrush.fill") {
            SettingsControlCard(title: "language", systemImage: "globe") {
                Picker(localizedString("language"), selection: $store.userProfile.preferredLanguage) {
                    Text("english").tag("en")
                    Text("spanish").tag("es")
                }
                .pickerStyle(.segmented)
            }

            SettingsControlCard(title: "theme", systemImage: "circle.lefthalf.filled") {
                Picker(localizedString("theme"), selection: Binding(
                    get: { store.userProfile.activeThemeMode },
                    set: { mode in
                        store.userProfile.themeMode = mode
                        HapticService.selection()
                    }
                )) {
                    ForEach(UserProfile.ThemeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct MeasurementSettingsScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        return SettingsDetailScaffold(title: "measurement", systemImage: "ruler.fill") {
            SettingsControlCard(title: "units_2", systemImage: "scalemass.fill") {
                Picker(localizedString("units_2"), selection: $store.userProfile.units) {
                    ForEach(UserProfile.Units.allCases) { units in
                        Text(units.rawValue).tag(units)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsControlCard(title: "distance_3", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                Picker(localizedString("distance_3"), selection: $store.userProfile.distanceUnit) {
                    ForEach(UserProfile.DistanceUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct WorkoutSessionSettingsScreen: View {
    @Environment(AppStore.self) private var store
    var onShowPaywall: (PaywallPresentation) -> Void

    var body: some View {
        @Bindable var store = store
        return SettingsDetailScaffold(title: "workout_session", systemImage: "figure.strengthtraining.traditional") {
            SettingsControlCard(title: "confirm_before_ending_workout", systemImage: "checkmark.shield.fill") {
                Toggle(localizedString("confirm_before_ending_workout"), isOn: $store.userProfile.confirmBeforeEndingWorkout)
                    .font(SettingsTypography.rowTitle)
                    .tint(PulseTheme.accent)
                Text(localizedString("confirm_before_ending_workout_subtitle"))
                    .font(SettingsTypography.rowSubtitle)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            SettingsControlCard(title: "audible_workout_cues", systemImage: "speaker.wave.2.fill") {
                Toggle(localizedString("audible_workout_cues"), isOn: Binding(
                    get: { store.userProfile.audibleWorkoutCuesEnabled },
                    set: { enabled in
                        store.userProfile.audibleWorkoutCuesEnabled = enabled
                        HapticService.selection()
                        TimerSoundCue.phaseChange(enabled: enabled)
                    }
                ))
                .font(SettingsTypography.rowTitle)
                .tint(PulseTheme.accent)
                Text(localizedString("audible_workout_cues_subtitle"))
                    .font(SettingsTypography.rowSubtitle)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            NavigationLink {
                ProPreferencesView(onShowPaywall: onShowPaywall)
            } label: {
                SettingsRowContent(
                    title: "pro_preferences",
                    subtitle: "pro_preferences_subtitle",
                    systemImage: "slider.horizontal.3",
                    tint: PulseTheme.accent
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private func colorForWidgetName(_ name: String) -> Color {
    switch name {
    case "blue": return .blue
    case "green": return Color(red: 0.2, green: 0.85, blue: 0.45)
    case "orange": return .orange
    case "purple": return .purple
    case "red": return .red
    case "yellow": return .yellow
    default: return PulseTheme.accent
    }
}

private struct WidgetSettingsScreen: View {
    @Environment(AppStore.self) private var store
    private let widgetColors = ["system", "blue", "green", "orange", "purple", "red", "yellow"]
    @State private var workoutWidgetSize = "small"
    @State private var streakWidgetSize = "medium"
    @State private var batteryMetricFocus = "readiness"
    @State private var showFriendsActivity = true
    @State private var liveActivityRestTimer = true

    var body: some View {
        SettingsDetailScaffold(title: "widgets", systemImage: "square.grid.2x2.fill") {
            // Master Color & Sync Card
            SettingsControlCard(title: "widget_color", systemImage: "paintpalette.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(settingsDisplayText("global_accent_color"))
                            .font(SettingsTypography.rowTitle)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Spacer()
                        Picker(localizedString("widget_color"), selection: Binding(
                            get: { store.userProfile.widgetAccentColorName },
                            set: { colorName in
                                store.userProfile.widgetAccentColorName = colorName
                                store.syncWidgets()
                                HapticService.selection()
                            }
                        )) {
                            ForEach(widgetColors, id: \.self) { colorName in
                                Text(settingsDisplayText("color_\(colorName)")).tag(colorName)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(PulseTheme.accent)
                    }

                    Button {
                        store.syncWidgets()
                        HapticService.notification(.success)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(settingsDisplayText("sync_widgets"))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(PulseTheme.accent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text(settingsDisplayText("widgets_watch_and_live_activities_follow_session_outside_app"))
                        .font(SettingsTypography.rowSubtitle)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            // Section Header: Previews & Independent Customization
            Text(settingsDisplayText("widget_previews_and_customization"))
                .font(SettingsTypography.sectionTitle)
                .foregroundStyle(PulseTheme.textPrimary)
                .padding(.top, 8)

            // 1. Workout Widget Preview & Settings
            WidgetPreviewCard(
                title: settingsDisplayText("workout_widget"),
                subtitle: settingsDisplayText("workout_widget_desc"),
                systemImage: "bolt.fill",
                accentColor: colorForWidgetName(store.userProfile.widgetAccentColorName)
            ) {
                WorkoutWidgetPreviewView(
                    routineName: store.activePlan.days.first?.title ?? "Push & Core Power",
                    exerciseCount: 5,
                    color: colorForWidgetName(store.userProfile.widgetAccentColorName),
                    size: workoutWidgetSize
                )
            } controls: {
                HStack {
                    Text(settingsDisplayText("widget_size"))
                        .font(SettingsTypography.rowTitle)
                        .foregroundStyle(PulseTheme.textPrimary)
                    Spacer()
                    Picker("Size", selection: $workoutWidgetSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }

            // 2. Streak & Consistency Widget Preview & Settings
            WidgetPreviewCard(
                title: settingsDisplayText("streak_widget"),
                subtitle: settingsDisplayText("streak_widget_desc"),
                systemImage: "flame.fill",
                accentColor: .orange
            ) {
                StreakWidgetPreviewView(
                    streakDays: max(store.streakDays, 7),
                    color: colorForWidgetName(store.userProfile.widgetAccentColorName),
                    size: streakWidgetSize
                )
            } controls: {
                HStack {
                    Text(settingsDisplayText("widget_size"))
                        .font(SettingsTypography.rowTitle)
                        .foregroundStyle(PulseTheme.textPrimary)
                    Spacer()
                    Picker("Size", selection: $streakWidgetSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }

            // 3. Battery & Recovery Widget Preview & Settings
            WidgetPreviewCard(
                title: settingsDisplayText("battery_widget"),
                subtitle: settingsDisplayText("battery_widget_desc"),
                systemImage: "battery.100.bolt",
                accentColor: .green
            ) {
                BatteryWidgetPreviewView(
                    batteryLevel: 88,
                    statusText: "Optimal Readiness",
                    color: colorForWidgetName(store.userProfile.widgetAccentColorName)
                )
            } controls: {
                HStack {
                    Text(settingsDisplayText("primary_metric"))
                        .font(SettingsTypography.rowTitle)
                        .foregroundStyle(PulseTheme.textPrimary)
                    Spacer()
                    Picker("Metric", selection: $batteryMetricFocus) {
                        Text("Readiness").tag("readiness")
                        Text("HRV").tag("hrv")
                        Text("Sleep").tag("sleep")
                    }
                    .pickerStyle(.menu)
                    .tint(PulseTheme.accent)
                }
            }

            // 4. Live Activity & Dynamic Island Preview & Settings
            WidgetPreviewCard(
                title: settingsDisplayText("live_activity_preview"),
                subtitle: settingsDisplayText("live_activity_desc"),
                systemImage: "waveform.path.ecg",
                accentColor: PulseTheme.accent
            ) {
                LiveActivityPreviewView(
                    exerciseName: "Bench Press",
                    setInfo: "Set 3 of 4 · 80 kg",
                    timeText: "42:15",
                    color: colorForWidgetName(store.userProfile.widgetAccentColorName)
                )
            } controls: {
                Toggle(settingsDisplayText("show_rest_timer_live_activity"), isOn: $liveActivityRestTimer)
                    .font(SettingsTypography.rowTitle)
                    .tint(PulseTheme.accent)
            }
        }
    }
}

// MARK: - Widget Preview Container & Preview Layouts

private struct WidgetPreviewCard<Preview: View, Controls: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        PulseCard(contentPadding: 16, backgroundColor: PulseTheme.card) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    PulseIconBadge(systemImage: systemImage, tint: accentColor, size: 36, radius: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(SettingsTypography.cardTitle)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(subtitle)
                            .font(SettingsTypography.rowSubtitle)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                // Interactive Live Preview Container
                VStack {
                    preview()
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                Divider()
                    .background(Color.white.opacity(0.1))

                controls()
            }
        }
    }
}

private struct WorkoutWidgetPreviewView: View {
    let routineName: String
    let exerciseCount: Int
    let color: Color
    let size: String

    var body: some View {
        if size == "medium" {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(color)
                        Text("TODAY'S WORKOUT")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(color)
                    }
                    Text(routineName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(exerciseCount) exercises · ~45 min")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "play.fill")
                        .font(.headline)
                        .foregroundStyle(color)
                }
                .frame(width: 54, height: 54)
            }
            .padding(14)
            .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(color)
                    Spacer()
                    Text("READY")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2), in: Capsule())
                        .foregroundStyle(color)
                }
                Text(routineName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text("\(exerciseCount) EXERCISES")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(12)
            .frame(width: 140, height: 130)
            .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct StreakWidgetPreviewView: View {
    let streakDays: Int
    let color: Color
    let size: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "flame.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakDays) DAY STREAK")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Text("Consistent & On Track")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Circle()
                        .fill(day == "S" || day == "F" ? color : color.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(12)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BatteryWidgetPreviewView: View {
    let batteryLevel: Int
    let statusText: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "battery.100.bolt")
                        .foregroundStyle(color)
                    Text("ENERGY & RECOVERY")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(color)
                }
                Text("\(batteryLevel)%")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(color.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(height: geometry.size.height * (CGFloat(batteryLevel) / 100.0))
                }
            }
            .frame(width: 14, height: 50)
        }
        .padding(12)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LiveActivityPreviewView: View {
    let exerciseName: String
    let setInfo: String
    let timeText: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(color)
                    Text("Reps")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(timeText)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))

            HStack(spacing: 12) {
                PulseIconBadge(systemImage: "bolt.fill", tint: color, size: 36, radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exerciseName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(setInfo)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text(timeText)
                    .font(.title3.weight(.black).monospacedDigit())
                    .foregroundStyle(color)
            }
            .padding(12)
            .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct ReminderSettingsScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        SettingsDetailScaffold(title: "workout_reminders", systemImage: "bell.badge.fill") {
            SettingsControlCard(title: "workout_reminders", systemImage: "bell.fill") {
                Toggle(localizedString("workout_reminders"), isOn: Binding(
                    get: { store.userProfile.remindersEnabled },
                    set: { enabled in
                        store.userProfile.remindersEnabled = enabled
                        HapticService.selection()
                        if enabled {
                            Task { await enableReminders() }
                        } else {
                            NotificationService.clearWorkoutReminders()
                        }
                    }
                ))
                .font(SettingsTypography.rowTitle)
                .tint(PulseTheme.accent)

                Text(localizedString("enable_alerts_for_scheduled_sessions_and_consistency_nudges"))
                    .font(SettingsTypography.rowSubtitle)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }

    private func enableReminders() async {
        do {
            let granted = try await NotificationService.requestAuthorization()
            guard granted else {
                store.userProfile.remindersEnabled = false
                return
            }
            store.refreshNotificationSchedule()
        } catch {
            store.userProfile.remindersEnabled = false
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "settings_notifications_enable")
        }
    }
}

struct ProPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    var onShowPaywall: ((PaywallPresentation) -> Void)?
    private let equipmentOptions = ["Barbell", "Dumbbells", "Kettlebell", "Resistance Band", "Cable", "Machine", "Bench", "Rack", "Pullup Bar", "Cardio Machine"]

    var body: some View {
        @Bindable var store = store
        return NavigationStack {
            Group {
                if store.hasFeatureAccess(.configurableProgression) {
                    Form {
                        Section("logging_avanzado") {
                            Toggle("mark_all", isOn: Binding(
                                get: {
                                    store.userProfile.showRPE &&
                                    store.userProfile.showRIR &&
                                    store.userProfile.showSetType &&
                                    store.userProfile.showTempo &&
                                    store.userProfile.autoProgressionEnabled
                                },
                                set: { selectAll in
                                    store.userProfile.showRPE = selectAll
                                    store.userProfile.showRIR = selectAll
                                    store.userProfile.showSetType = selectAll
                                    store.userProfile.showTempo = selectAll
                                    store.userProfile.autoProgressionEnabled = selectAll
                                }
                            ))
                            .font(SettingsTypography.rowTitle)
                            .foregroundStyle(PulseTheme.accent)

                            Toggle("show_rpe", isOn: $store.userProfile.showRPE)
                            Toggle("show_rir", isOn: $store.userProfile.showRIR)
                            Toggle("show_series_type", isOn: $store.userProfile.showSetType)
                            Toggle("show_tempo", isOn: $store.userProfile.showTempo)
                            Toggle("auto_progression", isOn: $store.userProfile.autoProgressionEnabled)
                            Stepper(
                                settingsFormatText("weight_increment_kg_format", store.userProfile.weightIncrementKg),
                                value: $store.userProfile.weightIncrementKg,
                                in: 0.5...10,
                                step: 0.5
                            )
                        }

                        Section("equipamiento_disponible") {
                            Toggle("mark_all", isOn: Binding(
                                get: {
                                    equipmentOptions.allSatisfy { store.userProfile.availableEquipment.contains($0) }
                                },
                                set: { selectAll in
                                    if selectAll {
                                        for option in equipmentOptions where !store.userProfile.availableEquipment.contains(option) {
                                            store.userProfile.availableEquipment.append(option)
                                        }
                                    } else {
                                        for option in equipmentOptions {
                                            store.userProfile.availableEquipment.removeAll { $0 == option }
                                        }
                                    }
                                }
                            ))
                            .font(SettingsTypography.rowTitle)
                            .foregroundStyle(PulseTheme.accent)

                            ForEach(equipmentOptions, id: \.self) { item in
                                Toggle(RepsText.equipment(item, language: store.userProfile.preferredLanguage), isOn: Binding(
                                    get: { store.userProfile.availableEquipment.contains(item) },
                                    set: { enabled in
                                        if enabled {
                                            if !store.userProfile.availableEquipment.contains(item) {
                                                store.userProfile.availableEquipment.append(item)
                                            }
                                        } else {
                                            store.userProfile.availableEquipment.removeAll { $0 == item }
                                        }
                                    }
                                ))
                            }
                        }
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 18) {
                            PaywallLockedCard(
                                title: "pro_preferences_locked",
                                message: "activate_reps_pro_for_advanced_progression_preferences",
                                buttonTitle: "view_reps_pro"
                            ) {
                                dismiss()
                                if let onShowPaywall {
                                    onShowPaywall(store.makePaywallPresentation(source: .proPreferences, feature: .configurableProgression))
                                } else {
                                    store.presentPaywall(source: .proPreferences, feature: .configurableProgression)
                                }
                            }
                        }
                        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                        .padding(.vertical, 20)
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    .screenBackground()
                }
            }
            .navigationTitle("preferencias_pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("ok") { dismiss() }
                }
            }
            .onAppear {
                store.sanitizeAvailableEquipment()
            }
        }
        .mainTabBarHidden()
        .quickActionAccessoryHidden()
    }
}

private struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        StickyHeaderScaffold(
            title: settingsDisplayText(title),
            subtitle: "settings",
            showsGlobalActions: false,
            accessory: {
                HStack(spacing: 10) {
                    SettingsBackHeaderButton()
                    SettingsTodayHeaderButton()
                }
            }
        ) {
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .quickActionAccessoryHidden()
    }
}

private struct SettingsControlCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(settingsDisplayText(title), systemImage: systemImage)
                    .font(SettingsTypography.rowTitle)
                    .foregroundStyle(PulseTheme.textPrimary)
                content
            }
        }
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            SettingsRowContent(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowContent: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PulseTheme.onColor(tint))
                .frame(width: 44, height: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(settingsDisplayText(title))
                    .font(SettingsTypography.rowTitle)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                Text(settingsDisplayText(subtitle))
                    .font(SettingsTypography.rowSubtitle)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(PulseTheme.separator)
            .padding(.leading, 76)
    }
}

private struct SettingsTodayHeaderButton: View {
    @Environment(\.navigateToToday) private var navigateToToday

    var body: some View {
        Button {
            HapticService.selection()
            navigateToToday()
        } label: {
            Image(systemName: AppTab.today.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                .navigationGlassCircle(.secondary, tint: PulseTheme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("today_3"))
    }
}

private struct SettingsBackHeaderButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            HapticService.selection()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                .navigationGlassCircle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("back_2"))
    }
}

private struct SettingsPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(SettingsTypography.pill)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct SettingsSummaryMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(settingsDisplayText(title), systemImage: systemImage)
                .font(SettingsTypography.metadataLabel)
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(SettingsTypography.metadataValue)
                .foregroundStyle(PulseTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .tint(tint)
    }
}

private struct SettingsInfoSection: Identifiable {
    let title: String
    let rows: [String]
    var id: String { title }
}

private struct SettingsInfoScreen: View {
    let title: String
    let systemImage: String
    let sections: [SettingsInfoSection]

    var body: some View {
        StickyHeaderScaffold(
            title: settingsDisplayText(title),
            subtitle: "settings",
            showsGlobalActions: false,
            accessory: {
                HStack(spacing: 10) {
                    SettingsBackHeaderButton()
                    SettingsTodayHeaderButton()
                }
            }
        ) {
            ForEach(sections) { section in
                PulseCard(backgroundColor: PulseTheme.grouped) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(settingsDisplayText(section.title))
                            .font(SettingsTypography.rowTitle)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(section.rows, id: \.self) { row in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(PulseTheme.accent)
                                        .padding(.top, 1)
                                    Text(settingsDisplayText(row))
                                        .font(SettingsTypography.rowSubtitle)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .stickyHeaderTitle(settingsDisplayText(section.title))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .quickActionAccessoryHidden()
    }
}

/// Dedicated, top-level Apple Health disclosure screen. Surfaced directly
/// from the Settings root (not buried under About) with a live connection
/// status so HealthKit usage is unambiguous to both users and App Review —
/// see Guideline 2.5.1 (HealthKit/CareKit functionality must be clearly
/// identified in the app's UI).
private struct AppleHealthSettingsScreen: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppStore.self) private var store
    @StateObject private var healthKit = HealthKitService.shared

    var body: some View {
        StickyHeaderScaffold(
            title: "apple_health",
            subtitle: "settings",
            showsGlobalActions: false,
            accessory: {
                HStack(spacing: 10) {
                    SettingsBackHeaderButton()
                    SettingsTodayHeaderButton()
                }
            }
        ) {
            PulseCard(backgroundColor: PulseTheme.grouped) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(settingsDisplayText("apple_health"), systemImage: "heart.fill")
                            .font(SettingsTypography.cardTitle)
                            .foregroundStyle(PulseTheme.accent)
                        Spacer()
                        Text(settingsDisplayText(store.health.isAuthorized ? "connected_to_apple_health" : "not_connected_to_apple_health"))
                            .font(SettingsTypography.rowSubtitle.weight(.semibold))
                            .foregroundStyle(store.health.isAuthorized ? PulseTheme.accent : PulseTheme.secondaryText)
                    }

                    Text(settingsDisplayText("apple_health_only_used_if_connected"))
                        .font(SettingsTypography.rowSubtitle)
                        .foregroundStyle(PulseTheme.secondaryText)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label(settingsDisplayText("open_health_settings"), systemImage: "gearshape.fill")
                            .font(SettingsTypography.buttonTitle)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!healthKit.isAvailable)
                }
            }
            .stickyHeaderTitle(settingsDisplayText("apple_health"))

            SettingsInfoSectionCard(
                title: "data",
                rows: [
                    "reads_steps_heart_rate_sleep_and_body_metrics_from_apple_health",
                    "writes_completed_workouts_and_body_metrics_when_you_sync",
                    "apple_health_only_used_if_connected"
                ]
            )
            .stickyHeaderTitle(settingsDisplayText("data"))
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .quickActionAccessoryHidden()
    }
}

private struct SettingsInfoSectionCard: View {
    let title: String
    let rows: [String]

    var body: some View {
        PulseCard(backgroundColor: PulseTheme.grouped) {
            VStack(alignment: .leading, spacing: 12) {
                Text(settingsDisplayText(title))
                    .font(SettingsTypography.rowTitle)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rows, id: \.self) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PulseTheme.accent)
                                .padding(.top, 1)
                            Text(settingsDisplayText(row))
                                .font(SettingsTypography.rowSubtitle)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    let onSend: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.title2.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(settingsDisplayText("feedback"))
                                .font(SettingsTypography.appTitle)
                            Text(settingsDisplayText("tell_us_what_you_would_improve_or_what_flow_was_confusing_for_you"))
                                .font(SettingsTypography.rowSubtitle)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    PulseCard(backgroundColor: PulseTheme.grouped) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(settingsDisplayText("message"))
                                .font(SettingsTypography.rowTitle)

                            TextEditor(text: $message)
                                .frame(minHeight: 180)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(PulseTheme.elevated)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text(settingsDisplayText("problem_idea_confusing_flow_or_missing_feature"))
                                            .font(SettingsTypography.rowSubtitle)
                                            .foregroundStyle(PulseTheme.tertiaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 18)
                                            .allowsHitTesting(false)
                                    }
                                }

                            Button {
                                onSend(message)
                            } label: {
                                Label(settingsDisplayText("send_feedback"), systemImage: "paperplane.fill")
                                    .font(SettingsTypography.buttonTitle)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .foregroundStyle(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PulseTheme.secondaryText : PulseTheme.onColor(PulseTheme.accent))
                                    .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PulseTheme.elevated : PulseTheme.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 20)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .background(PulseTheme.card.ignoresSafeArea())
            .presentationBackground(PulseTheme.card)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private func settingsDisplayText(_ key: String) -> String {
    let table = RepsLocalization.language == "es" ? settingsSpanishFallbacks : settingsEnglishFallbacks
    if let fallback = table[key] {
        return fallback
    }

    let localized = localizedString(key)
    if localized != key {
        return localized
    }

    return key
        .replacingOccurrences(of: "_", with: " ")
        .capitalizingFirstLetter()
}

private func settingsFormatText(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: settingsDisplayText(key), locale: RepsLocalization.locale, arguments: arguments)
}

private let settingsEnglishFallbacks: [String: String] = [
    "about": "About",
    "advanced": "Advanced",
    "alerts_for_scheduled_sessions_and_consistency": "Alerts for scheduled sessions and consistency nudges",
    "all_rights_reserved": "All rights reserved",
    "confirmations_advanced_logging_and_equipment": "Confirmations, advanced logging, and equipment",
    "designed_and_developed_by_romerodev": "Designed and developed by RomeroDev",
    "developer_tools": "Developer tools",
    "dev_menu_subtitle": "Onboarding, data, and Pro access",
    "home_screen_watch_and_live_activity_style": "Home Screen, Watch, and Live Activity style",
    "how_reps_uses_data_permissions_and_health_context": "How StreakReps uses data, permissions, and health context",
    "information_disclaimer": "Information and disclaimer",
    "language_theme_and_interface": "Language, theme, and interface",
    "last_active": "Last active",
    "manage_subscription": "Manage subscription",
    "member_since": "Member since",
    "personalization": "Personalization",
    "settings_app_build_format": "Build %@",
    "settings_app_version_format": "%@ version %@",
    "settings_build_value_format": "Build %@",
    "settings_version_value_format": "Version %@",
    "support": "Support",
    "support_subtitle": "Help center and contact",
    "faq": "FAQ",
    "faq_subtitle": "Frequently asked questions",
    "subscription_terms": "Subscription terms",
    "subscription_terms_subtitle": "Billing, renewal, cancellation, and Pro conditions",
    "tell_us_what_to_improve": "Tell us what to improve",
    "problem_idea_confusing_flow_or_missing_feature": "Problem, idea, confusing flow, or missing feature",
    "unlock_premium": "Unlock Premium",
    "unlock_pro_features_and_advanced_data": "Unlock Pro features and advanced data.",
    "units_distance_and_training_defaults": "Units, distance, and training defaults",
    "user_id_label": "User ID:",
    "user_id_copied": "Copied!",
    "widget_previews_and_customization": "Widget Previews & Customization",
    "global_accent_color": "Global Accent Color",
    "sync_widgets": "Sync Widgets",
    "workout_widget": "Workout Widget",
    "workout_widget_desc": "Displays today's routine and active workout progress",
    "streak_widget": "Streak Widget",
    "streak_widget_desc": "Tracks daily consistency and training streak",
    "battery_widget": "Recovery & Energy Widget",
    "battery_widget_desc": "Monitors body battery, readiness, and HRV status",
    "live_activity_preview": "Live Activity & Dynamic Island",
    "live_activity_desc": "Real-time workout controls on Lock Screen and Dynamic Island",
    "widget_size": "Widget Size",
    "primary_metric": "Primary Metric Focus",
    "show_rest_timer_live_activity": "Show Rest Timer in Live Activity",
    "color_system": "System",
    "color_blue": "Blue",
    "color_green": "Green",
    "color_orange": "Orange",
    "color_purple": "Purple",
    "color_red": "Red",
    "color_yellow": "Yellow",
    "view_options": "View options",
    "weight_increment_kg_format": "Increment: %.1f kg"
]

private let settingsSpanishFallbacks: [String: String] = [
    "about": "Acerca de",
    "advanced": "Avanzado",
    "alerts_for_scheduled_sessions_and_consistency": "Alertas para sesiones programadas y constancia",
    "all_rights_reserved": "Todos los derechos reservados",
    "confirmations_advanced_logging_and_equipment": "Confirmaciones, registro avanzado y equipamiento",
    "designed_and_developed_by_romerodev": "Diseñada y desarrollada por RomeroDev",
    "developer_tools": "Herramientas de desarrollo",
    "dev_menu_subtitle": "Inicio guiado, datos y acceso Pro",
    "home_screen_watch_and_live_activity_style": "Estilo para pantalla de inicio, Watch y Live Activity",
    "how_reps_uses_data_permissions_and_health_context": "Cómo StreakReps usa datos, permisos y contexto de salud",
    "information_disclaimer": "Información y aviso legal",
    "language_theme_and_interface": "Idioma, tema e interfaz",
    "last_active": "Última actividad",
    "manage_subscription": "Gestionar suscripción",
    "member_since": "Miembro desde",
    "personalization": "Personalización",
    "settings_app_build_format": "Compilación %@",
    "settings_app_version_format": "%@ versión %@",
    "settings_build_value_format": "Compilación %@",
    "settings_version_value_format": "Versión %@",
    "support": "Soporte",
    "support_subtitle": "Centro de ayuda y contacto",
    "faq": "Preguntas frecuentes",
    "faq_subtitle": "Preguntas frecuentes y respuestas rápidas",
    "subscription_terms": "Condiciones de suscripción",
    "subscription_terms_subtitle": "Facturación, renovación, cancelación y condiciones Pro",
    "tell_us_what_to_improve": "Cuéntanos qué mejorar",
    "problem_idea_confusing_flow_or_missing_feature": "Problema, idea, flujo confuso o funcionalidad que falta",
    "unlock_premium": "Desbloquear Premium",
    "unlock_pro_features_and_advanced_data": "Desbloquea funciones Pro y datos avanzados.",
    "units_distance_and_training_defaults": "Unidades, distancia y valores de entrenamiento",
    "user_id_label": "ID de usuario:",
    "user_id_copied": "¡Copiado!",
    "widget_previews_and_customization": "Vistas Previas y Personalización de Widgets",
    "global_accent_color": "Color de Acento Global",
    "sync_widgets": "Sincronizar Widgets",
    "workout_widget": "Widget de Entrenamiento",
    "workout_widget_desc": "Muestra la rutina de hoy y el progreso activo",
    "streak_widget": "Widget de Racha",
    "streak_widget_desc": "Seguimiento de racha diaria y constancia",
    "battery_widget": "Widget de Recuperación y Batería",
    "battery_widget_desc": "Monitorea la batería corporal, disposición y HRV",
    "live_activity_preview": "Live Activity y Dynamic Island",
    "live_activity_desc": "Controles en tiempo real en Pantalla de Bloqueo e Island",
    "widget_size": "Tamaño del Widget",
    "primary_metric": "Métrica Principal",
    "show_rest_timer_live_activity": "Mostrar Temporizador de Descanso",
    "color_system": "Sistema",
    "color_blue": "Azul",
    "color_green": "Verde",
    "color_orange": "Naranja",
    "color_purple": "Púrpura",
    "color_red": "Rojo",
    "color_yellow": "Amarillo",
    "view_options": "Ver opciones",
    "weight_increment_kg_format": "Incremento: %.1f kg"
]
