import SwiftUI

struct OnboardingGoalStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_goal_title",
                subtitle: "onboarding_goal_subtitle"
            )

            VStack(spacing: 12) {
                ForEach(UserProfile.MainGoal.allCases) { goal in
                    OnboardingOptionCard(
                        title: goal.title,
                        subtitle: goal.subtitle,
                        icon: goal.icon,
                        tint: goal.tint,
                        isSelected: draft.mainGoal == goal
                    ) {
                        draft.mainGoal = goal
                    }
                }
            }
        }
    }
}
