import Charts
import MuscleMap
import SwiftUI

struct MuscleMapProgressView: View {
    let sessions: [WorkoutSession]
    let plannedWorkout: WorkoutDay
    let startDate: Date
    let gender: BodyGender
    let catalog: [Exercise]

    @State private var selectedFilter: MuscleRegionFilter = .all
    @State private var selectedMode: MuscleMapMode = .actual
    @State private var selectedSegment: MuscleSegment?
    @State private var detailSegment: MuscleSegment?

    private let heatmapHeight: CGFloat = 520

    // `loads` used to be a computed property, walking the full (unfiltered)
    // session history via `MuscleLoadCalculator.loads` on every access. `body`
    // read it independently ~8-10 times per render (directly, plus through
    // `filteredLoads`/`underTargetLoads`/`highVolumeLoads`/`growthZoneCount`),
    // so a single render redid this O(n) scan that many times. Compute it
    // once per body evaluation and thread the value through instead.
    private func filteredLoads(from loads: [MuscleLoad]) -> [MuscleLoad] {
        loads
            .filter { selectedFilter.includes($0.segment) }
            .sorted { lhs, rhs in
                if lhs.displaySets == rhs.displaySets {
                    return lhs.segment.title < rhs.segment.title
                }
                return lhs.displaySets > rhs.displaySets
            }
    }

    private func underTargetLoads(from loads: [MuscleLoad]) -> [MuscleLoad] {
        loads.filter { $0.totalSets > 0 && $0.totalSets < 4 }
    }

    private func highVolumeLoads(from loads: [MuscleLoad]) -> [MuscleLoad] {
        loads.filter { $0.totalSets > 12 }
    }

    private func growthZoneCount(from loads: [MuscleLoad]) -> Int {
        loads.filter { $0.totalSets >= 4 && $0.totalSets <= 12 }.count
    }

    var body: some View {
        let loads = MuscleLoadCalculator.loads(
            sessions: sessions,
            plannedWorkout: plannedWorkout,
            startDate: startDate,
            includePrediction: selectedMode == .predict
        )
        let underTarget = underTargetLoads(from: loads)
        let highVolume = highVolumeLoads(from: loads)
        let filtered = filteredLoads(from: loads)

        return VStack(spacing: 14) {
            MuscleCoverageSummaryCard(
                subtitle: selectedMode.subtitle,
                totalSegments: loads.count,
                growthZoneCount: growthZoneCount(from: loads),
                underTargetCount: underTarget.count,
                highVolumeCount: highVolume.count,
                topFocus: underTarget.sorted { $0.totalSets < $1.totalSets }.first
                    ?? highVolume.sorted { $0.totalSets > $1.totalSets }.first
                    ?? loads.sorted { $0.totalSets > $1.totalSets }.first
            )

            InteractiveBodyHeatmap(
                loads: loads,
                gender: gender,
                selectedSegment: $selectedSegment
            )
            .frame(height: heatmapHeight)
            .padding(.vertical, 10)

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
                ForEach(filtered.filter { $0.segment != selectedSegment }) { load in
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
                gender: gender,
                catalog: catalog
            )
        }
    }

