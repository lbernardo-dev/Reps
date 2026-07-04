import SwiftUI

struct StepsView: View {
    @Environment(AppStore.self) private var store

    private var stepGoal: Int { store.userProfile.dailyStepsGoal }

    private var weekMetrics: [DailyHealthMetric] {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        return store.health.latestDailyMetrics
            .filter { $0.date >= weekStart }
            .sorted { $0.date < $1.date }
    }

    private var todaySteps: Int {
        Int(store.todayHealthMetric?.steps ?? 0)
    }

    private var dailyAvg: Int {
        let vals = weekMetrics.map { Int($0.steps) }.filter { $0 > 0 }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / vals.count
    }

    private var bestDay: (steps: Int, date: Date)? {
        weekMetrics
            .filter { $0.steps > 0 }
            .max(by: { $0.steps < $1.steps })
            .map { (Int($0.steps), $0.date) }
    }

    private var daysMet: Int {
        weekMetrics.filter { $0.steps >= Double(stepGoal) }.count
    }

    private var dayStreak: Int {
        let calendar = Calendar.current
        let sorted = store.health.latestDailyMetrics
            .filter { $0.steps >= Double(stepGoal) }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)
        var streak = 0
        var expected = calendar.startOfDay(for: .now)
        for day in sorted {
            if day == expected {
                streak += 1
                expected = calendar.date(byAdding: .day, value: -1, to: expected) ?? expected
            } else {
                break
            }
        }
        return streak
    }

    private var todayProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(todaySteps) / Double(stepGoal), 1.0)
    }

    /// Unclamped 0…n version of `todayProgress` — the ring and the "154%"
    /// badge both need to know how far *past* the goal today is.
    private var todayProgressRaw: Double {
        guard stepGoal > 0 else { return 0 }
        return Double(todaySteps) / Double(stepGoal)
    }

    private var allGoalMetDays: Set<Date> {
        let calendar = Calendar.current
        return Set(store.health.latestDailyMetrics
            .filter { $0.steps >= Double(stepGoal) }
            .map { calendar.startOfDay(for: $0.date) })
    }

    private var totalGoalDays: Int { allGoalMetDays.count }

    private var bestStreak: Int {
        let calendar = Calendar.current
        let sortedDays = allGoalMetDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for i in 1..<sortedDays.count {
            if calendar.dateComponents([.day], from: sortedDays[i - 1], to: sortedDays[i]).day == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return max(best, current)
    }

    private var previousWeekMetrics: [DailyHealthMetric] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: .now)) ?? .now
        let end = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: .now)) ?? .now
        return store.health.latestDailyMetrics.filter { $0.date >= start && $0.date < end }
    }

    private var previousWeekAvg: Int? {
        let vals = previousWeekMetrics.map { Int($0.steps) }.filter { $0 > 0 }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / vals.count
    }

    private var avgTrendPercent: Double? {
        guard let previous = previousWeekAvg, previous > 0 else { return nil }
        return Double(dailyAvg - previous) / Double(previous)
    }

    private var verdict: DomainVerdict {
        if todayProgress >= 1.0 { return .excellent }
        if todayProgress >= 0.7 { return .good }
        if todayProgress >= 0.4 { return .fair }
        return .worthALook
    }

    private var verdictMessage: String {
        let remaining = max(0, stepGoal - todaySteps)
        return remaining > 0
            ? localizedFormat("steps_remaining_format", remaining)
            : localizedString("goal_met")
    }

    private var domain: MetricDomain { .activity }

    private static func formatStepAxisValue(_ value: Double) -> String {
        let count = Int(value)
        return count >= 1000 ? "\(count / 1000)k" : "\(count)"
    }

    var body: some View {
        ZStack {
            PulseTheme.background.ignoresSafeArea()
            DomainTintedBackground(domain: domain, height: 420)

            ScrollView {
                VStack(spacing: 20) {
                    HealthWidgetDetailNavBar(title: localizedString("steps"), domain: domain)

                    if todaySteps > 0 {
                        DomainVerdictHeader(verdict: verdict, message: verdictMessage)
                            .padding(.top, 4)
                    }

                    headerStats.padding(.top, 4)
                    todayHeroCard
                    chartCard
                    calendarCard
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
            HealthStatItem(value: "\(todaySteps)", label: localizedString("today")),
            HealthStatItem(value: "\(stepGoal)", label: localizedString("goal")),
            HealthStatItem(value: "\(daysMet)/7", label: localizedString("days_met"))
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

                let calendar = Calendar.current
                DomainBarTrendChart(
                    domain: domain,
                    points: weekMetrics.map {
                        DomainTrendPoint(label: calendar.shortWeekdaySymbol(for: $0.date), date: $0.date, value: $0.steps)
                    },
                    goal: Double(stepGoal),
                    barColor: { $0.value >= Double(stepGoal) ? nil : domain.tint.opacity(0.45) },
                    valueFormat: Self.formatStepAxisValue
                )

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(dailyAvg)")
                                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                            if let avgTrendPercent {
                                TrendDelta(percent: avgTrendPercent)
                            }
                        }
                        Text(localizedString("daily_avg"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    if let best = bestDay {
                        Divider().frame(height: 30)
                        VStack(spacing: 2) {
                            Text("\(best.steps)")
                                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                            Text(localizedFormat("best_day_format", calendar.shortWeekdaySymbol(for: best.date)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Today hero: progress ring
    private var todayHeroCard: some View {
        GlassMetricCard(domain: domain, isSelected: todayProgressRaw >= 1.0) {
            VStack(spacing: 16) {
                if todayProgressRaw > 1.0 {
                    Text("\(Int(todayProgressRaw * 100))%")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(domain.tint)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(domain.tint.opacity(0.16), in: Capsule())
                }

                ZStack {
                    RepsActivityRings(
                        rings: [RepsActivityRings.Ring(id: 0, progress: todayProgressRaw, color: domain.tint)],
                        lineWidth: 16,
                        gap: 0
                    )
                    VStack(spacing: 3) {
                        Text("\(todaySteps)")
                            .font(.system(size: 38, weight: .heavy, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(localizedFormat("goal_format", stepGoal))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
                .frame(width: 176, height: 176)
                .animation(.spring(response: 0.9, dampingFraction: 0.82), value: todayProgressRaw)

                let remaining = max(0, stepGoal - todaySteps)
                Text(remaining > 0
                     ? localizedFormat("steps_remaining_format", remaining)
                     : localizedString("goal_met"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(remaining > 0 ? PulseTheme.secondaryText : PulseTheme.recovery)

                HStack(spacing: 0) {
                    miniStat(value: "\(dayStreak)", label: localizedString("day_streak"))
                    Divider().frame(height: 30)
                    miniStat(value: "\(bestStreak)", label: localizedString("best_streak"))
                    Divider().frame(height: 30)
                    miniStat(value: "\(totalGoalDays)", label: localizedString("goal_days"))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Monthly calendar
    private var calendarCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localizedString("this_month"))
                        .font(.headline)
                    Spacer()
                    DomainStatusPill(text: "\(totalGoalDays)", domain: domain, prominence: .secondary, systemImage: "checkmark.circle.fill")
                }
                StepsCalendarMonth(monthDate: .now, goalMetDays: allGoalMetDays, domain: domain)
            }
        }
    }

    // MARK: - Insights
    private var insightsCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("insights_and_flags"), systemImage: "lightbulb.fill").font(.headline)

                if let best = bestDay {
                    let calendar = Calendar.current
                    HealthInsightRow(
                        icon: "arrow.up.circle.fill", color: domain.tint,
                        title: localizedString("steps_insight_personal_best_title"),
                        message: String(format: localizedString("steps_insight_personal_best_body"),
                                        calendar.shortWeekdaySymbol(for: best.date), best.steps)
                    )
                }

                if dailyAvg > 0 {
                    let meetsGoal = dailyAvg >= stepGoal
                    HealthInsightRow(
                        icon: meetsGoal ? "checkmark.seal.fill" : "exclamationmark.circle.fill",
                        color: meetsGoal ? PulseTheme.recovery : PulseTheme.warning,
                        title: localizedString("steps_insight_avg_steps_title"),
                        message: String(format: localizedString("steps_insight_avg_steps_body"), dailyAvg, stepGoal)
                    )
                }

                if daysMet > 0 {
                    HealthInsightRow(
                        icon: "calendar.badge.checkmark", color: domain.tint,
                        title: localizedString("steps_insight_days_met_title"),
                        message: String(format: localizedString("steps_insight_days_met_body"), daysMet)
                    )
                }

                if dailyAvg == 0 {
                    Text(localizedString("connect_apple_health_for_steps"))
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

/// Month grid of day cells, filled when that day's step goal was met —
/// the competitor's "154% · 12,331 / 8,000 steps" calendar pattern, built
/// entirely from data already synced (no new HealthKit permissions needed).
private struct StepsCalendarMonth: View {
    let monthDate: Date
    let goalMetDays: Set<Date>
    let domain: MetricDomain

    private let calendar = Calendar.current

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL"
        fmt.locale = RepsLocalization.locale
        return fmt.string(from: monthDate).capitalizingFirstLetter()
    }

    /// Leading `nil`s pad the grid so day 1 lands under the correct weekday.
    private var cells: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
              let range = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let mondayIndexedOffset = (firstWeekday + 5) % 7
        let leadingBlanks = Array<Date?>(repeating: nil, count: mondayIndexedOffset)
        let days: [Date?] = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        return leadingBlanks + days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return Array(symbols[1...] + symbols[...0]).map { $0.prefix(1).uppercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PulseTheme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let met = goalMetDays.contains(calendar.startOfDay(for: day))
                        let isToday = calendar.isDateInToday(day)
                        let isFuture = day > .now

                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 12, weight: met ? .bold : .medium, design: .rounded))
                            .foregroundStyle(met ? PulseTheme.onColor(domain.tint) : (isFuture ? PulseTheme.tertiaryText : .primary))
                            .frame(width: 30, height: 30)
                            .background(met ? domain.tint : Color.clear, in: Circle())
                            .overlay {
                                if isToday {
                                    Circle().stroke(domain.tint, lineWidth: met ? 0 : 1.5)
                                }
                            }
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear.frame(width: 30, height: 30).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StepsView()
            .environment(AppStore())
    }
}
