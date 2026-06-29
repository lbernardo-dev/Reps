import Charts
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HealthWidgetDetailNavBar(title: localizedString("steps"))

                headerStats.padding(.top, 4)
                chartCard
                todayCard
                insightsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header stats
    private var headerStats: some View {
        HealthStatsHeader(items: [
            HealthStatItem(value: "\(todaySteps)", label: localizedString("today")),
            HealthStatItem(value: "\(stepGoal)", label: localizedString("goal")),
            HealthStatItem(value: "\(daysMet)/7", label: localizedString("days_met"))
        ])
    }

    // MARK: - Weekly bar chart
    private var chartCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(localizedString("this_week")).font(.headline)
                    Spacer()
                    Text("WEEK")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .tracking(1)
                }

                let calendar = Calendar.current
                Chart {
                    RuleMark(y: .value("goal", stepGoal))
                        .foregroundStyle(Color.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))

                    ForEach(weekMetrics) { m in
                        let steps = Int(m.steps)
                        let metGoal = steps >= stepGoal
                        BarMark(
                            x: .value("day", calendar.shortWeekdaySymbol(for: m.date)),
                            y: .value("steps", steps)
                        )
                        .foregroundStyle(metGoal ? Color.orange.gradient : Color.orange.opacity(0.45).gradient)
                        .cornerRadius(5)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.separator)
                        AxisValueLabel {
                            if let d = v.as(Int.self) {
                                Text(d >= 1000 ? "\(d / 1000)k" : "\(d)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 140)

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("\(dailyAvg)")
                            .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
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

    // MARK: - Today card
    private var todayCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(localizedString("today_s_steps").uppercased(), systemImage: "figure.walk")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color.orange)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(todaySteps)")
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.orange)
                    Text(localizedString("steps"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                ProgressView(value: todayProgress)
                    .tint(Color.orange)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)

                HStack {
                    let remaining = max(0, stepGoal - todaySteps)
                    Text(remaining > 0
                         ? localizedFormat("steps_remaining_format", remaining)
                         : localizedString("goal_met"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(remaining > 0 ? PulseTheme.secondaryText : PulseTheme.recovery)
                    Spacer()
                    HStack(spacing: 12) {
                        miniStat(value: "\(dayStreak)", label: localizedString("day_streak"))
                        miniStat(value: "\(Int(todayProgress * 100))%", label: localizedString("progress"))
                    }
                }
            }
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }

    // MARK: - Insights
    private var insightsCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("insights_and_flags"), systemImage: "lightbulb.fill").font(.headline)

                if let best = bestDay {
                    let calendar = Calendar.current
                    HealthInsightRow(
                        icon: "arrow.up.circle.fill", color: PulseTheme.accent,
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
                        icon: "calendar.badge.checkmark", color: PulseTheme.accent,
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

#Preview {
    NavigationStack {
        StepsView()
            .environment(AppStore())
    }
}
