import SwiftUI

struct OnboardingBaselineStepView: View {
    @Binding var draft: OnboardingDraft
    @State private var isLbs: Bool = false

    private var displayWeight: Double {
        isLbs ? draft.weightKg * 2.20462 : draft.weightKg
    }

    private var weightInteger: Int {
        Int(displayWeight)
    }

    private var weightFraction: Int {
        Int((displayWeight - Double(weightInteger)) * 10)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 22) {
            // Header with purpose micro-copy
            VStack(spacing: 8) {
                Text(localizedString("onboarding_baseline_title"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(localizedString("onboarding_weight_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            // 1. Anatomy / Sex Card Selection
            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("onboarding_sex_title"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(localizedString("onboarding_sex_subtitle"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)

                HStack(spacing: 12) {
                    ForEach(BodyMapPreference.allCases) { preference in
                        let isSelected = draft.bodyMapPreference == preference
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                draft.bodyMapPreference = preference
                            }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: preference == .masculine ? "figure.stand" : "figure.stand.dress")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(isSelected ? PulseTheme.accent : PulseTheme.secondaryText)
                                Text(localizedKey(preference.title))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(isSelected ? PulseTheme.textPrimary : PulseTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSelected ? PulseTheme.accent.opacity(0.12) : PulseTheme.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? PulseTheme.accent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .pressableFeedback(scale: 0.96)
                    }
                }
            }

            // 2. Weight Unit Toggle & Giant Typography Display
            VStack(spacing: 14) {
                // KG / LBS segmented toggle
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isLbs = false }
                    } label: {
                        Text("KG")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(!isLbs ? PulseTheme.accent : PulseTheme.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(!isLbs ? Color.white.opacity(0.15) : Color.clear, in: Capsule())
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isLbs = true }
                    } label: {
                        Text("LBS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isLbs ? PulseTheme.accent : PulseTheme.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isLbs ? Color.white.opacity(0.15) : Color.clear, in: Capsule())
                    }
                }
                .padding(4)
                .background(PulseTheme.card, in: Capsule())

                // Giant Weight Number
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", displayWeight))
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                    Text(isLbs ? "lbs" : "kg")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                // Dual Wheel Picker (Integer . Fraction)
                HStack(spacing: 4) {
                    Picker("Integer", selection: Binding(
                        get: { weightInteger },
                        set: { newInt in
                            let total = Double(newInt) + Double(weightFraction) / 10.0
                            draft.weightKg = isLbs ? total / 2.20462 : total
                        }
                    )) {
                        ForEach(isLbs ? 80...400 : 35...180, id: \.self) { val in
                            Text("\(val)")
                                .font(.headline.weight(.bold))
                                .tag(val)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 110)
                    .clipped()

                    Text(".")
                        .font(.title.weight(.bold))
                        .foregroundStyle(PulseTheme.textPrimary)

                    Picker("Fraction", selection: Binding(
                        get: { weightFraction },
                        set: { newFrac in
                            let total = Double(weightInteger) + Double(newFrac) / 10.0
                            draft.weightKg = isLbs ? total / 2.20462 : total
                        }
                    )) {
                        ForEach(0...9, id: \.self) { val in
                            Text("\(val)")
                                .font(.headline.weight(.bold))
                                .tag(val)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 110)
                    .clipped()
                }
                .padding(.horizontal, 16)
                .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // 3. Height & Age Pickers
            VStack(alignment: .leading, spacing: 14) {
                OnboardingMetricSlider(
                    title: "onboarding_height_title",
                    valueText: String(format: "%.0f", draft.heightCm),
                    unit: "onboarding_baseline_height_unit",
                    icon: "ruler",
                    value: $draft.heightCm,
                    range: 130...220,
                    step: 1
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
            }
        }
    }
}
