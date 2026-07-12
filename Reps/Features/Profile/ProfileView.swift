import SwiftUI
import PhotosUI
import UIKit
import CoreImage
import UniformTypeIdentifiers
import StoreKit
import MapKit
import CoreLocation

private enum AppLegalLinks {
    static var privacyPolicy: String { RepsLegalUrls.privacyPolicy }
    static var termsOfService: String { RepsLegalUrls.termsOfService }
    static var subscriptionTerms: String { RepsLegalUrls.subscriptionTerms }
    static var support: String { RepsLegalUrls.support }
    static var faq: String { RepsLegalUrls.faq }
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(AppStore.self) private var store
    var onOpenPlans: (() -> Void)?
    /// True when this view is the root of the Perfil tab (no back chevron,
    /// tab bar stays visible). False when pushed from another tab's stack.
    var isTabRoot: Bool = false
    @StateObject private var healthKit = HealthKitService.shared
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var activeSheet: ProfileSheet?
    @State private var showImportBackup = false
    @State private var showImportCSV = false
    @State private var showStrongImport = false
    @State private var showDeleteAllConfirmation = false
    @State private var csvExportURL: URL?
    @State private var backupExportURL: URL?
    @State private var shareImageURL: URL?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var localPaywall: PaywallPresentation?
    @State private var activeDestination: ProfileDestination?
    @State private var isCheckingSocialAge = false

