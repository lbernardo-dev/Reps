import Charts
import SwiftUI

// MARK: - HRV zone
enum HRVZone: String {
    case excellent, good, fair, low

    init(ms: Double) {
        switch ms {
        case 70...: self = .excellent
        case 50..<70: self = .good
        case 35..<50: self = .fair
        default: self = .low
        }
    }

    var label: String {
        switch self {
        case .excellent: localizedString("hrv_excellent")
        case .good:      localizedString("hrv_good")
        case .fair:      localizedString("hrv_fair")
        case .low:       localizedString("hrv_low")
        }
    }

    var color: Color {
        switch self {
        case .excellent: PulseTheme.primaryBright
        case .good:      PulseTheme.primary
        case .fair:      PulseTheme.warning
        case .low:       PulseTheme.destructive
        }
    }
}

// MARK: - Style enum
enum HRVGaugeStyle: String, CaseIterable, Identifiable {
    case signal, ring, spectrum
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .signal:   localizedString("signal_wave")
        case .ring:     localizedString("frequency_ring")
        case .spectrum: localizedString("zone_spectrum")
        }
    }

    func systemImage() -> String {
        switch self {
        case .signal:   "waveform.path.ecg"
        case .ring:     "circle.dotted"
        case .spectrum: "chart.bar.fill"
        }
    }
}

