import SwiftUI
import PhotosUI
import UIKit
import CoreImage
import UniformTypeIdentifiers
import StoreKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(AppStore.self) private var store
    var onOpenPlans: (() -> Void)?
    @StateObject private var healthKit = HealthKitService()
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var activeSheet: ProfileSheet?
    @State private var showImportBackup = false
    @State private var showImportCSV = false
    @State private var showDeleteAllConfirmation = false
    @State private var csvExportURL: URL?
    @State private var backupExportURL: URL?
    @State private var shareImageURL: URL?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var localPaywall: PaywallPresentation?
    @State private var suggestedPlanConfirmation: SuggestedPlanConfirmation?
    @State private var activeDestination: ProfileDestination?

    var body: some View {
        applyProfileModifiers(
            StickyHeaderScaffold(
                title: "profile",
                subtitle: "body_data_and_account",
                accessory: {
                    HStack(spacing: 10) {
                        Button {
                            HapticService.selection()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PulseTheme.primary)
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .background(PulseTheme.primary.opacity(0.10))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ProfileDetailView()
                        } label: {
                            let avatarData = store.userProfile.avatarImageData
                            AvatarMiniView(imageData: avatarData, size: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
            ) {
                bodyMetricsCard
                    .stickyHeaderTitle(localizedString("metrics_2"))
                bodyIndexCard
                    .stickyHeaderTitle(localizedString("body_indexes"))
                progressPhotoCard
                    .stickyHeaderTitle(localizedString("photos"))
                achievementsCard
                    .stickyHeaderTitle(localizedString("achievements"))
                gymPassesCard
                    .stickyHeaderTitle(localizedString("gyms"))
                healthCard
                    .stickyHeaderTitle(localizedString("apple_health"))
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
        .mainTabBarHidden()
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
                            color: PulseTheme.primary
                        )
                    }
                    .buttonStyle(.plain)

                    Button { activeSheet = .quickMetricEditor } label: {
                        ProfileMetric(
                            title: "height",
                            value: store.hasBodyMetrics ? String(format: "%.0f", store.displayedHeight.value) : "--",
                            unit: store.hasBodyMetrics ? store.displayedHeight.unit : localizedKey("add"),
                            color: PulseTheme.primaryBright
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
                        ProfileMetric(title: "IMC", value: String(format: "%.1f", store.bodyMassIndex), unit: bmiLabel, color: PulseTheme.accent)
                        ProfileMetric(title: "basal", value: "\(Int(store.basalMetabolicRate))", unit: localizedKey("kcal_per_day"), color: PulseTheme.primary)
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
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primary))
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
                            .foregroundStyle(.white)
                            .background(PulseTheme.primary)
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
        return PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localizedString("achievements_and_tickets"))
                        .font(.headline)
                    Spacer()
                    
                    NavigationLink {
                        AchievementsView()
                    } label: {
                        HStack(spacing: 4) {
                            Text(localizedString("view_all_2"))
                                .font(.caption.weight(.bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(PulseTheme.primary)
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
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let uiImage = UIImage(data: card.imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 160)
                                                .clipShape(SerratedThumbnailShape())
                                                .overlay(
                                                    SerratedThumbnailShape()
                                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                )
                                        } else {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(PulseTheme.grouped)
                                                .frame(width: 100, height: 160)
                                        }
                                        
                                        Text(card.workoutTitle)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .frame(width: 100, alignment: .leading)
                                        
                                        Text(receiptDateString(card.date))
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                            .lineLimit(1)
                                            .frame(width: 100, alignment: .leading)
                                    }
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
    
    private func receiptDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        return formatter.string(from: date).uppercased()
    }

    private var gymPassesCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("gimnasios")
                        .font(.headline)
                    Spacer()
                    Button { activeSheet = .addGymPass } label: {
                        Image(systemName: "qrcode")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.white)
                            .background(PulseTheme.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button { activeSheet = .addGymVisit } label: {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.white)
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
                    ForEach(store.gymPasses) { pass in
                        GymPassPreview(pass: pass)
                    }
                }

                if !store.gymVisits.isEmpty {
                    Divider()
                    Text("visit_timeline")
                        .font(.subheadline.weight(.semibold))
                    ForEach(store.gymVisits.sorted { $0.date > $1.date }.prefix(5)) { visit in
                        GymVisitRow(visit: visit)
                    }
                }
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
                        .foregroundStyle(store.health.isAuthorized ? PulseTheme.primary : PulseTheme.secondaryText)
                }

                HStack(spacing: 10) {
                    Button(store.health.isAuthorized ? "Actualizar" : "Conectar") {
                        Task { await connectHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primary))
                    .disabled(!store.health.isAvailable)

                    Button("sincronizar") {
                        Task { await saveToHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primaryBright))
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
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primary))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized)

                    Button("save_training") {
                        Task { await saveLatestWorkoutToHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primaryBright))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized || store.workoutSessions.isEmpty)
                }

                if let metric = store.todayHealthMetric {
                    LazyVGrid(columns: profileToolColumns, spacing: 10) {
                        HealthMiniMetric(title: "Pasos", value: "\(Int(metric.steps))", systemImage: "figure.walk")
                        HealthMiniMetric(title: "Ejercicio", value: "\(Int(metric.exerciseMinutes ?? 0)) min", systemImage: "figure.strengthtraining.traditional")
                        HealthMiniMetric(title: "Reposo", value: metric.restingHeartRate.map { "\(Int($0)) \(localizedString("lpm"))" } ?? "--", systemImage: "heart")
                        HealthMiniMetric(title: "HRV", value: metric.heartRateVariabilityMS.map { "\(Int($0)) ms" } ?? "--", systemImage: "waveform.path.ecg")
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
                        color: PulseTheme.primary
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
                        title: "goal",
                        subtitle: "strength_or_body",
                        systemImage: "target",
                        color: .orange
                    ) {
                        activeSheet = .goalEditor
                    }

                    ProfileToolButton(
                        title: "equipment_routine",
                        subtitle: "compatible_with_you",
                        systemImage: "wand.and.sparkles",
                        color: PulseTheme.primaryBright
                    ) {
                        createSuggestedEquipmentPlan()
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
        case .goalEditor:
            GoalEditorView()
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
        }
    }

    @ViewBuilder
    private func profileDestination(_ destination: ProfileDestination) -> some View {
        switch destination {
        case .exerciseLibrary:
            ExerciseLibraryView()
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
                                .foregroundStyle(PulseTheme.primary)
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .background(PulseTheme.primary.opacity(0.10))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "externaldrive.badge.icloud")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(PulseTheme.primary)
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
                            color: PulseTheme.primary
                        ) {
                            prepareCSVExport()
                        }

                        if let csvExportURL {
                            ShareLink(item: csvExportURL) {
                                ProfileToolCard(
                                    title: localizedString("Compartir CSV"),
                                    subtitle: localizedString("Enviar archivo"),
                                    systemImage: "square.and.arrow.up",
                                    color: PulseTheme.primary,
                                    badge: localizedString("listo")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        ProfileToolButton(
                            title: localizedString("Imagen"),
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
                            color: PulseTheme.primaryBright
                        ) {
                            showImportCSV = true
                        }

                        ProfileToolButton(
                            title: localizedString("Backup"),
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
                            color: PulseTheme.primary
                        ) {
                            if profileFeatureIsAvailable(.automaticBackups, source: .backupCenter) {
                                showImportBackup = true
                            }
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
                                .foregroundStyle(PulseTheme.primary)
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .background(PulseTheme.primary.opacity(0.10))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "questionmark.bubble.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(PulseTheme.primaryBright)
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
                            color: PulseTheme.primary
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "feedback"])
                            activeSheet = .feedback
                        }
                    }
                }
                .stickyHeaderTitle(localizedString("contacto"))

                ProfileToolSection(title: "product") {
                    LazyVGrid(columns: profileToolColumns, spacing: 12) {
                        ProfileToolButton(
                            title: "help",
                            subtitle: "quick_questions",
                            systemImage: "questionmark.circle",
                            color: PulseTheme.primaryBright
                        ) {
                            TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": "help"])
                            activeDestination = .help
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

    private func createSuggestedEquipmentPlan() {
        let plan = store.createSuggestedPlanForAvailableEquipment()
        HapticService.notification(.success)
        suggestedPlanConfirmation = SuggestedPlanConfirmation(plan: plan)
    }

    private func sendFeedback(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            store.health.message = "Escribe tu feedback antes de enviarlo."
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@romerodev.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Feedback Reps \(appVersionText)"),
            URLQueryItem(name: "body", value: trimmed)
        ]

        if let url = components.url {
            TelemetryService.shared.log(.feedbackSent, parameters: [
                "length_bucket": min(trimmed.count / 100, 9)
            ])
            openURL(url)
            activeSheet = nil
        } else {
            store.health.message = "No se pudo preparar el feedback."
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
            .alert(item: $suggestedPlanConfirmation) { confirmation in
                if onOpenPlans == nil {
                    Alert(
                        title: Text("routine_created"),
                        message: Text(localizedFormat("routine_active_days_per_week_format", confirmation.name, confirmation.daysPerWeek)),
                        dismissButton: .default(Text("ok"))
                    )
                } else {
                    Alert(
                        title: Text("routine_created"),
                        message: Text(localizedFormat("routine_active_days_per_week_format", confirmation.name, confirmation.daysPerWeek)),
                        primaryButton: .default(Text("view_plans")) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onOpenPlans?()
                            }
                        },
                        secondaryButton: .cancel(Text("continue"))
                    )
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
}

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
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(PulseTheme.grouped)
                        .clipShape(Circle())
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
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .navigationDestination(item: $activeDestination) { destination in
            switch destination {
            case .proPreferences:
                ProPreferencesView { presentation in
                    localPaywall = presentation
                }
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

    var id: String { rawValue }
}

private struct ProfileToolSection<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizedKey(title))
                    .font(.headline)

                content
            }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.white)
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
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private enum ProfileDestination: String, Identifiable {
    case exerciseLibrary
    case dataPrivacy
    case supportProduct
    case help
    case privacy
    case roadmap
    case version

    var id: String { rawValue }
}

private enum ProfileSheet: Identifiable {
    case goalEditor
    case cardioLog
    case bodyLog
    case quickMetricEditor
    case addProgressPhoto
    case addGymPass
    case addGymVisit
    case receiptPreview(SavedShareCard)
    case feedback
    case subscription

    var id: String {
        switch self {
        case .goalEditor: "goalEditor"
        case .cardioLog: "cardioLog"
        case .bodyLog: "bodyLog"
        case .quickMetricEditor: "quickMetricEditor"
        case .addProgressPhoto: "addProgressPhoto"
        case .addGymPass: "addGymPass"
        case .addGymVisit: "addGymVisit"
        case .receiptPreview(let card): "receiptPreview-\(card.id.uuidString)"
        case .feedback: "feedback"
        case .subscription: "subscription"
        }
    }
}

private struct SupportInfoSection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [String]
}

