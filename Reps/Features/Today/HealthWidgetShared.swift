import SwiftUI

// MARK: - Detail navigation bar used across health widget detail views
struct HealthWidgetDetailNavBar: View {
    @Environment(\.dismiss) private var dismiss

    let title: String

    var body: some View {
        HStack {
            Button {
                HapticService.selection()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .navigationGlassCircle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .opacity(0)
                .frame(width: 38, height: 38)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Insight row used across health detail views
struct HealthInsightRow: View {
    let icon: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, 2)

            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38)
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Mini metric tile for health detail views
struct HealthMiniTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        PulseCard(minHeight: 100, contentPadding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Text(localizedKey(title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                Text(localizedKey(subtitle))
                    .font(.system(size: 9))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}
