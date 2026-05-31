import Charts
import MuscleMap
import SwiftUI

struct ExerciseProgressView: View {
    @EnvironmentObject private var store: AppStore
    let exercise: Exercise

    @State private var metric = ProgressMetric.weight
    @State private var selectedTab: ExerciseDetailTab = .instructions
    @State private var selectedHistoryRange: ExerciseHistoryRange = .sixMonths

    private enum ProgressMetric: String, CaseIterable, Identifiable {
        case weight = "Peso"
        case reps = "Reps"
        case volume = "Volumen"
        case oneRepMax = "1RM"
        case sets = "Series"

        var id: String { rawValue }
    }

    private enum ExerciseDetailTab: String, CaseIterable, Identifiable {
        case instructions = "Instrucciones"
        case info = "Info"
        case history = "Historial"

        var id: String { rawValue }
    }

    private enum ExerciseHistoryRange: String, CaseIterable, Identifiable {
        case week = "1S"
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "12M"
        case max = "MAX"

        var id: String { rawValue }

        var startDate: Date {
            let calendar = Calendar.current
            switch self {
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: .now) ?? .distantPast
            case .threeMonths:
                return calendar.date(byAdding: .month, value: -3, to: .now) ?? .distantPast
            case .sixMonths:
                return calendar.date(byAdding: .month, value: -6, to: .now) ?? .distantPast
            case .year:
                return calendar.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
            case .max:
                return .distantPast
            }
        }
    }

    private var points: [FitnessMetrics.ExerciseProgressPoint] {
        FitnessMetrics.progressPoints(for: exercise, in: store.workoutSessions)
    }

    private var rangedPoints: [FitnessMetrics.ExerciseProgressPoint] {
        points.filter { $0.date >= selectedHistoryRange.startDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(exercise.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)

                Picker("Sección", selection: $selectedTab) {
                    ForEach(ExerciseDetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch selectedTab {
                    case .instructions:
                        instructionsContent
                    case .info:
                        infoContent
                    case .history:
                        historyContent
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 82)
        }
        .screenBackground()
        .navigationTitle("Ejercicio")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }

    private var instructionsContent: some View {
        VStack(spacing: 18) {
            ExerciseProgressHeroMedia(exercise: exercise)
            exerciseTechniqueCard
        }
    }

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ExerciseMuscleInfoPanel(exercise: exercise, gender: store.userProfile.muscleMapGender)

            SectionHeader(title: "Músculos trabajados")

            PulseCard {
                VStack(spacing: 0) {
                    ExerciseMuscleTargetRow(title: localizedMuscle(exercise.muscleGroup), subtitle: "1 serie", exercise: exercise, gender: store.userProfile.muscleMapGender)
                    if !exercise.secondaryMuscles.isEmpty {
                        Divider()
                        ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                            ExerciseMuscleTargetRow(title: localizedMuscle(muscle), subtitle: "0,35 series indirectas", exercise: exercise, gender: store.userProfile.muscleMapGender)
                            if muscle != exercise.secondaryMuscles.last {
                                Divider()
                            }
                        }
                    }
                }
            }

            SectionHeader(title: "Ajustes del ejercicio")

            PulseCard {
                HStack {
                    Text("Incremento")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(store.userProfile.weightIncrementKg, specifier: "%.1f") kg")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Prioridad del ejercicio")
                            .font(.headline)
                        Spacer()
                        Label("Preferente", systemImage: "circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.primaryBright)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(PulseTheme.grouped, in: Capsule())
                    }
                    Text("El plan priorizará ejercicios con el mismo patrón, equipo disponible y buen encaje muscular.")
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ResistanceCurveCard(profile: ResistanceCurveProfile(exercise: exercise))
            FatigueRatingCard(score: fatigueScore, description: fatigueDescription)
        }
    }

    private var historyContent: some View {
        VStack(spacing: 18) {
            Picker("Rango", selection: $selectedHistoryRange) {
                ForEach(ExerciseHistoryRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if rangedPoints.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "Ejercicio todavía no realizado",
                        message: "Cuando completes series de este ejercicio aparecerán aquí sus tendencias de peso, volumen, repeticiones y 1RM.",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
            } else {
                HStack(spacing: 14) {
                    MetricCard(title: "Mejor peso", value: String(format: "%.0f", rangedPoints.map(\.maxWeightKg).max() ?? 0), subtitle: "kg", systemImage: "scalemass", badgeColor: PulseTheme.primary)
                    MetricCard(title: "1RM estimada", value: String(format: "%.0f", rangedPoints.map(\.estimatedOneRepMaxKg).max() ?? 0), subtitle: "kg", systemImage: "bolt", badgeColor: PulseTheme.accent)
                }

                HStack(spacing: 14) {
                    MetricCard(title: "Sobrecarga", value: String(format: "%.1f", FitnessMetrics.progressiveOverloadDelta(for: rangedPoints)), subtitle: "cambio 1RM", systemImage: "arrow.up.right", badgeColor: PulseTheme.warning)
                    MetricCard(title: "Volumen medio", value: "\(Int(FitnessMetrics.averageVolumeKg(for: rangedPoints)))", subtitle: "kg/sesión", systemImage: "chart.bar", badgeColor: PulseTheme.primaryBright)
                }

                Picker("Métrica", selection: $metric) {
                    ForEach(ProgressMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                PulseCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Actividad").font(.headline)
                        Chart(rangedPoints) { point in
                            LineMark(
                                x: .value("Fecha", point.date),
                                y: .value(metric.rawValue, value(for: point))
                            )
                            .foregroundStyle(PulseTheme.primary)
                            PointMark(
                                x: .value("Fecha", point.date),
                                y: .value(metric.rawValue, value(for: point))
                            )
                            .foregroundStyle(PulseTheme.accent)
                        }
                        .frame(height: 220)
                    }
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sesiones recientes").font(.headline)
                        ForEach(rangedPoints.reversed()) { point in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(point.workoutTitle).font(.headline)
                                    Text(point.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(value(for: point))) \(metric.rawValue)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            if point.id != rangedPoints.reversed().last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var fatigueScore: Int {
        let text = "\(exercise.name) \(exercise.muscleGroup) \(exercise.equipment)".lowercased()
        var score = 1
        if text.contains("barbell") || text.contains("barra") { score += 1 }
        if text.contains("squat") || text.contains("deadlift") || text.contains("press") || text.contains("row") { score += 1 }
        if text.contains("legs") || text.contains("back") || text.contains("full") { score += 1 }
        return min(score, 4)
    }

    private var fatigueDescription: String {
        switch fatigueScore {
        case 1:
            return "Baja fatiga: movimiento local o estable, fácil de recuperar."
        case 2:
            return "Fatiga moderada: requiere control técnico pero suele ser recuperable."
        case 3:
            return "Alta fatiga: varias articulaciones o cargas altas, conviene gestionar volumen."
        default:
            return "Fatiga muy alta: compuesto inestable con varios grupos musculares y alta demanda de estabilización."
        }
    }

    private func localizedMuscle(_ value: String) -> String {
        guard store.userProfile.preferredLanguage.hasPrefix("es") else { return value }
        return switch value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased() {
        case "arms": "Brazos"
        case "back": "Espalda"
        case "cardio": "Cardio"
        case "chest": "Pecho"
        case "core", "abdominals": "Core"
        case "full body": "Cuerpo completo"
        case "glutes": "Glúteos"
        case "legs": "Piernas"
        case "neck": "Cuello"
        case "shoulders": "Hombros"
        default: value
        }
    }

    private var exerciseTechniqueCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Técnica del ejercicio", systemImage: "list.clipboard")
                        .font(.headline)
                    Spacer()
                    if let videoURL = exercise.videoURL, let url = URL(string: videoURL) {
                        Link(destination: url) {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundStyle(PulseTheme.primary)
                        }
                        .accessibilityLabel("Abrir vídeo del ejercicio")
                    }
                }

                if instructionsText.isEmpty {
                    Text("Este ejercicio todavía no tiene instrucciones detalladas. Si viene de la fuente abierta, se completará al sincronizar la biblioteca.")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                } else {
                    Text(instructionsText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !exercise.commonMistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Evita")
                            .font(.subheadline.weight(.semibold))
                        ForEach(exercise.commonMistakes, id: \.self) { mistake in
                            Label(mistake, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }

                HStack(spacing: 10) {
                    ForEach(exercise.requiredEquipment.prefix(3), id: \.self) { equipment in
                        ExerciseInfoChip(text: equipment, systemImage: "wrench.and.screwdriver")
                    }
                }

                if let sourceURL = exercise.sourceURL, let url = URL(string: sourceURL) {
                    Link(destination: url) {
                        Label(sourceFooter, systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.primary)
                    }
                    .accessibilityLabel("Abrir fuente del ejercicio")
                } else if let sourceName = exercise.sourceName {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private var sourceFooter: String {
        let name = exercise.sourceName ?? "Fuente"
        if let license = exercise.sourceLicense {
            return "\(name) · \(license)"
        }
        return name
    }

    private var instructionsText: String {
        exercise.instructions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func value(for point: FitnessMetrics.ExerciseProgressPoint) -> Double {
        switch metric {
        case .weight:
            return point.maxWeightKg
        case .reps:
            return Double(point.maxReps)
        case .volume:
            return point.totalVolumeKg
        case .oneRepMax:
            return point.estimatedOneRepMaxKg
        case .sets:
            return Double(point.completedSets)
        }
    }
}

struct ExerciseMuscleInfoPanel: View {
    let exercise: Exercise
    let gender: BodyGender

    private var descriptor: ExerciseAnatomyDescriptor {
        ExerciseAnatomyDescriptor(exercise: exercise)
    }

    var body: some View {
        HStack(spacing: 28) {
            BodyView(gender: gender, side: .front, style: .repsDark)
                .heatmap(frontHeatmap, configuration: .repsVolume)
                .frame(maxWidth: .infinity)
            BodyView(gender: gender, side: .back, style: .repsDark)
                .heatmap(backHeatmap, configuration: .repsVolume)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 280)
        .padding(.horizontal, 20)
        .accessibilityLabel("Músculos principales trabajados por \(exercise.name)")
    }

    private var frontHeatmap: [MuscleIntensity] {
        descriptor.muscles.map { MuscleIntensity(muscle: $0, intensity: 0.72) }
    }

    private var backHeatmap: [MuscleIntensity] {
        descriptor.muscles.map { MuscleIntensity(muscle: $0, intensity: 0.72) }
    }
}

struct ExerciseMuscleTargetRow: View {
    let title: String
    let subtitle: String
    let exercise: Exercise
    let gender: BodyGender

    var body: some View {
        HStack(spacing: 14) {
            ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct ResistanceCurveCard: View {
    let profile: ResistanceCurveProfile

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Curva de resistencia")
                    .font(.headline)
                Text("Los ejercicios con alta tensión en estiramiento suelen ser más eficientes para hipertrofia.")
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Chart(profile.points) { point in
                    RuleMark(x: .value("Fase", point.phase.rawValue))
                        .foregroundStyle(PulseTheme.separator)
                    PointMark(
                        x: .value("Fase", point.phase.rawValue),
                        y: .value("Tensión", point.intensity)
                    )
                    .symbolSize(point.intensity > 0 ? 220 : 90)
                    .foregroundStyle(point.intensity > 0 ? PulseTheme.primaryBright : PulseTheme.tertiaryText)
                    if point.intensity > 0 {
                        BarMark(
                            x: .value("Fase", point.phase.rawValue),
                            y: .value("Tensión", point.intensity)
                        )
                        .foregroundStyle(PulseTheme.primaryBright.opacity(0.55))
                        .clipShape(Capsule())
                    }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0.5, 1.0]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(Int(doubleValue * 100))%")
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
    }
}

struct ResistanceCurveProfile {
    enum Phase: String, CaseIterable {
        case stretch = "ESTIRAMIENTO"
        case middle = "MEDIO"
        case contraction = "CONTRACCIÓN"
    }

    struct Point: Identifiable {
        let phase: Phase
        let intensity: Double

        var id: Phase { phase }
    }

    let points: [Point]

    init(exercise: Exercise) {
        let text = "\(exercise.name) \(exercise.equipment)".lowercased()
        let stretch: Double
        let middle: Double
        let contraction: Double

        if text.contains("squat") || text.contains("deadlift") || text.contains("press") {
            stretch = 1.0
            middle = 0.88
            contraction = 0.18
        } else if text.contains("cable") {
            stretch = 0.55
            middle = 0.9
            contraction = 0.75
        } else if text.contains("curl") || text.contains("raise") {
            stretch = 0.48
            middle = 1.0
            contraction = 0.45
        } else {
            stretch = 0.65
            middle = 0.75
            contraction = 0.35
        }

        points = [
            Point(phase: .stretch, intensity: stretch),
            Point(phase: .middle, intensity: middle),
            Point(phase: .contraction, intensity: contraction)
        ]
    }
}

struct FatigueRatingCard: View {
    let score: Int
    let description: String

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Fatiga")
                        .font(.headline)
                    Spacer()
                    Text("\(score)/4")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(score >= 4 ? PulseTheme.destructive : score >= 3 ? PulseTheme.warning : PulseTheme.primaryBright)
                }
                Text(description)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    ForEach(1...4, id: \.self) { index in
                        Circle()
                            .fill(index <= score ? fatigueColor(for: index) : PulseTheme.grouped)
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
    }

    private func fatigueColor(for index: Int) -> Color {
        switch index {
        case 1, 2:
            return PulseTheme.primaryBright
        case 3:
            return PulseTheme.warning
        default:
            return PulseTheme.destructive
        }
    }
}

private struct ExerciseProgressHeroMedia: View {
    let exercise: Exercise

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let mediaURL = exercise.mediaURL, let url = URL(string: mediaURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        ProgressView()
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }

            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.48)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(typeLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.36), in: Capsule())
                .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .clipped()
    }

    private var fallback: some View {
        ZStack {
            PulseTheme.primary.opacity(0.10)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(PulseTheme.primary)
            }
    }

    private var typeLabel: String {
        switch exercise.exerciseType {
        case .strength: "Fuerza"
        case .cardio: "Cardio"
        case .mobility: "Movilidad"
        case .stretching: "Estiramiento"
        case .hiit: "HIIT"
        }
    }
}

private struct ExerciseInfoChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(PulseTheme.grouped, in: Capsule())
            .foregroundStyle(PulseTheme.secondaryText)
    }
}