private struct SuggestedPlanConfirmation: Identifiable {
    let id: UUID
    let name: String
    let daysPerWeek: Int

    init(plan: WorkoutPlan) {
        id = plan.id
        name = plan.name
        daysPerWeek = plan.daysPerWeek
    }
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
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.primary)
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
                                        .foregroundStyle(PulseTheme.primary)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.title2.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.white)
                            .background(PulseTheme.primary)
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
                                    .foregroundStyle(.black)
                                    .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PulseTheme.elevated : .white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(20)
            }
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
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.primary)
                    .clipShape(Circle())
            }
        ) {
            PulseCard(backgroundColor: PulseTheme.grouped) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("build")
                        .font(.headline)

                    supportRow("Versión: \(appVersionText)")
                    supportRow("Bundle ID: \(Bundle.main.bundleIdentifier ?? "com.romerodev.repsfitness")")
                }
            }
            .stickyHeaderTitle(localizedString("build"))

            #if DEBUG
            PulseCard(backgroundColor: PulseTheme.grouped) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("crashlytics")
                        .font(.headline)

                    Text("this_button_forces_a_test_crash_to_validate_firebase_crashlytics_on_device_or_in")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        TelemetryService.shared.triggerTestCrash()
                    } label: {
                        Label("send_test_crash", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(PulseTheme.destructive)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            #endif
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
    }

    private func supportRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.primary)
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(PulseTheme.primary)
                .background(PulseTheme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedKey(title))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ProfileActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
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
                    .fill(PulseTheme.primary.opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: "person.crop.square.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(PulseTheme.primary)
            }

            Image(systemName: "camera.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
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
                .foregroundStyle(PulseTheme.primary)
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
            CodePreview(value: pass.codeValue, type: pass.codeType)
                .frame(width: 86, height: 86)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(pass.gymName)
                    .font(.headline)
                Text(pass.membershipID)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(PulseTheme.secondaryText)
                if let notes = pass.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct CodePreview: View {
    let value: String
    let type: GymPass.CodeType

    var body: some View {
        if let image = generatedImage {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Image(systemName: type == .qr ? "qrcode" : "barcode")
                .font(.largeTitle)
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }

    private var generatedImage: UIImage? {
        let data = Data(value.utf8)
        let filterName = type == .qr ? "CIQRCodeGenerator" : "CICode128BarcodeGenerator"
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        guard let output = filter.outputImage else { return nil }
        let scale = CGAffineTransform(scaleX: 8, y: 8)
        let image = output.transformed(by: scale)
        return UIImage(ciImage: image)
    }
}

private struct GymVisitRow: View {
    let visit: GymVisit

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(PulseTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.gymName)
                    .font(.subheadline.weight(.semibold))
                Text(visit.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                if let workoutTitle = visit.workoutTitle, !workoutTitle.isEmpty {
                    Text(workoutTitle)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.primary)
                }
            }
        }
    }
}

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var kind: Goal.Kind = .strength
    @State private var title = ""
    @State private var current = ""
    @State private var target = ""
    @State private var unit = "kg"

    var body: some View {
        NavigationStack {
            Form {
                Section("goal") {
                    Picker("training_type", selection: $kind) {
                        ForEach(Goal.Kind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    TextField("qualification", text: $title)
                    TextField("actual", text: $current)
                        .keyboardType(.decimalPad)
                    TextField("meta", text: $target)
                        .keyboardType(.decimalPad)
                    TextField("unidad", text: $unit)
                }
            }
            .navigationTitle("create_goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(title.isEmpty || Double(target.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }

    private func save() {
        let currentValue = Double(current.replacingOccurrences(of: ",", with: ".")) ?? 0
        let targetValue = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
        store.addGoal(Goal(kind: kind, title: title, current: currentValue, target: targetValue, unit: unit, deadline: nil))
        dismiss()
    }
}

struct QuickBodyMetricEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var weight = ""
    @State private var height = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("top_metrics") {
                    TextField("Peso (\(store.displayedWeight.unit))", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("Altura (\(store.displayedHeight.unit))", text: $height)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("edit_body")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if store.hasBodyMetrics {
                    weight = String(format: "%.1f", store.displayedWeight.value)
                    height = String(format: "%.0f", store.displayedHeight.value)
                } else {
                    weight = ""
                    height = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(decimal(weight) == nil || decimal(height) == nil)
                }
            }
        }
    }

    private func save() {
        guard let rawWeight = decimal(weight), let rawHeight = decimal(height) else { return }
        let weightKg = store.userProfile.units == .metric ? rawWeight : UnitConverter.kilograms(fromPounds: rawWeight)
        let heightCm = store.userProfile.units == .metric ? rawHeight : UnitConverter.centimeters(fromInches: rawHeight)
        store.updateLatestBodyMetrics(weightKg: weightKg, heightCm: heightCm)
        dismiss()
    }
}

struct ProgressPhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var date = Date()
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var showPermissionDenied = false
    @State private var permissionDeniedMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("photo_2") {
                    VStack(spacing: 10) {
                        if CameraPicker.isAvailable {
                            Button(action: requestCameraAndOpen) {
                                ProgressPhotoSourceActionLabel(
                                    title: "take_photo",
                                    subtitle: "camera",
                                    systemImage: "camera.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            #if targetEnvironment(simulator)
                            Button {
                                if let image = UIImage(systemName: "figure.strengthtraining.traditional"),
                                   let data = image.jpegData(compressionQuality: 0.72) {
                                    imageData = data
                                    HapticService.notification(.success)
                                }
                            } label: {
                                ProgressPhotoSourceActionLabel(
                                    title: "Simular foto",
                                    subtitle: "Vista previa del simulador",
                                    systemImage: "camera.badge.ellipsis"
                                )
                            }
                            .buttonStyle(.plain)
                            #endif
                        }

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack(spacing: 14) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(PulseTheme.primary)
                                    .frame(width: 42, height: 42)
                                    .background(PulseTheme.primary.opacity(0.14))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("choose_from_gallery")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("photos")
                                        .font(.subheadline)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }

                                Spacer(minLength: 12)

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(PulseTheme.tertiaryText)
                            }
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(PulseTheme.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            .accessibilityLabel("selected_photo")
                    } else {
                        ProgressPhotoEmptyPreview()
                    }
                }

                Section("contexto") {
                    DatePicker("date_2", selection: $date, displayedComponents: [.date])
                    Text(store.hasBodyMetrics ? "Peso actual: \(String(format: "%.1f", store.currentWeight)) kg" : "Peso actual: sin registrar")
                    TextField("nota", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("progress_photo")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(imageData == nil)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let compressed = image.jpegData(compressionQuality: 0.72) {
                        imageData = compressed
                    }
                }
                .ignoresSafeArea()
            }
            .alert("permission_required", isPresented: $showPermissionDenied) {
                Button("abrir_ajustes") {
                    PermissionService.shared.openSettings()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text(permissionDeniedMessage)
            }
        }
    }

    private func requestCameraAndOpen() {
        Task {
            let granted = await PermissionService.shared.requestCamera()
            if granted {
                showCamera = true
            } else {
                permissionDeniedMessage = PermissionService.shared.deniedMessage ?? "La cámara está bloqueada. Actívala en Ajustes → Reps."
                showPermissionDenied = true
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.72) else {
            return
        }
        imageData = compressed
    }

    private func save() {
        guard let imageData else { return }
        store.addProgressPhoto(ProgressPhoto(date: date, imageData: imageData, weightKg: store.hasBodyMetrics ? store.currentWeight : nil, note: note.isEmpty ? nil : note))
        dismiss()
    }
}

private struct ProgressPhotoSourceActionLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 42, height: 42)
                .background(PulseTheme.primary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedKey(title))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(localizedKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PulseTheme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(PulseTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ProgressPhotoEmptyPreview: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(PulseTheme.primary)
            Text("no_photo_selected")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct GymPassEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var gymName = ""
    @State private var membershipID = ""
    @State private var codeValue = ""
    @State private var codeType: GymPass.CodeType = .qr
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("tarjeta") {
                    TextField("gym_2", text: $gymName)
                    TextField("id_socio", text: $membershipID)
                    Picker("training_type", selection: $codeType) {
                        Text("qr").tag(GymPass.CodeType.qr)
                        Text("barcode_2").tag(GymPass.CodeType.barcode)
                    }
                    .pickerStyle(.segmented)
                    TextField("valor_qr_barcode", text: $codeValue)
                        .textInputAutocapitalization(.never)
                    TextField("notes_2", text: $notes, axis: .vertical)
                }

                if !codeValue.isEmpty {
                    Section("preview") {
                        CodePreview(value: codeValue, type: codeType)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                    }
                }
            }
            .navigationTitle("gym_card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(gymName.isEmpty || codeValue.isEmpty)
                }
            }
        }
    }

    private func save() {
        store.addGymPass(GymPass(
            gymName: gymName,
            membershipID: membershipID.isEmpty ? codeValue : membershipID,
            codeValue: codeValue,
            codeType: codeType,
            notes: notes.isEmpty ? nil : notes
        ))
        dismiss()
    }
}

