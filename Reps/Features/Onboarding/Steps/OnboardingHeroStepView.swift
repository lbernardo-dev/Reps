import SwiftUI

struct OnboardingHeroStepView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 64)

            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 204, height: 204)
                    .blur(radius: 30)

                Image("StreakRepHeroIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 152, height: 152)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.18), radius: 26)
            }

            VStack(spacing: 14) {
                let brandText = Text("StreakReps")
                    .foregroundStyle(LinearGradient(
                        colors: [PulseTheme.accent, PulseTheme.warning],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                Text("\(Text("onboarding_hero_meet")) \(brandText)")
                    .font(.system(size: 38, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("onboarding_hero_tagline")
                    .font(.body.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }
}
