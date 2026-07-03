import Charts
import SwiftUI

// MARK: - Metric series point

/// A single day's value for a summary metric. Series are expected to be
/// chronological and cover up to the last 365 days (gaps allowed).
struct MetricDetailPoint: Identifiable, Hashable {
  let id = UUID()
  let date: Date
  let value: Double
}

// MARK: - Range selector (local to detail screens)

enum MetricDetailRange: String, CaseIterable, Identifiable {
  case week, month, year
  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .week: "week_label"
    case .month: "month_label"
    case .year: "year_label"
    }
  }

  var days: Int {
    switch self {
    case .week: 7
    case .month: 30
    case .year: 365
    }
  }

  /// Whether the main chart aggregates by month instead of by day.
  var aggregatesByMonth: Bool { self == .year }
}

// MARK: - Generic Apple-Fitness-style metric detail

/// A reusable drill-down screen for a single summary metric: a big current
/// value, a range-filtered bar chart with an average baseline, a
/// daily-averages-by-weekday breakdown, and an explanation — mirroring the
/// per-metric detail screens in Apple Fitness.
struct ProgressMetricDetailView: View {
  let title: String
  let accent: Color
  let unit: String
  /// Formats a raw value for display (e.g. "1.234", "5,8", "47").
  let format: (Double) -> String
  /// Full daily series (chronological). Filtered per selected range internally.
  let points: [MetricDetailPoint]
  /// Optional per-day goal drawn as a dashed baseline.
  let goal: Double?
  let explanation: String

  @State private var range: MetricDetailRange = .month

