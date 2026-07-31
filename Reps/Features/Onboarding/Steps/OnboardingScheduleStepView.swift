import SwiftUI

struct OnboardingScheduleStepView: View {
    @Binding var draft: OnboardingDraft

    private var scheduleHelperText: String {
        switch draft.weeklyTrainingDays {
        case 1: "onboarding_schedule_1_day"
        case 2: "onboarding_schedule_2_days"
        case 3: "onboarding_schedule_3_days"
        case 4: "onboarding_schedule_4_days"
        case 5: "onboarding_schedule_5_days"
        case 6: "onboarding_schedule_6_days"
        default: "onboarding_schedule_7_days"
        }
    }

    private var durationHelperText: String {
        switch draft.sessionLengthMinutes {
        case 15: "onboarding_duration_15min"
        case 30: "onboarding_duration_30min"
        case 45: "onboarding_duration_45min"
        case 60: "onboarding_duration_60min"
        case 75: "onboarding_duration_75min"
        default: "onboarding_duration_90min"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_schedule_title",
                subtitle: "onboarding_schedule_subtitle"
            )

            OnboardingNumberPicker(
                title: "onboarding_schedule_days_label",
                value: $draft.weeklyTrainingDays,
                options: Array(1...7),
                unit: "onboarding_schedule_days_unit",
                helper: scheduleHelperText
            )

            OnboardingNumberPicker(
                title: "onboarding_schedule_duration_label",
                value: $draft.sessionLengthMinutes,
                options: [15, 30, 45, 60, 75, 90],
                unit: "onboarding_schedule_duration_unit",
                helper: durationHelperText
            )
        }
    }
}
