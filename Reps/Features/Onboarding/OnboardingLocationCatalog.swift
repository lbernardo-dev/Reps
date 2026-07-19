import Foundation
import SwiftUI

struct OnboardingLocationCatalog {
    static let locations: [OnboardingTrainingLocationOption] = [
        .init(
            id: "full_gym",
            titleKey: "onboarding_loc_full_gym",
            subtitleKey: "onboarding_loc_full_gym_sub",
            icon: "figure.strengthtraining.traditional",
            profileLocation: .gym,
            equipment: ["Barbell", "Dumbbells", "Cables", "Machines", "Bench", "Bodyweight", "Cardio"]
        ),
        .init(
            id: "home_gym",
            titleKey: "onboarding_loc_home_gym",
            subtitleKey: "onboarding_loc_home_gym_sub",
            icon: "house.fill",
            profileLocation: .home,
            equipment: ["Dumbbells", "Bands", "Bench", "Bodyweight"]
        ),
        .init(
            id: "minimal_setup",
            titleKey: "onboarding_loc_minimal",
            subtitleKey: "onboarding_loc_minimal_sub",
            icon: "figure.strengthtraining.functional",
            profileLocation: .home,
            equipment: ["Bodyweight", "Bands"]
        )
    ]

    static let coreEquipment = [
        "Barbell",
        "Dumbbells",
        "Cables",
        "Machines",
        "Bands",
        "Bench",
        "Bodyweight",
        "Cardio"
    ]

    static var defaultLocation: OnboardingTrainingLocationOption {
        locations[0]
    }

    static func location(for id: String) -> OnboardingTrainingLocationOption {
        locations.first { $0.id == id } ?? defaultLocation
    }

    static func normalizedEquipment(from equipment: [String]) -> [String] {
        equipment.map { value in
            switch value {
            case "Cables": "Cable"
            case "Machines": "Machine"
            case "Bands": "Resistance Band"
            case "Cardio": "Cardio Machine"
            default: value
            }
        }
    }

    static func localizedEquipmentKey(_ name: String) -> String {
        switch name {
        case "Barbell":    return "equip_barbell"
        case "Dumbbells":  return "equip_dumbbells"
        case "Cables":     return "equip_cables"
        case "Machines":   return "equip_machines"
        case "Bands":      return "equip_bands"
        case "Bench":      return "equip_bench"
        case "Bodyweight": return "equip_bodyweight"
        case "Cardio":     return "equip_cardio"
        default:           return localizedString(name)
        }
    }
}

struct OnboardingTrainingLocationOption: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let icon: String
    let profileLocation: UserProfile.TrainingLocation
    let equipment: [String]

    var title: String { titleKey }
    var subtitle: String { subtitleKey }
}
