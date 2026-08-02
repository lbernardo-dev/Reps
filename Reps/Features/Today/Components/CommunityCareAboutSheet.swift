import SwiftUI

struct CommunityCareAboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header Graphic Illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                HStack(spacing: -12) {
                    ZStack {
                        Circle()
                            .fill(PulseTheme.card)
                            .frame(width: 52, height: 52)
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                    }

                    ZStack {
                        Circle()
                            .fill(PulseTheme.card)
                            .frame(width: 64, height: 64)
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.red)
                    }

                    ZStack {
                        Circle()
                            .fill(PulseTheme.card)
                            .frame(width: 52, height: 52)
                        Image(systemName: "applewatch.side.right")
                            .font(.system(size: 34))
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
            }
            .padding(.top, 24)

            // Title & Description
            VStack(spacing: 12) {
                Text(String(localized: "about_care_title"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(String(localized: "about_care_description"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            // Privacy Notice Box
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text(String(localized: "about_care_privacy_notice"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )

            Spacer()

            // Okay Button
            Button {
                HapticService.selection()
                dismiss()
            } label: {
                Text(String(localized: "okay_action", defaultValue: "Okay"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PulseTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .background(PulseTheme.background)
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.visible)
    }
}
