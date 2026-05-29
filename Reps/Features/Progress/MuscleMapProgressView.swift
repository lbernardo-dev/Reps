import Charts
import MuscleMap
import SwiftUI

struct MuscleMapProgressView: View {
    let sessions: [WorkoutSession]
    let plannedWorkout: WorkoutDay
    let startDate: Date
    let gender: BodyGender

    @State private var selectedFilter: MuscleRegionFilter = .all
    @State private var selectedMode: MuscleMapMode = .actual
    @State private var selectedSegment: MuscleSegment?
    @State private var detailSegment: MuscleSegment?

    private var loads: [MuscleLoad] {
        MuscleLoadCalculator.loads(
            sessions: sessions,
            plannedWorkout: plannedWorkout,
            startDate: startDate,
            includePrediction: selectedMode == .predict
        )
    }

    private var filteredLoads: [MuscleLoad] {
        loads
            .filter { selectedFilter.includes($0.segment) }
            .sorted { lhs, rhs in
                if lhs.displaySets == rhs.displaySets {
                    return lhs.segment.title < rhs.segment.title
                }
                return lhs.displaySets > rhs.displaySets
            }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(selectedMode.subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            InteractiveBodyHeatmap(
                loads: loads,
                gender: gender,
                selectedSegment: $selectedSegment
            )
            .frame(height: 390)
            .padding(.top, 2)

            modeControl

            filterStrip

            selectedSegmentControl

            if let selectedSegment,
               let selectedLoad = loads.first(where: { $0.segment == selectedSegment }) {
                Button {
                    detailSegment = selectedSegment
                } label: {
                    MuscleLoadCard(load: selectedLoad, gender: gender, isSelected: true, showsAnalysisHint: true)
                }
                .buttonStyle(.plain)
            }

            LazyVStack(spacing: 14) {
                ForEach(filteredLoads) { load in
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            if selectedSegment == load.segment {
                                detailSegment = load.segment
                            } else {
                                selectedSegment = load.segment
                            }
                        }
                    } label: {
                        MuscleLoadCard(load: load, gender: gender, isSelected: selectedSegment == load.segment)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $detailSegment) { segment in
            MuscleSegmentDetailSheet(
                segment: segment,
                load: loads.first(where: { $0.segment == segment }) ?? MuscleLoad(segment: segment, actualSets: 0, predictedSets: 0, totalVolumeKg: 0),
                sessions: sessions,
                startDate: startDate,
                gender: gender
            )
        }
    }

    private var modeControl: some View {
        HStack(spacing: 8) {
            ForEach(MuscleMapMode.allCases) { mode in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .foregroundStyle(selectedMode == mode ? .black : PulseTheme.secondaryText)
                        .background(selectedMode == mode ? .white : PulseTheme.grouped.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var selectedSegmentControl: some View {
        if let selectedSegment {
            HStack(spacing: 8) {
                Circle()
                    .fill(PulseTheme.primary)
                    .frame(width: 7, height: 7)
                Text(selectedSegment.title)
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        self.selectedSegment = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(PulseTheme.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(PulseTheme.grouped.opacity(0.7))
            .clipShape(Capsule())
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MuscleRegionFilter.allCases) { filter in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        QuietFilterChip(title: filter.title, isSelected: selectedFilter == filter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct QuietFilterChip: View {
    let title: LocalizedStringKey
    var isSelected = false

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .foregroundStyle(isSelected ? .black : PulseTheme.secondaryText)
            .background(isSelected ? .white : PulseTheme.grouped.opacity(0.7))
            .clipShape(Capsule())
    }
}

private struct InteractiveBodyHeatmap: View {
    let loads: [MuscleLoad]
    let gender: BodyGender
    @Binding var selectedSegment: MuscleSegment?

    var body: some View {
        GeometryReader { proxy in
            let spacing = proxy.size.width * 0.05
            let bodyWidth = (proxy.size.width - spacing) / 2
            let visualScale = min(1.22, max(1.08, proxy.size.width / 340))

            HStack(spacing: spacing) {
                bodyView(side: .front)
                    .frame(width: bodyWidth, height: proxy.size.height)
                    .scaleEffect(visualScale, anchor: .center)
                bodyView(side: .back)
                    .frame(width: bodyWidth, height: proxy.size.height)
                    .scaleEffect(visualScale, anchor: .center)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Mapa muscular interactivo")
    }

    private func bodyView(side: BodySide) -> some View {
        BodyView(gender: gender, side: side, style: .repsDark)
            .heatmap(heatmapData, configuration: .repsVolume)
            .selected(selectedMuscles)
            .pulseSelected(speed: 1.35)
            .onMuscleSelected { muscle, _ in
                withAnimation(.snappy(duration: 0.22)) {
                    selectedSegment = MuscleSegment.segment(containing: muscle)
                }
            }
    }

    private var heatmapData: [MuscleIntensity] {
        var intensities: [Muscle: Double] = [:]
        for load in loads {
            for muscle in load.segment.muscles {
                intensities[muscle] = max(intensities[muscle] ?? 0, load.intensity)
            }
        }
        return intensities.map { muscle, intensity in
            MuscleIntensity(muscle: muscle, intensity: intensity)
        }
    }

    private var selectedMuscles: Set<Muscle> {
        guard let selectedSegment else { return [] }
        return Set(selectedSegment.muscles)
    }
}

private struct MuscleLoadCard: View {
    let load: MuscleLoad
    let gender: BodyGender
    var isSelected = false
    var showsAnalysisHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                MuscleAnatomyThumbnail(segment: load.segment, intensity: load.intensity, gender: gender)
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text(load.segment.title)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text("\(load.displaySets) de 12 series semanales")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                    if load.predictedSets > 0 {
                        Text("+\(load.predictedSets) previstas en el próximo entreno")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primaryBright)
                    }
                }

                Spacer()

                Text(load.compactZoneTitle)
                    .font(.caption.weight(.bold))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(load.zoneColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(load.zoneColor.opacity(0.14), in: Capsule())
            }

            RepsProgressiveSegmentBar(value: load.totalSets)

            HStack {
                Text(load.rangeText)
                Spacer()
                Text("\(Int(load.totalVolumeKg)) kg")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(PulseTheme.tertiaryText)

            if showsAnalysisHint {
                Label("Ver frecuencia, ejercicios directos e indirectos", systemImage: "chart.xyaxis.line")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.primary)
            }
        }
        .padding(14)
        .background(isSelected ? PulseTheme.elevated : PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(isSelected ? PulseTheme.primary : PulseTheme.separator, lineWidth: isSelected ? 1.4 : 1)
        )
    }
}

private struct MuscleSegmentDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let segment: MuscleSegment
    let load: MuscleLoad
    let sessions: [WorkoutSession]
    let startDate: Date
    let gender: BodyGender

    private var activity: MuscleActivitySummary {
        MuscleActivitySummary(segment: segment, sessions: sessions, startDate: startDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 12) {
                        BodyView(gender: gender, side: segment.preferredSide, style: .repsDark)
                            .heatmap(segment.muscles.map { MuscleIntensity(muscle: $0, intensity: max(load.intensity, 0.55)) }, configuration: .repsVolume)
                            .selected(Set(segment.muscles))
                            .frame(height: 260)
                            .allowsHitTesting(false)

                        MuscleWeeklyVolumeCard(load: load, segment: segment, gender: gender)
                    }

                    SectionHeader(title: "Análisis muscular")

                    PulseCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Frecuencia y volumen")
                                .font(.title3.weight(.bold))
                            Text("Has entrenado \(segment.title.lowercased()) \(activity.trainingDays) \(activity.trainingDays == 1 ? "vez" : "veces") (\(activity.directDays) directas) en los últimos 7 días. Se recomienda una frecuencia de al menos 2.")
                                .font(.body)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Chart(activity.dailyPoints) { point in
                                BarMark(
                                    x: .value("Día", point.label),
                                    y: .value("Series", point.sets)
                                )
                                .foregroundStyle(point.sets > 0 ? PulseTheme.primary : PulseTheme.separator)

                                if point.sets > 0 {
                                    PointMark(
                                        x: .value("Día", point.label),
                                        y: .value("Series", point.sets)
                                    )
                                    .annotation(position: .top) {
                                        Text("\(Int(point.sets.rounded()))")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.black)
                                            .padding(6)
                                            .background(PulseTheme.primary, in: Circle())
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                            }
                            .frame(height: 180)
                        }
                    }

                    if !activity.indirectExercises.isEmpty {
                        SectionHeader(title: "Ejercicios indirectos")
                        VStack(spacing: 10) {
                            ForEach(activity.indirectExercises) { item in
                                MuscleExerciseContributionRow(item: item, gender: gender, isIndirect: true)
                            }
                        }
                    }

                    if !activity.directExercises.isEmpty {
                        SectionHeader(title: "Ejercicios directos")
                        VStack(spacing: 10) {
                            ForEach(activity.directExercises) { item in
                                MuscleExerciseContributionRow(item: item, gender: gender, isIndirect: false)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 96)
            }
            .screenBackground()
            .navigationTitle(segment.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Cerrar")
                        .font(.headline)
                        .frame(width: 142, height: 58)
                        .foregroundStyle(.black)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct MuscleWeeklyVolumeCard: View {
    let load: MuscleLoad
    let segment: MuscleSegment
    let gender: BodyGender

    var body: some View {
        PulseCard {
            HStack(alignment: .center, spacing: 16) {
                MuscleAnatomyThumbnail(segment: segment, intensity: load.intensity, gender: gender)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(load.displaySets) de 12 series semanales")
                            .font(.title3.weight(.bold).monospacedDigit())
                        Spacer()
                        Text(load.setsToGrowthZoneText)
                            .font(.headline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    RepsProgressiveSegmentBar(value: load.totalSets)
                }
            }
        }
    }
}

private struct MuscleExerciseContributionRow: View {
    let item: MuscleExerciseContribution
    let gender: BodyGender
    let isIndirect: Bool

    var body: some View {
        HStack(spacing: 14) {
            ExerciseMediaThumbnail(exercise: item.exercise, gender: gender)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("\(item.completedSets) series de \(item.repText)\(isIndirect ? " (cuentan como \(item.effectiveSetsText))" : "") · \(item.relativeDate)")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()
            Image(systemName: "chevron.down")
                .font(.headline.weight(.bold))
                .foregroundStyle(PulseTheme.tertiaryText)
        }
        .padding(16)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }
}

private struct MuscleActivitySummary {
    let segment: MuscleSegment
    let sessions: [WorkoutSession]
    let startDate: Date

    var dailyPoints: [MuscleDailyPoint] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let end = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let sets = setsBetween(date, and: end)
            return MuscleDailyPoint(date: date, label: label(for: offset), sets: sets)
        }
    }

    var trainingDays: Int {
        dailyPoints.filter { $0.sets > 0 }.count
    }

    var directDays: Int {
        let calendar = Calendar.current
        return Set(directExercises.map { calendar.startOfDay(for: $0.date) }).count
    }

    var directExercises: [MuscleExerciseContribution] {
        contributions.filter { $0.isDirect }
    }

    var indirectExercises: [MuscleExerciseContribution] {
        contributions.filter { !$0.isDirect }
    }

    private var contributions: [MuscleExerciseContribution] {
        sessions
            .filter { $0.date >= startDate }
            .flatMap { session in
                (session.exerciseLogs ?? []).compactMap { log -> MuscleExerciseContribution? in
                    let completed = log.sets.filter(\.completed)
                    guard !completed.isEmpty else { return nil }
                    let direct = MuscleLoadCalculator.segments(for: log.exercise).contains(segment)
                    let indirect = !direct && log.exercise.secondaryMuscles.contains { secondary in
                        MuscleLoadCalculator.segments(forMuscleName: secondary).contains(segment)
                    }
                    guard direct || indirect else { return nil }
                    let multiplier = direct ? 1.0 : 0.35
                    return MuscleExerciseContribution(
                        exercise: log.exercise,
                        date: session.date,
                        completedSets: completed.count,
                        effectiveSets: Double(completed.count) * multiplier,
                        repText: repText(from: completed),
                        isDirect: direct
                    )
                }
            }
            .sorted { $0.date > $1.date }
    }

    private func setsBetween(_ start: Date, and end: Date) -> Double {
        contributions
            .filter { $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.effectiveSets }
    }

    private func label(for offset: Int) -> String {
        switch offset {
        case 0: "6 días"
        case 1: "5 días"
        case 2: "4 días"
        case 3: "3 días"
        case 4: "2 días"
        case 5: "Ayer"
        default: "Hoy"
        }
    }

    private func repText(from sets: [SetLog]) -> String {
        let reps = sets.map(\.reps)
        guard let first = reps.first else { return "0 reps" }
        if reps.allSatisfy({ $0 == first }) {
            return "\(first) reps"
        }
        guard let min = reps.min(), let max = reps.max() else {
            return "\(first) reps"
        }
        return "\(min)-\(max) reps"
    }
}

private struct MuscleDailyPoint: Identifiable {
    let date: Date
    let label: String
    let sets: Double

    var id: Date { date }
}

private struct MuscleExerciseContribution: Identifiable {
    let id = UUID()
    let exercise: Exercise
    let date: Date
    let completedSets: Int
    let effectiveSets: Double
    let repText: String
    let isDirect: Bool

    var effectiveSetsText: String {
        if effectiveSets.rounded() == effectiveSets {
            return "\(Int(effectiveSets)) series"
        }
        return String(format: "%.1f series", effectiveSets)
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct MuscleAnatomyThumbnail: View {
    let segment: MuscleSegment
    let intensity: Double
    let gender: BodyGender

    var body: some View {
        BodyView(gender: gender, side: segment.preferredSide, style: .repsThumbnail)
            .heatmap(thumbnailData, configuration: .repsVolume)
            .frame(width: 70, height: 70)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var thumbnailData: [MuscleIntensity] {
        segment.muscles.map {
            MuscleIntensity(muscle: $0, intensity: max(intensity, 0.45))
        }
    }
}

private struct RepsProgressiveSegmentBar: View {
    let value: Double
    private let segmentCount = 12

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fillColor(for: index))
                    .frame(height: 28)
            }
        }
        .accessibilityLabel("\(Int(value.rounded())) de 12 series semanales")
    }

    private func fillColor(for index: Int) -> Color {
        let zoneColor: Color
        switch index {
        case 0..<4:
            zoneColor = PulseTheme.primary
        case 4..<10:
            zoneColor = PulseTheme.primaryBright
        default:
            zoneColor = PulseTheme.accent
        }

        return Double(index) < value ? zoneColor : zoneColor.opacity(0.16)
    }
}

private struct MuscleLoad: Identifiable {
    let segment: MuscleSegment
    let actualSets: Double
    let predictedSets: Int
    let totalVolumeKg: Double

    var id: MuscleSegment { segment }
    var totalSets: Double { actualSets + Double(predictedSets) }
    var displaySets: Int { Int(totalSets.rounded()) }
    var intensity: Double { min(totalSets / 12, 1) }

    var zoneTitle: String {
        switch totalSets {
        case 0..<4:
            "Mantenimiento"
        case 4..<10:
            "Zona de crecimiento"
        default:
            "Foco"
        }
    }

    var compactZoneTitle: String {
        switch totalSets {
        case 0..<4:
            "Mant."
        case 4..<10:
            "Crecimiento"
        default:
            "Foco"
        }
    }

    var zoneColor: Color {
        switch totalSets {
        case 0..<4:
            PulseTheme.primary
        case 4..<10:
            PulseTheme.primaryBright
        default:
            PulseTheme.accent
        }
    }

    var rangeText: String {
        switch totalSets {
        case 0..<4:
            "Por debajo de la zona de crecimiento"
        case 4..<10:
            "Volumen productivo esta semana"
        case 10...12:
            "Parte alta del objetivo semanal"
        default:
            "Volumen alto: vigila recuperación"
        }
    }

    var setsToGrowthZoneText: String {
        let missing = max(0, 4 - displaySets)
        if missing == 0 {
            return "en zona de crecimiento"
        }
        return missing == 1 ? "1 serie hasta zona" : "\(missing) series hasta zona"
    }
}

private enum MuscleMapMode: String, CaseIterable, Identifiable {
    case actual
    case predict

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .actual: "Últimos 7 días"
        case .predict: "Predecir"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .actual: "Número de series por músculo en los últimos 7 días"
        case .predict: "Tu progreso después del próximo entrenamiento"
        }
    }
}

private enum MuscleRegionFilter: String, CaseIterable, Identifiable {
    case all
    case upper
    case arms
    case back
    case legs

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "Todos"
        case .upper: "Superior"
        case .arms: "Brazos"
        case .back: "Espalda"
        case .legs: "Piernas"
        }
    }

    func includes(_ segment: MuscleSegment) -> Bool {
        switch self {
        case .all:
            true
        case .upper:
            [.chest, .deltoids, .traps, .upperBack, .abs, .obliques].contains(segment)
        case .arms:
            [.biceps, .triceps, .forearms].contains(segment)
        case .back:
            [.traps, .upperBack, .lowerBack].contains(segment)
        case .legs:
            [.quads, .hamstrings, .glutes, .calves, .adductors].contains(segment)
        }
    }
}

private enum MuscleSegment: String, CaseIterable, Identifiable {
    case chest
    case deltoids
    case traps
    case upperBack
    case lowerBack
    case biceps
    case triceps
    case forearms
    case abs
    case obliques
    case quads
    case hamstrings
    case glutes
    case calves
    case adductors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Pecho"
        case .deltoids: "Deltoides"
        case .traps: "Trapecios"
        case .upperBack: "Espalda alta"
        case .lowerBack: "Lumbar"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .forearms: "Antebrazos"
        case .abs: "Abdominales"
        case .obliques: "Oblicuos"
        case .quads: "Cuádriceps"
        case .hamstrings: "Isquios"
        case .glutes: "Glúteos"
        case .calves: "Gemelos"
        case .adductors: "Aductores"
        }
    }

    var muscles: [Muscle] {
        switch self {
        case .chest: [.chest, .upperChest, .lowerChest]
        case .deltoids: [.deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff]
        case .traps: [.trapezius, .upperTrapezius, .lowerTrapezius]
        case .upperBack: [.upperBack, .rhomboids]
        case .lowerBack: [.lowerBack]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearm]
        case .abs: [.abs, .upperAbs, .lowerAbs]
        case .obliques: [.obliques, .serratus]
        case .quads: [.quadriceps, .innerQuad, .outerQuad, .hipFlexors]
        case .hamstrings: [.hamstring]
        case .glutes: [.gluteal]
        case .calves: [.calves, .tibialis]
        case .adductors: [.adductors]
        }
    }

