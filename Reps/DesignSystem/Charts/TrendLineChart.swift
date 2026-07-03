import Charts
import SwiftUI

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    var isRecord: Bool = false
}

/// Line + area trend chart with optional PR annotation dots —
/// used for per-exercise progression (max weight, 1RM, volume…).
struct TrendLineChart: View {
    let points: [TrendPoint]
    var tint: Color = PulseTheme.accent
    var height: CGFloat = 160
    var valueFormatter: (Double) -> String = { String(format: "%.0f", $0) }

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("date", point.date),
                y: .value("value", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.28), tint.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("date", point.date),
                y: .value("value", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            if point.isRecord {
                PointMark(
                    x: .value("date", point.date),
                    y: .value("value", point.value)
                )
                .foregroundStyle(tint)
                .symbolSize(70)
                .annotation(position: .top) {
                    Text(valueFormatter(point.value))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(tint))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.9), in: Capsule())
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(PulseTheme.separator)
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(PulseTheme.separator)
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .frame(height: height)
    }
}

#Preview("Trend Line") {
    let base = Date()
    let calendar = Calendar.current
    let points: [TrendPoint] = (0..<8).map { offset in
        TrendPoint(
            date: calendar.date(byAdding: .weekOfYear, value: -offset, to: base) ?? base,
            value: Double(80 + offset * 3 + Int.random(in: -2...2)),
            isRecord: offset == 0
        )
    }.reversed()

    return TrendLineChart(points: points)
        .padding()
        .screenBackground()
        .preferredColorScheme(.dark)
}
