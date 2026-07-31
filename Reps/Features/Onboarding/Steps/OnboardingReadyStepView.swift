import MuscleMap
import SwiftUI

struct OnboardingReadyStepView: View {
    @Environment(AppStore.self) private var store
    @Binding var draft: OnboardingDraft
    let generatedPlan: WorkoutPlan
    let weeklySetTotal: Int
    let onUnlockPro: () -> Void

    private var selectedGender: BodyGender {
        draft.bodyMapPreference.bodyGender
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_ready_title",
                subtitle: "onboarding_ready_subtitle"
            )

            HStack(spacing: 8) {
                GenerationPill(title: "onboarding_pill_days", value: "\(generatedPlan.daysPerWeek)")
                GenerationPill(title: "onboarding_pill_sets", value: "\(weeklySetTotal)")
                GenerationPill(title: "onboarding_pill_weeks", value: "\(generatedPlan.totalWeeks)")
            }

            if let firstDay = generatedPlan.days.first {
                PlanDay1LockedPreviewCard(
                    day: firstDay,
                    gender: selectedGender,
                    language: draft.preferredLanguage,
                    exercises: store.exercises,
                    isPro: store.monetization.hasProAccess
                )
            }

            if generatedPlan.days.count > 1 {
                PlanLockedDaysCard(
                    plan: generatedPlan,
                    isPro: store.monetization.hasProAccess
                )
            }

            if !store.monetization.hasProAccess {
                PlanUnlockProCard(
                    totalWeeks: generatedPlan.totalWeeks,
                    daysPerWeek: generatedPlan.daysPerWeek,
                    onUnlock: onUnlockPro
                )
            }
        }
    }
}