struct GymVisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var gymName = ""
    @State private var date = Date()
    @State private var locationNote = ""
    @State private var workoutTitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("visita") {
                    TextField("gym_local", text: $gymName)
                    DatePicker("date_2", selection: $date)
                    TextField("location_or_room", text: $locationNote)
                    TextField("training_done", text: $workoutTitle)
                }

                if !store.gymPasses.isEmpty {
                    Section("fast") {
                        ForEach(store.gymPasses) { pass in
                            Button(pass.gymName) {
                                gymName = pass.gymName
                            }
                        }
                    }
                }
            }
            .navigationTitle("registrar_visita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(gymName.isEmpty)
                }
            }
        }
    }

    private func save() {
        store.addGymVisit(GymVisit(
            gymName: gymName,
            date: date,
            locationNote: locationNote.isEmpty ? nil : locationNote,
            workoutTitle: workoutTitle.isEmpty ? nil : workoutTitle
        ))
        dismiss()
    }
}

struct CardioLogEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var activityType: CardioLog.ActivityType = .treadmill
    @State private var date = Date()
    @State private var duration = "30"
    @State private var distance = ""
    @State private var averageHeartRate = ""
    @State private var maxHeartRate = ""
    @State private var calories = ""
    @State private var rpe = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("activity_2") {
                    Picker("training_type", selection: $activityType) {
                        ForEach(CardioLog.ActivityType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    DatePicker("date_2", selection: $date)
                    TextField("duration_min_2", text: $duration)
                        .keyboardType(.numberPad)
                    TextField("Distancia (\(store.userProfile.distanceUnit.rawValue))", text: $distance)
                        .keyboardType(.decimalPad)
                }

                Section("intensidad") {
                    TextField("fc_media", text: $averageHeartRate)
                        .keyboardType(.decimalPad)
                    TextField("maximum_hr", text: $maxHeartRate)
                        .keyboardType(.decimalPad)
                    TextField("calories_2", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("rpe_1_10", text: $rpe)
                        .keyboardType(.decimalPad)
                }

                Section("notes_2") {
                    TextField("sensaciones_ritmo_molestias", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("registrar_cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(Int(duration) == nil)
                }
            }
        }
    }

    private func save() {
        let distanceValue = decimal(distance)
        let distanceKm: Double?
        if let distanceValue {
            distanceKm = store.userProfile.distanceUnit == .kilometers ? distanceValue : distanceValue * 1.609_344
        } else {
            distanceKm = nil
        }

        store.addCardioLog(CardioLog(
            activityType: activityType,
            date: date,
            durationMinutes: Int(duration) ?? 0,
            distanceKm: distanceKm,
            averageSpeedKmh: nil,
            averagePaceSecondsPerKm: nil,
            averageHeartRate: decimal(averageHeartRate),
            maxHeartRate: decimal(maxHeartRate),
            estimatedCalories: decimal(calories),
            rpe: decimal(rpe),
            notes: notes.isEmpty ? nil : notes
        ))
        dismiss()
    }
}

struct BodyWellnessEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @StateObject private var healthKit = HealthKitService()

    @State private var date = Date()
    @State private var weight = ""
    @State private var height = ""
    @State private var bodyFat = ""
    @State private var waist = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var thigh = ""
    @State private var hip = ""
    @State private var sleep = ""
    @State private var sleepQuality = 3
    @State private var fatigue = 3
    @State private var stress = 3
    @State private var water = ""
    @State private var dietaryEnergy = ""
    @State private var soreness = ""
    @State private var healthDefaultsMessage: String?

    init(initialWeightKg: Double, initialHeightCm: Double) {
        _weight = State(initialValue: String(format: "%.1f", initialWeightKg))
        _height = State(initialValue: String(format: "%.0f", initialHeightCm))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("essential") {
                    DatePicker("date_2", selection: $date)
                    TextField("weight_kg_2", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("height_cm_2", text: $height)
                        .keyboardType(.decimalPad)
                    TextField("body_fat", text: $bodyFat)
                        .keyboardType(.decimalPad)
                }

                if let healthDefaultsMessage {
                    Section("apple_health") {
                        Text(healthDefaultsMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("measurements") {
                    TextField("cintura_cm", text: $waist)
                        .keyboardType(.decimalPad)
                    TextField("pecho_cm", text: $chest)
                        .keyboardType(.decimalPad)
                    TextField("brazo_cm", text: $arm)
                        .keyboardType(.decimalPad)
                    TextField("muslo_cm", text: $thigh)
                        .keyboardType(.decimalPad)
                    TextField("cadera_cm", text: $hip)
                        .keyboardType(.decimalPad)
                }

                Section("wellness") {
                    TextField("sleep_hours_2", text: $sleep)
                        .keyboardType(.decimalPad)
                    TextField("water_l", text: $water)
                        .keyboardType(.decimalPad)
                    TextField("energy_ingested_kcal", text: $dietaryEnergy)
                        .keyboardType(.decimalPad)
                    Stepper(value: $sleepQuality, in: 1...5) {
                        Text(localizedFormat("sleep_quality_value_format", sleepQuality))
                    }
                    Stepper(value: $fatigue, in: 1...5) {
                        Text(localizedFormat("fatigue_value_format", fatigue))
                    }
                    Stepper(value: $stress, in: 1...5) {
                        Text(localizedFormat("stress_value_format", stress))
                    }
                    TextField("discomfort_or_injuries", text: $soreness, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("body_and_wellness")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadHealthDefaults()
            }
            .onChange(of: date) { _, _ in
                Task { await loadHealthDefaults() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(decimal(weight) == nil || decimal(height) == nil)
                }
            }
        }
    }

    private func loadHealthDefaults() async {
        guard healthKit.isAvailable, store.health.isAuthorized else { return }

        do {
            let defaults = try await healthKit.fetchBodyWellnessDefaults(for: date)
            applyHealthDefaults(defaults)
            healthDefaultsMessage = "Valores sugeridos desde Apple Health. Puedes editarlos antes de guardar."
        } catch {
            healthDefaultsMessage = error.localizedDescription
        }
    }

    private func applyHealthDefaults(_ defaults: BodyWellnessDefaults) {
        fill(&bodyFat, with: defaults.bodyFatPercentage, format: "%.1f")
        fill(&waist, with: defaults.waistCm, format: "%.1f")
        fill(&sleep, with: defaults.sleepHours, format: "%.1f")
        fill(&water, with: defaults.waterLiters, format: "%.2f")
        fill(&dietaryEnergy, with: defaults.dietaryEnergyKcal, format: "%.0f")

        if sleepQuality == 3, let suggested = defaults.sleepQuality {
            sleepQuality = suggested
        }
        if fatigue == 3, let suggested = defaults.fatigue {
            fatigue = suggested
        }
        if stress == 3, let suggested = defaults.stress {
            stress = suggested
        }
    }

    private func fill(_ text: inout String, with value: Double?, format: String) {
        guard text.isEmpty, let value else { return }
        text = String(format: format, value)
    }

    private func save() {
        guard let weightKg = decimal(weight), let heightCm = decimal(height) else { return }
        store.saveBodyMetric(BodyMetric(
            date: date,
            weightKg: weightKg,
            heightCm: heightCm,
            bodyFatPercentage: decimal(bodyFat),
            waistCm: decimal(waist),
            chestCm: decimal(chest),
            armCm: decimal(arm),
            thighCm: decimal(thigh),
            hipCm: decimal(hip),
            calfCm: nil,
            neckCm: nil,
            sleepHours: decimal(sleep),
            sleepQuality: sleepQuality,
            fatigue: fatigue,
            stress: stress,
            waterLiters: decimal(water),
            dietaryEnergyKcal: decimal(dietaryEnergy),
            sorenessNotes: soreness.isEmpty ? nil : soreness,
            source: .manual
        ))
        dismiss()
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
                            .font(.headline)
                            .foregroundStyle(PulseTheme.primary)

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
                            .foregroundStyle(PulseTheme.primary)

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
                    ScrollView {
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
                        .padding(20)
                    }
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

private extension CardioLog.ActivityType {
    var displayName: LocalizedStringKey {
        switch self {
        case .treadmill: "treadmill"
        case .elliptical: "elliptical"
        case .stationaryBike: "stationary_bike"
        case .outdoorRun: "outdoor_run"
        case .walking: "walking"
        case .rowing: "rowing"
        case .hiit: "HIIT"
        case .other: "other"
        }
    }
}

private extension Goal.Kind {
    var displayName: LocalizedStringKey {
        switch self {
        case .strength: "strength"
        case .consistency: "consistency"
        case .bodyWeight: "bodyweight"
        case .custom: "custom"
        }
    }
}

private extension UserProfile.MainGoal {
    var displayNameText: String {
        switch self {
        case .buildMuscle: localizedKey("gain_muscle")
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
                        .fill(PulseTheme.primary.opacity(0.12))
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: size * 0.58))
                        .foregroundStyle(PulseTheme.primary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.12), radius: 3)
    }
}

private struct ReceiptPreviewSheet: View {
    let card: SavedShareCard
    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let img = uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 520)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.24), radius: 12, x: 0, y: 6)
                } else {
                    ProgressView()
                        .frame(height: 300)
                }
                
                if let img = uiImage {
                    ShareLink(item: Image(uiImage: img), preview: SharePreview(card.workoutTitle, image: Image(uiImage: img))) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("share_receipt")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(PulseTheme.primaryBright)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 24)
            .screenBackground()
            .navigationTitle(card.workoutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            uiImage = UIImage(data: card.imageData)
        }
    }
}
