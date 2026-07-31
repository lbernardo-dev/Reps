import SwiftUI

struct OnboardingEquipmentStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_equipment_title",
                subtitle: "onboarding_equipment_subtitle"
            )

            VStack(spacing: 12) {
                ForEach(OnboardingLocationCatalog.locations) { location in
                    OnboardingOptionCard(
                        title: location.title,
                        subtitle: location.subtitle,
                        icon: location.icon,
                        tint: PulseTheme.recovery,
                        isSelected: draft.selectedLocationID == location.id
                    ) {
                        draft.applyLocation(location)
                    }
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("onboarding_equipment_available_label")
                        .font(.headline)

                    FlowLayout(spacing: 10) {
                        ForEach(OnboardingLocationCatalog.coreEquipment, id: \.self) { equipment in
                            EquipmentChip(
                                title: OnboardingLocationCatalog.localizedEquipmentKey(equipment),
                                isSelected: draft.availableEquipment.contains(equipment)
                            ) {
                                draft.toggleEquipment(equipment)
                            }
                        }
                    }

                    Text("onboarding_equipment_refine_hint")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }
}