    private var modeControl: some View {
        HStack(spacing: 10) {
            ForEach(MuscleMapMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .foregroundStyle(selectedMode == mode ? .black : Color.white.opacity(0.7))
                        .background(
                            selectedMode == mode ? PulseTheme.accent : Color.white.opacity(0.05)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedMode == mode ? PulseTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .shadow(color: selectedMode == mode ? PulseTheme.accent.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var selectedSegmentControl: some View {
        if let selectedSegment {
            HStack(spacing: 8) {
                Circle()
                    .fill(PulseTheme.ringStand)
                    .frame(width: 6, height: 6)
                    .shadow(color: PulseTheme.ringStand, radius: 2)
                Text(selectedSegment.title)
                    .font(.system(size: 12, weight: .bold))
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        self.selectedSegment = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .black))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color.white.opacity(0.08))
            .overlay(
                Capsule()
                    .stroke(PulseTheme.ringStand.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MuscleRegionFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
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

private struct MuscleCoverageSummaryCard: View {
    let subtitle: LocalizedStringKey
    let totalSegments: Int
    let growthZoneCount: Int
    let underTargetCount: Int
    let highVolumeCount: Int
    let topFocus: MuscleLoad?

    private var coverageRatio: Double {
        guard totalSegments > 0 else { return 0 }
        return Double(growthZoneCount) / Double(totalSegments)
    }

    private var headline: String {
        if underTargetCount > 0 {
            return localizedString("below_growth_zone")
        }
        if highVolumeCount > 0 {
            return localizedString("high_volume_monitor_recovery")
        }
        return localizedString("productive_volume")
    }

    var body: some View {
        PulseCard(contentPadding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.grouped, lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: min(max(coverageRatio, 0), 1))
                            .stroke(PulseTheme.growth, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(coverageRatio * 100))%")
                            .font(.caption.weight(.black).monospacedDigit())
                            .foregroundStyle(PulseTheme.growth)
                    }
                    .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("muscle_map")
                            .font(.caption.weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.ringStand)
                        Text(headline)
                            .font(.headline.weight(.black))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(localizedKey(subtitle))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    MuscleCoverageMetric(value: "\(growthZoneCount)", label: "growth_label", systemImage: "leaf.fill", color: PulseTheme.growth)
                    MuscleCoverageMetric(value: "\(underTargetCount)", label: "alerts_label", systemImage: "arrow.down.circle.fill", color: PulseTheme.warning)
                    MuscleCoverageMetric(value: "\(highVolumeCount)", label: "load", systemImage: "exclamationmark.triangle.fill", color: PulseTheme.destructive)
                }

                if let topFocus {
                    HStack(spacing: 10) {
                        Image(systemName: topFocus.totalSets > 12 ? "exclamationmark.triangle.fill" : "scope")
                            .font(.caption.weight(.black))
                            .foregroundStyle(topFocus.zoneColor)
                            .frame(width: 28, height: 28)
                            .background(topFocus.zoneColor.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topFocus.segment.title)
                                .font(.caption.weight(.black))
                            Text(topFocus.rangeText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        Spacer()
                        Text("\(topFocus.displaySets)/12")
                            .font(.caption.weight(.black).monospacedDigit())
                            .foregroundStyle(topFocus.zoneColor)
                    }
                    .padding(10)
                    .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

private struct MuscleCoverageMetric: View {
    let value: String
    let label: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(color)
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
            Text(localizedKey(label))
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct QuietFilterChip: View {
    let title: LocalizedStringKey
    var isSelected = false

    var body: some View {
        Text(localizedKey(title))
            .font(.system(size: 13, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .foregroundStyle(isSelected ? .black : Color.white.opacity(0.7))
            .background(
                isSelected ? PulseTheme.ringStand : Color.white.opacity(0.05)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? PulseTheme.ringStand : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(color: isSelected ? PulseTheme.ringStand.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 1)
    }
}

struct InteractiveBodyHeatmap: View {
    let loads: [MuscleLoad]
    let gender: BodyGender
    @Binding var selectedSegment: MuscleSegment?

    var body: some View {
        GeometryReader { proxy in
            let bodyWidth = proxy.size.width * 0.62
            let bodyHeight = proxy.size.height * 0.88
            let visualScale = min(1.1, max(1.0, proxy.size.width / 390))

            ZStack {
                bodyView(side: .back)
                    .frame(width: bodyWidth, height: bodyHeight)
                    .scaleEffect(visualScale, anchor: .center)
                    .offset(x: proxy.size.width * 0.17, y: 4)
                    .opacity(selectedSegment == nil ? 0.88 : 0.72)
                    .zIndex(1)

                bodyView(side: .front)
                    .frame(width: bodyWidth, height: bodyHeight)
                    .scaleEffect(visualScale, anchor: .center)
                    .offset(x: -proxy.size.width * 0.16, y: -2)
                    .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .compositingGroup()
            .clipped()
            .contentShape(Rectangle())
        }
        .accessibilityLabel("mapa_muscular_interactivo")
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
	        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                MuscleAnatomyThumbnail(segment: load.segment, intensity: load.intensity, gender: gender, size: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? PulseTheme.ringStand : Color.white.opacity(0.06), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(load.segment.title)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 8)

                        MuscleZonePill(title: load.compactZoneTitle, color: load.zoneColor)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(load.displaySets)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(load.zoneColor)
                        Text("/")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.32))
                        Text("12 \(localizedString("weekly"))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PulseTheme.secondaryText)

                        if load.predictedSets > 0 {
                            Label("+\(load.predictedSets)", systemImage: "sparkles")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(PulseTheme.ringStand)
                                .padding(.leading, 2)
                        }
                    }
                }
            }

            RepsProgressiveSegmentBar(value: load.totalSets)

            HStack(alignment: .firstTextBaseline) {
                Text(load.rangeText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer()
                Text("\(Int(load.totalVolumeKg)) kg")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            if showsAnalysisHint {
                Divider()
                    .overlay(Color.white.opacity(0.06))

                HStack(spacing: 7) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 11, weight: .black))
                    Text(localizedString("view_frequency_and_contributions"))
                        .font(.system(size: 12, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundStyle(PulseTheme.ringStand)
            }
	        }
	        .padding(14)
	        .background(
	            ZStack {
	                RoundedRectangle(cornerRadius: 20, style: .continuous)
	                    .fill(Color.white.opacity(isSelected ? 0.045 : 0.025))

	                LinearGradient(
	                    colors: [
	                        Color.white.opacity(isSelected ? 0.07 : 0.035),
	                        load.zoneColor.opacity(isSelected ? 0.035 : 0.012),
	                        Color.black.opacity(0.18)
	                    ],
	                    startPoint: .topLeading,
	                    endPoint: .bottomTrailing
	                )
	            }
	        )
	        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
	        .overlay(
	            RoundedRectangle(cornerRadius: 20, style: .continuous)
	                .stroke(isSelected ? PulseTheme.ringStand.opacity(0.82) : Color.white.opacity(0.075), lineWidth: isSelected ? 1.6 : 1)
	        )
	        .shadow(color: isSelected ? PulseTheme.ringStand.opacity(0.10) : Color.black.opacity(0.14), radius: isSelected ? 12 : 8, x: 0, y: 5)
	    }
	}

private struct MuscleZonePill: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black))
                .tracking(0.8)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(color.opacity(0.10), in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.22), lineWidth: 1)
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
    let catalog: [Exercise]

    private var activity: MuscleActivitySummary {
        MuscleActivitySummary(segment: segment, sessions: sessions, startDate: startDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 12) {
                        MuscleSegmentHero(
                            segment: segment,
                            intensity: max(load.intensity, 0.55),
                            gender: gender
                        )
                        .frame(height: 320)

                        MuscleWeeklyVolumeCard(load: load, segment: segment, gender: gender)
                    }

                    SectionHeader(title: "muscle_analysis")

                    PulseCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("frequency_and_volume")
                                .font(.title3.weight(.bold))
                            Text(localizedFormat("muscle_training_frequency_format",
                                segment.title.lowercased(),
                                activity.trainingDays,
                                localizedString(activity.trainingDays == 1 ? "time" : "times_plural"),
                                activity.directDays))
                                .font(.body)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Chart(activity.dailyPoints) { point in
                                BarMark(
                                    x: .value(localizedString("day"), point.label),
                                    y: .value(localizedString("sets"), point.sets)
                                )
                                .foregroundStyle(point.sets > 0 ? PulseTheme.accent : PulseTheme.separator)

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
                                            .background(PulseTheme.accent, in: Circle())
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
                        SectionHeader(title: "indirect_exercises")
                        VStack(spacing: 10) {
                            ForEach(activity.indirectExercises) { item in
                                MuscleExerciseContributionRow(item: item, gender: gender, isIndirect: true, catalog: catalog)
                            }
                        }
                    }

                    if !activity.directExercises.isEmpty {
                        SectionHeader(title: "direct_exercises")
                        VStack(spacing: 10) {
                            ForEach(activity.directExercises) { item in
                                MuscleExerciseContributionRow(item: item, gender: gender, isIndirect: false, catalog: catalog)
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 20)
                .padding(.bottom, 96)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle(segment.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("close")
                        .font(.headline)
                        .frame(width: 142, height: 58)
                        .foregroundStyle(.black)
                        .background(PulseTheme.accent)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(load.displaySets) \(localizedString("of_12_weekly_sets"))")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()
                Text(load.setsToGrowthZoneText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(alignment: .center, spacing: 14) {
                MuscleAnatomyThumbnail(segment: segment, intensity: load.intensity, gender: gender, size: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                RepsProgressiveSegmentBar(value: load.totalSets, height: 32, spacing: 6)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct MuscleExerciseContributionRow: View {
    let item: MuscleExerciseContribution
    let gender: BodyGender
    let isIndirect: Bool
    let catalog: [Exercise]

    var body: some View {
        HStack(spacing: 14) {
            ExerciseMediaThumbnail(exercise: item.exercise, gender: gender, catalog: catalog)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

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
                    let indirectMuscles = log.exercise.secondaryMuscles.filter { secondary in
                        MuscleLoadCalculator.segments(forMuscleName: secondary).contains(segment)
                    }
                    let indirect = !direct && !indirectMuscles.isEmpty
                    guard direct || indirect else { return nil }
                    let multiplier = direct
                        ? 1.0
                        : (indirectMuscles.map { log.exercise.secondaryInvolvement($0) }.max() ?? Exercise.defaultSecondaryInvolvement)
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
        case 0: localizedFormat("days_plural_count_format", 6)
        case 1: localizedFormat("days_plural_count_format", 5)
        case 2: localizedFormat("days_plural_count_format", 4)
        case 3: localizedFormat("days_plural_count_format", 3)
        case 4: localizedFormat("days_plural_count_format", 2)
        case 5: localizedString("yesterday_2")
        default: localizedString("today")
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
    let exercise: Exercise
    let date: Date
    let completedSets: Int
    let effectiveSets: Double
    let repText: String
    let isDirect: Bool
    var id: String { "\(exercise.id)-\(date.timeIntervalSince1970)-\(isDirect)" }

    var effectiveSetsText: String {
        if effectiveSets.rounded() == effectiveSets {
            return localizedFormat("sets_count_format", Int(effectiveSets))
        }
        return localizedFormat("sets_decimal_count_format", effectiveSets)
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = RepsLocalization.locale
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct MuscleAnatomyThumbnail: View {
    let segment: MuscleSegment
    let intensity: Double
    let gender: BodyGender
    var size: CGFloat = 58

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(segment.visibleSides.enumerated()), id: \.offset) { index, side in
                    body(side: side)
                        .frame(width: proxy.size.width * thumbnailBodyWidthMultiplier, height: proxy.size.height * 1.05)
                        .scaleEffect(viewport.scale, anchor: viewport.anchor)
                        .offset(
                            x: thumbnailXOffset(for: index, in: proxy.size),
                            y: proxy.size.height * viewport.offset.height
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func body(side: BodySide) -> some View {
        BodyView(gender: gender, side: side, style: .repsThumbnail)
            .heatmap(thumbnailData, configuration: .repsVolume)
            .showSubGroups()
    }

    private var thumbnailData: [MuscleIntensity] {
        segment.muscles.map {
            MuscleIntensity(muscle: $0, intensity: min(max(intensity, 0.18), 1))
        }
    }

    private var thumbnailBodyWidthMultiplier: CGFloat {
        segment.visibleSides.count == 1 ? 0.96 : 0.62
    }

    private func thumbnailXOffset(for index: Int, in size: CGSize) -> CGFloat {
        guard segment.visibleSides.count > 1 else {
            return size.width * viewport.offset.width
        }

        let sideSpacing = size.width * 0.18
        return (index == 0 ? -sideSpacing : sideSpacing) + size.width * viewport.offset.width
    }

    private var viewport: AnatomyViewport {
        segment.regionFocus.thumbnail
    }
}

private struct MuscleSegmentHero: View {
    let segment: MuscleSegment
    let intensity: Double
    let gender: BodyGender

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(segment.visibleSides.enumerated()), id: \.offset) { index, side in
                    BodyView(gender: gender, side: side, style: .repsDark)
                        .heatmap(heatmapData, configuration: .repsVolume)
                        .selected(Set(segment.muscles))
                        .frame(width: proxy.size.width * heroBodyWidthMultiplier, height: proxy.size.height * 1.18)
                        .scaleEffect(viewport.scale, anchor: viewport.anchor)
                        .offset(
                            x: heroXOffset(for: index, in: proxy.size),
                            y: proxy.size.height * viewport.offset.height
                        )
                        .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, PulseTheme.background.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: proxy.size.height * 0.28)
                .allowsHitTesting(false)
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private var heatmapData: [MuscleIntensity] {
        segment.muscles.map {
            MuscleIntensity(muscle: $0, intensity: min(max(intensity, 0.48), 1))
        }
    }

    private var heroBodyWidthMultiplier: CGFloat {
        segment.visibleSides.count == 1 ? 0.88 : 0.58
    }

    private func heroXOffset(for index: Int, in size: CGSize) -> CGFloat {
        guard segment.visibleSides.count > 1 else {
            return size.width * viewport.offset.width
        }

        let sideSpacing = size.width * 0.18
        return (index == 0 ? -sideSpacing : sideSpacing) + size.width * viewport.offset.width
    }

    private var viewport: AnatomyViewport {
        segment.regionFocus.hero
    }
}

struct RepsProgressiveSegmentBar: View {
    let value: Double
    var height: CGFloat = 8
    var spacing: CGFloat = 4
    private let segmentCount = 12

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<segmentCount, id: \.self) { index in
                let isActive = Double(index) < value
                let color = fillColor(for: index)
                
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isActive ? color : color.opacity(0.18))
                    .frame(height: height)
                    .shadow(color: isActive ? color.opacity(0.34) : Color.clear, radius: 2, x: 0, y: 0)
            }
        }
        .accessibilityLabel("\(Int(value.rounded())) de 12 series semanales")
    }

    private func fillColor(for index: Int) -> Color {
        // Mirrors MuscleZone semantics cell-by-cell: blue (maintaining) -> green (growing) -> yellow (focus).
        switch index {
        case 0..<4:
            return PulseTheme.accent
        case 4..<10:
            return PulseTheme.growth
        default:
            return PulseTheme.warning
        }
    }
}

struct MuscleLoad: Identifiable {
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
            localizedString("maintenance")
        case 4..<10:
            localizedString("growth_zone")
        default:
            localizedString("focus_zone")
        }
    }

    var compactZoneTitle: String {
        switch totalSets {
        case 0..<4:
            localizedString("maint_short")
        case 4..<10:
            localizedString("growth_label")
        default:
            localizedString("focus_zone")
        }
    }

    var zoneColor: Color {
        switch totalSets {
        case 0..<4:
            PulseTheme.accent
        case 4..<10:
            PulseTheme.growth
        default:
            PulseTheme.warning
        }
    }

    var rangeText: String {
        switch totalSets {
        case 0..<4:
            localizedString("below_growth_zone")
        case 4..<10:
            localizedString("productive_volume")
        case 10...12:
            localizedString("top_of_weekly_target")
        default:
            localizedString("high_volume_monitor_recovery")
        }
    }

    var setsToGrowthZoneText: String {
        let missing = max(0, 4 - displaySets)
        if missing == 0 {
            return localizedString("in_growth_zone")
        }
        return localizedFormat("n_sets_to_growth_zone_format", missing)
    }
}

private enum MuscleMapMode: String, CaseIterable, Identifiable {
    case actual
    case predict

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .actual: "last_7_days"
        case .predict: "predict"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .actual: "muscle_map_actual_subtitle"
        case .predict: "muscle_map_predict_subtitle"
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
        case .all: "all_muscles"
        case .upper: "upper_body"
        case .arms: "arms_label"
        case .back: "back_label"
        case .legs: "legs_label"
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

enum MuscleSegment: String, CaseIterable, Identifiable {
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
        case .chest: localizedString("chest_label")
        case .deltoids: localizedString("deltoids_label")
        case .traps: localizedString("traps_label")
        case .upperBack: localizedString("upper_back_label")
        case .lowerBack: localizedString("lower_back_label")
        case .biceps: localizedString("biceps_label")
        case .triceps: localizedString("triceps_label")
        case .forearms: localizedString("forearms_label")
        case .abs: localizedString("abs_label")
        case .obliques: localizedString("obliques_label")
        case .quads: localizedString("quads_label")
        case .hamstrings: localizedString("hamstrings_label")
        case .glutes: localizedString("glutes_label")
        case .calves: localizedString("calves_label")
        case .adductors: localizedString("adductors_label")
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

    var visibleSides: [BodySide] {
        switch self {
        case .deltoids, .traps, .forearms, .calves, .adductors:
            [.back, .front]
        default:
            [preferredSide]
        }
    }

    var regionFocus: AnatomyRegionFocus {
        switch self {
        case .chest: .chest
        case .deltoids: .shoulders
        case .traps: .traps
        case .upperBack: .upperBack
        case .lowerBack: .lowerBack
        case .biceps, .triceps, .forearms: .arms
        case .abs, .obliques: .core
        case .quads: .quads
        case .hamstrings: .hamstrings
        case .glutes: .glutes
        case .calves: .calves
        case .adductors: .adductors
        }
    }

    static func segment(containing muscle: Muscle) -> MuscleSegment? {
        MuscleSegment.allCases.first { $0.muscles.contains(muscle) }
    }
}

enum MuscleLoadCalculator {
    static func loads(
        sessions: [WorkoutSession],
        plannedWorkout: WorkoutDay,
        startDate: Date,
        includePrediction: Bool
    ) -> [MuscleLoad] {
        var actualSets: [MuscleSegment: Double] = [:]
        var predictedSets: [MuscleSegment: Int] = [:]
        var volume: [MuscleSegment: Double] = [:]

        let recentSessions = sessions.filter { $0.date >= startDate }

        recentSessions
            .flatMap(FitnessMetrics.completedExerciseLogs(in:))
            .forEach { log in
                let setCount = Double(log.sets.count)
                let totalVolume = log.sets.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
                apply(exercise: log.exercise, sets: setCount, volume: totalVolume, into: &actualSets, volumeBuckets: &volume)
            }

        // Cardio (walking/running, free or imported) loads the legs. Map it to a
        // set-equivalent by duration so the muscle map reflects these workouts too.
        for session in recentSessions where session.isRouteSession {
            let setEquivalent = min(max(Double(session.durationMinutes) / 10, 0.5), 8)
            let work = setEquivalent * (session.estimatedCalories.map { min($0 / 250, 2) } ?? 1)
            let legLoad: [(MuscleSegment, Double)] = [
                (.quads, 1.0), (.hamstrings, 0.8), (.glutes, 0.9), (.calves, 0.7)
            ]
            for (segment, weight) in legLoad {
                actualSets[segment, default: 0] += work * weight
                volume[segment, default: 0] += work * weight * 40
            }
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
            let involvement = exercise.secondaryInvolvement(secondary)
            for segment in segments(forMuscleName: secondary) {
                setBuckets[segment, default: 0] += sets * involvement
                volumeBuckets[segment, default: 0] += volume * involvement
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
        defaultFillColor: Color.white.opacity(0.06),
        strokeColor: Color.white.opacity(0.20),
        strokeWidth: 0.6,
        selectionColor: PulseTheme.accent,
        selectionStrokeColor: .white,
        selectionStrokeWidth: 1.5,
        headColor: Color.white.opacity(0.08),
        hairColor: Color.white.opacity(0.05)
    )

    static let repsThumbnail = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.08),
        strokeColor: Color.white.opacity(0.20),
        strokeWidth: 0.6,
        selectionColor: PulseTheme.accent,
        selectionStrokeColor: PulseTheme.accent,
        selectionStrokeWidth: 1,
        headColor: Color.white.opacity(0.10),
        hairColor: Color.white.opacity(0.05)
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
        PulseTheme.accent,
        PulseTheme.ringStand,
        PulseTheme.accent
    ])
}
