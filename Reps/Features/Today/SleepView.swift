import Charts
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

    private var lastNightHours: Double? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return weekMetrics.last(where: { Calendar.current.isDate($0.date, inSameDayAs: yesterday) || Calendar.current.isDateInToday($0.date) })?.sleepHours
    }

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var barColor: Color { PulseTheme.primary }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HealthWidgetDetailNavBar(title: localizedString("sleep"))

                headerStats.padding(.top, 4)
                chartCard
                lastNightCard
                insightsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header stats row
    private var headerStats: some View {
        HealthStatsHeader(items: [
            HealthStatItem(value: weeklyAvg.map { String(format: "%.1fh", $0) } ?? "--", label: localizedString("weekly_avg")),
            HealthStatItem(value: totalNightsWithData > 0 ? "\(goodNights)/\(totalNightsWithData)" : "--", label: localizedString("good_nights")),
            HealthStatItem(value: String(format: "%.0fh", sleepGoalHours), label: localizedString("goal"))
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

                if weekMetrics.compactMap(\.sleepHours).isEmpty {
                    Text(localizedString("no_health_data"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    let calendar = Calendar.current
                    Chart {
                        RuleMark(y: .value("goal", sleepGoalHours))
                            .foregroundStyle(PulseTheme.primary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))

                        ForEach(weekMetrics) { m in
                            let hours = m.sleepHours ?? 0
                            let isGood = hours >= sleepGoalHours
                            let label = calendar.shortWeekdaySymbol(for: m.date)
                            BarMark(
                                x: .value("day", label),
                                y: .value("hours", hours)
                            )
                            .foregroundStyle(isGood ? PulseTheme.recovery.gradient : PulseTheme.warning.opacity(0.7).gradient)
                            .cornerRadius(5)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { v in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.separator)
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(String(format: "%.0fh", d))
                                        .font(.system(size: 9))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .frame(height: 140)

                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(PulseTheme.recovery).frame(width: 12, height: 12)
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

    // MARK: - Last night card
    private var lastNightCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(localizedString("last_night_sleep").uppercased(), systemImage: "moon.fill")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(PulseTheme.primary)

                if let hours = lastNightHours, hours > 0 {
                    HStack(spacing: 0) {
                        nightStatCell(value: String(format: "%.1fh", hours), label: localizedString("duration"))
                        Divider().frame(height: 32)
                        nightStatCell(
                            value: hours >= sleepGoalHours ? localizedString("goal_met") : localizedString("below_goal"),
                            label: localizedString("status")
                        )
                    }
                } else {
                    Text(localizedString("no_sleep_data"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                }
            }
        }
    }

    private func nightStatCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.primary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insights
    private var insightsCard: some View {
        PulseCard {
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
                    HealthInsightRow(icon: "moon.stars.fill", color: PulseTheme.primary,
                                     title: localizedString("sleep_insight_goal_progress_title"),
                                     message: String(format: localizedString("sleep_insight_goal_progress_body"), goodNights, totalNightsWithData, Int(sleepGoalHours)))
                }

                if let best = weekMetrics.compactMap({ m -> (Double, Date)? in
                    guard let h = m.sleepHours, h > 0 else { return nil }
                    return (h, m.date)
                }).max(by: { $0.0 < $1.0 }) {
                    let dayName = Calendar.current.shortWeekdaySymbol(for: best.1)
                    HealthInsightRow(icon: "star.fill", color: PulseTheme.accent,
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
