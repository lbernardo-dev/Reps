import SwiftUI

struct OnboardingExperienceStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_exp_title",
                subtitle: "onboarding_exp_subtitle"
            )

            VStack(spacing: 12) {
                ForEach(UserProfile.Experience.allCases) { experience in
                    OnboardingOptionCard(
                        title: experience.title,
                        subtitle: experience.subtitle,
                        icon: experience.icon,
                        tint: PulseTheme.ringStand,
                        isSelected: draft.experience == experience
                    ) {
                        draft.experience = experience
                    }
                }
            }
        }
    }
}