    var preferredSide: BodySide {
        switch self {
        case .traps, .upperBack, .lowerBack, .hamstrings, .glutes, .calves:
            .back
        default:
            .front
        }
    }

    static func segment(containing muscle: Muscle) -> MuscleSegment? {
        MuscleSegment.allCases.first { $0.muscles.contains(muscle) }
    }
}

private enum MuscleLoadCalculator {
    static func loads(
        sessions: [WorkoutSession],
        plannedWorkout: WorkoutDay,
        startDate: Date,
        includePrediction: Bool
    ) -> [MuscleLoad] {
        var actualSets: [MuscleSegment: Double] = [:]
        var predictedSets: [MuscleSegment: Int] = [:]
        var volume: [MuscleSegment: Double] = [:]

        sessions
            .filter { $0.date >= startDate }
            .flatMap { $0.exerciseLogs ?? [] }
            .forEach { log in
                let completedSets = log.sets.filter(\.completed)
                let setCount = Double(completedSets.count)
                let totalVolume = completedSets.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
                apply(exercise: log.exercise, sets: setCount, volume: totalVolume, into: &actualSets, volumeBuckets: &volume)
            }

        if includePrediction {
            for item in plannedWorkout.exercises {
                for segment in segments(for: item.exercise) {
                    predictedSets[segment, default: 0] += item.targetSets
                }
            }
        }

        return MuscleSegment.allCases.map { segment in
            MuscleLoad(
                segment: segment,
                actualSets: actualSets[segment, default: 0],
                predictedSets: predictedSets[segment, default: 0],
                totalVolumeKg: volume[segment, default: 0]
            )
        }
    }

