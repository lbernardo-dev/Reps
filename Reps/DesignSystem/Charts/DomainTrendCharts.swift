import Charts
import SwiftUI

// MARK: - Domain Trend Point

/// A single plotted point shared by the domain trend charts below. `label` is
/// the x-axis category (day initial, weekday short name…); `date` is kept for
/// sorting/future use even though the chart itself plots by `label`.
struct DomainTrendPoint: Identifiable {
    let id: String
    let label: String
    let date: Date
    let value: Double

    init(id: String? = nil, label: String, date: Date = .now, value: Double) {
        self.id = id ?? "\(label)-\(date.timeIntervalSince1970)-\(value)"
        self.label = label
        self.date = date
        self.value = value
    }
}

// MARK: - Floating value pill

/// The "54 BPM" floating annotation anchored to the average rule mark —
/// the single most recognizable trait shared by every chart in the
/// competitor reference. Centralizing it here means every metric gets it
/// for free instead of each view reinventing its own average label.
private struct TrendValuePill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
    }
}

private func thinnedAxisLabels(_ points: [DomainTrendPoint]) -> [String] {
    guard points.count > 7 else { return points.map(\.label) }
    let stride = max(points.count / 4, 1)
    return points.enumerated().filter { $0.offset % stride == 0 }.map(\.element.label)
}

private func averageValue(_ points: [DomainTrendPoint]) -> Double? {
    let vals = points.map(\.value).filter { $0 > 0 }
    guard !vals.isEmpty else { return nil }
    return vals.reduce(0, +) / Double(vals.count)
}

// MARK: - Bar Trend Chart

/// Period bar chart shared by Steps, Sleep, and HRV history — domain-tinted
/// bars, a dashed white average rule with a floating value pill, and an
/// optional dashed goal line. Replaces four near-identical bespoke `Chart`
/// blocks with one component so every metric shares the same visual language.
struct DomainBarTrendChart: View {
    let domain: MetricDomain
    let points: [DomainTrendPoint]
    var goal: Double? = nil
    /// Per-bar color override (e.g. muted when a day misses its goal).
    /// Return `nil` to use `domain.tint`.
    var barColor: (DomainTrendPoint) -> Color? = { _ in nil }
    var valueFormat: (Double) -> String = { String(format: "%.0f", $0) }
    /// Overrides the self-computed average — e.g. HRV shows its 7-day
    /// average as the rule even though the chart itself plots 30 days.
    var average: Double?? = nil
    var height: CGFloat = 140

    var body: some View {
        let average = self.average ?? averageValue(points)
        let xLabels = thinnedAxisLabels(points)

        Chart {
            if let goal {
                RuleMark(y: .value("goal", goal))
                    .foregroundStyle(domain.tint.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }

            ForEach(points) { point in
                BarMark(
                    x: .value("label", point.label),
                    y: .value("value", point.value)
                )
                .foregroundStyle((barColor(point) ?? domain.tint).gradient)
                .cornerRadius(5)
            }

            if let average {
                RuleMark(y: .value("avg", average))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing, spacing: 4) {
                        TrendValuePill(text: valueFormat(average), tint: domain.tint)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(PulseTheme.separator)
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(valueFormat(d))
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xLabels) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(PulseTheme.separator)
                AxisValueLabel()
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Line Trend Chart

/// Continuous trend chart (VO2 Max, multi-week HRV) — hollow-dot line over a
/// domain-tinted area gradient, with the same average-rule-plus-pill pattern
/// as `DomainBarTrendChart` so a user learns the pattern once.
struct DomainLineTrendChart: View {
    let domain: MetricDomain
    let points: [DomainTrendPoint]
    var valueFormat: (Double) -> String = { String(format: "%.0f", $0) }
    var height: CGFloat = 140

    var body: some View {
        let average = averageValue(points)
        let xLabels = thinnedAxisLabels(points)

        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("label", point.label),
                    y: .value("value", point.value)
                )
                .foregroundStyle(domain.chartAreaGradient)

                LineMark(
                    x: .value("label", point.label),
                    y: .value("value", point.value)
                )
                .foregroundStyle(domain.tint)
                .lineStyle(StrokeStyle(lineWidth: 2.2))
                .symbol {
                    Circle()
                        .fill(PulseTheme.card)
                        .overlay(Circle().stroke(domain.tint, lineWidth: 2))
                        .frame(width: 7, height: 7)
                }
            }

            if let average {
                RuleMark(y: .value("avg", average))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing, spacing: 4) {
                        TrendValuePill(text: valueFormat(average), tint: domain.tint)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(PulseTheme.separator)
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(valueFormat(d))
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xLabels) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(PulseTheme.separator)
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .frame(height: height)
    }
}
