import SwiftUI

struct SleepView: View {
    @Environment(AppStore.self) private var store

    private var sleepGoalHours: Double { store.userProfile.sleepTargetHours }

    private var weekMetrics: [DailyHealthMetric] {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        return store.health.latestDailyMetrics
            .filter { $0.date >= weekStart }
            .sorted { $0.date < $1.date }
    }

    private var weeklyAvg: Double? {
        let vals = weekMetrics.compactMap(\.sleepHours).filter { $0 > 0 }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var goodNights: Int {
        weekMetrics.filter { ($0.sleepHours ?? 0) >= sleepGoalHours }.count
    }

    private var totalNightsWithData: Int {
        weekMetrics.filter { ($0.sleepHours ?? 0) > 0 }.count
    }

    private var lastNightMetric: DailyHealthMetric? {
        store.health.latestDailyMetrics
            .filter { ($0.sleepHours ?? 0) > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    private var lastNightHours: Double? { lastNightMetric?.sleepHours }

    private var lastNightHasStageData: Bool {
        guard let m = lastNightMetric else { return false }
        return (m.sleepRemHours ?? 0) > 0 || (m.sleepDeepHours ?? 0) > 0 || (m.sleepCoreHours ?? 0) > 0
    }

    /// Night-to-night variability in sleep duration across the week — a real,
    /// honest proxy for "consistency" since we don't capture exact bed/wake
    /// clock times, only nightly totals.
    private var nightlyConsistencyStdDev: Double? {
        let vals = weekMetrics.compactMap(\.sleepHours).filter { $0 > 0 }
        guard vals.count >= 2 else { return nil }
        let mean = vals.reduce(0, +) / Double(vals.count)
        let variance = vals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(vals.count)
        return sqrt(variance)
    }

    private var domain: MetricDomain { .sleep }

    private func verdict(forScore score: Int) -> DomainVerdict {
        if score >= 85 { return .excellent }
        if score >= 70 { return .good }
        if score >= 50 { return .fair }
        return .worthALook
    }

    private var verdict: DomainVerdict? {
        if let score = sleepScore { return verdict(forScore: score.total) }
        guard let avg = weeklyAvg else { return nil }
        if avg >= sleepGoalHours { return .excellent }
        if avg >= sleepGoalHours * 0.85 { return .fair }
        return .worthALook
    }

    private var verdictMessage: String? {
        guard let avg = weeklyAvg else { return nil }
        return avg >= sleepGoalHours
            ? String(format: localizedString("sleep_insight_great_duration_body"), String(format: "%.1f", avg), Int(sleepGoalHours))
            : String(format: localizedString("sleep_insight_below_goal_body"), String(format: "%.1f", avg), Int(sleepGoalHours))
    }

    // MARK: - Sleep score (duration + consistency + restorative, when available)

    struct SleepScoreFactor: Identifiable {
        let id: String
        let title: String
        let points: Int
        let maxPoints: Int
        let factorVerdict: DomainVerdict
    }

    /// Composite 0–100 score built only from data we actually measure. When a
    /// night has no stage breakdown (older watch, manual entry), Restorative
    /// is omitted entirely rather than shown as a fake zero — Duration and
    /// Consistency absorb its weight so the score stays meaningful.
    private var sleepScore: (total: Int, factors: [SleepScoreFactor])? {
        guard let hours = lastNightHours, hours > 0, sleepGoalHours > 0 else { return nil }

        let hasStages = lastNightHasStageData
        let durationMax = hasStages ? 40 : 55
        let consistencyMax = hasStages ? 30 : 45
        let restorativeMax = 30

        let durationRatio = min(hours / sleepGoalHours, 1.15) / 1.15
        let durationPoints = min(Int((durationRatio * Double(durationMax)).rounded()), durationMax)
        let durationVerdict: DomainVerdict = hours >= sleepGoalHours ? .excellent : hours >= sleepGoalHours * 0.85 ? .fair : .worthALook

        var factors = [
            SleepScoreFactor(id: "duration", title: localizedString("duration").capitalizingFirstLetter(), points: durationPoints, maxPoints: durationMax, factorVerdict: durationVerdict)
        ]

        let consistencyPoints: Int
        let consistencyVerdict: DomainVerdict
        if let stdDev = nightlyConsistencyStdDev {
            if stdDev <= 0.5 { consistencyPoints = consistencyMax; consistencyVerdict = .excellent }
            else if stdDev <= 1.0 { consistencyPoints = Int(Double(consistencyMax) * 0.75); consistencyVerdict = .good }
            else if stdDev <= 1.75 { consistencyPoints = Int(Double(consistencyMax) * 0.5); consistencyVerdict = .fair }
            else { consistencyPoints = Int(Double(consistencyMax) * 0.25); consistencyVerdict = .worthALook }
        } else {
            consistencyPoints = Int(Double(consistencyMax) * 0.6)
            consistencyVerdict = .fair
        }
        factors.append(SleepScoreFactor(id: "consistency", title: localizedString("consistency"), points: consistencyPoints, maxPoints: consistencyMax, factorVerdict: consistencyVerdict))

        if hasStages, let metric = lastNightMetric {
            let restorativeHours = (metric.sleepRemHours ?? 0) + (metric.sleepDeepHours ?? 0)
            let percent = restorativeHours / hours
            let restorativePoints: Int
            let restorativeVerdict: DomainVerdict
            if percent >= 0.33 { restorativePoints = restorativeMax; restorativeVerdict = .excellent }
            else if percent >= 0.22 { restorativePoints = Int(Double(restorativeMax) * 0.7); restorativeVerdict = .good }
            else if percent >= 0.12 { restorativePoints = Int(Double(restorativeMax) * 0.45); restorativeVerdict = .fair }
            else { restorativePoints = Int(Double(restorativeMax) * 0.2); restorativeVerdict = .worthALook }
            factors.append(SleepScoreFactor(id: "restorative", title: localizedString("restorative_sleep"), points: restorativePoints, maxPoints: restorativeMax, factorVerdict: restorativeVerdict))
        }

        let total = min(factors.reduce(0) { $0 + $1.points }, 100)
        return (total, factors)
    }

    var body: some View {
        ZStack {
            PulseTheme.background.ignoresSafeArea()
            DomainTintedBackground(domain: domain, height: 420)

            ScrollView {
                VStack(spacing: 20) {
                    HealthWidgetDetailNavBar(title: localizedString("sleep"), domain: domain)

                    if let verdict, let verdictMessage {
                        DomainVerdictHeader(verdict: verdict, message: verdictMessage)
                            .padding(.top, 4)
                    }

                    headerStats.padding(.top, 4)
                    scoreHeroCard
                    if lastNightHasStageData {
                        phasesCard
                    }
                    chartCard
                    insightsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header stats row
    private var headerStats: some View {
        HealthStatsHeader(items: [
            HealthStatItem(value: weeklyAvg.map { String(format: "%.1fh", $0) } ?? "--", label: localizedString("weekly_avg")),
            HealthStatItem(value: totalNightsWithData > 0 ? "\(goodNights)/\(totalNightsWithData)" : "--", label: localizedString("good_nights")),
            HealthStatItem(value: String(format: "%.0fh", sleepGoalHours), label: localizedString("goal"))
        ], domain: domain)
    }

    // MARK: - Weekly bar chart
    private var chartCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localizedString("this_week")).font(.headline)
                    Spacer()
                    DomainStatusPill(text: "WEEK", domain: domain, prominence: .secondary, systemImage: "calendar")
                }

                if weekMetrics.compactMap(\.sleepHours).isEmpty {
                    Text(localizedString("no_health_data"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    let calendar = Calendar.current
                    DomainBarTrendChart(
                        domain: domain,
                        points: weekMetrics.map {
                            DomainTrendPoint(label: calendar.shortWeekdaySymbol(for: $0.date), date: $0.date, value: $0.sleepHours ?? 0)
                        },
                        goal: sleepGoalHours,
                        barColor: { $0.value >= sleepGoalHours ? nil : PulseTheme.warning.opacity(0.74) },
                        valueFormat: { String(format: "%.0fh", $0) }
                    )

                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(domain.tint).frame(width: 12, height: 12)
                            Text(localizedString("good_sleep")).font(.system(size: 9, weight: .semibold)).foregroundStyle(PulseTheme.secondaryText)
                        }
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(PulseTheme.warning.opacity(0.7)).frame(width: 12, height: 12)
                            Text(localizedString("under_goal")).font(.system(size: 9, weight: .semibold)).foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Score hero: ring + factor breakdown
    private var scoreHeroCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(spacing: 16) {
                Label(localizedString("last_night_sleep").uppercased(), systemImage: "moon.fill")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(domain.tint)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let score = sleepScore, let hours = lastNightHours {
                    ZStack {
                        RepsActivityRings(
                            rings: [RepsActivityRings.Ring(id: 0, progress: Double(score.total) / 100, color: domain.tint)],
                            lineWidth: 14,
                            gap: 0
                        )
                        VStack(spacing: 2) {
                            Text("\(score.total)")
                                .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                                .contentTransition(.numericText())
                            Text(localizedString("sleep_score"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                    .frame(width: 150, height: 150)
                    .animation(.spring(response: 0.9, dampingFraction: 0.82), value: score.total)

                    Text(String(format: "%.1fh", hours))
                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(domain.tint)

                    VStack(spacing: 10) {
                        ForEach(score.factors) { factor in
                            sleepFactorRow(factor)
                        }
                    }
                } else {
                    Text(localizedString("no_sleep_data"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                }
            }
        }
    }

    private func sleepFactorRow(_ factor: SleepScoreFactor) -> some View {
        HStack(spacing: 10) {
            Text(factor.title.capitalizingFirstLetter())
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 90, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PulseTheme.grouped)
                    Capsule()
                        .fill(factor.factorVerdict.color)
                        .frame(width: geo.size.width * CGFloat(factor.points) / CGFloat(max(factor.maxPoints, 1)))
                        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: factor.points)
                }
            }
            .frame(height: 8)

            Text(localizedKey(factor.factorVerdict.label))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(factor.factorVerdict.color)
                .frame(width: 68, alignment: .trailing)
        }
    }

    // MARK: - Sleep stages
    private var phasesCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("sleep_stages")).font(.headline)

                if let m = lastNightMetric, let total = m.sleepHours, total > 0 {
                    sleepStageRow(title: localizedString("awake_time"), hours: m.sleepAwakeHours ?? 0, total: total, optimalRange: 0...5, color: PulseTheme.warning)
                    sleepStageRow(title: localizedString("rem_sleep"), hours: m.sleepRemHours ?? 0, total: total, optimalRange: 20...25, color: PulseTheme.ringStand)
                    sleepStageRow(title: localizedString("light_sleep"), hours: m.sleepCoreHours ?? 0, total: total, optimalRange: 45...55, color: domain.tint)
                    sleepStageRow(title: localizedString("deep_sleep"), hours: m.sleepDeepHours ?? 0, total: total, optimalRange: 13...23, color: domain.secondaryTint)

                    if let interruptions = m.sleepInterruptions {
                        HStack {
                            Text(localizedString("interruptions"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            Text("\(interruptions)")
                                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func sleepStageRow(title: String, hours: Double, total: Double, optimalRange: ClosedRange<Int>, color: Color) -> some View {
        let percent = total > 0 ? Int((hours / total * 100).rounded()) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(String(format: "%.1fh", hours))")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .frame(width: 36, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PulseTheme.grouped).frame(height: 8)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(min(percent, 100)) / 100, height: 8)
                        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: percent)
                }
            }
            .frame(height: 8)
            Text(String(format: localizedString("optimal_colon_format"), optimalRange.lowerBound, optimalRange.upperBound))
                .font(.system(size: 9))
                .foregroundStyle(PulseTheme.tertiaryText)
        }
    }

    // MARK: - Insights
    private var insightsCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("insights_and_flags"), systemImage: "lightbulb.fill").font(.headline)

                if let avg = weeklyAvg {
                    if avg >= sleepGoalHours {
                        HealthInsightRow(icon: "checkmark.seal.fill", color: PulseTheme.recovery,
                                         title: localizedString("sleep_insight_great_duration_title"),
                                         message: String(format: localizedString("sleep_insight_great_duration_body"), String(format: "%.1f", avg), Int(sleepGoalHours)))
                    } else {
                        HealthInsightRow(icon: "exclamationmark.triangle.fill", color: PulseTheme.warning,
                                         title: localizedString("sleep_insight_below_goal_title"),
                                         message: String(format: localizedString("sleep_insight_below_goal_body"), String(format: "%.1f", avg), Int(sleepGoalHours)))
                    }
                }

                if totalNightsWithData > 0 {
                    HealthInsightRow(icon: "moon.stars.fill", color: domain.tint,
                                     title: localizedString("sleep_insight_goal_progress_title"),
                                     message: String(format: localizedString("sleep_insight_goal_progress_body"), goodNights, totalNightsWithData, Int(sleepGoalHours)))
                }

                if let best = weekMetrics.compactMap({ m -> (Double, Date)? in
                    guard let h = m.sleepHours, h > 0 else { return nil }
                    return (h, m.date)
                }).max(by: { $0.0 < $1.0 }) {
                    let dayName = Calendar.current.shortWeekdaySymbol(for: best.1)
                    HealthInsightRow(icon: "star.fill", color: domain.tint,
                                     title: localizedString("sleep_insight_best_night_title"),
                                     message: String(format: localizedString("sleep_insight_best_night_body"), dayName, String(format: "%.1f", best.0)))
                }

                if totalNightsWithData == 0 {
                    Text(localizedString("connect_apple_watch_for_sleep"))
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
        SleepView()
            .environment(AppStore())
    }
}
