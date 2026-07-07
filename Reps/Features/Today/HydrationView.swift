import Charts
import SwiftUI

// MARK: - Style enum
enum HydrationStyle: String, CaseIterable, Identifiable {
    case bottle, ring, cells
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottle: localizedString("water_bottle")
        case .ring:   localizedString("drop_arc")
        case .cells:  localizedString("water_cells")
        }
    }

    func systemImage() -> String {
        switch self {
        case .bottle: "waterbottle.fill"
        case .ring:   "drop.circle.fill"
        case .cells:  "rectangle.split.3x1.fill"
        }
    }
}

// MARK: - Main view
struct HydrationView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedStyle: HydrationStyle = .bottle
    @State private var amountMl: Double = 250
    @State private var logFeedback = false

    private var goalLiters: Double {
        max(store.userProfile.dailyWaterGoalLiters, 0.1)
    }

    private var todayLiters: Double { store.todayHealthMetric?.waterLiters ?? 0 }
    private var fraction: Double { min(todayLiters / goalLiters, 1.0) }

    private var weeklyMetrics: [DailyHealthMetric] {
        store.health.latestDailyMetrics.sorted { $0.date < $1.date }.suffix(7).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                gaugeCard.padding(.top, 8)
                stylePicker
                addWaterCard
                weeklyTrendCard
                insightsCard
            }
            .padding(.top, DetailNavigationHeaderBar.contentTopPadding)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .overlay(alignment: .top) {
            HealthWidgetDetailNavBar(title: localizedString("hydration"))
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: logFeedback)
    }

    // MARK: - Gauge Card
    private var gaugeCard: some View {
        PulseCard {
            VStack(spacing: 16) {
                Text(localizedString("hydration_state").uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(PulseTheme.secondaryText)

                Text(statusTitle)
                    .font(.title3.bold())
                    .foregroundStyle(PulseTheme.ringStand)
                    .multilineTextAlignment(.center)

                gaugeView
                    .frame(height: 220)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Single non-duplicate summary row
                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f L", todayLiters))
                            .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PulseTheme.ringStand)
                        Text(localizedString("hydration_today"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Rectangle().fill(PulseTheme.separator).frame(width: 1, height: 32)
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f L", goalLiters - todayLiters > 0 ? goalLiters - todayLiters : 0))
                            .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                        Text(localizedString("hydration_remaining"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Rectangle().fill(PulseTheme.separator).frame(width: 1, height: 32)
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f L", goalLiters))
                            .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                        Text(localizedString("goal_label"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var statusTitle: String {
        if fraction >= 1.0 { return localizedString("hydration_goal_reached") }
        if fraction >= 0.5 { return localizedString("hydration_on_track") }
        return localizedString("hydration_low_title")
    }

    @ViewBuilder
    private var gaugeView: some View {
        switch selectedStyle {
        case .bottle: WaterBottleGauge(fraction: fraction, color: PulseTheme.ringStand)
        case .ring:   WaterDropRing(fraction: fraction, color: PulseTheme.ringStand, todayLiters: todayLiters, goalLiters: goalLiters)
        case .cells:  WaterFlowGrid(fraction: fraction, color: PulseTheme.ringStand)
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
                ForEach(HydrationStyle.allCases) { style in
                    let sel = selectedStyle == style
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedStyle = style }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: style.systemImage())
                                .font(.title3)
                                .foregroundStyle(sel ? PulseTheme.onColor(PulseTheme.ringStand) : PulseTheme.ringStand)
                            Text(style.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(sel ? PulseTheme.onColor(PulseTheme.ringStand) : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(sel ? PulseTheme.ringStand : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(sel ? PulseTheme.ringStand : PulseTheme.separator, lineWidth: 1.5))
                        .shadow(color: sel ? PulseTheme.ringStand.opacity(0.2) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Add Water
    private var addWaterCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "drop.fill").font(.headline).foregroundStyle(PulseTheme.ringStand)
                    Text(localizedString("add_water_action")).font(.headline)
                }

                // Amount picker + slider
                HStack(alignment: .center, spacing: 20) {
                    // Mini bottle progress
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PulseTheme.separator.opacity(0.4))
                            .frame(width: 32, height: 80)

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PulseTheme.ringStand)
                            .frame(width: 32, height: 80 * min(CGFloat(amountMl / 1000), 1.0))
                            .animation(.spring(response: 0.3), value: amountMl)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PulseTheme.ringStand.opacity(0.5), lineWidth: 1.5)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(amountMl))")
                                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(PulseTheme.ringStand)
                            Text("ml")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .offset(y: -4)
                        }

                        Slider(value: $amountMl, in: 50...1000, step: 25)
                            .tint(PulseTheme.ringStand)

                        HStack {
                            Text("50 ml").font(.caption2).foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            Text("1.000 ml").font(.caption2).foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }

                // Quick add chips
                Text(localizedString("quick_add"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(PulseTheme.secondaryText)

                HStack(spacing: 8) {
                    ForEach([250, 500, 750, 1000], id: \.self) { ml in
                        Button {
                            withAnimation(.spring(response: 0.25)) { amountMl = Double(ml) }
                        } label: {
                            Text("\(ml)")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(amountMl == Double(ml) ? PulseTheme.ringStand : PulseTheme.grouped)
                                .foregroundStyle(amountMl == Double(ml) ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.2), value: amountMl)
                    }
                }

                Button { logWater() } label: {
                    Text(String(format: localizedString("log_amount_ml"), Int(amountMl)))
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PulseTheme.ringStand)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.ringStand))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Weekly Trend
    private var weeklyTrendCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("weekly_trend")).font(.headline)
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
                                y: .value("L", m.waterLiters)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [PulseTheme.ringStand, PulseTheme.ringStand.opacity(0.55)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(5)
                        }
                        RuleMark(y: .value("goal", goalLiters))
                            .foregroundStyle(PulseTheme.ringStand.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            .annotation(position: .leading) {
                                Text(localizedString("goal_label"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(PulseTheme.ringStand.opacity(0.8))
                            }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { v in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.separator)
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(String(format: "%.1f L", d))
                                        .font(.system(size: 9))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .frame(height: 120)
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
                               title: localizedString("hydration_goal_reached"),
                               message: localizedString("hydration_great_job"))
                } else if fraction >= 0.5 {
                    HealthInsightRow(icon: "timer", color: PulseTheme.warning,
                               title: localizedString("hydration_halfway"),
                               message: String(format: localizedString("hydration_need_more_fmt"), goalLiters - todayLiters))
                } else {
                    HealthInsightRow(icon: "exclamationmark.triangle.fill", color: PulseTheme.destructive,
                               title: localizedString("hydration_low_title"),
                               message: localizedString("hydration_drink_more"))
                }
                HealthInsightRow(icon: "target", color: PulseTheme.accent,
                           title: localizedString("hydration_goal_based"),
                           message: localizedFormat("hydration_goal_target_fmt", Int(goalLiters * 1000)))
            }
        }
    }

    // MARK: - Action
    private func logWater() {
        store.logWater(liters: amountMl / 1000.0)
        logFeedback.toggle()
    }
}

// MARK: - GAUGE 1: Water Bottle
struct WaterBottleGauge: View {
    let fraction: Double
    let color: Color
    @State private var isAnimationActive = false

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isAnimationActive)) { timeline in
            let time = timeline.date.timeIntervalSince1970
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let bottleW: CGFloat = min(w * 0.55, 110)
                let bottleH: CGFloat = h * 0.92

                ZStack(alignment: .center) {
                    // Bottle outline fill (dark background)
                    WaterBottleShape()
                        .fill(.black.opacity(0.35))
                        .frame(width: bottleW, height: bottleH)
                        .position(x: w / 2, y: h / 2)

                    // Water fill clipped to bottle shape
                    waterFill(time: time, bottleW: bottleW, bottleH: bottleH)
                        .position(x: w / 2, y: h / 2)

                    // Bottle border
                    WaterBottleShape()
                        .stroke(PulseTheme.separator, lineWidth: 4)
                        .frame(width: bottleW, height: bottleH)
                        .shadow(color: color.opacity(0.18), radius: 10)
                        .position(x: w / 2, y: h / 2)

                    // Glass shine
                    WaterBottleShape()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.14), .clear, .white.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: bottleW, height: bottleH)
                        .position(x: w / 2, y: h / 2)

                    // Percentage label centered in bottle body
                    VStack(spacing: -2) {
                        Text(String(format: "%.0f", fraction * 100))
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 6)
                        Text("%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .offset(y: bottleH * 0.12)
                }
            }
        }
        .onAppear {
            isAnimationActive = true
        }
        .onDisappear {
            isAnimationActive = false
        }
    }

    private func waterFill(time: TimeInterval, bottleW: CGFloat, bottleH: CGFloat) -> some View {
        let fillH = bottleH * CGFloat(fraction)
        return ZStack(alignment: .bottom) {
            LiquidWaveShape(phase: time * 2.8, level: CGFloat(fraction))
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.65), color.opacity(0.88)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: bottleW, height: max(12, fillH + 8))
                .shadow(color: color.opacity(0.38), radius: 10)

            // Small bubbles
            GeometryReader { geo in
                ForEach(0..<4) { i in
                    let xOff = sin(time + Double(i) * 2.0) * 14
                    let yCycle = CGFloat((Int(time * 22.0) + i * 45) % 140)
                    if yCycle < fillH {
                        Circle()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: CGFloat(3 + (i % 2)))
                            .position(x: geo.size.width / 2 + CGFloat(xOff),
                                      y: geo.size.height - yCycle)
                    }
                }
            }
        }
        .frame(width: bottleW, height: bottleH)
        .clipShape(WaterBottleShape())
    }
}

