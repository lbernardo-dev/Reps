import Charts
import MuscleMap
import SwiftUI
import PhotosUI

struct ExerciseProgressView: View {
    @Environment(AppStore.self) private var store
    let exercise: Exercise

    @State private var metric = ExerciseProgressMetric.weight
    @State private var selectedTab: ExerciseDetailTab = .instructions
    @State private var selectedHistoryRange: ExerciseHistoryRange = .sixMonths
    @State private var showLocalVideoPlayer = false

    private enum ExerciseDetailTab: String, CaseIterable, Identifiable {
        case instructions = "Instrucciones"
        case info = "Info"
        case history = "Historial"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .instructions: localizedString("instructions")
            case .info: "Info"
            case .history: localizedString("history")
            }
        }
    }

    private var currentExercise: Exercise {
        ExerciseVisualResolver.resolved(exercise, catalog: store.exercises)
    }

    private var points: [FitnessMetrics.ExerciseProgressPoint] {
        FitnessMetrics.progressPoints(for: currentExercise, in: store.workoutSessions)
    }

    private var rangedPoints: [FitnessMetrics.ExerciseProgressPoint] {
        points.filter { $0.date >= selectedHistoryRange.startDate }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                Text(currentExercise.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)

                exerciseTabControl

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
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.vertical, 20)
            .padding(.bottom, 82)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("exercise_2")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }

    private var instructionsContent: some View {
        VStack(spacing: 18) {
            ExerciseHeroMedia(exercise: currentExercise, gender: store.userProfile.muscleMapGender, height: 260)
            personalizationCard
            exerciseTechniqueCard
        }
    }

    private var exerciseTabControl: some View {
        HStack(spacing: 4) {
            ForEach(ExerciseDetailTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.localizedTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(selectedTab == tab ? .white : PulseTheme.secondaryText)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.26))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(selectedTab == tab ? "Seleccionada" : "")
            }
        }
        .padding(4)
        .background(PulseTheme.card, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var personalizationCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle("personalization")
                HStack(spacing: 10) {
                    ExerciseMediaPickerMenu(
                        hasCustomImage: ExerciseVisualResolver.hasValidCustomImage(currentExercise.customImageData),
                        hasCustomVideo: ExerciseVisualResolver.hasValidCustomVideo(currentExercise.customVideoData),
                        onImageCaptured: { data in
                            var updated = currentExercise
                            updated.customImageData = data
                            store.updateExercise(updated)
                        },
                        onVideoCaptured: { data, thumbnail in
                            var updated = currentExercise
                            updated.customVideoData = data
                            updated.customVideoThumbnailData = thumbnail
                            store.updateExercise(updated)
                        },
                        onDeleteImage: {
                            var updated = currentExercise
                            updated.customImageData = nil
                            store.updateExercise(updated)
                        },
                        onDeleteVideo: {
                            var updated = currentExercise
                            updated.customVideoData = nil
                            updated.customVideoThumbnailData = nil
                            store.updateExercise(updated)
                        }
                    ) {
                        Label("cambiar_imagen_o_video", systemImage: "photo.badge.plus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(PulseTheme.accent)
                            .background(PulseTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }

                if ExerciseVisualResolver.hasValidCustomImage(currentExercise.customImageData) {
                    Label("imagen_propia_guardada_offline", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                }
                if ExerciseVisualResolver.hasValidCustomVideo(currentExercise.customVideoData) {
                    Label("video_propio_guardado_offline", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ExerciseMuscleInfoPanel(exercise: currentExercise, gender: store.userProfile.muscleMapGender)

            SectionHeader(title: "muscles_worked")

            PulseCard {
                VStack(spacing: 0) {
                    ExerciseMuscleTargetRow(title: localizedMuscle(currentExercise.muscleGroup), subtitle: "1 serie", muscleGroup: currentExercise.muscleGroup, exerciseName: currentExercise.name, gender: store.userProfile.muscleMapGender)
                    if !currentExercise.secondaryMuscles.isEmpty {
                        Divider()
                        ForEach(currentExercise.secondaryMuscles, id: \.self) { muscle in
                            ExerciseMuscleTargetRow(title: localizedMuscle(muscle), subtitle: "0,35 series indirectas", muscleGroup: muscle, exerciseName: currentExercise.name, gender: store.userProfile.muscleMapGender)
                            if muscle != currentExercise.secondaryMuscles.last {
                                Divider()
                            }
                        }
                    }
                }
            }

            SectionHeader(title: "exercise_settings_section")

            PulseCard {
                HStack {
                    Text("incremento")
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
                        Text("exercise_priority")
                            .font(.headline)
                        Spacer()
                        Label("preferente", systemImage: "circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.ringStand)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(PulseTheme.grouped, in: Capsule())
                    }
                    Text("the_plan_will_prioritize_exercises_with_the_same_pattern_available_equipment_and")
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ResistanceCurveCard(profile: ResistanceCurveProfile(exercise: currentExercise))
            FatigueRatingCard(score: fatigueScore, description: fatigueDescription)
        }
    }

    private var historyContent: some View {
        VStack(spacing: 18) {
            Picker("range", selection: $selectedHistoryRange) {
                ForEach(ExerciseHistoryRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if rangedPoints.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "exercise_not_done_yet",
                        message: "exercise_not_done_message",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
            } else {
                HStack(spacing: 14) {
                    MetricCard(title: "best_weight", value: String(format: "%.0f", rangedPoints.map(\.maxWeightKg).max() ?? 0), subtitle: "kg", systemImage: "scalemass", badgeColor: PulseTheme.accent, domain: .strength)
                    MetricCard(title: "estimated_1rm", value: String(format: "%.0f", rangedPoints.map(\.estimatedOneRepMaxKg).max() ?? 0), subtitle: "kg", systemImage: "bolt", badgeColor: PulseTheme.accent, domain: .strength)
                }

                HStack(spacing: 14) {
                    MetricCard(title: "overload_metric", value: String(format: "%.1f", FitnessMetrics.progressiveOverloadDelta(for: rangedPoints)), subtitle: "one_rm_change", systemImage: "arrow.up.right", badgeColor: PulseTheme.warning, domain: .strength)
                    MetricCard(title: "avg_volume_metric", value: "\(Int(FitnessMetrics.averageVolumeKg(for: rangedPoints)))", subtitle: "kg_per_session", systemImage: "chart.bar", badgeColor: PulseTheme.ringStand, domain: .strength)
                }

                Picker("metrics", selection: $metric) {
                    ForEach(ExerciseProgressMetric.allCases) { metric in
                        Text(metric.localizedTitle).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                PulseCard {
                    ExercisePerformanceChart(
                        points: rangedPoints,
                        metric: metric
                    )
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CardTitle("recent_sessions")
                        ForEach(rangedPoints.reversed()) { point in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(point.workoutTitle).font(.headline)
                                    Text(point.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(metric.valueText(for: point))
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
        let text = "\(currentExercise.name) \(currentExercise.muscleGroup) \(currentExercise.equipment)".lowercased()
        var score = 1
        if text.contains("barbell") || text.contains("barra") { score += 1 }
        if text.contains("squat") || text.contains("deadlift") || text.contains("press") || text.contains("row") { score += 1 }
        if text.contains("legs") || text.contains("back") || text.contains("full") { score += 1 }
        return min(score, 4)
    }

    private var fatigueDescription: String {
        switch fatigueScore {
        case 1:   return localizedString("low_fatigue_desc")
        case 2:   return localizedString("moderate_fatigue_desc")
        case 3:   return localizedString("high_fatigue_desc")
        default:  return localizedString("very_high_fatigue_desc")
        }
    }

    private func localizedMuscle(_ value: String) -> String {
        RepsText.muscle(value, language: store.userProfile.preferredLanguage)
    }

    private var exerciseTechniqueCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("exercise_technique", systemImage: "list.clipboard")
                        .font(.headline)
                    Spacer()
                    if let videoURL = currentExercise.videoURL, let url = URL(string: videoURL) {
                        Link(destination: url) {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundStyle(PulseTheme.accent)
                        }
                        .accessibilityLabel("open_exercise_video")
                    } else if ExerciseVisualResolver.hasValidCustomVideo(currentExercise.customVideoData) {
                        Button {
                            showLocalVideoPlayer = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundStyle(PulseTheme.accent)
                        }
                        .accessibilityLabel(localizedString("play_guide_video"))
                    }
                }

                if instructionsText.isEmpty {
                    Text("this_exercise_does_not_yet_have_detailed_instructions_if_it_comes_from_open_sour")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                } else {
                    Text(instructionsText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !currentExercise.commonMistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("avoid")
                            .font(.subheadline.weight(.semibold))
                        ForEach(currentExercise.commonMistakes, id: \.self) { mistake in
                            Label(mistake, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }

                HStack(spacing: 10) {
                    ForEach(currentExercise.requiredEquipment.prefix(3), id: \.self) { equipment in
                        ExerciseInfoChip(text: equipment, systemImage: "wrench.and.screwdriver")
                    }
                }

                if let sourceURL = currentExercise.sourceURL, let url = URL(string: sourceURL) {
                    Link(destination: url) {
                        Label(sourceFooter, systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .accessibilityLabel("open_exercise_source")
                } else if let sourceName = currentExercise.sourceName {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .sheet(isPresented: $showLocalVideoPlayer) {
            if let videoData = currentExercise.customVideoData {
                ExerciseGuideVideoPlayerSheet(videoData: videoData, title: currentExercise.name)
            }
        }
    }

    private var sourceFooter: String {
        let name = currentExercise.sourceName ?? "Fuente"
        if let license = currentExercise.sourceLicense {
            return "\(name) · \(license)"
        }
        return name
    }

    private var instructionsText: String {
        currentExercise.instructions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

}

enum ExerciseProgressMetric: String, CaseIterable, Identifiable {
    case weight = "Peso"
    case reps = "Reps"
    case volume = "Volumen"
    case oneRepMax = "1RM"
    case sets = "Series"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .weight: localizedString("weight")
        case .reps: localizedString("reps")
        case .volume: localizedString("volume")
        case .oneRepMax: "1RM"
        case .sets: localizedString("sets")
        }
    }

    var unitLabel: String {
        switch self {
        case .weight, .volume, .oneRepMax:
            "kg"
        case .reps:
            localizedString("reps")
        case .sets:
            localizedString("sets_3")
        }
    }

    func value(for point: FitnessMetrics.ExerciseProgressPoint) -> Double {
        switch self {
        case .weight:
            point.maxWeightKg
        case .reps:
            Double(point.maxReps)
        case .volume:
            point.totalVolumeKg
        case .oneRepMax:
            point.estimatedOneRepMaxKg
        case .sets:
            Double(point.completedSets)
        }
    }

    func valueText(for point: FitnessMetrics.ExerciseProgressPoint) -> String {
        "\(Self.formatted(value(for: point))) \(localizedTitle)"
    }

    static func formatted(_ value: Double) -> String {
        if abs(value) >= 100 || value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

enum ExerciseHistoryRange: String, CaseIterable, Identifiable {
    case week = "1S"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "12M"
    case max = "MAX"

    var id: String { rawValue }

    var startDate: Date {
        let calendar = Calendar.current
        return switch self {
        case .week:
            calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        case .month:
            calendar.date(byAdding: .month, value: -1, to: .now) ?? .distantPast
        case .threeMonths:
            calendar.date(byAdding: .month, value: -3, to: .now) ?? .distantPast
        case .sixMonths:
            calendar.date(byAdding: .month, value: -6, to: .now) ?? .distantPast
        case .year:
            calendar.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
        case .max:
            Date.distantPast
        }
    }
}

struct ExercisePerformanceChart: View {
    let points: [FitnessMetrics.ExerciseProgressPoint]
    let metric: ExerciseProgressMetric

    private var chartPoints: [ChartPoint] {
        points.map { point in
            ChartPoint(
                id: point.id,
                date: point.date,
                workoutTitle: point.workoutTitle,
                value: metric.value(for: point)
            )
        }
    }

    private var latestPoint: ChartPoint? {
        chartPoints.max { $0.date < $1.date }
    }

    private var bestPoint: ChartPoint? {
        chartPoints.max { $0.value < $1.value }
    }

    private var averageValue: Double {
        guard !chartPoints.isEmpty else { return 0 }
        return chartPoints.map(\.value).reduce(0, +) / Double(chartPoints.count)
    }

    private var trendText: String {
        guard let first = chartPoints.min(by: { $0.date < $1.date }),
              let last = latestPoint else {
            return "-"
        }
        let delta = last.value - first.value
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(formatted(delta)) \(unitLabel)"
    }

    private var unitLabel: String { metric.unitLabel }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedString("exercise_trend"))
                        .font(.headline)
                    Text(metric.localizedTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(latestPoint.map { formatted($0.value) } ?? "-")
                        .font(.title3.weight(.black).monospacedDigit())
                        .foregroundStyle(PulseTheme.accent)
                    Text(unitLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            HStack(spacing: 10) {
                chartMetric(title: "best", value: bestPoint.map { "\(formatted($0.value)) \(unitLabel)" } ?? "-")
                chartMetric(title: "average", value: "\(formatted(averageValue)) \(unitLabel)")
                chartMetric(title: "trend", value: trendText)
            }

            Chart {
                ForEach(chartPoints) { point in
                    AreaMark(
                        x: .value("Fecha", point.date),
                        y: .value(metric.localizedTitle, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accent.opacity(0.28), PulseTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Fecha", point.date),
                        y: .value(metric.localizedTitle, point.value)
                    )
                    .foregroundStyle(PulseTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Fecha", point.date),
                        y: .value(metric.localizedTitle, point.value)
                    )
                    .foregroundStyle(point.id == latestPoint?.id ? PulseTheme.accent : PulseTheme.ringStand)
                    .symbolSize(point.id == latestPoint?.id ? 88 : 42)
                }

                RuleMark(y: .value(localizedString("average"), averageValue))
                    .foregroundStyle(PulseTheme.secondaryText.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(PulseTheme.separator.opacity(0.5))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatted(doubleValue))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                        .foregroundStyle(PulseTheme.separator.opacity(0.25))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
            .frame(height: 240)

            if let latestPoint {
                Text("\(localizedString("last_session")): \(latestPoint.workoutTitle) · \(formatted(latestPoint.value)) \(unitLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private func chartMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(localizedKey(title))
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func formatted(_ value: Double) -> String {
        if abs(value) >= 100 || value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private struct ChartPoint: Identifiable {
        let id: UUID
        let date: Date
        let workoutTitle: String
        let value: Double
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
                .showSubGroups()
                .frame(maxWidth: .infinity)
            BodyView(gender: gender, side: .back, style: .repsDark)
                .heatmap(backHeatmap, configuration: .repsVolume)
                .showSubGroups()
                .frame(maxWidth: .infinity)
        }
        .frame(height: 280)
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .accessibilityLabel(localizedFormat("primary_muscles_worked_by_exercise_accessibility_format", exercise.name))
    }

    private var frontHeatmap: [MuscleIntensity] {
        descriptor.thumbnailHeatmap(primaryIntensity: 0.92)
    }

    private var backHeatmap: [MuscleIntensity] {
        descriptor.thumbnailHeatmap(primaryIntensity: 0.92)
    }
}

struct ExerciseMuscleTargetRow: View {
    let title: String
    let subtitle: String
    let muscleGroup: String
    var exerciseName = ""
    let gender: BodyGender

    var body: some View {
        HStack(spacing: 14) {
            MuscleGroupAnatomyThumbnail(muscleGroup: muscleGroup, exerciseName: exerciseName, gender: gender, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedKey(title))
                    .font(.title3.weight(.bold))
                Text(localizedKey(subtitle))
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
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("resistance_curve")
                            .font(.headline)
                        Text("estimated_tension_through_the_range_of_motion")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(profile.dominantPoint.phase.shortTitle)
                            .font(.caption.weight(.black))
                            .foregroundStyle(profile.dominantPoint.pressureColor)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(profile.dominantPoint.pressureColor.opacity(0.14), in: Capsule())
                        Text(localizedFormat("peak_percentage_format", Int((profile.dominantPoint.intensity * 100).rounded())))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                ResistancePressureGraph(points: profile.points)
                    .frame(height: 210)

                HStack(spacing: 8) {
                    PressureLegendDot(title: localizedString("pressure_low"), color: ResistanceCurveProfile.pressureColor(for: 0.22))
                    PressureLegendDot(title: localizedString("pressure_medium"), color: ResistanceCurveProfile.pressureColor(for: 0.52))
                    PressureLegendDot(title: localizedString("pressure_high"), color: ResistanceCurveProfile.pressureColor(for: 0.78))
                    PressureLegendDot(title: localizedString("pressure_peak"), color: ResistanceCurveProfile.pressureColor(for: 0.95))
                }
            }
        }
    }
}

struct ResistanceCurveProfile {
    enum Phase: String, CaseIterable, Identifiable {
        case stretch = "ESTIRAMIENTO"
        case middle = "MEDIO"
        case contraction = "CONTRACCIÓN"

        var id: String { rawValue }

        var shortTitle: String {
            switch self {
            case .stretch:     localizedString("phase_stretch_short")
            case .middle:      localizedString("phase_middle_short")
            case .contraction: localizedString("phase_contraction_short")
            }
        }

        var index: Double {
            switch self {
            case .stretch: 0
            case .middle: 1
            case .contraction: 2
            }
        }
    }

    struct Point: Identifiable {
        let phase: Phase
        let intensity: Double

        var id: Phase { phase }

        var pressureColor: Color {
            ResistanceCurveProfile.pressureColor(for: intensity)
        }

        var pressureTitle: String {
            switch intensity {
            case 0..<0.35:    localizedString("pressure_low")
            case 0.35..<0.65: localizedString("pressure_medium")
            case 0.65..<0.88: localizedString("pressure_high")
            default:          localizedString("pressure_peak")
            }
        }
    }

    let points: [Point]

    var dominantPoint: Point {
        points.max { $0.intensity < $1.intensity } ?? Point(phase: .middle, intensity: 0)
    }

    static func pressureColor(for intensity: Double) -> Color {
        switch intensity {
        case 0..<0.35:
            return PulseTheme.accent
        case 0.35..<0.65:
            return PulseTheme.ringStand
        case 0.65..<0.88:
            return PulseTheme.warning
        default:
            return PulseTheme.destructive
        }
    }

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

private struct ResistancePressureGraph: View {
    let points: [ResistanceCurveProfile.Point]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let plotTop: CGFloat = 18
            let plotBottom: CGFloat = 46
            let plotHeight = max(height - plotTop - plotBottom, 1)
            let xPositions = points.map { xPosition(for: $0.phase, width: width) }
            let coordinates = points.enumerated().map { index, point in
                CGPoint(
                    x: xPositions[index],
                    y: plotTop + (1 - min(max(point.intensity, 0), 1)) * plotHeight
                )
            }

            ZStack {
                VStack(spacing: 0) {
                    ForEach([1.0, 0.75, 0.5, 0.25], id: \.self) { value in
                        HStack(spacing: 8) {
                            Text("\(Int(value * 100))%")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(width: 36, alignment: .trailing)
                            Rectangle()
                                .fill(PulseTheme.separator.opacity(value == 1.0 || value == 0.5 ? 0.7 : 0.32))
                                .frame(height: value == 1.0 || value == 0.5 ? 1 : 0.5)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.top, plotTop - 6)
                .padding(.bottom, plotBottom + 4)

                Path { path in
                    guard let first = coordinates.first else { return }
                    path.move(to: first)
                    for coordinate in coordinates.dropFirst() {
                        path.addLine(to: coordinate)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: points.map(\.pressureColor),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: PulseTheme.ringStand.opacity(0.22), radius: 8)

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let x = xPositions[index]
                    let barHeight = max(point.intensity * plotHeight, 12)
                    let y = plotTop + plotHeight - barHeight

                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(PulseTheme.grouped.opacity(0.9))
                                .frame(width: 54, height: plotHeight)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            point.pressureColor.opacity(0.45),
                                            point.pressureColor
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 54, height: barHeight)
                                .shadow(color: point.pressureColor.opacity(0.28), radius: 8)
                        }
                        .overlay(alignment: .top) {
                            Text("\(Int((point.intensity * 100).rounded()))%")
                                .font(.caption2.weight(.black).monospacedDigit())
                                .foregroundStyle(point.pressureColor)
                                .offset(y: -18)
                        }
                        .overlay(alignment: .center) {
                            Circle()
                                .fill(point.pressureColor)
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 2))
                                .position(x: 27, y: max(y - plotTop, 9))
                        }

                        VStack(spacing: 2) {
                            Text(point.phase.rawValue)
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(point.pressureTitle)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(point.pressureColor)
                        }
                        .frame(width: 92)
                    }
                    .position(x: x, y: height / 2 + 12)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("resistance_curve")
        .accessibilityValue(points.map { "\($0.phase.rawValue) \(Int(($0.intensity * 100).rounded()))%" }.joined(separator: ", "))
    }

    private func xPosition(for phase: ResistanceCurveProfile.Phase, width: CGFloat) -> CGFloat {
        let available = max(width - 86, 1)
        return 43 + (available * CGFloat(phase.index / 2))
    }
}

private struct PressureLegendDot: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(localizedKey(title))
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FatigueRatingCard: View {
    let score: Int
    let description: String

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(localizedString("fatigue"))
                        .font(.headline)
                    Spacer()
                    Text("\(score)/4")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(score >= 4 ? PulseTheme.destructive : score >= 3 ? PulseTheme.warning : PulseTheme.ringStand)
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
            return PulseTheme.ringStand
        case 3:
            return PulseTheme.warning
        default:
            return PulseTheme.destructive
        }
    }
}
