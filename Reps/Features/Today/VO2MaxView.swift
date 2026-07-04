import SwiftUI

// MARK: - VO₂ Max zone

enum VO2MaxZone: String {
    case excellent, good, fair, low

    init(mlKgMin: Double, ageMale: Bool = true) {
        switch mlKgMin {
        case 50...: self = .excellent
        case 38..<50: self = .good
        case 28..<38: self = .fair
        default: self = .low
        }
    }

    var label: String {
        switch self {
        case .excellent: localizedString("vo2_zone_excellent")
        case .good:      localizedString("vo2_zone_good")
        case .fair:      localizedString("vo2_zone_fair")
        case .low:       localizedString("vo2_zone_low")
        }
    }

    var color: Color {
        switch self {
        case .excellent: PulseTheme.ringStand
        case .good:      PulseTheme.recovery
        case .fair:      PulseTheme.warning
        case .low:       PulseTheme.destructive
        }
    }
}

// MARK: - Main view

struct VO2MaxView: View {
    @Environment(AppStore.self) private var store

    private var latestVO2: Double? {
        store.health.latestDailyMetrics
            .sorted { $0.date > $1.date }
            .first(where: { $0.vo2MaxMlKgMin != nil })?.vo2MaxMlKgMin
    }

    private var zone: VO2MaxZone { latestVO2.map { VO2MaxZone(mlKgMin: $0) } ?? .low }

    private var historyMetrics: [DailyHealthMetric] {
        store.health.latestDailyMetrics
            .sorted { $0.date < $1.date }
            .suffix(30)
            .filter { $0.vo2MaxMlKgMin != nil }
    }

    private var trend7day: String {
        let vals = store.health.latestDailyMetrics
            .sorted { $0.date > $1.date }
            .prefix(14)
            .compactMap(\.vo2MaxMlKgMin)
        guard vals.count >= 2 else { return "--" }
        let recent = vals.prefix(7).reduce(0, +) / Double(min(vals.count, 7))
        let older  = vals.dropFirst(7).reduce(0, +) / Double(max(vals.dropFirst(7).count, 1))
        let delta  = recent - older
        if abs(delta) < 0.5 { return "→" }
        return delta > 0 ? "↑ \(String(format: "%.1f", delta))" : "↓ \(String(format: "%.1f", abs(delta)))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HealthWidgetDetailNavBar(title: "VO₂ Max", domain: .cardio)

                gaugeCard.padding(.top, 4)
                trendCard
                zonesCard
                insightsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background {
            ZStack {
                PulseTheme.background.ignoresSafeArea()
                DomainTintedBackground(domain: .cardio)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Gauge card
    private var gaugeCard: some View {
        GlassMetricCard(domain: .cardio) {
            VStack(spacing: 14) {
                Text(localizedString("cardiorespiratory_fitness").uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(PulseTheme.secondaryText)

                Text(zone.label)
                    .font(.title3.bold())
                    .foregroundStyle(zone.color)

                ZStack {
                    Circle()
                        .stroke(PulseTheme.separator, lineWidth: 2)
                        .frame(width: 188, height: 188)

                    let maxVO2: Double = 70
                    Circle()
                        .trim(from: 0, to: CGFloat(min((latestVO2 ?? 0) / maxVO2, 1.0)))
                        .stroke(
                            AngularGradient(
                                colors: [MetricDomain.cardio.tint.opacity(0.3), MetricDomain.cardio.tint, zone.color],
                                center: .center,
                                startAngle: .degrees(-90), endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 170, height: 170)
                        .shadow(color: zone.color.opacity(0.55), radius: 10)
                        .animation(.spring(response: 0.5), value: latestVO2)

                    VStack(spacing: 3) {
                        Text("VO₂ MAX")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(PulseTheme.secondaryText)

                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(latestVO2.map { String(format: "%.1f", $0) } ?? "--")
                                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                            Text("ml/kg/min")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
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
                .frame(height: 190)

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text(localizedString("weekly_trend"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    Text(trend7day)
                            .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(MetricDomain.cardio.tint)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 30-Day Trend
    private var trendCard: some View {
        GlassMetricCard(domain: .cardio) {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("thirty_day_trend")).font(.headline)

                if historyMetrics.isEmpty {
                    Text(localizedString("no_health_data"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    let fmt: DateFormatter = {
                        let f = DateFormatter(); f.dateFormat = "d"; return f
                    }()
                    DomainLineTrendChart(
                        domain: .cardio,
                        points: historyMetrics.compactMap { m in
                            m.vo2MaxMlKgMin.map { DomainTrendPoint(label: fmt.string(from: m.date), date: m.date, value: $0) }
                        },
                        valueFormat: { String(format: "%.0f", $0) },
                        height: 120
                    )
                }
            }
        }
    }

    // MARK: - Reference zones
    private var zonesCard: some View {
        GlassMetricCard(domain: .cardio) {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("reference_zones")).font(.headline)

                let specs: [(label: String, range: String, zone: VO2MaxZone)] = [
                    (localizedString("vo2_zone_excellent"), "≥ 50 ml/kg/min", .excellent),
                    (localizedString("vo2_zone_good"),      "38–49 ml/kg/min", .good),
                    (localizedString("vo2_zone_fair"),      "28–37 ml/kg/min", .fair),
                    (localizedString("vo2_zone_low"),       "< 28 ml/kg/min", .low)
                ]

                ForEach(specs, id: \.label) { spec in
                    let isActive = spec.zone == zone
                    HStack {
                        Circle()
                            .fill(spec.zone.color)
                            .frame(width: 8, height: 8)
                        Text(spec.label)
                            .font(.subheadline.weight(isActive ? .bold : .regular))
                            .foregroundStyle(isActive ? spec.zone.color : .primary)
                        Spacer()
                        Text(spec.range)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Insights
    private var insightsCard: some View {
        GlassMetricCard(domain: .cardio) {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("insights_and_flags"), systemImage: "lightbulb.fill").font(.headline)

                switch zone {
                case .excellent:
                    HealthInsightRow(icon: "bolt.fill", color: zone.color,
                                     title: localizedString("vo2_insight_excellent_title"),
                                     message: localizedString("vo2_insight_excellent_body"))
                case .good:
                    HealthInsightRow(icon: "heart.fill", color: zone.color,
                                     title: localizedString("vo2_insight_good_title"),
                                     message: localizedString("vo2_insight_good_body"))
                case .fair:
                    HealthInsightRow(icon: "figure.run", color: zone.color,
                                     title: localizedString("vo2_insight_fair_title"),
                                     message: localizedString("vo2_insight_fair_body"))
                case .low:
                    HealthInsightRow(icon: "exclamationmark.triangle.fill", color: zone.color,
                                     title: localizedString("vo2_insight_low_title"),
                                     message: localizedString("vo2_insight_low_body"))
                }

                if latestVO2 == nil {
                    HealthInsightRow(icon: "applewatch", color: PulseTheme.secondaryText,
                                     title: localizedString("vo2_no_data_title"),
                                     message: localizedString("vo2_no_data_body"))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VO2MaxView()
            .environment(AppStore())
    }
}