    var body: some View {
        applyProfileModifiers(
            StickyHeaderScaffold(
                title: "profile",
                subtitle: "body_data_and_account",
                backAction: isTabRoot ? nil : {
                    HapticService.selection()
                    dismiss()
                },
                accessory: {
                    EmptyView()
                }
            ) {
                accountCard
                    .stickyHeaderTitle(localizedString("account"))
                socialCard
                    .stickyHeaderTitle(localizedString("community"))
                bodyMetricsCard
                    .stickyHeaderTitle(localizedString("metrics_2"))
                // Only surface body indices once there are metrics to derive
                // them from; the metrics card above already prompts to add them,
                // so an empty indices card would just repeat that call to action.
                if store.hasBodyMetrics {
                    bodyIndexCard
                        .stickyHeaderTitle(localizedString("body_indexes"))
                }
                progressPhotoCard
                    .stickyHeaderTitle(localizedString("photos"))
                achievementsCard
                    .stickyHeaderTitle(localizedString("achievements"))
                gymPassesCard
                    .stickyHeaderTitle(localizedString("gyms"))
                healthCard
                    .stickyHeaderTitle(localizedString("apple_health"))
                HealthGoalsView()
                    .stickyHeaderTitle(localizedString("health_goals"))
                toolsCard
                    .stickyHeaderTitle(localizedString("actions"))
                settingsCard
                    .stickyHeaderTitle(localizedString("settings"))
                supportAndProductCard
                    .stickyHeaderTitle(localizedString("support"))
            }
        )
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshMetricTextFields()
            store.health.isAvailable = healthKit.isAvailable
            Task { await healthKit.refreshAuthorizationCache() }
        }
        .onChange(of: store.userProfile.units) { _, _ in
            refreshMetricTextFields()
        }
        .onChange(of: avatarPickerItem) { _, item in
            Task { await loadAvatar(from: item) }
        }
        .navigationDestination(item: $activeDestination) { destination in
            profileDestination(destination)
        }
        .mainTabBarHidden(!isTabRoot)
    }



    private var accountCard: some View {
        PulseCard {
            NavigationLink {
                ProfileDetailView()
            } label: {
                HStack(spacing: 14) {
                    AvatarMiniView(imageData: store.userProfile.avatarImageData, size: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        if let name = store.userProfile.displayName, !name.isEmpty {
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        } else {
                            Text("profile")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        if let email = store.userProfile.email, !email.isEmpty {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                        } else {
                            Text(localizedString("profile_setup_hint"))
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.accent)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var bodyMetricsCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("body_metrics_2")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button { activeSheet = .quickMetricEditor } label: {
                        ProfileMetric(
                            title: "weight",
                            value: store.hasBodyMetrics ? String(format: "%.1f", store.displayedWeight.value) : "--",
                            unit: store.hasBodyMetrics ? store.displayedWeight.unit : localizedKey("add"),
                            color: TrackedMetric.bodyWeight.tint
                        )
                    }
                    .buttonStyle(.plain)

                    Button { activeSheet = .quickMetricEditor } label: {
                        ProfileMetric(
                            title: "height",
                            value: store.hasBodyMetrics ? String(format: "%.0f", store.displayedHeight.value) : "--",
                            unit: store.hasBodyMetrics ? store.displayedHeight.unit : localizedKey("add"),
                            color: PulseTheme.ringStand
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    activeSheet = .bodyLog
                } label: {
                    PulseListRow(title: "advanced_log", subtitle: "weight_fat_measurements_sleep_stress_and_discomfort", systemImage: "heart.text.square")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bodyIndexCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("body_indices")
                        .font(.headline)
                    Spacer()
                    Text(store.hasBodyMetrics ? "estimate" : "pending")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                if store.hasBodyMetrics {
                    HStack(spacing: 12) {
                        ProfileMetric(title: "IMC", value: String(format: "%.1f", store.bodyMassIndex), unit: bmiLabel, color: TrackedMetric.bodyWeight.tint)
                        ProfileMetric(title: "basal", value: "\(Int(store.basalMetabolicRate))", unit: localizedKey("kcal_per_day"), color: TrackedMetric.activeEnergy.tint)
                    }

                    VStack(spacing: 10) {
                        CalorieRow(title: "deficit", value: store.deficitCalories, subtitle: "lose_fat")
                        CalorieRow(title: "recomposition", value: store.recompositionCalories, subtitle: "stable_progress")
                        CalorieRow(title: "volume", value: store.leanBulkCalories, subtitle: "controlled_gain")
                    }
                } else {
                    PulseEmptyState(
                        title: "add_your_metrics",
                        message: "save_weight_and_height_to_calculate_bmi_bmr_and_calorie_targets",
                        systemImage: "scalemass"
                    )

                    Button {
                        activeSheet = .quickMetricEditor
                    } label: {
                        Label("add_metrics", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.accent))
                }
            }
        }
    }

    private var progressPhotoCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("progress_photos_2")
                        .font(.headline)
                    Spacer()
                    Button {
                        activeSheet = .addProgressPhoto
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if store.progressPhotos.isEmpty {
                    PulseEmptyState(
                        title: "no_photos_yet",
                        message: "add_periodic_photos_to_compare_progress",
                        systemImage: "photo.on.rectangle"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.progressPhotos.sorted { $0.date < $1.date }) { photo in
                                ProgressPhotoTile(photo: photo)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var achievementsCard: some View {
        let xp = store.playerXP
        let lvl = GamificationEngine.playerLevel(for: xp)
        return PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localizedString("achievements_and_tickets"))
                        .font(.headline)
                    Spacer()

                    Text(localizedFormat("player_level_abbr_title_format", "\(lvl.level)", lvl.title))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PulseTheme.accent.opacity(0.10))
                        .clipShape(Capsule())

                    NavigationLink {
                        AchievementsView()
                    } label: {
                        HStack(spacing: 4) {
                            Text(localizedString("view_all_2"))
                                .font(.caption.weight(.bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(PulseTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                if !store.hasFeatureAccess(.shareCards) {
                    PaywallLockedCard(
                        title: "pro_receipts",
                        message: "unlock_the_receipt_gallery_shareable_cards_and_workout_images_with_reps_pro",
                        buttonTitle: localizedString("see_reps_pro")
                    ) {
                        localPaywall = store.makePaywallPresentation(source: .receiptGallery, feature: .shareCards)
                    }
                } else if store.savedShareCards.isEmpty {
                    PulseEmptyState(
                        title: "no_achievements_yet",
                        message: "complete_workouts_to_track_apple_health_achievements_and_auto_save_training_tick",
                        systemImage: "trophy"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            NavigationLink {
                                AchievementsView()
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(PulseTheme.accent.opacity(0.12))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "trophy.fill")
                                            .font(.title3)
                                            .foregroundStyle(PulseTheme.accent)
                                    }
                                    .frame(width: 100, height: 160)
                                    .background(PulseTheme.grouped)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    
                                    Text(localizedString("achievements"))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    
                                    Text(localizedString("view_milestones"))
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(PulseTheme.accent)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            ForEach(store.savedShareCards.sorted { $0.date > $1.date }) { card in
                                Button {
                                    activeSheet = .receiptPreview(card)
                                } label: {
                                    SavedShareCardThumbnail(
                                        card: card,
                                        language: store.userProfile.preferredLanguage,
                                        style: .compact
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    private var socialCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localizedString("community"))
                        .font(.headline)
                    Spacer()
                    if store.userProfile.socialEnabled, store.userProfile.socialCapabilitiesAllowed {
                        NavigationLink {
                            SocialHubView()
                        } label: {
                            HStack(spacing: 4) {
                                Text(localizedString("view_all_2"))
                                    .font(.caption.weight(.bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(PulseTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if store.userProfile.socialEnabled,
                   store.userProfile.socialCapabilitiesAllowed,
                   let uname = store.userProfile.socialUsername {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(PulseTheme.accent.opacity(0.10))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PulseTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(uname)")
                                .font(.subheadline.weight(.semibold))
                            Text(localizedString("community_active"))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.ringStand)
                        }
                        Spacer()
                        NavigationLink {
                            SocialHubView()
                        } label: {
                            Text(localizedString("friends_2"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(PulseTheme.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizedString("auto_share_workouts"))
                                .font(.subheadline.weight(.semibold))
                            Text(localizedString("auto_share_workouts_note"))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.userProfile.autoShareWorkouts },
                            set: { store.userProfile.autoShareWorkouts = $0 }
                        ))
                        .labelsHidden()
                        .tint(PulseTheme.accent)
                    }
                    .padding(.vertical, 2)

                } else if !store.userProfile.socialCapabilitiesAllowed {
                    socialAgeGatePrompt
                } else {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(PulseTheme.accent.opacity(0.10))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.2")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PulseTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizedString("connect_with_friends"))
                                .font(.subheadline.weight(.semibold))
                            Text(localizedString("compare_and_compete"))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                        Button {
                            Task { await openSocialOnboardingAfterAgeCheck() }
                        } label: {
                            if isCheckingSocialAge {
                                ProgressView()
                                    .tint(PulseTheme.onColor(PulseTheme.accent))
                                    .frame(width: 48, height: 28)
                                    .background(PulseTheme.accent)
                                    .clipShape(Capsule())
                            } else {
                                Text(localizedString("activate"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(PulseTheme.accent)
                                    .clipShape(Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isCheckingSocialAge)
                    }
                }
            }
        }
    }

    private var socialAgeGatePrompt: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PulseTheme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("social_age_gate_title"))
                    .font(.subheadline.weight(.semibold))
                Text(localizedString(socialAgeGateMessageKey))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Button {
                Task { await openSocialOnboardingAfterAgeCheck() }
            } label: {
                if isCheckingSocialAge {
                    ProgressView()
                        .tint(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 74, height: 30)
                        .background(PulseTheme.accent)
                        .clipShape(Capsule())
                } else {
                    Text(localizedString("social_age_gate_verify"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PulseTheme.accent)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(isCheckingSocialAge)
        }
    }

    private var socialAgeGateMessageKey: String {
        switch store.userProfile.socialAgeGateStatus {
        case .blockedUnder13:
            "social_age_gate_under_13_message"
        case .sharingDeclined:
            "social_age_gate_declined_message"
        case .unavailable:
            "social_age_gate_unavailable_message"
        case .unknown, .allowed13Plus:
            "social_age_gate_message"
        }
    }

    private func openSocialOnboardingAfterAgeCheck() async {
        guard !isCheckingSocialAge else { return }
        isCheckingSocialAge = true
        let allowed = await store.ensureSocialAgeEligibility()
        isCheckingSocialAge = false
        if allowed {
            activeSheet = .socialOnboarding
        }
    }

    private var gymPassesCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardTitle("gyms")
                    Spacer()
                    Button { activeSheet = .addGymPass } label: {
                        Image(systemName: "qrcode")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button { activeSheet = .addGymVisit } label: {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if store.gymPasses.isEmpty {
                    PulseEmptyState(
                        title: "no_gym_cards",
                        message: "save_gym_qr_or_barcode_for_quick_access",
                        systemImage: "wallet.pass"
                    )
                } else {
                    let active = store.gymPasses.filter(\.isActive)
                    let history = store.gymPasses
                        .filter { !$0.isActive }
                        .sorted { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) }

                    ForEach(active) { pass in
                        gymPassRow(pass)
                    }

                    if !history.isEmpty {
                        DisclosureGroup {
                            VStack(spacing: 10) {
                                ForEach(history) { pass in
                                    gymPassRow(pass)
                                }
                            }
                            .padding(.top, 6)
                        } label: {
                            Text("gym_history")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .tint(PulseTheme.secondaryText)
                    }
                }

                if !store.gymVisits.isEmpty {
                    Divider()
                    HStack {
                        Text("visit_timeline")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        NavigationLink {
                            GymVisitTimelineView()
                        } label: {
                            HStack(spacing: 3) {
                                Text("Ver más")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PulseTheme.accent)
                    }
                    if let latestVisit = store.gymVisits.max(by: { $0.date < $1.date }) {
                        GymVisitRow(visit: latestVisit)
                    }
                }
            }
        }
    }

    private func gymPassRow(_ pass: GymPass) -> some View {
        Button {
            activeSheet = .editGymPass(pass)
        } label: {
            GymPassPreview(pass: pass)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                activeSheet = .editGymPass(pass)
            } label: {
                Label("edit", systemImage: "pencil")
            }
            if pass.isActive {
                Button {
                    store.endMembership(pass)
                } label: {
                    Label("end_membership", systemImage: "calendar.badge.minus")
                }
            }
            Button(role: .destructive) {
                store.deleteGymPass(pass)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    private var healthCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("apple_health", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(PulseTheme.accent)
                    Spacer()
                    Text(healthStatus)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.health.isAuthorized ? PulseTheme.accent : PulseTheme.secondaryText)
                }

                HStack(spacing: 10) {
                    Button(localizedString(store.health.isAuthorized ? "Actualizar" : "Conectar")) {
                        Task { await connectHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.accent))
                    .disabled(!store.health.isAvailable)

                    Button("sincronizar") {
                        Task { await saveToHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.ringStand))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized)
                }

                if store.health.isAuthorized && healthKit.needsWorkoutWriteUpgrade {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reconnect_health_upgrade_message")
                                .font(.footnote)
                                .foregroundStyle(PulseTheme.secondaryText)
                            Button("reconnect_apple_health") {
                                Task { await connectHealth() }
                            }
                            .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.accent))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PulseTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button("importar_cardio") {
                        Task { await importCardioFromHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.accent))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized)

                    Button("save_training") {
                        Task { await saveLatestWorkoutToHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.ringStand))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized || store.workoutSessions.isEmpty)
                }

                if let metric = store.todayHealthMetric {
                    LazyVGrid(columns: profileToolColumns, spacing: 10) {
                        HealthMiniMetric(title: "Pasos", value: "\(Int(metric.steps))", systemImage: TrackedMetric.steps.systemImage, tint: TrackedMetric.steps.tint)
                        HealthMiniMetric(title: "Ejercicio", value: "\(Int(metric.exerciseMinutes ?? 0)) min", systemImage: TrackedMetric.exerciseMinutes.systemImage, tint: TrackedMetric.exerciseMinutes.tint)
                        HealthMiniMetric(title: "Reposo", value: metric.restingHeartRate.map { "\(Int($0)) \(localizedString("lpm"))" } ?? "--", systemImage: TrackedMetric.restingHeartRate.systemImage, tint: TrackedMetric.restingHeartRate.tint)
                        HealthMiniMetric(title: "HRV", value: metric.heartRateVariabilityMS.map { "\(Int($0)) ms" } ?? "--", systemImage: TrackedMetric.hrv.systemImage, tint: TrackedMetric.hrv.tint)
                    }
                }

                if store.health.isAuthorized {
                    Button("desconectar_apple_health", role: .destructive) {
                        store.disconnectHealth()
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if let message = store.health.message {
                    Text(localizedKey(message))
                        .font(.footnote)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private var settingsCard: some View {
        PulseCard {
            NavigationLink {
                SettingsView()
            } label: {
                PulseListRow(
                    title: "settings",
                    subtitle: "units_language_theme_widgets_reminders_and_pro_preferences",
                    systemImage: "gearshape.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("action_center")
                .font(.title3.bold())
                .padding(.horizontal, 2)

            ProfileToolSection(title: "train_and_build") {
                LazyVGrid(columns: profileToolColumns, spacing: 12) {
                    ProfileToolButton(
                        title: "library",
                        subtitle: localizedFormat("exercise_count_format", store.exercises.count),
                        systemImage: "magnifyingglass",
                        color: PulseTheme.accent
                    ) {
                        activeDestination = .exerciseLibrary
                    }

                    ProfileToolButton(
                        title: "Cardio",
                        subtitle: "route_heart_rate_and_rpe",
                        systemImage: "figure.run",
                        color: PulseTheme.accent
                    ) {
                        activeSheet = .cardioLog
                    }

                    ProfileToolButton(
                        title: "goals_title",
                        subtitle: "goal_hub_subtitle",
                        systemImage: "target",
                        color: .orange
                    ) {
                        activeDestination = .goals
                    }

                    ProfileToolButton(
                        title: "equipment_routine",
                        subtitle: "compatible_with_you",
                        systemImage: "wand.and.sparkles",
                        color: PulseTheme.ringStand
                    ) {
                        activeSheet = .equipmentRoutineWizard
                    }
                }
            }

            ProfileToolSection(title: "data_and_privacy") {
                Button {
                    activeDestination = .dataPrivacy
                } label: {
                    PulseListRow(
                        title: "data_center",
                        subtitle: "csv_backups_restore_privacy_and_delete",
                        systemImage: "externaldrive.badge.icloud"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var supportAndProductCard: some View {
        PulseCard {
            Button {
                activeDestination = .supportProduct
            } label: {
                PulseListRow(
                    title: "support_and_product",
                    subtitle: "help_feedback_privacy_subscription_whats_new_and_version",
                    systemImage: "questionmark.bubble.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func profileSheetDestination(_ sheet: ProfileSheet) -> some View {
        switch sheet {
        case .cardioLog:
            CardioLogEditorView()
        case .bodyLog:
            BodyWellnessEditorView(
                initialWeightKg: store.currentWeight,
                initialHeightCm: store.currentHeight
            )
        case .quickMetricEditor:
            QuickBodyMetricEditorView()
        case .addProgressPhoto:
            ProgressPhotoEditorView()
        case .addGymPass:
            GymPassEditorView()
        case .editGymPass(let pass):
            GymPassEditorView(pass: pass)
        case .addGymVisit:
            GymVisitEditorView()
        case .receiptPreview(let card):
            ReceiptPreviewSheet(card: card)
        case .feedback:
            FeedbackSheet { message in
                sendFeedback(message)
            }
        case .subscription:
            SubscriptionCenterView()
        case .socialOnboarding:
            SocialOnboardingView()
        case .equipmentRoutineWizard:
            EquipmentRoutineWizardView(profile: store.userProfile)
        }
    }

    @ViewBuilder
    private func profileDestination(_ destination: ProfileDestination) -> some View {
        switch destination {
        case .exerciseLibrary:
            ExerciseLibraryView()
        case .goals:
            GoalsView()
        case .dataPrivacy:
            dataPrivacyCenter
        case .supportProduct:
            supportProductCenter
        case .help:
            helpInfoScreen
        case .privacy:
            privacyInfoScreen
        case .roadmap:
            roadmapInfoScreen
        case .version:
            VersionInfoScreen(appVersionText: appVersionText) {
                activeDestination = nil
            }
        }
    }

    private var dataPrivacyCenter: some View {
        applyProfileModifiers(
            StickyHeaderScaffold(
                title: "data_center",
                subtitle: "export_backup_and_privacy",
                accessory: {
                    HStack(spacing: 10) {
                        Button {
                            HapticService.selection()
                            activeDestination = nil
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PulseTheme.textPrimary)
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .navigationGlassCircle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "externaldrive.badge.icloud")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .frame(width: 40, height: 40)
                            .background(PulseTheme.accent)
                            .clipShape(Circle())
                    }
                }
            ) {
                ProfileToolSection(title: "Compartir progreso") {
                    LazyVGrid(columns: profileToolColumns, spacing: 12) {
                        ProfileToolButton(
                            title: "CSV",
                            subtitle: localizedString(csvExportURL == nil ? "Generar archivo" : "Listo para compartir"),
                            systemImage: "tablecells",
                            color: PulseTheme.accent
                        ) {
                            prepareCSVExport()
                        }

                        if let csvExportURL {
                            ShareLink(item: csvExportURL) {
                                ProfileToolCard(
                                    title: localizedString("share_csv"),
                                    subtitle: localizedString("send_file"),
                                    systemImage: "square.and.arrow.up",
                                    color: PulseTheme.accent,
                                    badge: localizedString("listo")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        ProfileToolButton(
                            title: localizedString("image_label"),
                            subtitle: localizedString(shareImageURL == nil ? "Resumen privado" : "PNG listo"),
                            systemImage: "photo.on.rectangle",
                            color: .orange
                        ) {
                            if profileFeatureIsAvailable(.shareCards, source: .shareCards) {
                                prepareWorkoutShareImage()
                            }
                        }

                        if let shareImageURL {
                            ShareLink(item: shareImageURL) {
                                ProfileToolCard(
                                    title: localizedString("share_png"),
                                    subtitle: localizedString("last_workout"),
                                    systemImage: "square.and.arrow.up",
                                    color: .orange,
                                    badge: localizedString("listo")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .stickyHeaderTitle(localizedString("share"))

                ProfileToolSection(title: "data_and_privacy") {
                    LazyVGrid(columns: profileToolColumns, spacing: 12) {
                        ProfileToolButton(
                            title: "import_csv",
                            subtitle: "cardio_and_body",
                            systemImage: "square.and.arrow.down",
                            color: PulseTheme.ringStand
                        ) {
                            showImportCSV = true
                        }

                        ProfileToolButton(
                            title: localizedString("import_from_strong"),
                            subtitle: localizedString("strong_import_subtitle"),
                            systemImage: "tray.and.arrow.down",
                            color: .purple
                        ) {
                            showStrongImport = true
                        }

                        ProfileToolButton(
                            title: localizedString("backup_label"),
                            subtitle: localizedString(backupExportURL == nil ? "generate_json" : "json_ready"),
                            systemImage: "externaldrive",
                            color: PulseTheme.accent
                        ) {
                            if profileFeatureIsAvailable(.automaticBackups, source: .backupCenter) {
                                prepareBackupExport()
                            }
                        }

                        if let backupExportURL {
                            ShareLink(item: backupExportURL) {
                                ProfileToolCard(
                                    title: localizedString("share_backup"),
                                    subtitle: localizedString("full_copy"),
                                    systemImage: "doc.badge.gearshape",
                                    color: PulseTheme.accent,
                                    badge: localizedString("listo")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        ProfileToolButton(
                            title: "restore",
                            subtitle: "import_json",
                            systemImage: "arrow.down.doc",
                            color: PulseTheme.accent
                        ) {
                            if profileFeatureIsAvailable(.automaticBackups, source: .backupCenter) {
                                showImportBackup = true
                            }
                        }

                        if store.monetization.hasProAccess {
                            let iCloudStatusSubtitle: String = {
                                if let date = store.iCloudBackupDate {
                                    return localizedFormat("last_icloud_backup_date_format", date.formatted(date: .abbreviated, time: .shortened))
                                }
                                return localizedString("icloud_backup_pending")
                            }()
                            ProfileToolCard(
                                title: localizedString("icloud_backup"),
                                subtitle: iCloudStatusSubtitle,
                                systemImage: "icloud.and.arrow.up",
                                color: .blue
                            )
                        }

                        ProfileToolButton(
                            title: "delete_data",
                            subtitle: "reset_app",
                            systemImage: "trash",
                            color: .red
                        ) {
                            showDeleteAllConfirmation = true
                        }
                    }
                }
                .stickyHeaderTitle(localizedString("privacidad"))
            }
        )
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
    }

    private var supportProductCenter: some View {
        applyProfileModifiers(
            StickyHeaderScaffold(
                title: "support",
                subtitle: "help_product_and_subscription",
                accessory: {
                    HStack(spacing: 10) {
                        Button {
                            HapticService.selection()
                            activeDestination = nil
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PulseTheme.textPrimary)
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .navigationGlassCircle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "questionmark.bubble.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.ringStand))
                            .frame(width: 40, height: 40)
                            .background(PulseTheme.ringStand)
                            .clipShape(Circle())
                    }
                }
            ) {
                ProfileToolSection(title: "contact") {
                    LazyVGrid(columns: profileToolColumns, spacing: 12) {
                        ProfileToolButton(
                            title: "rate_app",
                            subtitle: "request_review",
                            systemImage: "star.bubble",
                            color: PulseTheme.accent
                        ) {
                            TelemetryService.shared.log(.reviewPromptRequested)
                            requestReview()
                        }

                        ProfileToolButton(
                            title: "Feedback",
                            subtitle: "send_feedback",
                            systemImage: "bubble.left.and.text.bubble.right",
                            color: PulseTheme.accent
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "feedback"])
                            activeSheet = .feedback
                        }

                        ProfileToolButton(
                            title: "support",
                            subtitle: "support_subtitle",
                            systemImage: "questionmark.bubble",
                            color: PulseTheme.accent
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "support_web"])
                            if let url = URL(string: AppLegalLinks.support) {
                                UIApplication.shared.open(url)
                            }
                        }

                        ShareLink(
                            item: WorkoutReceiptDeepLink.appStoreURL,
                            message: Text(localizedKey("share_app_subtitle"))
                        ) {
                            ProfileToolCard(
                                title: localizedString("share_app"),
                                subtitle: localizedString("share_app_subtitle"),
                                systemImage: "square.and.arrow.up",
                                color: PulseTheme.ringStand
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .stickyHeaderTitle(localizedString("contacto"))

                ProfileToolSection(title: "product") {
                    LazyVGrid(columns: profileToolColumns, spacing: 12) {
                        ProfileToolButton(
                            title: "faq",
                            subtitle: "faq_subtitle",
                            systemImage: "questionmark.circle",
                            color: PulseTheme.ringStand
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "faq"])
                            if let url = URL(string: AppLegalLinks.faq) {
                                UIApplication.shared.open(url)
                            }
                        }

                        ProfileToolButton(
                            title: "privacy",
                            subtitle: "data_and_permissions",
                            systemImage: "hand.raised",
                            color: .purple
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "privacy"])
                            activeDestination = .privacy
                        }

                        ProfileToolButton(
                            title: "subscription_label",
                            subtitle: store.monetization.hasProAccess ? store.monetization.statusLabel : localizedString("status_and_pro"),
                            systemImage: "creditcard",
                            color: .orange
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "subscription"])
                            activeSheet = .subscription
                        }

                        ProfileToolButton(
                            title: "whats_new",
                            subtitle: "included_improvements",
                            systemImage: "sparkles",
                            color: .teal
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "roadmap"])
                            activeDestination = .roadmap
                        }

                        ProfileToolButton(
                            title: "version_label",
                            subtitle: appVersionText,
                            systemImage: "info.circle",
                            color: PulseTheme.secondaryText
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "version"])
                            activeDestination = .version
                        }
                    }
                }
                .stickyHeaderTitle(localizedString("producto"))

                ProfileToolSection(title: "legal") {
                    LazyVGrid(columns: profileToolColumns, spacing: 12) {
                        ProfileToolButton(
                            title: "privacy_policy",
                            subtitle: "privacy_policy_subtitle",
                            systemImage: "doc.text",
                            color: .indigo
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "privacy_policy"])
                            if let url = URL(string: AppLegalLinks.privacyPolicy) {
                                UIApplication.shared.open(url)
                            }
                        }

                        ProfileToolButton(
                            title: "terms_of_service",
                            subtitle: "terms_of_service_subtitle",
                            systemImage: "doc.plaintext",
                            color: .gray
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "terms_of_service"])
                            if let url = URL(string: AppLegalLinks.termsOfService) {
                                UIApplication.shared.open(url)
                            }
                        }

                        ProfileToolButton(
                            title: "subscription_terms",
                            subtitle: "subscription_terms_subtitle",
                            systemImage: "doc.badge.gearshape",
                            color: .gray
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "subscription_terms"])
                            if let url = URL(string: AppLegalLinks.subscriptionTerms) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
                .stickyHeaderTitle(localizedString("legal"))
            }
        )
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
    }

    private var helpInfoScreen: some View {
        SupportInfoScreen(
            title: "help",
            systemImage: "questionmark.circle",
            sections: [
                SupportInfoSection(title: "train", rows: [
                    "start_from_today_or_scheduled_routine",
                    "during_workout_pause_complete_sets_add_notes_photos_and_water",
                    "summary_updates_progress_widgets_and_receipts"
                ]),
                SupportInfoSection(title: "data", rows: [
                    "json_backup_saves_full_copy",
                    "csv_exports_sessions_cardio_and_body_metrics",
                    "apple_health_connects_from_profile_with_permission"
                ])
            ]
        ) {
            activeDestination = nil
        }
    }

    private var privacyInfoScreen: some View {
        SupportInfoScreen(
            title: "privacy",
            systemImage: "hand.raised",
            sections: [
                SupportInfoSection(title: "local_data", rows: [
                    "reps_stores_workouts_routines_metrics_photos_and_cards_locally",
                    "you_can_export_import_backup_and_delete_profile_data"
                ]),
                SupportInfoSection(title: "permissions", rows: [
                    "apple_health_only_used_if_connected",
                    "photos_camera_music_notifications_and_location_requested_when_used",
                    "widgets_read_minimum_summary_from_app_group"
                ]),
                SupportInfoSection(title: "privacy_and_telemetry", rows: [
                    "app_records_minimum_product_events_for_stability",
                    "no_workout_names_notes_photos_or_health_data_sent_to_analytics",
                    "you_can_delete_local_data_and_export_copy_from_profile"
                ])
            ]
        ) {
            activeDestination = nil
        }
    }

    private var roadmapInfoScreen: some View {
        SupportInfoScreen(
            title: "whats_new",
            systemImage: "sparkles",
            sections: [
                SupportInfoSection(title: "training", rows: [
                    "ready_routines_with_days_exercises_sets_rests_and_progression",
                    "free_log_with_notes_photos_water_rpe_rir_tempo_and_rests",
                    "final_summary_with_volume_records_and_visual_receipts"
                ]),
                SupportInfoSection(title: "integrations", rows: [
                    "apple_health_imports_metrics_and_saves_workouts_with_permission",
                    "widgets_watch_and_live_activities_follow_session_outside_app",
                    "apple_music_plays_playlists_during_workouts"
                ]),
                SupportInfoSection(title: "progress", rows: [
                    "analytics_by_exercise_muscle_load_streaks_and_training_battery",
                    "json_backups_csv_export_and_shareable_cards",
                    "gym_passes_and_visits_keep_accesses_handy"
                ])
            ]
        ) {
            activeDestination = nil
        }
    }

    private var profileToolColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var healthStatus: LocalizedStringKey {
        if !store.health.isAvailable {
            return "No disponible"
        }

        return store.health.isAuthorized ? "Conectado" : "Sin conectar"
    }

    private var bmiLabel: String {
        switch store.bodyMassIndex {
        case ..<18.5: localizedString("bajo")
        case 18.5..<25: localizedString("normal")
        case 25..<30: localizedString("alto")
        default: localizedString("muy alto")
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func profileFeatureIsAvailable(
        _ feature: ProductFeature,
        source: PaywallSource,
        trigger: PaywallTrigger = .featureGate
    ) -> Bool {
        guard !store.hasFeatureAccess(feature) else {
            return true
        }

        TelemetryService.shared.log(.paywallFeatureGateHit, parameters: [
            "feature": feature.rawValue,
            "source": source.rawValue
        ])
        presentPaywallAfterCurrentSheet(
            store.makePaywallPresentation(source: source, feature: feature, trigger: trigger)
        )
        return false
    }

    private func presentPaywallAfterCurrentSheet(_ presentation: PaywallPresentation) {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            localPaywall = presentation
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
        components.path = "support@romerodev.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Feedback StreakRep \(appVersionText)"),
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

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.72) else {
            return
        }
        store.updateAvatarImageData(compressed)
    }

    private func saveManualMetrics() {
        guard let rawWeight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let rawHeight = Double(heightText.replacingOccurrences(of: ",", with: ".")) else {
            store.health.message = localizedKey("enter_valid_weight_and_height")
            return
        }
        let weight = store.userProfile.units == .metric ? rawWeight : UnitConverter.kilograms(fromPounds: rawWeight)
        let height = store.userProfile.units == .metric ? rawHeight : UnitConverter.centimeters(fromInches: rawHeight)
        store.saveBodyMetrics(weightKg: weight, heightCm: height)
        store.health.message = localizedString("body_metrics_saved_in_reps")
    }

    private func refreshMetricTextFields() {
        if store.hasBodyMetrics {
            weightText = String(format: "%.1f", store.displayedWeight.value)
            heightText = String(format: "%.0f", store.displayedHeight.value)
        } else {
            weightText = ""
            heightText = ""
        }
    }

    private func connectHealth() async {
        do {
            try await healthKit.requestAuthorization()
            store.health.isAuthorized = healthKit.hasWriteAuthorization
            store.health.lastSyncDate = .now
            store.startHealthKitWorkoutObserverIfAuthorized()
            let metrics = try await healthKit.fetchLatestBodyMetrics()
            let resolvedWeight = metrics.weightKg ?? (store.hasBodyMetrics ? store.currentWeight : nil)
            let resolvedHeight = metrics.heightCm ?? (store.hasBodyMetrics ? store.currentHeight : nil)
            if let resolvedWeight, let resolvedHeight {
                store.saveBodyMetrics(
                    weightKg: resolvedWeight,
                    heightCm: resolvedHeight,
                    source: .appleHealth
                )
                let dailyMetrics = try await healthKit.fetchDailyMetrics()
                store.health.latestDailyMetrics = dailyMetrics
                store.health.message = localizedString("apple_health_connected_imported_weight_height_steps_calories_and_hydration")
            } else {
                store.health.latestDailyMetrics = try await healthKit.fetchDailyMetrics()
                store.health.message = localizedString("apple_health_connected_daily_activity_and_nutrition_imported")
            }
        } catch {
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "healthkit_connect")
        }
    }

    private func importCardioFromHealth() async {
        do {
            let logs = try await healthKit.fetchRecentCardioLogs()
            let imported = store.importCardioLogs(logs)
            store.health.lastSyncDate = .now
            store.health.message = localizedFormat("cardio_imported_from_apple_health_count_format", imported)
        } catch {
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "healthkit_import_cardio")
        }
    }

    private func saveToHealth() async {
        do {
            guard store.hasBodyMetrics else {
                store.health.message = localizedKey("add_weight_and_height_before_saving_to_apple_health")
                return
            }
            try await healthKit.saveBodyMetrics(weightKg: store.currentWeight, heightCm: store.currentHeight)
            if let latestMetric = store.bodyMetrics.sorted(by: { $0.date > $1.date }).first {
                try await healthKit.saveDailyNutrition(
                    waterLiters: latestMetric.waterLiters,
                    dietaryEnergyKcal: latestMetric.dietaryEnergyKcal,
                    date: latestMetric.date
                )
            }
            store.health.lastSyncDate = .now
            store.health.message = localizedString("weight_height_hydration_and_energy_saved_in_apple_health_when_data_is_available")
        } catch {
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "healthkit_save_body")
        }
    }

    private func saveLatestWorkoutToHealth() async {
        guard let session = store.workoutSessions.sorted(by: { $0.date > $1.date }).first else {
            return
        }

        do {
            try await healthKit.saveWorkout(session)
            store.health.lastSyncDate = .now
            store.health.message = localizedString("last_workout_saved_in_apple_health")
        } catch {
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "healthkit_save_workout")
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
            TelemetryService.shared.record(error, context: "notifications_enable_reminders")
        }
    }

    private func prepareCSVExport() {
        do {
            csvExportURL = try store.exportCSVURL()
            store.health.message = localizedString("csv_generated_use_share_csv_to_send_it")
        } catch {
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "csv_export_prepare")
        }
    }

    private func prepareBackupExport() {
        do {
            backupExportURL = try store.exportBackupURL()
            store.health.message = localizedString("backup_generated_use_share_backup_to_send_it")
        } catch {
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "backup_export_prepare")
        }
    }

    private func prepareWorkoutShareImage() {
        do {
            shareImageURL = try store.exportWorkoutShareImageURL()
            store.health.message = localizedString("generated_image_use_share_image_to_send_it")
        } catch {
            store.health.message = localizedString("the_shareable_image_could_not_be_created")
            TelemetryService.shared.record(error, context: "share_image_prepare")
        }
    }

    private func handleBackupImport(_ result: Result<URL, Error>) {
        guard profileFeatureIsAvailable(.automaticBackups, source: .backupCenter) else {
            return
        }
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try store.importBackup(from: url)
            refreshMetricTextFields()
            store.health.message = localizedString("backup_importado_correctamente")
        } catch {
            store.health.message = error.localizedDescription
            TelemetryService.shared.record(error, context: "backup_import_handle")
        }
    }

    private func handleCSVImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try store.importCSV(from: url)
            refreshMetricTextFields()
            store.health.message = localizedString("csv_importado_correctamente")
        } catch {
            store.health.message = localizedString("could_not_import_the_csv")
            TelemetryService.shared.record(error, context: "csv_import_handle")
        }
    }

    private func handleStrongCSVImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            let count = try store.importStrongCSV(from: url)
            store.health.message = localizedFormat("strong_import_success_format", count)
        } catch {
            store.health.message = localizedString("could_not_import_the_csv")
            TelemetryService.shared.record(error, context: "strong_csv_import_handle")
        }
    }

    private func applyProfileModifiers<V: View>(_ view: V) -> some View {
        view
            .sheet(item: $activeSheet) { sheet in
                profileSheetDestination(sheet)
            }
            .fileImporter(isPresented: $showImportBackup, allowedContentTypes: [.json]) { result in
                handleBackupImport(result)
            }
            .fileImporter(isPresented: $showImportCSV, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handleCSVImport(result)
            }
            .fileImporter(isPresented: $showStrongImport, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handleStrongCSVImport(result)
            }
            .confirmationDialog(
                "delete_all_data",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("delete_all", role: .destructive) {
                    store.resetAllData()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("workouts_routines_metrics_photos_cards_and_local_settings_will_be_removed_export")
            }
            .fullScreenCover(item: $localPaywall) { presentation in
                PaywallView(presentation: presentation) { reason in
                    store.trackPaywallDismissal(presentation, reason: reason)
                    localPaywall = nil
                }
                .environment(store)
            }
    }
}

private struct ProfileToolSection<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedKey(title))
                .font(.headline)
                .padding(.horizontal, 2)

            content
        }
    }
}

private struct ProfileToolButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            ProfileToolCard(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                color: color
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileToolCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    var badge: String?

    var body: some View {
        PulseCard(minHeight: 126, contentPadding: 12) {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(PulseTheme.onColor(color))
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer(minLength: 6)

                if let badge {
                    Text(localizedKey(badge))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(color.opacity(0.65))
                        .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(localizedKey(title))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(localizedKey(subtitle))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
    }
}

private enum ProfileDestination: String, Identifiable {
    case exerciseLibrary
    case goals
    case dataPrivacy
    case supportProduct
    case help
    case privacy
    case roadmap
    case version

    var id: String { rawValue }
}

private enum ProfileSheet: Identifiable {
    case cardioLog
    case bodyLog
    case quickMetricEditor
    case addProgressPhoto
    case addGymPass
    case editGymPass(GymPass)
    case addGymVisit
    case receiptPreview(SavedShareCard)
    case feedback
    case subscription
    case socialOnboarding
    case equipmentRoutineWizard

    var id: String {
        switch self {
        case .cardioLog: "cardioLog"
        case .bodyLog: "bodyLog"
        case .quickMetricEditor: "quickMetricEditor"
        case .addProgressPhoto: "addProgressPhoto"
        case .addGymPass: "addGymPass"
        case .editGymPass(let pass): "editGymPass-\(pass.id.uuidString)"
        case .addGymVisit: "addGymVisit"
        case .receiptPreview(let card): "receiptPreview-\(card.id.uuidString)"
        case .feedback: "feedback"
        case .subscription: "subscription"
        case .socialOnboarding: "socialOnboarding"
        case .equipmentRoutineWizard: "equipmentRoutineWizard"
        }
    }
}

private struct SupportInfoSection: Identifiable {
    let title: String
    let rows: [String]
    var id: String { title }
}

private struct SupportInfoScreen: View {
    let title: String
    let systemImage: String
    let sections: [SupportInfoSection]
    let onBack: () -> Void

    var body: some View {
        StickyHeaderScaffold(
            title: title,
            subtitle: "Soporte",
            backAction: onBack,
            accessory: {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }
        ) {
            ForEach(sections) { section in
                PulseCard(backgroundColor: PulseTheme.grouped) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(section.rows, id: \.self) { row in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(PulseTheme.accent)
                                        .padding(.top, 1)
                                    Text(row)
                                        .font(.subheadline)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .stickyHeaderTitle(section.title)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
    }
}

private struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    let onSend: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.title2.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("feedback")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("tell_us_what_you_would_improve_or_what_flow_was_confusing_for_you")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    PulseCard(backgroundColor: PulseTheme.grouped) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("mensaje")
                                .font(.headline)

                            TextEditor(text: $message)
                                .frame(minHeight: 180)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(PulseTheme.elevated)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text("problema_idea_flujo_confuso_o_funcionalidad_que_falta")
                                            .font(.subheadline)
                                            .foregroundStyle(PulseTheme.tertiaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 18)
                                            .allowsHitTesting(false)
                                    }
                                }

                            Button {
                                onSend(message)
                            } label: {
                                Label("send_feedback", systemImage: "paperplane.fill")
                                    .font(.headline)
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
            .profileSupportSheetBackground()
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

private struct VersionInfoScreen: View {
    let appVersionText: String
    let onBack: () -> Void

    var body: some View {
        StickyHeaderScaffold(
            title: "version_label",
            subtitle: "support",
            backAction: onBack,
            accessory: {
                Image(systemName: "info.circle")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }
        ) {
            PulseCard(backgroundColor: PulseTheme.grouped) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("build")
                        .font(.headline)

                    supportRow(localizedFormat("version_format", appVersionText))
                    supportRow("Bundle ID: \(Bundle.main.bundleIdentifier ?? "com.romerodev.repsfitness")")
                }
            }
            .stickyHeaderTitle(localizedString("build"))

        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
    }

    private func supportRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
                .padding(.top, 1)
            Text(localizedKey(text))
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension View {
    func profileSupportSheetBackground() -> some View {
        background(PulseTheme.card.ignoresSafeArea())
            .presentationBackground(PulseTheme.card)
    }
}

private struct ProfileMetric: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct HealthMiniMetric: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    var tint: Color = PulseTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(localizedKey(title))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.3)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(PulseTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 0.8)
                )
        }
    }
}

/// Glass-tinted capsule button used for Apple Health actions.
/// Replaces the old solid-colour `ProfileActionButtonStyle` with a
/// translucent glass look that doesn't break card harmony.
private struct ProfileActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(color)
            .background {
                RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.18 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                            .stroke(color.opacity(0.35), lineWidth: 1)
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct AvatarPickerLabel: View {
    let imageData: Data?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: "person.crop.square.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(PulseTheme.accent)
            }

            Image(systemName: "camera.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                .frame(width: 24, height: 24)
                .background(PulseTheme.accent)
                .clipShape(Circle())
                .offset(x: 6, y: 6)
        }
    }
}

private struct CalorieRow: View {
    let title: LocalizedStringKey
    let value: Double
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedKey(title))
                    .font(.subheadline.weight(.semibold))
                Text(localizedKey(subtitle))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Text("\(Int(value)) kcal")
                .font(.headline.monospacedDigit())
                .foregroundStyle(PulseTheme.accent)
        }
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ProgressPhotoTile: View {
    let photo: ProgressPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 118, height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            }
            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.semibold))
            Text(photo.weightKg.map { String(format: "%.1f kg", $0) } ?? "sin peso")
                .font(.caption2)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(width: 118, alignment: .leading)
    }
}

private struct GymPassPreview: View {
    let pass: GymPass

    var body: some View {
        HStack(spacing: 14) {
            CodePreview(value: pass.codeValue, type: pass.codeType, imageData: pass.imageData)
                .frame(width: 86, height: 86)
                .background(PulseTheme.codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                .opacity(pass.isActive ? 1 : 0.55)

            VStack(alignment: .leading, spacing: 4) {
                Text(pass.gymName)
                    .font(.headline)
                if !pass.membershipID.isEmpty {
                    Text(pass.membershipID)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                HStack(spacing: 6) {
                    statusBadge
                    if !pass.invoices.isEmpty {
                        Label("\(pass.invoices.count)", systemImage: "doc.text")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                if pass.isActive, pass.renewalReminderEnabled, let renewal = pass.nextRenewalDate {
                    Label(renewal.formatted(date: .abbreviated, time: .omitted), systemImage: "bell")
                        .font(.caption2)
                        .foregroundStyle(PulseTheme.accent)
                } else if let notes = pass.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if pass.isActive {
            Text("membership_active")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
        } else {
            let ended = pass.endDate.map { $0.formatted(date: .abbreviated, time: .omitted) }
            Text(ended.map { localizedFormat("membership_ended_format", $0) } ?? localizedString("membership_ended"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }
}

private struct GymVisitRow: View {
    let visit: GymVisit
    var linkedSessions: [WorkoutSession] = []
    var showsSessionLinks = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(PulseTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.gymName)
                    .font(.subheadline.weight(.semibold))
                if let address = visit.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Text(visit.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                if let workoutTitle = visit.workoutTitle, !workoutTitle.isEmpty {
                    if showsSessionLinks, !linkedSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(linkedSessions) { session in
                                NavigationLink {
                                    WorkoutSessionDetailView(session: session)
                                } label: {
                                    Label(session.workoutTitle, systemImage: "dumbbell.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Label(workoutTitle, systemImage: "dumbbell.fill")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
            }
        }
    }
}

private struct GymVisitTimelineView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .newestFirst
    @State private var sessionFilter: SessionFilter = .all

    private struct DayGroup: Identifiable {
        let date: Date
        let title: String
        let visits: [GymVisit]
        var id: Date { date }
    }

    private enum SortOrder: String, CaseIterable, Identifiable {
        case newestFirst
        case oldestFirst

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newestFirst: "Recientes"
            case .oldestFirst: "Antiguas"
            }
        }
    }

    private enum SessionFilter: String, CaseIterable, Identifiable {
        case all
        case withSession
        case withoutSession

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: localizedString("all").capitalizingFirstLetter()
            case .withSession: "Con sesión"
            case .withoutSession: "Sin sesión"
            }
        }
    }

    private var groups: [DayGroup] {
        let filteredVisits = store.gymVisits
            .filter(matchesSearch)
            .filter(matchesSessionFilter)
            .sorted { lhs, rhs in
                switch sortOrder {
                case .newestFirst: lhs.date > rhs.date
                case .oldestFirst: lhs.date < rhs.date
                }
            }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = RepsLocalization.locale

        let grouped = Dictionary(grouping: filteredVisits) { visit in
            calendar.startOfDay(for: visit.date)
        }

        return grouped.map { date, visits in
            DayGroup(
                date: date,
                title: formatter.string(from: date).capitalizingFirstLetter(),
                visits: visits.sorted { lhs, rhs in
                    switch sortOrder {
                    case .newestFirst: lhs.date > rhs.date
                    case .oldestFirst: lhs.date < rhs.date
                    }
                }
            )
        }
        .sorted { lhs, rhs in
            switch sortOrder {
            case .newestFirst: lhs.date > rhs.date
            case .oldestFirst: lhs.date < rhs.date
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if groups.isEmpty {
                        PulseCard {
                            PulseEmptyState(
                                title: "no_results",
                                message: "completed_sessions_match_message",
                                systemImage: "calendar.badge.exclamationmark"
                            )
                        }
                    } else {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(verbatim: group.title)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.horizontal, 6)

                                LazyVStack(spacing: 10) {
                                    ForEach(group.visits) { visit in
                                        PulseCard {
                                            GymVisitRow(
                                                visit: visit,
                                                linkedSessions: linkedSessions(for: visit),
                                                showsSessionLinks: true
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 116)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .screenBackground()
        .navigationTitle("visit_timeline")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PulseTheme.secondaryText)
                TextField("search_by_title_or_notes", text: $searchText)
                    .font(.subheadline)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PulseTheme.accent.opacity(0.18), lineWidth: 0.8)
            }

            HStack(spacing: 10) {
                Picker("Orden", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.segmented)

                Menu {
                    Picker("Filtro", selection: $sessionFilter) {
                        ForEach(SessionFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                } label: {
                    Label(sessionFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(PulseTheme.grouped, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(PulseTheme.background)
    }

    private func linkedSessions(for visit: GymVisit) -> [WorkoutSession] {
        let ids = Set(visit.workoutSessionIDs)
        guard !ids.isEmpty else { return [] }
        return store.workoutSessions
            .filter { ids.contains($0.id) }
            .sorted { $0.date > $1.date }
    }

    private func matchesSearch(_ visit: GymVisit) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return visit.gymName.localizedCaseInsensitiveContains(query)
            || (visit.address ?? "").localizedCaseInsensitiveContains(query)
            || (visit.locationNote ?? "").localizedCaseInsensitiveContains(query)
            || (visit.workoutTitle ?? "").localizedCaseInsensitiveContains(query)
    }

    private func matchesSessionFilter(_ visit: GymVisit) -> Bool {
        switch sessionFilter {
        case .all:
            true
        case .withSession:
            !visit.workoutSessionIDs.isEmpty
        case .withoutSession:
            visit.workoutSessionIDs.isEmpty
        }
    }
}

private extension UserProfile.MainGoal {
    var displayNameText: String {
        switch self {
        case .buildMuscle: localizedKey("gain_muscle")
        case .bodyRecomposition: "Body recomposition"
        case .loseFat: localizedKey("lose_fat")
        case .getStronger: localizedKey("more_strength")
        case .stayActive: localizedKey("stay_active")
        }
    }
}

private extension UserProfile.Experience {
    var displayNameText: String {
        switch self {
        case .beginner: localizedKey("beginner")
        case .intermediate: localizedKey("intermediate")
        case .advanced: localizedKey("advanced")
        }
    }
}

private func decimal(_ text: String) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}

private struct AvatarMiniView: View {
    let imageData: Data?
    var size: CGFloat = 76

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(PulseTheme.accent.opacity(0.12))
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: size * 0.58))
                        .foregroundStyle(PulseTheme.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.12), radius: 3)
    }
}