// MARK: - Main view
struct HRVView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedStyle: HRVGaugeStyle = .signal

    private var latestHRV: Double? {
        store.health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.heartRateVariabilityMS
    }
    private var latestResting: Double? {
        store.health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.restingHeartRate
    }
    private var zone: HRVZone { latestHRV.map { HRVZone(ms: $0) } ?? .low }

    // 7-day average
    private var avgHRV7: Double? {
        let vals = store.health.latestDailyMetrics
            .sorted { $0.date > $1.date }
            .prefix(7)
            .compactMap { $0.heartRateVariabilityMS }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    // 30 most recent daily metrics with HRV
    private var historyMetrics: [DailyHealthMetric] {
        store.health.latestDailyMetrics
            .sorted { $0.date < $1.date }
            .suffix(30)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                gaugeCard.padding(.top, 8)
                stylePicker
                trendCard
                insightsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle(localizedString("hrv_heart_rate"))
        .navigationBarTitleDisplayMode(.large)
        .background(PulseTheme.background.ignoresSafeArea())
    }

    // MARK: - Gauge Card
    private var gaugeCard: some View {
        PulseCard {
            VStack(spacing: 14) {
                Text(localizedString("hrv_state").uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(PulseTheme.secondaryText)

                Text(zone.label)
                    .font(.title3.bold())
                    .foregroundStyle(zone.color)

                gaugeView.frame(height: 220)

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(latestHRV.map { "\(Int($0)) ms" } ?? "--")
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(zone.color)
                        Text(localizedString("hrv_latest"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text(avgHRV7.map { "\(Int($0)) ms" } ?? "--")
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                        Text(localizedString("seven_day_avg"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Divider().frame(height: 30)
                    VStack(spacing: 2) {
                        Text(latestResting.map { "\(Int($0)) bpm" } ?? "--")
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                        Text(localizedString("resting_hr_short"))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var gaugeView: some View {
        let ms = latestHRV ?? 0
        switch selectedStyle {
        case .signal:   HRVSignalGauge(ms: ms, zone: zone)
        case .ring:     HRVFrequencyRing(ms: ms, zone: zone)
        case .spectrum: HRVZoneSpectrum(ms: ms, zone: zone, avgMs: avgHRV7 ?? 0)
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
                ForEach(HRVGaugeStyle.allCases) { style in
                    let sel = selectedStyle == style
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedStyle = style }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: style.systemImage())
                                .font(.title3)
                                .foregroundStyle(sel ? .white : zone.color)
                            Text(style.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(sel ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(sel ? zone.color : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(sel ? zone.color : PulseTheme.separator, lineWidth: 1.5))
                        .shadow(color: sel ? zone.color.opacity(0.2) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 30-Day Trend
    private var trendCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("thirty_day_trend")).font(.headline)
                if historyMetrics.compactMap({ $0.heartRateVariabilityMS }).isEmpty {
                    Text(localizedString("no_health_data"))
                        .font(.subheadline).foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    let dayFmt: DateFormatter = {
                        let f = DateFormatter(); f.dateFormat = "d"; return f
                    }()
                    Chart {
                        ForEach(historyMetrics) { m in
                            if let hrv = m.heartRateVariabilityMS {
                                let z = HRVZone(ms: hrv)
                                BarMark(
                                    x: .value("day", dayFmt.string(from: m.date)),
                                    y: .value("ms", hrv)
                                )
                                .foregroundStyle(z.color.gradient)
                                .cornerRadius(3)
                            }
                        }
                        if let avg = avgHRV7 {
                            RuleMark(y: .value("avg", avg))
                                .foregroundStyle(zone.color.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                                .annotation(position: .leading) {
                                    Text(localizedString("seven_day_avg"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(zone.color.opacity(0.8))
                                }
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
                    .frame(height: 120)

                    // Zone legend
                    HStack(spacing: 12) {
                        ForEach([HRVZone.excellent, .good, .fair, .low], id: \.rawValue) { z in
                            HStack(spacing: 4) {
                                Circle().fill(z.color).frame(width: 7, height: 7)
                                Text(z.label).font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Insights
    private var insightsCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("insights_and_flags"), systemImage: "lightbulb.fill").font(.headline)

                switch zone {
                case .excellent:
                    HealthInsightRow(icon: "bolt.fill", color: PulseTheme.primaryBright,
                               title: localizedString("hrv_insight_excellent_title"),
                               message: localizedString("hrv_insight_excellent_body"))
                case .good:
                    HealthInsightRow(icon: "heart.fill", color: PulseTheme.primary,
                               title: localizedString("hrv_insight_good_title"),
                               message: localizedString("hrv_insight_good_body"))
                case .fair:
                    HealthInsightRow(icon: "moon.fill", color: PulseTheme.warning,
                               title: localizedString("hrv_insight_fair_title"),
                               message: localizedString("hrv_insight_fair_body"))
                case .low:
                    HealthInsightRow(icon: "exclamationmark.triangle.fill", color: PulseTheme.destructive,
                               title: localizedString("hrv_insight_low_title"),
                               message: localizedString("hrv_insight_low_body"))
                }

                if let resting = latestResting, resting < 60 {
                    HealthInsightRow(icon: "arrow.down.heart.fill", color: PulseTheme.primaryBright,
                               title: localizedString("hrv_resting_hr_good"),
                               message: String(format: localizedString("hrv_resting_hr_good_body_fmt"), Int(resting)))
                }
            }
        }
    }
}

// MARK: - GAUGE 1: Signal Wave scale
struct HRVSignalGauge: View {
    let ms: Double
    let zone: HRVZone

    private let maxMs: Double = 100

    var body: some View {
        TimelineView(.animation) { tl in
            let time = tl.date.timeIntervalSince1970
            VStack(spacing: 20) {
                // ECG-style animated waveform
                Canvas { ctx, size in
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height / 2))
                        for x in stride(from: 0.0, through: size.width, by: 1.5) {
                            let t = x / size.width
                            let amplitude = size.height * 0.35 * CGFloat(min(ms / 80.0, 1.2))
                            let y: CGFloat
                            if t > 0.35 && t < 0.45 {
                                let spike = sin((t - 0.35) / 0.10 * .pi)
                                y = size.height / 2 - amplitude * CGFloat(spike)
                            } else {
                                y = size.height / 2 + amplitude * 0.15 * sin(t * .pi * 6 + time * 3)
                            }
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    ctx.stroke(path, with: .color(zone.color), lineWidth: 2)
                    ctx.stroke(path, with: .color(zone.color.opacity(0.25)), lineWidth: 6)
                }
                .frame(height: 80)

                // Horizontal zone bar with needle
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            LinearGradient(
                                colors: [HRVZone.low.color, HRVZone.fair.color, HRVZone.good.color, HRVZone.excellent.color],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(height: 12)
                            .clipShape(Capsule())

                            let needleX = geo.size.width * CGFloat(min(ms / maxMs, 1.0))
                            Circle()
                                .fill(.white)
                                .frame(width: 20, height: 20)
                                .shadow(color: zone.color.opacity(0.6), radius: 6)
                                .overlay(Circle().stroke(zone.color, lineWidth: 2.5))
                                .offset(x: needleX - 10, y: 0)
                                .animation(.spring(response: 0.5), value: ms)
                        }
                        .frame(height: 20)
                    }
                    .frame(height: 20)

                    HStack {
                        Text(localizedString("hrv_low")).font(.system(size: 9, weight: .bold)).foregroundStyle(HRVZone.low.color)
                        Spacer()
                        Text(localizedString("hrv_fair")).font(.system(size: 9, weight: .bold)).foregroundStyle(HRVZone.fair.color)
                        Spacer()
                        Text(localizedString("hrv_good")).font(.system(size: 9, weight: .bold)).foregroundStyle(HRVZone.good.color)
                        Spacer()
                        Text(localizedString("hrv_excellent")).font(.system(size: 9, weight: .bold)).foregroundStyle(HRVZone.excellent.color)
                    }

                    Text(ms > 0 ? "\(Int(ms)) ms" : "--")
                        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(zone.color)
                }
            }
        }
    }
}

// MARK: - GAUGE 2: Frequency Ring
struct HRVFrequencyRing: View {
    let ms: Double
    let zone: HRVZone

    private let maxMs: Double = 100

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
                .trim(from: 0, to: CGFloat(min(ms / maxMs, 1.0)))
                .stroke(
                    AngularGradient(
                        colors: [zone.color.opacity(0.3), zone.color, zone.color],
                        center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 170, height: 170)
                .shadow(color: zone.color.opacity(0.55), radius: 10)

            Circle()
                .stroke(Color.black.opacity(0.2),
                        style: StrokeStyle(lineWidth: 13, lineCap: .butt, dash: [1.5, 4]))
                .frame(width: 170, height: 170)

            VStack(spacing: 3) {
                Text(localizedString("heart_rate_variability").uppercased()
                    .split(separator: " ").prefix(2).joined(separator: " "))
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(ms > 0 ? "\(Int(ms))" : "--")
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    Text("ms")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                Text(zone.label)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(zone.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(zone.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - GAUGE 3: Zone Spectrum
struct HRVZoneSpectrum: View {
    let ms: Double
    let zone: HRVZone
    let avgMs: Double

    private struct ZoneSpec {
        let label: String
        let range: ClosedRange<Double>
        let color: Color
    }

    private let specs: [ZoneSpec] = [
        ZoneSpec(label: HRVZone.excellent.label, range: 70...120, color: HRVZone.excellent.color),
        ZoneSpec(label: HRVZone.good.label,      range: 50...70,  color: HRVZone.good.color),
        ZoneSpec(label: HRVZone.fair.label,       range: 35...50,  color: HRVZone.fair.color),
        ZoneSpec(label: HRVZone.low.label,        range: 0...35,   color: HRVZone.low.color),
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(specs, id: \.label) { spec in
                let maxRange = spec.range.upperBound - spec.range.lowerBound
                let clampedMs = max(min(ms, spec.range.upperBound), spec.range.lowerBound)
                let fill = max(0, (clampedMs - spec.range.lowerBound) / maxRange)
                let isActive = spec.range.contains(ms)

                HStack(spacing: 10) {
                    Text(spec.label)
                        .font(.system(size: 11, weight: isActive ? .black : .regular, design: .rounded))
                        .foregroundStyle(isActive ? spec.color : PulseTheme.secondaryText.opacity(0.6))
                        .frame(width: 62, alignment: .trailing)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(spec.color.opacity(0.12)).frame(height: 20)
                            Capsule()
                                .fill(spec.color)
                                .frame(width: isActive ? geo.size.width * CGFloat(fill) : (ms > spec.range.lowerBound ? geo.size.width : 0), height: 20)
                                .animation(.spring(response: 0.5), value: ms)
                        }
                        .clipShape(Capsule())
                        .shadow(color: isActive ? spec.color.opacity(0.4) : .clear, radius: 6)
                    }
                    .frame(height: 20)

                    Text(isActive ? "\(Int(ms)) ms" : "")
                        .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(spec.color)
                        .frame(width: 40, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    let store = AppStore()
    return NavigationStack {
        HRVView()
            .environment(store)
    }
}