  init(
    title: String,
    accent: Color,
    unit: String,
    points: [MetricDetailPoint],
    goal: Double? = nil,
    explanation: String,
    format: @escaping (Double) -> String = { String(Int($0.rounded())) }
  ) {
    self.title = title
    self.accent = accent
    self.unit = unit
    self.points = points
    self.goal = goal
    self.explanation = explanation
    self.format = format
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        HealthWidgetDetailNavBar(title: title)
        headerValue.padding(.top, 4)
        rangePicker
        chartCard
        weekdayCard
        explanationCard
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 32)
    }
    .background(PulseTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }

  // MARK: Derived data

  private var rangePoints: [MetricDetailPoint] {
    let cal = Calendar.current
    guard let start = cal.date(byAdding: .day, value: -(range.days - 1), to: cal.startOfDay(for: .now))
    else { return points }
    return points.filter { $0.date >= start }.sorted { $0.date < $1.date }
  }

  private var activeValues: [Double] { rangePoints.map(\.value).filter { $0 > 0 } }

  private var dailyAverage: Double {
    guard !activeValues.isEmpty else { return 0 }
    return activeValues.reduce(0, +) / Double(activeValues.count)
  }

  private var total: Double { rangePoints.reduce(0) { $0 + $1.value } }

  private var bestDay: MetricDetailPoint? { rangePoints.max { $0.value < $1.value } }

  private var trendDirection: TrendMetric.Direction {
    // Compare the most recent half of the range with the previous half.
    let pts = rangePoints
    guard pts.count >= 4 else { return .neutral }
    let mid = pts.count / 2
    let recent = pts.suffix(pts.count - mid).map(\.value)
    let prior = pts.prefix(mid).map(\.value)
    let avgRecent = recent.isEmpty ? 0 : recent.reduce(0, +) / Double(recent.count)
    let avgPrior = prior.isEmpty ? 0 : prior.reduce(0, +) / Double(prior.count)
    if avgRecent > avgPrior * 1.03 { return .up }
    if avgRecent < avgPrior * 0.97 { return .down }
    return .neutral
  }

  // MARK: Header

  private var headerValue: some View {
    VStack(spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Image(systemName: trendArrow)
          .font(.system(size: 18, weight: .heavy))
          .foregroundStyle(accent)
        Text(format(dailyAverage))
          .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(accent)
        Text(unit)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(PulseTheme.secondaryText)
      }
      Text(localizedString("daily_avg"))
        .font(.caption.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(PulseTheme.secondaryText)
    }
    .frame(maxWidth: .infinity)
  }

  private var trendArrow: String {
    switch trendDirection {
    case .up: "chevron.up"
    case .down: "chevron.down"
    case .neutral: "minus"
    }
  }

  private var rangePicker: some View {
    Picker("range", selection: $range) {
      ForEach(MetricDetailRange.allCases) { r in
        Text(r.title).tag(r)
      }
    }
    .pickerStyle(.segmented)
  }

  // MARK: Main chart

  private var chartCard: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text(localizedKey(rangeHeadingKey)).font(.headline)
          Spacer()
          statPair(value: format(dailyAverage), label: localizedString("daily_avg"))
          if let best = bestDay, best.value > 0 {
            Divider().frame(height: 30)
            statPair(value: format(best.value), label: bestLabel(best.date))
          }
        }

        if activeValues.isEmpty {
          PulseEmptyState(
            title: "no_data",
            message: "no_data_for_this_range",
            systemImage: "chart.bar"
          )
          .frame(height: 140)
        } else {
          Chart {
            if let goal, goal > 0 {
              RuleMark(y: .value("goal", goal))
                .foregroundStyle(accent.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            } else if dailyAverage > 0 {
              RuleMark(y: .value("avg", dailyAverage))
                .foregroundStyle(PulseTheme.secondaryText.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }

            ForEach(chartBars) { bar in
              BarMark(
                x: .value("date", bar.label),
                y: .value("value", bar.value)
              )
              .foregroundStyle(accent.gradient)
              .cornerRadius(4)
            }
          }
          .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
              AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.separator)
              AxisValueLabel {
                if let d = v.as(Double.self) {
                  Text(compact(d))
                    .font(.system(size: 9))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
              }
            }
          }
          .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
              AxisValueLabel {
                if let s = value.as(String.self) {
                  Text(s)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PulseTheme.tertiaryText)
                }
              }
            }
          }
          .frame(height: 160)
        }
      }
    }
  }

  private struct ChartBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
  }

  private var chartBars: [ChartBar] {
    let cal = Calendar.current
    if range.aggregatesByMonth {
      let grouped = Dictionary(grouping: rangePoints) { p -> Date in
        cal.date(from: cal.dateComponents([.year, .month], from: p.date)) ?? p.date
      }
      let f = DateFormatter()
      f.dateFormat = "MMM"
      return grouped.keys.sorted().map { key in
        ChartBar(label: f.string(from: key), value: grouped[key]?.reduce(0) { $0 + $1.value } ?? 0)
      }
    } else {
      let f = DateFormatter()
      f.dateFormat = range == .week ? "EEEEE" : "d"
      return rangePoints.map { ChartBar(label: f.string(from: $0.date), value: $0.value) }
    }
  }

  private var rangeHeadingKey: String {
    switch range {
    case .week: "this_week"
    case .month: "this_month"
    case .year: "this_year"
    }
  }

  // MARK: Weekday averages

  private var weekdayCard: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        Text(localizedString("daily_averages")).font(.headline)

        if weekdayAverages.allSatisfy({ $0.value == 0 }) {
          PulseEmptyState(
            title: "no_data",
            message: "no_data_for_this_range",
            systemImage: "calendar"
          )
          .frame(height: 120)
        } else {
          Chart(weekdayAverages) { day in
            BarMark(
              x: .value("day", day.symbol),
              y: .value("avg", day.value)
            )
            .foregroundStyle(accent.opacity(0.85).gradient)
            .cornerRadius(4)
          }
          .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { v in
              AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(PulseTheme.separator)
              AxisValueLabel {
                if let d = v.as(Double.self) {
                  Text(compact(d)).font(.system(size: 9)).foregroundStyle(PulseTheme.secondaryText)
                }
              }
            }
          }
          .frame(height: 130)
        }
      }
    }
  }

  private struct WeekdayAverage: Identifiable {
    let id: Int
    let symbol: String
    let value: Double
  }

  private var weekdayAverages: [WeekdayAverage] {
    let cal = Calendar.current
    let symbols = cal.shortWeekdaySymbols
    var sums = Array(repeating: 0.0, count: 7)
    var counts = Array(repeating: 0, count: 7)
    for p in rangePoints where p.value > 0 {
      let idx = cal.component(.weekday, from: p.date) - 1
      sums[idx] += p.value
      counts[idx] += 1
    }
    // Reorder so the week starts on the locale's first weekday.
    let first = cal.firstWeekday - 1
    return (0..<7).map { offset in
      let idx = (first + offset) % 7
      let avg = counts[idx] > 0 ? sums[idx] / Double(counts[idx]) : 0
      return WeekdayAverage(id: offset, symbol: symbols[idx], value: avg)
    }
  }

  // MARK: Explanation

  private var explanationCard: some View {
    PulseCard {
      Text(explanation)
        .font(.subheadline)
        .foregroundStyle(PulseTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: Helpers

  private func statPair(value: String, label: String) -> some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
      Text(label)
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(PulseTheme.secondaryText)
    }
  }

  private func bestLabel(_ date: Date) -> String {
    let cal = Calendar.current
    let idx = cal.component(.weekday, from: date) - 1
    return localizedFormat("best_day_format", cal.shortWeekdaySymbols[idx])
  }

  private func compact(_ d: Double) -> String {
    if d >= 1000 { return "\(Int((d / 1000).rounded()))k" }
    return String(Int(d.rounded()))
  }
}
