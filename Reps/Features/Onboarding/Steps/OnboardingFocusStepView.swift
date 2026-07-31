import MuscleMap
import SwiftUI

struct OnboardingFocusStepView: View {
    @Binding var draft: OnboardingDraft

    private var selectedGender: BodyGender {
        draft.bodyMapPreference.bodyGender
    }

    private var selectedFocusMuscles: Set<Muscle> {
        Set(draft.focusMuscles.flatMap(muscles(for:)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_focus_title",
                subtitle: "onboarding_focus_subtitle"
            )

            OnboardingBodyPair(gender: selectedGender, selectedMuscles: selectedFocusMuscles) { muscle in
                if let focus = focusKey(for: muscle) {
                    draft.toggleFocus(focus)
                }
            }
            .frame(height: 410)

            FlowLayout(spacing: 10) {
                ForEach(OnboardingDraft.focusOptions, id: \.self) { focus in
                    EquipmentChip(
                        title: OnboardingDraft.localizedFocusKey(focus),
                        isSelected: draft.focusMuscles.contains(focus)
                    ) {
                        draft.toggleFocus(focus)
                    }
                }
                EquipmentChip(
                    title: "onboarding_focus_all",
                    isSelected: draft.allFocusSelected
                ) {
                    draft.toggleAllFocus()
                }
            }
        }
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

    private func focusKey(for muscle: Muscle) -> String? {
        if [.chest, .upperChest, .lowerChest].contains(muscle) { return "Chest" }
        if [.upperBack, .rhomboids, .trapezius, .upperTrapezius, .lowerTrapezius, .lowerBack].contains(muscle) { return "Back" }
        if [.deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff].contains(muscle) { return "Shoulders" }
        if [.biceps, .triceps, .forearm].contains(muscle) { return "Arms" }
        if [.quadriceps, .innerQuad, .outerQuad, .hamstring, .calves, .tibialis, .adductors].contains(muscle) { return "Legs" }
        if [.gluteal].contains(muscle) { return "Glutes" }
        if [.abs, .upperAbs, .lowerAbs, .obliques, .serratus].contains(muscle) { return "Core" }
        return nil
    }
}
