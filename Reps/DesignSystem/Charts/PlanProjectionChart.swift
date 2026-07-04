import Charts
import SwiftUI

/// Interactive line+point chart for a plan's projected progress. Deliberately
/// avoids `catmullRom` smoothing (it overshoots and reads as an artificial
/// curve) in favor of `.monotone`, and always draws a point per week so the
/// chart looks like plotted checkpoints rather than a single drawn line.
struct PlanProjectionChart: View {
    let points: [FitnessMetrics.PlanProjectionPoint]
    var tint: Color = PulseTheme.accent
    var height: CGFloat = 160

    @State private var activeWeek: Int?

    private var activePoint: FitnessMetrics.PlanProjectionPoint? {
        guard let activeWeek else { return nil }
        return points.first { $0.week == activeWeek }
    }

    private var minValue: Double { points.map(\.percentGain).min() ?? 0 }
    private var maxValue: Double { points.map(\.percentGain).max() ?? 0 }
    private var margin: Double { max((maxValue - minValue) * 0.3, 1.5) }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.22), tint.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ChartContentBuilder
    private var areaContent: some ChartContent {
        ForEach(points) { point in
            AreaMark(
                x: .value("week", point.week),
                yStart: .value("base", minValue - margin),
                yEnd: .value("gain", point.percentGain)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(areaGradient)
        }
    }

    @ChartContentBuilder
    private var lineContent: some ChartContent {
        ForEach(points) { point in
            LineMark(
                x: .value("week", point.week),
                y: .value("gain", point.percentGain)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private var pointContent: some ChartContent {
        ForEach(points) { point in
            PointMark(
                x: .value("week", point.week),
                y: .value("gain", point.percentGain)
            )
            .foregroundStyle(tint)
            .symbolSize(activeWeek == point.week ? 70 : 20)
        }
    }

    private func selectionLabel(for point: FitnessMetrics.PlanProjectionPoint) -> String {
        point.week == 0
            ? localizedString("today_2")
            : String(format: localizedString("week_label_format"), point.week)
    }

    @ChartContentBuilder
    private var selectionContent: some ChartContent {
        if let activePoint {
            RuleMark(x: .value("week", activePoint.week))
                .foregroundStyle(PulseTheme.secondaryText.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, spacing: 6) {
                    HStack(spacing: 5) {
                        Text(selectionLabel(for: activePoint))
                            .foregroundStyle(PulseTheme.onColor(tint).opacity(0.75))
                        Text(String(format: "%+.1f%%", activePoint.percentGain))
                            .foregroundStyle(PulseTheme.onColor(tint))
                    }
                    .font(.caption2.weight(.black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint, in: Capsule())
                }
        }
    }

    var body: some View {
        Chart {
            areaContent
            lineContent
            pointContent
            selectionContent
        }
        .chartYScale(domain: (minValue - margin)...(maxValue + margin))
        .chartXAxis {
            AxisMarks(values: points.map(\.week)) { value in
                AxisGridLine().foregroundStyle(PulseTheme.separator.opacity(0.5))
                if let week = value.as(Int.self) {
                    AxisValueLabel {
                        Text(week == 0 ? localizedString("today_2") : String(format: localizedString("week_label_format"), week))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(PulseTheme.separator.opacity(0.5))
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text(String(format: "%+.0f%%", percent))
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let week: Int = proxy.value(atX: value.location.x) else { return }
                                let bounds = (points.first?.week ?? 0)...(points.last?.week ?? 0)
                                let clamped = min(max(week, bounds.lowerBound), bounds.upperBound)
                                if activeWeek != clamped {
                                    HapticService.selection()
                                }
                                activeWeek = clamped
                            }
                            .onEnded { _ in activeWeek = nil }
                    )
            }
        }
        .frame(height: height)
    }
}