    private static func apply(
        exercise: Exercise,
        sets: Double,
        volume: Double,
        into setBuckets: inout [MuscleSegment: Double],
        volumeBuckets: inout [MuscleSegment: Double]
    ) {
        let primarySegments = segments(for: exercise)
        for segment in primarySegments {
            setBuckets[segment, default: 0] += sets
            volumeBuckets[segment, default: 0] += volume
        }

        for secondary in exercise.secondaryMuscles {
            for segment in segments(forMuscleName: secondary) {
                setBuckets[segment, default: 0] += sets * 0.35
                volumeBuckets[segment, default: 0] += volume * 0.35
            }
        }
    }

    static func segments(for exercise: Exercise) -> [MuscleSegment] {
        let name = exercise.name.lowercased()
        let primary = exercise.muscleGroup.lowercased()

        if primary.contains("arm") {
            if name.contains("tricep") || name.contains("extension") || name.contains("pushdown") || name.contains("dip") {
                return [.triceps]
            }
            if name.contains("curl") || name.contains("bicep") {
                return [.biceps]
            }
            return [.biceps, .triceps]
        }

        if primary.contains("back") {
            if name.contains("deadlift") || name.contains("hinge") {
                return [.lowerBack, .hamstrings, .glutes]
            }
            if name.contains("shrug") {
                return [.traps]
            }
            return [.upperBack, .traps]
        }

        if primary.contains("leg") {
            if name.contains("romanian") || name.contains("hamstring") {
                return [.hamstrings, .glutes]
            }
            if name.contains("calf") {
                return [.calves]
            }
            if name.contains("lunge") || name.contains("split") {
                return [.quads, .glutes, .adductors]
            }
            return [.quads, .hamstrings, .glutes]
        }

        if primary.contains("glute") {
            return [.glutes, .hamstrings]
        }

        if primary.contains("shoulder") || primary.contains("delt") {
            return [.deltoids, .traps]
        }

        if primary.contains("core") || primary.contains("abs") {
            return [.abs, .obliques]
        }

        if primary.contains("chest") {
            return [.chest, .triceps, .deltoids]
        }

        if primary.contains("full") {
            return [.quads, .glutes, .upperBack, .deltoids, .abs]
        }

        return segments(forMuscleName: primary)
    }

