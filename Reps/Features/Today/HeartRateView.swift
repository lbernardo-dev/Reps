import SwiftUI

/// Dedicated Heart Rate detail — separate from HRV since it answers a
/// different question ("is my heart working harder than usual?" vs "how well
/// am I adapting/recovering?"). Built entirely from data already synced:
/// daily resting HR (`DailyHealthMetric`) and per-session workout HR
/// (`WorkoutSession.averageHeartRate` / `.heartRateBefore` / `.heartRateAfter`).
struct HeartRateView: View {
    @Environment(AppStore.self) private var store

    private var domain: MetricDomain { .heartRate }

    private var sortedMetrics: [DailyHealthMetric] {
        store.health.latestDailyMetrics.sorted { $0.date > $1.date }
    }

    private var latestResting: Double? {
        sortedMetrics.first(where: { $0.restingHeartRate != nil })?.restingHeartRate
    }

    private var avgResting7: Double? {
        let vals = sortedMetrics.prefix(7).compactMap(\.restingHeartRate)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var historyMetrics: [DailyHealthMetric] {
        store.health.latestDailyMetrics
            .sorted { $0.date < $1.date }
            .suffix(30)
            .filter { $0.restingHeartRate != nil }
    }

    private var recentWorkoutsWithHR: [WorkoutSession] {
        Array(store.workoutSessions
            .filter { $0.averageHeartRate != nil }
            .sorted { $0.date > $1.date }
            .prefix(10))
    }

    private var recoveryDrops: [Double] {
        store.workoutSessions.compactMap { session -> Double? in
            guard let before = session.heartRateBefore, let after = session.heartRateAfter, before > after else { return nil }
            return before - after
        }
    }

    private var avgRecoveryDrop: Double? {
        guard !recoveryDrops.isEmpty else { return nil }
        return recoveryDrops.reduce(0, +) / Double(recoveryDrops.count)
    }

    private var verdict: DomainVerdict? {
        guard let latest = latestResting, let avg = avgResting7 else { return nil }
        let delta = latest - avg
        if delta <= 2 { return .excellent }
        if delta <= 5 { return .good }
        if delta <= 8 { return .fair }
        return .worthALook
    }

    private var verdictMessage: String? {
        guard let latest = latestResting, let avg = avgResting7 else { return nil }
        return latest - avg <= 5
            ? localizedString("hr_insight_resting_normal_body")
            : localizedString("hr_insight_resting_elevated_body")
    }

    var body: some View {
        ZStack {
            PulseTheme.background.ignoresSafeArea()
            DomainTintedBackground(domain: domain, height: 420)

            ScrollView {
                VStack(spacing: 20) {
                    HealthWidgetDetailNavBar(title: localizedString("heart_rate_title"), domain: domain)

                    if let verdict, let verdictMessage {
                        DomainVerdictHeader(verdict: verdict, message: verdictMessage)
                            .padding(.top, 4)
                    }

                    headerStats.padding(.top, 4)
                    trendCard

                    if !recentWorkoutsWithHR.isEmpty {
                        workoutsCard
                    }
                    if let avgRecoveryDrop {
                        recoveryCard(drop: avgRecoveryDrop)
                    }

                    insightsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header stats
    private var headerStats: some View {
        HealthStatsHeader(items: [
            HealthStatItem(value: latestResting.map { "\(Int($0))" } ?? "--", label: localizedString("resting_heart_rate")),
            HealthStatItem(value: avgResting7.map { "\(Int($0))" } ?? "--", label: localizedString("seven_day_avg")),
            HealthStatItem(value: "\(recentWorkoutsWithHR.count)", label: localizedString("workout"))
        ], domain: domain)
    }

    // MARK: - Resting HR trend
    private var trendCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("thirty_day_trend")).font(.headline)

                if historyMetrics.isEmpty {
                    Text(localizedString("hr_no_data"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    let dayFmt: DateFormatter = {
                        let f = DateFormatter(); f.dateFormat = "d"; return f
                    }()
                    DomainLineTrendChart(
                        domain: domain,
                        points: historyMetrics.compactMap { m in
                            m.restingHeartRate.map { DomainTrendPoint(label: dayFmt.string(from: m.date), date: m.date, value: $0) }
                        },
                        valueFormat: { String(format: "%.0f", $0) },
                        height: 120
                    )
                }
            }
        }
    }

    // MARK: - Recent workout HR
    private var workoutsCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localizedString("workout_heart_rate")).font(.headline)
                    Spacer()
                    DomainStatusPill(text: "\(recentWorkoutsWithHR.count)", domain: domain, prominence: .secondary, systemImage: "figure.strengthtraining.traditional")
                }

                let calendar = Calendar.current
                DomainBarTrendChart(
                    domain: domain,
                    points: recentWorkoutsWithHR.reversed().map {
                        DomainTrendPoint(label: calendar.shortWeekdaySymbol(for: $0.date), date: $0.date, value: $0.averageHeartRate ?? 0)
                    },
                    valueFormat: { String(format: "%.0f", $0) },
                    height: 120
                )

                VStack(spacing: 8) {
                    ForEach(recentWorkoutsWithHR.prefix(5)) { session in
                        workoutRow(session)
                    }
                }
            }
        }
    }

    private func workoutRow(_ session: WorkoutSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            if let avg = session.averageHeartRate {
                Text("\(Int(avg))")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(domain.tint)
                Text(localizedString("average"))
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            if let max = session.maxHeartRate {
                Text("\(Int(max))")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .padding(.leading, 6)
                Text(localizedString("max"))
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Recovery
    private func recoveryCard(drop: Double) -> some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 10) {
                Label(localizedString("post_workout_recovery"), systemImage: "heart.text.square.fill")
                    .font(.headline)
                Text(String(format: localizedString("recovery_drop_format"), Int(drop)))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Insights
    private var insightsCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("insights_and_flags"), systemImage: "lightbulb.fill").font(.headline)

                if let latest = latestResting, let avg = avgResting7 {
                    if latest - avg <= 5 {
                        HealthInsightRow(icon: "checkmark.seal.fill", color: PulseTheme.recovery,
                                         title: localizedString("hr_insight_resting_normal_title"),
                                         message: localizedString("hr_insight_resting_normal_body"))
                    } else {
                        HealthInsightRow(icon: "arrow.up.heart.fill", color: PulseTheme.warning,
                                         title: localizedString("hr_insight_resting_elevated_title"),
                                         message: localizedString("hr_insight_resting_elevated_body"))
                    }
                }

                if let avgRecoveryDrop {
                    HealthInsightRow(icon: "arrow.down.heart.fill", color: domain.tint,
                                     title: localizedString("hr_insight_recovery_title"),
                                     message: String(format: localizedString("recovery_drop_format"), Int(avgRecoveryDrop)))
                }

                if latestResting == nil {
                    Text(localizedString("hr_no_data"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }
}

private extension Calendar {
    func shortWeekdaySymbol(for date: Date) -> String {
        let idx = component(.weekday, from: date) - 1
        return shortWeekdaySymbols[idx]
    }
}

#Preview {
    NavigationStack {
        HeartRateView()
            .environment(AppStore())
    }
}
