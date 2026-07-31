import SwiftUI

struct OnboardingBaselineStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_baseline_title",
                subtitle: "onboarding_baseline_subtitle"
            )

            OnboardingMetricSlider(
                title: "onboarding_baseline_age",
                valueText: "\(draft.age)",
                unit: "onboarding_baseline_age_unit",
                icon: "calendar",
                value: Binding(
                    get: { Double(draft.age) },
                    set: { draft.age = Int($0.rounded()) }
                ),
                range: 14...85,
                step: 1
            )

            OnboardingMetricSlider(
                title: "onboarding_baseline_height",
                valueText: String(format: "%.0f", draft.heightCm),
                unit: "onboarding_baseline_height_unit",
                icon: "ruler",
                value: $draft.heightCm,
                range: 130...220,
                step: 1
            )

            OnboardingMetricSlider(
                title: "onboarding_baseline_weight",
                valueText: String(format: "%.1f", draft.weightKg),
                unit: "onboarding_baseline_weight_unit",
                icon: "scalemass.fill",
                value: $draft.weightKg,
                range: 35...180,
                step: 0.5
            )

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("onboarding_baseline_anatomy_label")
                        .font(.headline)
                    Text("onboarding_baseline_anatomy_subtitle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)

                    HStack(spacing: 8) {
                        ForEach(BodyMapPreference.allCases) { preference in
                            Button {
                                draft.bodyMapPreference = preference
                            } label: {
                                Text(localizedKey(preference.title))
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .contentShape(Capsule())
                                    .foregroundStyle(draft.bodyMapPreference == preference ? .black : PulseTheme.secondaryText)
                                    .background(draft.bodyMapPreference == preference ? .white : PulseTheme.grouped)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .pressableFeedback(scale: 0.94)
                        }
                    }
                }
            }
        }
    }
}
