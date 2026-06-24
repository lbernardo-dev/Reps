import Foundation

struct OnboardingLocationCatalog {
    static let locations: [OnboardingTrainingLocationOption] = [
        .init(
            id: "full_gym",
            title: "Full gym",
            subtitle: "Barbells, machines, cables, and more",
            icon: "figure.strengthtraining.traditional",
            profileLocation: .gym,
            equipment: ["Barbell", "Dumbbells", "Cables", "Machines", "Bench", "Bodyweight", "Cardio"]
        ),
        .init(
            id: "home_gym",
            title: "Home gym",
            subtitle: "Dumbbells, bands, bench, and basics",
            icon: "house.fill",
            profileLocation: .home,
            equipment: ["Dumbbells", "Bands", "Bench", "Bodyweight"]
        ),
        .init(
            id: "minimal_setup",
            title: "Minimal setup",
            subtitle: "Bodyweight and simple accessories",
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
}

struct OnboardingTrainingLocationOption: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let profileLocation: UserProfile.TrainingLocation
    let equipment: [String]
}
