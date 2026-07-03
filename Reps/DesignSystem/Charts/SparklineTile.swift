import SwiftUI

/// Compact tile: label + hero value + trend arrow + tiny sparkline.
/// Used for Trends grids (Stand, Cardio Fitness, Move, Exercise…).
struct SparklineTile: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String
    var trend: TrendDirection = .neutral
    var points: [Double] = []
    var tint: Color = PulseTheme.accent

    enum TrendDirection {
        case up, down, neutral

        var systemImage: String {
            switch self {
            case .up: "arrow.up.right"
            case .down: "arrow.down.right"
            case .neutral: "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: PulseTheme.growth
            case .down: PulseTheme.destructive
            case .neutral: PulseTheme.secondaryText
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: trend.systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(trend.color)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            if points.count > 1 {
                SparklinePath(points: points)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(height: 24)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct SparklinePath: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        guard points.count > 1,
              let minValue = points.min(),
              let maxValue = points.max() else { return Path() }

        let range = max(maxValue - minValue, 0.0001)
        let stepX = rect.width / CGFloat(points.count - 1)

        var path = Path()
        for (index, value) in points.enumerated() {
            let x = CGFloat(index) * stepX
            let normalized = (value - minValue) / range
            let y = rect.height - (CGFloat(normalized) * rect.height)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

#Preview("Sparkline Tile") {
    HStack(spacing: 12) {
        SparklineTile(
            title: "cardio_fitness",
            value: "42",
            unit: "VO2max",
            trend: .up,
            points: [38, 39, 38.5, 40, 41, 41.5, 42],
            tint: PulseTheme.fitOrange
        )
        SparklineTile(
            title: "stand",
            value: "9",
            unit: "hr/day",
            trend: .down,
            points: [11, 10, 10, 9.5, 9, 9, 9],
            tint: PulseTheme.ringStand
        )
    }
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
