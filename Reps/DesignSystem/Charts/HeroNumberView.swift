import SwiftUI

/// The competitive reference's core typographic pattern: a huge number
/// with a small trailing unit, and a small caption label below.
/// Never label-big/number-small — see PLAN_REFORMA_INTEGRAL.md §4.
struct HeroNumberView: View {
    let value: String
    var unit: String? = nil
    let label: LocalizedStringKey
    var tint: Color = .white
    var size: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(2)
        }
    }
}

/// Record row for per-exercise history (star + weight + reps + date) —
/// mirrors the "110 kg · 24 May 2026" list from the competitive audit.
struct RecordRow: View {
    let value: String
    var secondaryValue: String? = nil
    let date: Date
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isHighlighted ? "star.fill" : "circle.fill")
                .font(.system(size: isHighlighted ? 14 : 6))
                .foregroundStyle(isHighlighted ? PulseTheme.accent : PulseTheme.tertiaryText)
                .frame(width: 20)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.textPrimary)
                if let secondaryValue {
                    Text(secondaryValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                }
            }

            Spacer(minLength: 8)

            Text(date, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.vertical, 6)
    }
}

#Preview("Hero Number + Record Row") {
    VStack(alignment: .leading, spacing: 20) {
        HeroNumberView(value: "100", unit: "kg", label: "max_weight", size: 44)
        VStack(spacing: 2) {
            RecordRow(value: "110 kg", date: .now, isHighlighted: true)
            RecordRow(value: "105 kg", date: .now.addingTimeInterval(-86400 * 14))
            RecordRow(value: "50 kg", secondaryValue: "× 10", date: .now.addingTimeInterval(-86400 * 30))
        }
    }
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
