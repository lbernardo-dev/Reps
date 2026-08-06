import SwiftUI

/// Horizontal ranked-bar breakdown with a centered total header and
/// tap-to-highlight rows. Replaces `MetricDonutChart` for the muscle-group
/// volume card — a single-slice pie there rendered as a half ring (Swift
/// Charts' `SectorMark` collapses a 100%-share sector), and bars degrade
/// gracefully whether there's one muscle group or eight.
struct MetricBarChart: View {
    let slices: [DonutSlice]
    let centerValue: String
    let centerLabel: String
    var legendValueFormatter: (Double) -> String = { String(format: "%.0f", $0) }

    @State private var selectedID: DonutSlice.ID?

    private var sortedSlices: [DonutSlice] { slices.sorted { $0.value > $1.value } }
    private var maxValue: Double { sortedSlices.map(\.value).max() ?? 1 }
    private var total: Double { slices.reduce(0) { $0 + $1.value } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(centerValue)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(localizedKey(centerLabel))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            VStack(spacing: 14) {
                ForEach(sortedSlices) { slice in
                    MetricBarChartRow(
                        slice: slice,
                        widthFraction: maxValue > 0 ? max(slice.value / maxValue, 0.04) : 0,
                        sharePercent: total > 0 ? Int((slice.value / total * 100).rounded()) : 0,
                        valueText: legendValueFormatter(slice.value),
                        isSelected: selectedID == slice.id,
                        isDimmed: selectedID != nil && selectedID != slice.id
                    ) {
                        HapticService.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedID = selectedID == slice.id ? nil : slice.id
                        }
                    }
                }
            }
        }
    }
}

private struct MetricBarChartRow: View {
    let slice: DonutSlice
    let widthFraction: Double
    let sharePercent: Int
    let valueText: String
    let isSelected: Bool
    let isDimmed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 8, height: 8)
                    Text(slice.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if isSelected {
                        Text("\(sharePercent)%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Text(valueText)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PulseTheme.grouped)
                        Capsule()
                            .fill(slice.color)
                            .frame(width: proxy.size.width * widthFraction)
                    }
                }
                .frame(height: 10)
            }
            .opacity(isDimmed ? 0.4 : 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Metric Bar Chart") {
    MetricBarChart(
        slices: [
            DonutSlice(label: "Legs", value: 280, color: PulseTheme.accent)
        ],
        centerValue: "280 kg",
        centerLabel: "total_volume"
    )
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
