import Charts
import SwiftUI

// MARK: - Style enum
enum ExerciseGaugeStyle: String, CaseIterable, Identifiable {
    case ring, pulse, segments
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ring:     localizedString("activity_ring")
        case .pulse:    localizedString("pulse_bar")
        case .segments: localizedString("time_cells")
        }
    }

    func systemImage() -> String {
        switch self {
        case .ring:     "circle.circle.fill"
        case .pulse:    "waveform"
        case .segments: "rectangle.split.3x1"
        }
    }
}

// MARK: - Main view
struct ExerciseView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedStyle: ExerciseGaugeStyle = .ring

    private let goalMinutes: Double = 30

    private var todayMinutes: Double { store.todayHealthMetric?.exerciseMinutes ?? 0 }
    private var fraction: Double { min(todayMinutes / goalMinutes, 1.0) }
    private var activeKcal: Double { store.todayHealthMetric?.activeEnergyKcal ?? 0 }
    private var todaySteps: Double { store.todayHealthMetric?.steps ?? 0 }

    private var weeklyMetrics: [DailyHealthMetric] {
        store.health.latestDailyMetrics.sorted { $0.date < $1.date }.suffix(7).map { $0 }
    }

    private var exerciseColor: Color { fraction >= 1.0 ? PulseTheme.ringStand : PulseTheme.accent }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                gaugeCard.padding(.top, 8)
                stylePicker
                weeklyTrendCard
                insightsCard
            }
            .padding(.top, DetailNavigationHeaderBar.contentTopPadding)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .overlay(alignment: .top) {
            HealthWidgetDetailNavBar(title: localizedString("exercise_2"))
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // metricsGrid removed — data moved to gauge card to avoid duplication

    // MARK: - Gauge Card
    private var gaugeCard: some View {
        PulseCard {
            VStack(spacing: 16) {
                Text(localizedString("exercise_state").uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(PulseTheme.secondaryText)

                Text(statusTitle)
                    .font(.title3.bold())
                    .foregroundStyle(exerciseColor)
                    .multilineTextAlignment(.center)

                gaugeView.frame(height: 220)

                // Non-duplicate secondary stats: kcal + steps (not shown in gauge)
                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(activeKcal))")
                                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.orange)
                            Text("kcal")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Text(localizedString("active_calories_label"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Rectangle().fill(PulseTheme.separator).frame(width: 1, height: 32)
                    VStack(spacing: 2) {
                        Text("\(Int(todaySteps))")
                            .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(exerciseColor)
                        Text(localizedString("steps_today"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var statusTitle: String {
        if fraction >= 1.0 { return localizedString("exercise_goal_reached") }
        if fraction >= 0.5 { return localizedString("exercise_on_track") }
        return localizedString("exercise_low_title")
    }

    @ViewBuilder
    private var gaugeView: some View {
        switch selectedStyle {
        case .ring:     ActivityRingGauge(fraction: fraction, color: exerciseColor, minutes: Int(todayMinutes), goal: Int(goalMinutes))
        case .pulse:    ExercisePulseGauge(fraction: fraction, color: exerciseColor, minutes: Int(todayMinutes))
        case .segments: ExerciseSegmentGauge(fraction: fraction, color: exerciseColor, goalMinutes: Int(goalMinutes))
        }
    }

    // MARK: - Style Picker
    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("display_styles"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
            HStack(spacing: 10) {
                ForEach(ExerciseGaugeStyle.allCases) { style in
                    let sel = selectedStyle == style
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedStyle = style }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: style.systemImage())
                                .font(.title3)
                                .foregroundStyle(sel ? PulseTheme.onColor(exerciseColor) : exerciseColor)
                            Text(style.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(sel ? PulseTheme.onColor(exerciseColor) : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(sel ? exerciseColor : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(sel ? exerciseColor : PulseTheme.separator, lineWidth: 1.5))
                        .shadow(color: sel ? exerciseColor.opacity(0.2) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Weekly Trend
    private var weeklyTrendCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("weekly_exercise_trend")).font(.headline)
                if weeklyMetrics.isEmpty {
                    Text(localizedString("no_health_data"))
                        .font(.subheadline).foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    let dayFmt: DateFormatter = {
                        let f = DateFormatter(); f.dateFormat = "EEE"; return f
                    }()
                    Chart {
                        ForEach(weeklyMetrics) { m in
                            BarMark(
                                x: .value("day", dayFmt.string(from: m.date)),
                                y: .value("min", m.exerciseMinutes ?? 0)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [exerciseColor, exerciseColor.opacity(0.6)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(5)
                        }
                        RuleMark(y: .value("goal", goalMinutes))
                            .foregroundStyle(exerciseColor.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            .annotation(position: .leading) {
                                Text(localizedString("goal_label"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(exerciseColor.opacity(0.8))
                            }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { v in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.separator)
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(String(format: "%.0f", d))
                                        .font(.system(size: 9))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .frame(height: 110)
                }
            }
        }
    }

    // MARK: - Insights
    private var insightsCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("insights_and_flags"), systemImage: "lightbulb.fill").font(.headline)
                if fraction >= 1.0 {
                    HealthInsightRow(icon: "checkmark.circle.fill", color: PulseTheme.ringStand,
                               title: localizedString("exercise_goal_reached"),
                               message: localizedString("exercise_great_body"))
                } else if fraction >= 0.5 {
                    HealthInsightRow(icon: "figure.run", color: exerciseColor,
                               title: localizedString("exercise_on_track"),
                               message: localizedString("exercise_on_track_body"))
                } else {
                    HealthInsightRow(icon: "figure.walk", color: PulseTheme.warning,
                               title: localizedString("exercise_low_title"),
                               message: localizedString("exercise_low_body"))
                }
                if activeKcal > 0 {
                    HealthInsightRow(icon: "flame.fill", color: .orange,
                               title: localizedString("active_calories_label"),
                               message: String(format: localizedString("active_calories_body_fmt"), Int(activeKcal)))
                }
            }
        }
    }
}

// MARK: - GAUGE 1: Activity Ring
struct ActivityRingGauge: View {
    let fraction: Double
    let color: Color
    let minutes: Int
    let goal: Int

    var body: some View {
        let ringSize: CGFloat = 190
        let strokeW: CGFloat = 16

        ZStack {
            Circle()
                .stroke(color.opacity(0.12), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.4), color, color],
                        center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .shadow(color: color.opacity(0.5), radius: 10)

            VStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(minutes)")
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    Text("min")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                Text(String(format: "%@ %d min", localizedString("goal_label"), goal))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - GAUGE 2: Pulse Progress Bar
struct ExercisePulseGauge: View {
    let fraction: Double
    let color: Color
    let minutes: Int

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince1970
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(minutes)")
                        .font(.system(size: 72, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                    Text("min")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .offset(y: -8)
                }

                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(color.opacity(0.12))
                                .frame(height: 18)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [color.opacity(0.7), color],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: max(18, geo.size.width * CGFloat(fraction)), height: 18)
                                .shadow(color: color.opacity(0.5), radius: 6)
                                .overlay(alignment: .trailing) {
                                    if fraction > 0.05 {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 14, height: 14)
                                            .shadow(color: color.opacity(0.6), radius: 4)
                                            .scaleEffect(1.0 + 0.06 * sin(time * 4))
                                    }
                                }
                        }
                    }
                    .frame(height: 18)

                    // Waveform below bar
                    Canvas { ctx, size in
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: size.height / 2))
                            for x in stride(from: 0, through: size.width, by: 2) {
                                let progress = x / size.width
                                let amplitude: CGFloat = progress < fraction ? 8 : 2
                                let y = size.height / 2 + amplitude * sin(progress * .pi * 10 + time * 5)
                                p.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        ctx.stroke(path, with: .color(color.opacity(0.5)), lineWidth: 1.5)
                    }
                    .frame(height: 28)
                }
                .padding(.horizontal, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - GAUGE 3: Time Segment Cells
struct ExerciseSegmentGauge: View {
    let fraction: Double
    let color: Color
    let goalMinutes: Int

    private var segments: Int { max(goalMinutes / 5, 6) }

    var body: some View {
        GeometryReader { geo in
            let activeCount = Int(Double(segments) * fraction)
            let pulsing = activeCount < segments && Int(fraction * Double(segments) * 10) % 10 > 0
            let labelW: CGFloat = 26
            let horizontalSpacing: CGFloat = 8
            let rowSpacing: CGFloat = 8
            let totalSpacing = rowSpacing * CGFloat(max(segments - 1, 0))
            let rowHeight = max(16, (geo.size.height - totalSpacing) / CGFloat(segments))
            let barHeight = max(14, rowHeight * 0.72)
            let cornerRadius = min(7, barHeight / 2)
            let barW = max(0, geo.size.width - labelW - horizontalSpacing)

            VStack(spacing: rowSpacing) {
                ForEach((0..<segments).reversed(), id: \.self) { i in
                    let isActive = i < activeCount
                    let isPulsing = pulsing && i == activeCount

                    HStack(spacing: horizontalSpacing) {
                        Text(i % 2 == 0 ? "\((i + 1) * 5)m" : "")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.secondaryText.opacity(0.6))
                            .frame(width: labelW, alignment: .trailing)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(isActive ? color : (isPulsing ? color.opacity(0.55) : color.opacity(0.1)))
                            .frame(width: barW, height: barHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(isActive ? .white.opacity(0.18) : .clear, lineWidth: 1)
                            )
                            .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: 4, y: 1)
                            .scaleEffect(x: isPulsing ? 1.02 : 1.0, anchor: .leading)
                            .animation(
                                isPulsing ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default,
                                value: isPulsing
                            )
                    }
                    .frame(height: rowHeight)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }
}

#Preview {
    let store = AppStore()
    return NavigationStack {
        ExerciseView()
            .environment(store)
    }
}
