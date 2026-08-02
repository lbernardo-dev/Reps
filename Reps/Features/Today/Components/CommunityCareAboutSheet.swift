import SwiftUI

struct CommunityCareAboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            CareHeroGraphic()
                .padding(.top, 18)
                .entryEffect(isVisible: hasAppeared, offset: 18, reduceMotion: reduceMotion)

            VStack(spacing: 10) {
                Text(String(localized: "about_care_title"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(String(localized: "about_care_description"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 16)
            .entryEffect(isVisible: hasAppeared, offset: 14, reduceMotion: reduceMotion)

            CarePrivacyNotice()
                .padding(.top, 20)
                .entryEffect(isVisible: hasAppeared, offset: 10, reduceMotion: reduceMotion)

            Spacer(minLength: 22)

            Button {
                HapticService.selection()
                dismiss()
            } label: {
                Text(String(localized: "okay_action", defaultValue: "Okay"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(PulseTheme.accent, in: Capsule())
                    .shadow(color: PulseTheme.accent.opacity(0.24), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .entryEffect(isVisible: hasAppeared, offset: 8, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
        .background(PulseTheme.background)
        // A single detent keeps the explanation stable instead of letting the
        // system jump to a large, mostly empty sheet.
        .presentationDetents([.height(540)])
        .presentationDragIndicator(.visible)
        .onAppear {
            guard !hasAppeared else { return }

            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.smooth(duration: 0.45, extraBounce: 0)) {
                    hasAppeared = true
                }
            }
        }
    }
}

private struct CareHeroGraphic: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PulseTheme.semanticEffort.opacity(0.22), Color.purple.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 116, height: 116)

            HStack(spacing: -10) {
                CareHeroSymbol(systemName: "figure.run", size: 48, tint: PulseTheme.semanticHealth)
                CareHeroSymbol(systemName: "heart.fill", size: 60, tint: PulseTheme.semanticEffort)
                CareHeroSymbol(systemName: "applewatch.side.right", size: 48, tint: PulseTheme.accent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "about_care_title"))
    }
}

private struct CareHeroSymbol: View {
    let systemName: String
    let size: CGFloat
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.48, weight: .bold))
            .foregroundStyle(PulseTheme.onColor(tint))
            .frame(width: size, height: size)
            .background(tint, in: Circle())
            .overlay(Circle().stroke(PulseTheme.background, lineWidth: 5))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }
}

private struct CarePrivacyNotice: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PulseTheme.onColor(PulseTheme.semanticHealth))
                .frame(width: 34, height: 34)
                .background(PulseTheme.semanticHealth, in: Circle())

            Text(String(localized: "about_care_privacy_notice"))
                .font(.footnote)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PulseTheme.semanticHealth.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PulseTheme.semanticHealth.opacity(0.30), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func entryEffect(isVisible: Bool, offset: CGFloat, reduceMotion: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : offset)
            .animation(reduceMotion ? .linear(duration: 0) : .smooth(duration: 0.45, extraBounce: 0), value: isVisible)
    }
}
