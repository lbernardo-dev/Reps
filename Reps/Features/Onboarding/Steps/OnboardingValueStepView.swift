import SwiftUI

struct OnboardingValueStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingTitle(
                title: "onboarding_value_title",
                subtitle: "onboarding_value_subtitle"
            )

            OnboardingProgressBodyHero(
                goal: draft.mainGoal.shortTitle,
                daysPerWeek: draft.weeklyTrainingDays,
                minutes: draft.sessionLengthMinutes
            )
            .frame(height: 540)
        }
    }
}
