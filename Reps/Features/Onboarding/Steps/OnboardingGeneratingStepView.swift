import MuscleMap
import SwiftUI

struct OnboardingGeneratingStepView: View {
    @Binding var draft: OnboardingDraft
    let generatedPlan: WorkoutPlan
    let weeklySetTotal: Int
    let isGenerationComplete: Bool
    let generationProgress: Double
    let generationStatusText: String
    let generationPulse: Bool

    @State private var testimonialIndex = 0

    private static let planTestimonials: [(text: String, author: String)] = [
        (text: "Al fin tengo un plan adaptado a mi horario y equipamiento real.", author: "Alex R."),
        (text: "La primera semana fue retadora pero en la 3era ya vi cambios reales.", author: "María K."),
        (text: "Una app que realmente ajusta la carga de trabajo según mi progreso.", author: "Carlos M."),
    ]

    private var selectedGender: BodyGender {
        draft.bodyMapPreference.bodyGender
    }

    private var activeGenerationStep: Int {
        if generationProgress < 0.25 { return 0 }
        if generationProgress < 0.55 { return 1 }
        if generationProgress < 0.82 { return 2 }
        return 3
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isGenerationComplete {
                planGeneratingView
            } else {
                planCompleteView
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var planGeneratingView: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding_personalizing_title")
                    .font(.system(size: 34, weight: .heavy))
                Text("onboarding_personalizing_subtitle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("PROGRESO")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .tracking(1.2)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [PulseTheme.ringStand, PulseTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(16, proxy.size.width * generationProgress))
                    }
                }
                .frame(height: 5)
            }

            PulseCard {
                let stepTitles: [String] = [
                    "onboarding_step_saving_profile",
                    "onboarding_step_preferences",
                    "onboarding_step_volume",
                    "onboarding_step_templates"
                ]
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stepTitles.enumerated()), id: \.offset) { index, title in
                        GenerationStepRow(
                            title: title,
                            isCompleted: index < activeGenerationStep,
                            isActive: index == activeGenerationStep,
                            isLast: index == stepTitles.count - 1
                        )
                    }
                }
            }

            PulseCard(backgroundColor: PulseTheme.grouped) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PulseTheme.tertiaryText)

                    Text(Self.planTestimonials[testimonialIndex].text)
                        .font(.body.weight(.medium))
                        .italic()
                        .foregroundStyle(PulseTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(testimonialIndex)
                        .transition(.opacity)

                    Text("— \(Self.planTestimonials[testimonialIndex].author)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.easeInOut(duration: 0.45)) {
                    testimonialIndex = (testimonialIndex + 1) % Self.planTestimonials.count
                }
            }
        }
    }

    private var planCompleteView: some View {
        VStack(spacing: 22) {
            OnboardingTitle(
                title: "onboarding_generating_title",
                subtitle: "onboarding_generating_subtitle"
            )

            OnboardingBodyPair(gender: selectedGender, heatmap: generationHeatmap)
                .frame(height: 410)
                .scaleEffect(generationPulse ? 1.02 : 0.98)
                .opacity(generationPulse ? 1 : 0.82)

            HStack(spacing: 8) {
                GenerationPill(title: "onboarding_pill_days", value: "\(generatedPlan.daysPerWeek)")
                GenerationPill(title: "onboarding_pill_sets", value: "\(weeklySetTotal)")
                GenerationPill(title: "onboarding_pill_weeks", value: "\(generatedPlan.totalWeeks)")
            }

            PlanProjectionCard(
                plan: generatedPlan,
                weeklySetTotal: weeklySetTotal,
                goal: draft.mainGoal,
                experience: draft.experience,
                focusMuscles: Array(draft.focusMuscles).sorted(),
                locationID: draft.selectedLocationID
            )
        }
    }

    private var generationHeatmap: [MuscleIntensity] {
        let trained = Set(generatedPlan.days.flatMap(\.exercises).flatMap { muscles(for: $0.exercise.muscleGroup) })
        let focus = Set(draft.focusMuscles.flatMap(muscles(for:)))
        let focusIntensity = generationPulse ? 1.0 : 0.88
        let trainedIntensity = generationPulse ? 0.55 : 0.30

        let focusEntries = focus.map {
            MuscleIntensity(muscle: $0, intensity: focusIntensity, color: PulseTheme.focus)
        }
        let trainedEntries = trained.subtracting(focus).map {
            MuscleIntensity(muscle: $0, intensity: trainedIntensity, color: PulseTheme.accent.opacity(0.45))
        }
        return focusEntries + trainedEntries
    }

    private func muscles(for group: String) -> [Muscle] {
        let lower = group.lowercased()
        if lower.contains("chest") { return [.chest, .upperChest, .lowerChest] }
        if lower.contains("back") { return [.upperBack, .rhomboids, .trapezius, .lowerBack] }
        if lower.contains("shoulder") { return [.deltoids, .frontDeltoid, .rearDeltoid] }
        if lower.contains("arm") { return [.biceps, .triceps, .forearm] }
        if lower.contains("leg") { return [.quadriceps, .hamstring, .calves, .adductors] }
        if lower.contains("glute") { return [.gluteal, .hamstring] }
        if lower.contains("core") { return [.abs, .upperAbs, .lowerAbs, .obliques] }
        return []
    }
}
