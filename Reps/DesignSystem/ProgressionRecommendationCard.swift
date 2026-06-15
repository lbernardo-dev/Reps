import SwiftUI

struct ProgressionRecommendationCard: View {
    let recommendations: [SmartProgressionAdvisor.Recommendation]
    let language: String
    var title: LocalizedStringKey = "smart_progression"
    var emptyMessage: LocalizedStringKey = "log_a_few_sessions_to_unlock_weight_rep_and_deload_recommendations"

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedKey(title))
                            .font(.headline)
                        Text(localizedString("next_suggested_load_based_on_your_recent_history"))
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                if recommendations.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                } else {
                    VStack(spacing: 10) {
                        ForEach(recommendations) { recommendation in
                            ProgressionRecommendationRow(
                                recommendation: recommendation,
                                language: language
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct ProgressionRecommendationRow: View {
    let recommendation: SmartProgressionAdvisor.Recommendation
    let language: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: recommendation.suggestion.shouldDeload ? "arrow.down.forward.circle.fill" : "arrow.up.forward.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(recommendation.suggestion.shouldDeload ? PulseTheme.warning : PulseTheme.primary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(RepsText.exerciseName(recommendation.exercise.name, language: language))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    Text(targetText)
                        .font(.caption.weight(.black).monospacedDigit())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(recommendation.suggestion.shouldDeload ? PulseTheme.warning : PulseTheme.accent, in: Capsule())
                }

                Text(recommendation.suggestion.explanation)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(PulseTheme.grouped.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(RepsText.exerciseName(recommendation.exercise.name, language: language)), \(targetText), \(recommendation.suggestion.explanation)")
    }

    private var targetText: String {
        guard recommendation.suggestion.targetWeightKg > 0 else {
            return "\(recommendation.suggestion.targetReps) reps"
        }

        let weight = recommendation.suggestion.targetWeightKg
        let weightText = weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight)) kg"
            : String(format: "%.1f kg", weight)
        return "\(weightText) x \(recommendation.suggestion.targetReps)"
    }
}