// MARK: - Bottle shape (body + narrow neck + cap)
struct WaterBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let capH = h * 0.06
        let neckH = h * 0.16
        let shoulderH = h * 0.10
        let bodyTop = capH + neckH + shoulderH

        let capInset = w * 0.20
        let neckInset = w * 0.25
        let r: CGFloat = 14

        var path = Path()

        // Cap top-left → top-right → right side down
        path.move(to: CGPoint(x: capInset + 4, y: 0))
        path.addLine(to: CGPoint(x: w - capInset - 4, y: 0))
        path.addQuadCurve(to: CGPoint(x: w - capInset, y: 4), control: CGPoint(x: w - capInset, y: 0))
        path.addLine(to: CGPoint(x: w - capInset, y: capH))

        // Neck right side
        path.addLine(to: CGPoint(x: w - neckInset, y: capH))
        path.addLine(to: CGPoint(x: w - neckInset, y: capH + neckH))

        // Shoulder curve right → body right
        path.addQuadCurve(to: CGPoint(x: w, y: bodyTop),
                          control: CGPoint(x: w - neckInset, y: capH + neckH + shoulderH * 0.6))

        // Body right side → bottom-right corner
        path.addLine(to: CGPoint(x: w, y: h - r))
        path.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h))

        // Bottom → bottom-left corner
        path.addLine(to: CGPoint(x: r, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))

        // Body left side → shoulder
        path.addLine(to: CGPoint(x: 0, y: bodyTop))

        // Shoulder curve left → neck left
        path.addQuadCurve(to: CGPoint(x: neckInset, y: capH + neckH),
                          control: CGPoint(x: neckInset, y: capH + neckH + shoulderH * 0.6))

        // Neck left → cap left
        path.addLine(to: CGPoint(x: neckInset, y: capH))
        path.addLine(to: CGPoint(x: capInset, y: capH))

        // Cap left side → top-left corner
        path.addLine(to: CGPoint(x: capInset, y: 4))
        path.addQuadCurve(to: CGPoint(x: capInset + 4, y: 0), control: CGPoint(x: capInset, y: 0))

        path.closeSubpath()
        return path
    }
}

