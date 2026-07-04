import Charts
import SwiftUI

struct DonutSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

/// Donut chart with a centered total and a legend list below —
/// mirrors "Volume by exercise" from the competitive audit.
struct MetricDonutChart: View {
    let slices: [DonutSlice]
    let centerValue: String
    let centerLabel: LocalizedStringKey
    var legendValueFormatter: (Double) -> String = { String(format: "%.0f", $0) }

    private var total: Double { slices.reduce(0) { $0 + $1.value } }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("value", slice.value),
                        innerRadius: .ratio(0.68),
                        outerRadius: .ratio(1.0),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .clipShape(.rect(cornerRadius: PulseTheme.smallRadius))
                }
                .chartLegend(.hidden)
                .frame(width: 168, height: 168)

                VStack(spacing: 2) {
                    Text(centerValue)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(centerLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(slices) { slice in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 9, height: 9)
                        Text(slice.label)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(legendValueFormatter(slice.value))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
    }
}

#Preview("Metric Donut") {
    MetricDonutChart(
        slices: [
            DonutSlice(label: "Dips", value: 40, color: PulseTheme.accent),
            DonutSlice(label: "Muscle-ups", value: 34, color: PulseTheme.ringStand),
            DonutSlice(label: "Pull-ups", value: 28, color: PulseTheme.semanticProgress),
            DonutSlice(label: "Barbell Squat", value: 15, color: PulseTheme.growth),
            DonutSlice(label: "Hyperextension", value: 8.4, color: PulseTheme.warning),
        ],
        centerValue: "128k kg",
        centerLabel: "total_2"
    )
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