    static func segments(forMuscleName value: String) -> [MuscleSegment] {
        let name = value.lowercased()
        if name.contains("chest") || name.contains("pec") { return [.chest] }
        if name.contains("shoulder") || name.contains("delt") { return [.deltoids] }
        if name.contains("trap") { return [.traps] }
        if name.contains("lat") || name.contains("back") { return [.upperBack] }
        if name.contains("lower back") || name.contains("lumbar") { return [.lowerBack] }
        if name.contains("bicep") { return [.biceps] }
        if name.contains("tricep") { return [.triceps] }
        if name.contains("forearm") { return [.forearms] }
        if name.contains("core") || name.contains("abs") { return [.abs] }
        if name.contains("oblique") { return [.obliques] }
        if name.contains("quad") || name.contains("leg") { return [.quads] }
        if name.contains("hamstring") { return [.hamstrings] }
        if name.contains("glute") { return [.glutes] }
        if name.contains("calf") { return [.calves] }
        if name.contains("adductor") { return [.adductors] }
        return []
    }
}

extension BodyViewStyle {
    static let repsDark = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.16),
        strokeColor: Color.black.opacity(0.55),
        strokeWidth: 0.65,
        selectionColor: PulseTheme.primary,
        selectionStrokeColor: .white,
        selectionStrokeWidth: 1.8,
        headColor: Color.white.opacity(0.22),
        hairColor: Color.white.opacity(0.10)
    )

    static let repsThumbnail = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.18),
        strokeColor: Color.black.opacity(0.55),
        strokeWidth: 0.8,
        selectionColor: PulseTheme.primary,
        selectionStrokeColor: PulseTheme.primary,
        selectionStrokeWidth: 1,
        headColor: Color.white.opacity(0.22),
        hairColor: Color.white.opacity(0.10)
    )
}

extension HeatmapConfiguration {
    static let repsVolume = HeatmapConfiguration(
        colorScale: .repsProgressVolume,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.55
    )
}

extension HeatmapColorScale {
    static let repsProgressVolume = HeatmapColorScale(colors: [
        PulseTheme.primary,
        PulseTheme.primaryBright,
        PulseTheme.accent
    ])
}
