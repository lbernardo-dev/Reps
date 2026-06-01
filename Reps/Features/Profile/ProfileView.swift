import SwiftUI
import PhotosUI
import UIKit
import CoreImage
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @StateObject private var healthKit = HealthKitService()
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var showExerciseLibrary = false
    @State private var showGoalEditor = false
    @State private var showCardioLog = false
    @State private var showBodyLog = false
    @State private var showQuickMetricEditor = false
    @State private var showAddProgressPhoto = false
    @State private var showAddGymPass = false
    @State private var showAddGymVisit = false
    @State private var showProPreferences = false
    @State private var showImportBackup = false
    @State private var showImportCSV = false
    @State private var showDeleteAllConfirmation = false
    @State private var csvExportURL: URL?
    @State private var backupExportURL: URL?
    @State private var shareImageURL: URL?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var selectedReceiptForPreview: SavedShareCard? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        Button {
                            HapticService.selection()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        let isSpanish = store.userProfile.preferredLanguage.hasPrefix("es")
                        Text(isSpanish ? "Perfil" : "Profile")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        Spacer()
                        
                        NavigationLink {
                            ProfileDetailView()
                        } label: {
                            let avatarData = store.userProfile.avatarImageData
                            AvatarMiniView(imageData: avatarData, size: 40)
                        }
                        .buttonStyle(.plain)
                    }

                    bodyMetricsCard
                    bodyIndexCard
                    progressPhotoCard
                    achievementsCard
                    gymPassesCard
                    healthCard
                    settingsCard
                    toolsCard
                }
                .padding(20)
                .padding(.bottom, 112)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                weightText = String(format: "%.1f", store.displayedWeight.value)
                heightText = String(format: "%.0f", store.displayedHeight.value)
                store.health.isAvailable = healthKit.isAvailable
            }
            .onChange(of: store.userProfile.units) { _, _ in
                weightText = String(format: "%.1f", store.displayedWeight.value)
                heightText = String(format: "%.0f", store.displayedHeight.value)
            }
            .sheet(isPresented: $showExerciseLibrary) {
                ExerciseLibraryView()
            }
            .sheet(isPresented: $showGoalEditor) {
                GoalEditorView()
            }
            .sheet(isPresented: $showCardioLog) {
                CardioLogEditorView()
            }
            .sheet(isPresented: $showBodyLog) {
                BodyWellnessEditorView(
                    initialWeightKg: store.currentWeight,
                    initialHeightCm: store.currentHeight
                )
            }
            .sheet(isPresented: $showQuickMetricEditor) {
                QuickBodyMetricEditorView()
            }
            .sheet(isPresented: $showAddProgressPhoto) {
                ProgressPhotoEditorView()
            }
            .sheet(isPresented: $showAddGymPass) {
                GymPassEditorView()
            }
            .sheet(isPresented: $showAddGymVisit) {
                GymVisitEditorView()
            }
            .sheet(isPresented: $showProPreferences) {
                ProPreferencesView()
            }
            .fileImporter(isPresented: $showImportBackup, allowedContentTypes: [.json]) { result in
                handleBackupImport(result)
            }
            .fileImporter(isPresented: $showImportCSV, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handleCSVImport(result)
            }
            .confirmationDialog(
                "Borrar todos los datos",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Borrar todo", role: .destructive) {
                    store.resetAllData()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se eliminarán entrenos, rutinas, métricas, fotos, tarjetas y ajustes locales. Exporta un backup antes si quieres conservarlos.")
            }
            .onChange(of: avatarPickerItem) { _, item in
                Task { await loadAvatar(from: item) }
            }
            .sheet(item: $selectedReceiptForPreview) { card in
                ReceiptPreviewSheet(card: card)
            }
        }
    }



    private var bodyMetricsCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Métricas corporales")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button { showQuickMetricEditor = true } label: {
                        ProfileMetric(title: "Peso", value: String(format: "%.1f", store.displayedWeight.value), unit: store.displayedWeight.unit, color: PulseTheme.primary)
                    }
                    .buttonStyle(.plain)

                    Button { showQuickMetricEditor = true } label: {
                        ProfileMetric(title: "Altura", value: String(format: "%.0f", store.displayedHeight.value), unit: store.displayedHeight.unit, color: PulseTheme.primaryBright)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showBodyLog = true
                } label: {
                    PulseListRow(title: "Registro avanzado", subtitle: "Peso, grasa, medidas, sueño, estrés y molestias", systemImage: "heart.text.square")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bodyIndexCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Índices corporales")
                        .font(.headline)
                    Spacer()
                    Text("estimación")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                HStack(spacing: 12) {
                    ProfileMetric(title: "IMC", value: String(format: "%.1f", store.bodyMassIndex), unit: bmiLabel, color: PulseTheme.accent)
                    ProfileMetric(title: "Basal", value: "\(Int(store.basalMetabolicRate))", unit: "kcal/día", color: PulseTheme.primary)
                }

                VStack(spacing: 10) {
                    CalorieRow(title: "Déficit", value: store.deficitCalories, subtitle: "perder grasa")
                    CalorieRow(title: "Recomposición", value: store.recompositionCalories, subtitle: "progreso estable")
                    CalorieRow(title: "Volumen", value: store.leanBulkCalories, subtitle: "ganancia controlada")
                }
            }
        }
    }

    private var progressPhotoCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Fotos de progreso")
                        .font(.headline)
                    Spacer()
                    Button {
                        showAddProgressPhoto = true
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
                        title: "Aún no hay fotos",
                        message: "Añade fotos periódicas para comparar tu evolución con contexto de fecha y peso.",
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
        let isSpanish = store.userProfile.preferredLanguage.hasPrefix("es")
        return PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(isSpanish ? "Logros y Recibos" : "Achievements & Tickets")
                        .font(.headline)
                    Spacer()
                    
                    NavigationLink {
                        AchievementsView()
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSpanish ? "Ver todo" : "View all")
                                .font(.caption.weight(.bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(PulseTheme.primary)
                    }
                    .buttonStyle(.plain)
                }

                if store.savedShareCards.isEmpty {
                    PulseEmptyState(
                        title: isSpanish ? "Sin logros aún" : "No achievements yet",
                        message: isSpanish 
                            ? "Completa tus sesiones para registrar logros de Apple Health y guardar tus recibos automáticamente."
                            : "Complete workouts to track Apple Health achievements and auto-save training tickets here.",
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
                                    
                                    Text(isSpanish ? "Logros" : "Achievements")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    
                                    Text(isSpanish ? "VER HITOS" : "VIEW MILESTONES")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(PulseTheme.accent)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            ForEach(store.savedShareCards.sorted { $0.date > $1.date }) { card in
                                Button {
                                    selectedReceiptForPreview = card
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
                    Text("Gimnasios")
                        .font(.headline)
                    Spacer()
                    Button { showAddGymPass = true } label: {
                        Image(systemName: "qrcode")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.white)
                            .background(PulseTheme.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button { showAddGymVisit = true } label: {
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
                        title: "Sin tarjetas de gimnasio",
                        message: "Guarda QR o código de barras de tus gimnasios para tenerlos siempre a mano.",
                        systemImage: "wallet.pass"
                    )
                } else {
                    ForEach(store.gymPasses) { pass in
                        GymPassPreview(pass: pass)
                    }
                }

                if !store.gymVisits.isEmpty {
                    Divider()
                    Text("Timeline de visitas")
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
                    Label("Apple Health", systemImage: "heart.fill")
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

                    Button("Sincronizar") {
                        Task { await saveToHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primaryBright))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized)
                }

                HStack(spacing: 10) {
                    Button("Importar cardio") {
                        Task { await importCardioFromHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primary))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized)

                    Button("Guardar entreno") {
                        Task { await saveLatestWorkoutToHealth() }
                    }
                    .buttonStyle(ProfileActionButtonStyle(color: PulseTheme.primaryBright))
                    .disabled(!store.health.isAvailable || !store.health.isAuthorized || store.workoutSessions.isEmpty)
                }

                if let metric = store.todayHealthMetric {
                    LazyVGrid(columns: profileToolColumns, spacing: 10) {
                        HealthMiniMetric(title: "Pasos", value: "\(Int(metric.steps))", systemImage: "figure.walk")
                        HealthMiniMetric(title: "Ejercicio", value: "\(Int(metric.exerciseMinutes ?? 0)) min", systemImage: "figure.strengthtraining.traditional")
                        HealthMiniMetric(title: "Reposo", value: metric.restingHeartRate.map { "\(Int($0)) lpm" } ?? "--", systemImage: "heart")
                        HealthMiniMetric(title: "HRV", value: metric.heartRateVariabilityMS.map { "\(Int($0)) ms" } ?? "--", systemImage: "waveform.path.ecg")
                    }
                }

                if store.health.isAuthorized {
                    Button("Desconectar Apple Health", role: .destructive) {
                        store.disconnectHealth()
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if let message = store.health.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private var settingsCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ajustes")
                    .font(.headline)

                Picker("Unidades", selection: $store.userProfile.units) {
                    ForEach(UserProfile.Units.allCases) { units in
                        Text(units.rawValue).tag(units)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Idioma", selection: $store.userProfile.preferredLanguage) {
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }
                .pickerStyle(.segmented)

                Picker("Distancia", selection: $store.userProfile.distanceUnit) {
                    ForEach(UserProfile.DistanceUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Tema", selection: Binding(
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

                Picker("Color de Widgets", selection: Binding(
                    get: { store.userProfile.widgetAccentColorName },
                    set: { colorName in
                        store.userProfile.widgetAccentColorName = colorName
                        store.syncWidgets()
                        HapticService.selection()
                    }
                )) {
                    let widgetColors = ["system", "blue", "green", "orange", "purple", "red", "yellow"]
                    let colorTranslations = [
                        "system": "Sistema",
                        "blue": "Azul",
                        "green": "Verde",
                        "orange": "Naranja",
                        "purple": "Morado",
                        "red": "Rojo",
                        "yellow": "Amarillo"
                    ]
                    ForEach(widgetColors, id: \.self) { colorName in
                        Text(colorTranslations[colorName] ?? colorName.capitalized).tag(colorName)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Recordatorios de entreno", isOn: Binding(
                    get: { store.userProfile.remindersEnabled },
                    set: { enabled in
                        store.userProfile.remindersEnabled = enabled
                        if enabled {
                            Task { await enableReminders() }
                        } else {
                            NotificationService.clearWorkoutReminders()
                        }
                    }
                ))
                .font(.headline)

                Button {
                    showProPreferences = true
                } label: {
                    PulseListRow(title: "Preferencias Pro", subtitle: "RPE/RIR, tipo de serie, tempo y auto-progresión", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Centro de acciones")
                .font(.title3.bold())
                .padding(.horizontal, 2)

            ProfileToolSection(title: "Entrenar y construir") {
                LazyVGrid(columns: profileToolColumns, spacing: 12) {
                    ProfileToolButton(
                        title: "Biblioteca",
                        subtitle: "\(store.exercises.count) ejercicios",
                        systemImage: "magnifyingglass",
                        color: PulseTheme.primary
                    ) {
                        showExerciseLibrary = true
                    }

                    ProfileToolButton(
                        title: "Cardio",
                        subtitle: "Ruta, pulso y RPE",
                        systemImage: "figure.run",
                        color: PulseTheme.accent
                    ) {
                        showCardioLog = true
                    }

                    ProfileToolButton(
                        title: "Objetivo",
                        subtitle: "Fuerza o cuerpo",
                        systemImage: "target",
                        color: .orange
                    ) {
                        showGoalEditor = true
                    }

                    ProfileToolButton(
                        title: "Rutina por equipo",
                        subtitle: "Compatible contigo",
                        systemImage: "wand.and.sparkles",
                        color: PulseTheme.primaryBright
                    ) {
                        store.createSuggestedPlanForAvailableEquipment()
                    }
                }
            }

            ProfileToolSection(title: "Compartir y exportar") {
                LazyVGrid(columns: profileToolColumns, spacing: 12) {
                    ProfileToolButton(
                        title: "CSV",
                        subtitle: csvExportURL == nil ? "Generar archivo" : "Listo para compartir",
                        systemImage: "tablecells",
                        color: PulseTheme.primary
                    ) {
                        prepareCSVExport()
                    }

                    if let csvExportURL {
                        ShareLink(item: csvExportURL) {
                            ProfileToolCard(
                                title: "Compartir CSV",
                                subtitle: "Enviar archivo",
                                systemImage: "square.and.arrow.up",
                                color: PulseTheme.primary,
                                badge: "listo"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ProfileToolButton(
                        title: "Imagen",
                        subtitle: shareImageURL == nil ? "Resumen privado" : "PNG listo",
                        systemImage: "photo.on.rectangle",
                        color: .orange
                    ) {
                        prepareWorkoutShareImage()
                    }

                    if let shareImageURL {
                        ShareLink(item: shareImageURL) {
                            ProfileToolCard(
                                title: "Compartir PNG",
                                subtitle: "Último entreno",
                                systemImage: "square.and.arrow.up",
                                color: .orange,
                                badge: "listo"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ProfileToolSection(title: "Datos y privacidad") {
                LazyVGrid(columns: profileToolColumns, spacing: 12) {
                    ProfileToolButton(
                        title: "Importar CSV",
                        subtitle: "Cardio y cuerpo",
                        systemImage: "square.and.arrow.down",
                        color: PulseTheme.primaryBright
                    ) {
                        showImportCSV = true
                    }

                    ProfileToolButton(
                        title: "Backup",
                        subtitle: backupExportURL == nil ? "Generar JSON" : "JSON listo",
                        systemImage: "externaldrive",
                        color: PulseTheme.accent
                    ) {
                        prepareBackupExport()
                    }

                    if let backupExportURL {
                        ShareLink(item: backupExportURL) {
                            ProfileToolCard(
                                title: "Compartir backup",
                                subtitle: "Copia completa",
                                systemImage: "doc.badge.gearshape",
                                color: PulseTheme.accent,
                                badge: "listo"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ProfileToolButton(
                        title: "Restaurar",
                        subtitle: "Importar JSON",
                        systemImage: "arrow.down.doc",
                        color: PulseTheme.primary
                    ) {
                        showImportBackup = true
                    }

                    ProfileToolButton(
                        title: "Borrar datos",
                        subtitle: "Reiniciar app",
                        systemImage: "trash",
                        color: .red
                    ) {
                        showDeleteAllConfirmation = true
                    }
                }
            }
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
        case ..<18.5: "bajo"
        case 18.5..<25: "normal"
        case 25..<30: "alto"
        default: "muy alto"
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
            store.health.message = "Introduce valores válidos de peso y altura."
            return
        }
        let weight = store.userProfile.units == .metric ? rawWeight : UnitConverter.kilograms(fromPounds: rawWeight)
        let height = store.userProfile.units == .metric ? rawHeight : UnitConverter.centimeters(fromInches: rawHeight)
        store.saveBodyMetrics(weightKg: weight, heightCm: height)
        store.health.message = String(localized: "Métricas corporales guardadas en Reps.")
    }

    private func connectHealth() async {
        do {
            try await healthKit.requestAuthorization()
            store.health.isAuthorized = healthKit.hasWriteAuthorization
            store.health.lastSyncDate = .now
            let metrics = try await healthKit.fetchLatestBodyMetrics()
            if metrics.weightKg != nil || metrics.heightCm != nil {
                store.saveBodyMetrics(
                    weightKg: metrics.weightKg ?? store.currentWeight,
                    heightCm: metrics.heightCm ?? store.currentHeight,
                    source: .appleHealth
                )
                let dailyMetrics = try await healthKit.fetchDailyMetrics()
                store.health.latestDailyMetrics = dailyMetrics
                store.health.message = String(localized: "Apple Health conectado. Peso, altura, pasos, calorías e hidratación importados.")
            } else {
                store.health.latestDailyMetrics = try await healthKit.fetchDailyMetrics()
                store.health.message = String(localized: "Apple Health conectado. Actividad diaria y nutrición importadas.")
            }
        } catch {
            store.health.message = error.localizedDescription
        }
    }

    private func importCardioFromHealth() async {
        do {
            let logs = try await healthKit.fetchRecentCardioLogs()
            let imported = store.importCardioLogs(logs)
            store.health.lastSyncDate = .now
            store.health.message = String(localized: "Cardio importado desde Apple Health: \(imported) registros nuevos.")
        } catch {
            store.health.message = error.localizedDescription
        }
    }

    private func saveToHealth() async {
        do {
            try await healthKit.saveBodyMetrics(weightKg: store.currentWeight, heightCm: store.currentHeight)
            if let latestMetric = store.bodyMetrics.sorted(by: { $0.date > $1.date }).first {
                try await healthKit.saveDailyNutrition(
                    waterLiters: latestMetric.waterLiters,
                    dietaryEnergyKcal: latestMetric.dietaryEnergyKcal,
                    date: latestMetric.date
                )
            }
            store.health.lastSyncDate = .now
            store.health.message = String(localized: "Peso, altura, hidratación y energía guardados en Apple Health cuando hay datos disponibles.")
        } catch {
            store.health.message = error.localizedDescription
        }
    }

    private func saveLatestWorkoutToHealth() async {
        guard let session = store.workoutSessions.sorted(by: { $0.date > $1.date }).first else {
            return
        }

        do {
            try await healthKit.saveWorkout(session)
            store.health.lastSyncDate = .now
            store.health.message = String(localized: "Último entreno guardado en Apple Health.")
        } catch {
            store.health.message = error.localizedDescription
        }
    }

    private func enableReminders() async {
        do {
            let granted = try await NotificationService.requestAuthorization()
            guard granted else {
                store.userProfile.remindersEnabled = false
                return
            }

            for scheduled in store.scheduledWorkouts where scheduled.status == .scheduled {
                try await NotificationService.scheduleWorkoutReminder(for: scheduled)
                try await NotificationService.scheduleMissedWorkoutCheck(for: scheduled)
            }
            try await NotificationService.scheduleDailySummary()
        } catch {
            store.userProfile.remindersEnabled = false
            store.health.message = error.localizedDescription
        }
    }

    private func prepareCSVExport() {
        do {
            csvExportURL = try store.exportCSVURL()
            store.health.message = String(localized: "CSV generado. Usa Compartir CSV para enviarlo.")
        } catch {
            store.health.message = error.localizedDescription
        }
    }

    private func prepareBackupExport() {
        do {
            backupExportURL = try store.exportBackupURL()
            store.health.message = String(localized: "Backup generado. Usa Compartir backup para enviarlo.")
        } catch {
            store.health.message = error.localizedDescription
        }
    }

    private func prepareWorkoutShareImage() {
        do {
            shareImageURL = try store.exportWorkoutShareImageURL()
            store.health.message = String(localized: "Imagen generada. Usa Compartir imagen para enviarla.")
        } catch {
            store.health.message = String(localized: "No se pudo crear la imagen compartible.")
        }
    }

    private func handleBackupImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try store.importBackup(from: url)
            weightText = String(format: "%.1f", store.displayedWeight.value)
            heightText = String(format: "%.0f", store.displayedHeight.value)
            store.health.message = String(localized: "Backup importado correctamente.")
        } catch {
            store.health.message = error.localizedDescription
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
            weightText = String(format: "%.1f", store.displayedWeight.value)
            heightText = String(format: "%.0f", store.displayedHeight.value)
            store.health.message = String(localized: "CSV importado correctamente.")
        } catch {
            store.health.message = String(localized: "No se pudo importar el CSV.")
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
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
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
        Button(action: action) {
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
                    Text(badge)
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
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
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

private struct ProfileMetric: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
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
                Text(title)
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
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
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
    @EnvironmentObject private var store: AppStore

    @State private var kind: Goal.Kind = .strength
    @State private var title = ""
    @State private var current = ""
    @State private var target = ""
    @State private var unit = "kg"

    var body: some View {
        NavigationStack {
            Form {
                Section("Objetivo") {
                    Picker("Tipo", selection: $kind) {
                        ForEach(Goal.Kind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    TextField("Título", text: $title)
                    TextField("Actual", text: $current)
                        .keyboardType(.decimalPad)
                    TextField("Meta", text: $target)
                        .keyboardType(.decimalPad)
                    TextField("Unidad", text: $unit)
                }
            }
            .navigationTitle("Crear objetivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
    @EnvironmentObject private var store: AppStore
    @State private var weight = ""
    @State private var height = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Métricas principales") {
                    TextField("Peso (\(store.displayedWeight.unit))", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("Altura (\(store.displayedHeight.unit))", text: $height)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Editar cuerpo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                weight = String(format: "%.1f", store.displayedWeight.value)
                height = String(format: "%.0f", store.displayedHeight.value)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
    @EnvironmentObject private var store: AppStore
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
                Section("Foto") {
                    VStack(spacing: 10) {
                        if CameraPicker.isAvailable {
                            Button(action: requestCameraAndOpen) {
                                ProgressPhotoSourceActionLabel(
                                    title: "Tomar foto",
                                    subtitle: "Cámara",
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
                                    Text("Elegir de galería")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Fotos")
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
                            .accessibilityLabel("Foto seleccionada")
                    } else {
                        ProgressPhotoEmptyPreview()
                    }
                }

                Section("Contexto") {
                    DatePicker("Fecha", selection: $date, displayedComponents: [.date])
                    Text("Peso actual: \(store.currentWeight, specifier: "%.1f") kg")
                    TextField("Nota", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Foto de progreso")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
            .alert("Permiso necesario", isPresented: $showPermissionDenied) {
                Button("Abrir Ajustes") {
                    PermissionService.shared.openSettings()
                }
                Button("Cancelar", role: .cancel) {}
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
        store.addProgressPhoto(ProgressPhoto(date: date, imageData: imageData, weightKg: store.currentWeight, note: note.isEmpty ? nil : note))
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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
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
            Text("Sin foto seleccionada")
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
    @EnvironmentObject private var store: AppStore
    @State private var gymName = ""
    @State private var membershipID = ""
    @State private var codeValue = ""
    @State private var codeType: GymPass.CodeType = .qr
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tarjeta") {
                    TextField("Gimnasio", text: $gymName)
                    TextField("ID socio", text: $membershipID)
                    Picker("Tipo", selection: $codeType) {
                        Text("QR").tag(GymPass.CodeType.qr)
                        Text("Barcode").tag(GymPass.CodeType.barcode)
                    }
                    .pickerStyle(.segmented)
                    TextField("Valor QR/barcode", text: $codeValue)
                        .textInputAutocapitalization(.never)
                    TextField("Notas", text: $notes, axis: .vertical)
                }

                if !codeValue.isEmpty {
                    Section("Preview") {
                        CodePreview(value: codeValue, type: codeType)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                    }
                }
            }
            .navigationTitle("Tarjeta gimnasio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
    @EnvironmentObject private var store: AppStore
    @State private var gymName = ""
    @State private var date = Date()
    @State private var locationNote = ""
    @State private var workoutTitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Visita") {
                    TextField("Gimnasio/local", text: $gymName)
                    DatePicker("Fecha", selection: $date)
                    TextField("Ubicación o sala", text: $locationNote)
                    TextField("Entreno realizado", text: $workoutTitle)
                }

                if !store.gymPasses.isEmpty {
                    Section("Rápido") {
                        ForEach(store.gymPasses) { pass in
                            Button(pass.gymName) {
                                gymName = pass.gymName
                            }
                        }
                    }
                }
            }
            .navigationTitle("Registrar visita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
    @EnvironmentObject private var store: AppStore

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
                Section("Actividad") {
                    Picker("Tipo", selection: $activityType) {
                        ForEach(CardioLog.ActivityType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    DatePicker("Fecha", selection: $date)
                    TextField("Duración (min)", text: $duration)
                        .keyboardType(.numberPad)
                    TextField("Distancia (\(store.userProfile.distanceUnit.rawValue))", text: $distance)
                        .keyboardType(.decimalPad)
                }

                Section("Intensidad") {
                    TextField("FC media", text: $averageHeartRate)
                        .keyboardType(.decimalPad)
                    TextField("FC máxima", text: $maxHeartRate)
                        .keyboardType(.decimalPad)
                    TextField("Calorías", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("RPE 1-10", text: $rpe)
                        .keyboardType(.decimalPad)
                }

                Section("Notas") {
                    TextField("Sensaciones, ritmo, molestias...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Registrar cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
    @EnvironmentObject private var store: AppStore
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
                Section("Básico") {
                    DatePicker("Fecha", selection: $date)
                    TextField("Peso (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("Altura (cm)", text: $height)
                        .keyboardType(.decimalPad)
                    TextField("% grasa", text: $bodyFat)
                        .keyboardType(.decimalPad)
                }

                if let healthDefaultsMessage {
                    Section("Apple Health") {
                        Text(healthDefaultsMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Medidas") {
                    TextField("Cintura (cm)", text: $waist)
                        .keyboardType(.decimalPad)
                    TextField("Pecho (cm)", text: $chest)
                        .keyboardType(.decimalPad)
                    TextField("Brazo (cm)", text: $arm)
                        .keyboardType(.decimalPad)
                    TextField("Muslo (cm)", text: $thigh)
                        .keyboardType(.decimalPad)
                    TextField("Cadera (cm)", text: $hip)
                        .keyboardType(.decimalPad)
                }

                Section("Bienestar") {
                    TextField("Sueño (horas)", text: $sleep)
                        .keyboardType(.decimalPad)
                    TextField("Agua (L)", text: $water)
                        .keyboardType(.decimalPad)
                    TextField("Energía ingerida (kcal)", text: $dietaryEnergy)
                        .keyboardType(.decimalPad)
                    Stepper("Calidad sueño: \(sleepQuality)/5", value: $sleepQuality, in: 1...5)
                    Stepper("Fatiga: \(fatigue)/5", value: $fatigue, in: 1...5)
                    Stepper("Estrés: \(stress)/5", value: $stress, in: 1...5)
                    TextField("Molestias o lesiones", text: $soreness, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Cuerpo y bienestar")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadHealthDefaults()
            }
            .onChange(of: date) { _, _ in
                Task { await loadHealthDefaults() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
    @EnvironmentObject private var store: AppStore
    private let equipmentOptions = ["Barbell", "Dumbbells", "Kettlebell", "Resistance Band", "Cable", "Machine", "Bench", "Rack", "Pullup Bar", "Cardio Machine"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Logging avanzado") {
                    Toggle("Marcar todos", isOn: Binding(
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

                    Toggle("Mostrar RPE", isOn: $store.userProfile.showRPE)
                    Toggle("Mostrar RIR", isOn: $store.userProfile.showRIR)
                    Toggle("Mostrar tipo de serie", isOn: $store.userProfile.showSetType)
                    Toggle("Mostrar tempo", isOn: $store.userProfile.showTempo)
                    Toggle("Auto-progresión", isOn: $store.userProfile.autoProgressionEnabled)
                    Stepper("Incremento: \(store.userProfile.weightIncrementKg, specifier: "%.1f") kg", value: $store.userProfile.weightIncrementKg, in: 0.5...10, step: 0.5)
                }

                Section("Equipamiento disponible") {
                    Toggle("Marcar todos", isOn: Binding(
                        get: {
                            equipmentOptions.allSatisfy { store.userProfile.availableEquipment.contains($0) }
                        },
                        set: { selectAll in
                            if selectAll {
                                for option in equipmentOptions {
                                    if !store.userProfile.availableEquipment.contains(option) {
                                        store.userProfile.availableEquipment.append(option)
                                    }
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
            .navigationTitle("Preferencias Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
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
        case .treadmill: "Cinta"
        case .elliptical: "Elíptica"
        case .stationaryBike: "Bici estática"
        case .outdoorRun: "Carrera exterior"
        case .walking: "Caminar"
        case .rowing: "Remo"
        case .hiit: "HIIT"
        case .other: "Otro"
        }
    }
}

private extension Goal.Kind {
    var displayName: LocalizedStringKey {
        switch self {
        case .strength: "Fuerza"
        case .consistency: "Constancia"
        case .bodyWeight: "Peso corporal"
        case .custom: "Personalizado"
        }
    }
}

private extension UserProfile.MainGoal {
    var displayNameText: String {
        switch self {
        case .buildMuscle: "Ganar músculo"
        case .loseFat: "Perder grasa"
        case .getStronger: "Más fuerza"
        case .stayActive: "Mantener actividad"
        }
    }
}

private extension UserProfile.Experience {
    var displayNameText: String {
        switch self {
        case .beginner: "Principiante"
        case .intermediate: "Intermedio"
        case .advanced: "Avanzado"
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
                            Text("Compartir recibo")
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
                    Button("Cerrar") {
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
