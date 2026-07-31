import SwiftUI

struct OnboardingSetupStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_setup_title",
                subtitle: "onboarding_setup_subtitle"
            )

            VStack(spacing: 12) {
                OnboardingOptionCard(
                    title: "onboarding_setup_create",
                    subtitle: "onboarding_setup_create_sub",
                    icon: "sparkles",
                    tint: PulseTheme.accent,
                    isSelected: !draft.buildsOwnPlan
                ) {
                    draft.buildsOwnPlan = false
                }

                OnboardingOptionCard(
                    title: "onboarding_setup_self",
                    subtitle: "onboarding_setup_self_sub",
                    icon: "wrench.fill",
                    tint: PulseTheme.secondaryText,
                    isSelected: draft.buildsOwnPlan
                ) {
                    draft.buildsOwnPlan = true
                }
            }
        }
    }
}