// MARK: - GAUGE 2: Water Drop Ring
struct WaterDropRing: View {
    let fraction: Double
    let color: Color
    let todayLiters: Double
    let goalLiters: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(PulseTheme.separator, lineWidth: 2)
                .frame(width: 188, height: 188)

            Circle()
                .stroke(PulseTheme.separator.opacity(0.4),
                        style: StrokeStyle(lineWidth: 12, lineCap: .butt, dash: [2, 5]))
                .frame(width: 170, height: 170)

            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.3), color, color],
                        center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 170, height: 170)
                .shadow(color: color.opacity(0.5), radius: 10)

            Circle()
                .stroke(Color.black.opacity(0.2), style: StrokeStyle(lineWidth: 13, lineCap: .butt, dash: [1.5, 4]))
                .frame(width: 170, height: 170)

            VStack(spacing: 3) {
                Text(localizedString("level").uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(PulseTheme.secondaryText)

                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", todayLiters))
                        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    Text("L")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                Text(String(format: "/ %.1f L", goalLiters))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - GAUGE 3: Water Flow Grid (horizontal cups)
struct WaterFlowGrid: View {
    let fraction: Double
    let color: Color

    private let totalCells = 10

    var body: some View {
        VStack(spacing: 10) {
            // Header label
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(color)
                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
            }

            HStack(spacing: 5) {
                let active = Int(Double(totalCells) * fraction)
                let pulsing = active < totalCells && Int(fraction * Double(totalCells) * 10) % 10 > 0

                ForEach(0..<totalCells, id: \.self) { i in
                    let isActive = i < active
                    let isPulsing = pulsing && i == active

                    VStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(isActive ? color : color.opacity(0.15))

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isActive ? color : (isPulsing ? color.opacity(0.6) : color.opacity(0.1)))
                            .frame(width: 22, height: 65)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isActive ? .white.opacity(0.2) : .clear, lineWidth: 1)
                            )
                            .shadow(color: isActive ? color.opacity(0.45) : .clear, radius: 5, y: 1)
                            .scaleEffect(isPulsing ? 1.04 : 1.0)
                            .animation(isPulsing ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isPulsing)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(PulseTheme.separator, lineWidth: 3))
            )
        }
    }
}

#Preview {
    let store = AppStore()
    return NavigationStack {
        HydrationView()
            .environment(store)
    }
}
