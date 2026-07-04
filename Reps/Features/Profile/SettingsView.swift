import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var activeDestination: SettingsDestination?
    @State private var localPaywall: PaywallPresentation?

    var body: some View {
        StickyHeaderScaffold(
            title: "settings",
            subtitle: "app_training_and_permissions",
            accessory: {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .destructiveGlassCircle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("close_settings"))
            }
        ) {
            appPreferences
                .stickyHeaderTitle(localizedString("app"))
            trainingPreferences
                .stickyHeaderTitle(localizedString("training_2"))
            widgetPreferences
                .stickyHeaderTitle(localizedString("widgets"))
            notificationPreferences
                .stickyHeaderTitle(localizedString("reminders"))
            proPreferencesEntry
                .stickyHeaderTitle(localizedString("pro_preferences"))
            #if DEBUG
            developerMenuEntry
                .stickyHeaderTitle(localizedString("dev_menu_title"))
            #endif
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .navigationDestination(item: $activeDestination) { destination in
            switch destination {
            case .proPreferences:
                ProPreferencesView { presentation in
                    localPaywall = presentation
                }
            #if DEBUG
            case .developerMenu:
                DeveloperMenuView()
            #endif
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

    private var appPreferences: some View {
        @Bindable var store = store
        return PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Label(localizedString("app_preferences"), systemImage: "app.badge")
                    .font(.headline)

                Picker(localizedString("language"), selection: $store.userProfile.preferredLanguage) {
                    Text("english").tag("en")
                    Text("spanish").tag("es")
                }
                .pickerStyle(.segmented)

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

    private var trainingPreferences: some View {
        @Bindable var store = store
        return PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Label(localizedString("measurement"), systemImage: "ruler")
                    .font(.headline)

                Picker(localizedString("units_2"), selection: $store.userProfile.units) {
                    ForEach(UserProfile.Units.allCases) { units in
                        Text(units.rawValue).tag(units)
                    }
                }
                .pickerStyle(.segmented)

                Picker(localizedString("distance_3"), selection: $store.userProfile.distanceUnit) {
                    ForEach(UserProfile.DistanceUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var widgetPreferences: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Label(localizedString("widgets"), systemImage: "rectangle.grid.2x2")
                    .font(.headline)

                Picker(localizedString("widget_color"), selection: Binding(
                    get: { store.userProfile.widgetAccentColorName },
                    set: { colorName in
                        store.userProfile.widgetAccentColorName = colorName
                        store.syncWidgets()
                        HapticService.selection()
                    }
                )) {
                    ForEach(widgetColors, id: \.self) { colorName in
                        Text(widgetColorTitle(colorName)).tag(colorName)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var notificationPreferences: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
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
                .font(.headline)

                Text(localizedString("enable_alerts_for_scheduled_sessions_and_consistency_nudges"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }

    private var proPreferencesEntry: some View {
        PulseCard {
            Button {
                if store.hasFeatureAccess(.configurableProgression) {
                    activeDestination = .proPreferences
                } else {
                    localPaywall = store.makePaywallPresentation(source: .proPreferences, feature: .configurableProgression)
                }
            } label: {
                PulseListRow(
                    title: "pro_preferences",
                    subtitle: "pro_preferences_subtitle",
                    systemImage: "slider.horizontal.3"
                )
            }
            .buttonStyle(.plain)
        }
    }

    #if DEBUG
    private var developerMenuEntry: some View {
        PulseCard {
            Button {
                activeDestination = .developerMenu
            } label: {
                PulseListRow(
                    title: "dev_menu_title",
                    subtitle: "dev_menu_subtitle",
                    systemImage: "hammer.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    private var widgetColors: [String] {
        ["system", "blue", "green", "orange", "purple", "red", "yellow"]
    }

    private func widgetColorTitle(_ colorName: String) -> String {
        localizedString("color_\(colorName)")
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

private enum SettingsDestination: String, Identifiable {
    case proPreferences
    #if DEBUG
    case developerMenu
    #endif

    var id: String { rawValue }
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
                            .font(.headline)
                            .foregroundStyle(PulseTheme.accent)

                            Toggle("show_rpe", isOn: $store.userProfile.showRPE)
                            Toggle("show_rir", isOn: $store.userProfile.showRIR)
                            Toggle("show_series_type", isOn: $store.userProfile.showSetType)
                            Toggle("show_tempo", isOn: $store.userProfile.showTempo)
                            Toggle("auto_progression", isOn: $store.userProfile.autoProgressionEnabled)
                            Stepper("Incremento: \(store.userProfile.weightIncrementKg, specifier: "%.1f") kg", value: $store.userProfile.weightIncrementKg, in: 0.5...10, step: 0.5)
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
                            .font(.headline)
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
    }
}
