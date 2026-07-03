import Charts
import SwiftUI

struct BarPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    var isHighlighted: Bool = false
}

/// Compact rounded bar chart for weekly/monthly aggregates
/// (sessions, volume, minutes) with a highlighted "today" bar.
struct WeeklyBarsChart: View {
    let points: [BarPoint]
    var tint: Color = PulseTheme.accent
    var height: CGFloat = 100

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("label", point.label),
                y: .value("value", point.value),
                width: .ratio(0.55)
            )
            .foregroundStyle(point.isHighlighted ? tint : tint.opacity(0.32))
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: height)
    }
}

#Preview("Weekly Bars") {
    WeeklyBarsChart(points: [
        BarPoint(label: "L", value: 12),
        BarPoint(label: "M", value: 0),
        BarPoint(label: "X", value: 18),
        BarPoint(label: "J", value: 6),
        BarPoint(label: "V", value: 22, isHighlighted: true),
        BarPoint(label: "S", value: 0),
        BarPoint(label: "D", value: 0),
    ])
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
