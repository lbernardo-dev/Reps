import MuscleMap
import SwiftUI

enum OnboardingStep: String, CaseIterable, Identifiable {
    case hero
    case value
    case setup
    case goal
    case experience
    case schedule
    case equipment
    case baseline
    case focus
    case generating
    case ready

    var id: String { rawValue }

    var primaryButtonTitle: String {
        switch self {
        case .hero: "onboarding_btn_get_started"
        case .value: "onboarding_btn_start_setup"
        case .generating: "onboarding_btn_see_my_plan"
        case .ready: "onboarding_btn_unlock_plan"
        default: "onboarding_btn_continue"
        }
    }
}

enum BodyMapPreference: String, CaseIterable, Identifiable {
    case mapA
    case mapB
    case preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mapA: "onboarding_body_map_male"
        case .mapB: "onboarding_body_map_female"
        case .preferNotToSay: "onboarding_body_map_skip"
        }
    }

    var bodyGender: BodyGender {
        switch self {
        case .mapB: .female
        case .mapA, .preferNotToSay: .male
        }
    }

    var profileSex: UserProfile.Sex? {
        switch self {
        case .mapA: .male
        case .mapB: .female
        case .preferNotToSay: nil
        }
    }
}

struct OnboardingDraft {
    var mainGoal: UserProfile.MainGoal = .buildMuscle
    var experience: UserProfile.Experience = .intermediate
    var weeklyTrainingDays = 4
    var sessionLengthMinutes = 60
    var selectedLocationID = OnboardingLocationCatalog.defaultLocation.id
    var trainingLocation: UserProfile.TrainingLocation = OnboardingLocationCatalog.defaultLocation.profileLocation
    var availableEquipment: [String] = OnboardingLocationCatalog.defaultLocation.equipment
    var age = 32
    var heightCm = 178.0
    var weightKg = 78.0
    var bodyMapPreference: BodyMapPreference = .mapA
    var focusMuscles: Set<String> = []
    var preferredLanguage = UserProfile.deviceDefaultLanguage
    var buildsOwnPlan = false

    static let focusOptions = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"]

    static func localizedFocusKey(_ focus: String) -> String {
        switch focus {
        case "Chest":     return "muscle_group_chest"
        case "Back":      return "muscle_group_back"
        case "Shoulders": return "muscle_group_shoulders"
        case "Arms":      return "muscle_group_arms"
        case "Legs":      return "muscle_group_legs"
        case "Glutes":    return "muscle_group_glutes"
        case "Core":      return "muscle_group_core"
        default:          return localizedString(focus)
        }
    }

    mutating func applyLocation(_ location: OnboardingTrainingLocationOption) {
        selectedLocationID = location.id
        trainingLocation = location.profileLocation
        availableEquipment = location.equipment
    }

    mutating func toggleEquipment(_ equipment: String) {
        if availableEquipment.contains(equipment) {
            availableEquipment.removeAll { $0 == equipment }
        } else {
            availableEquipment.append(equipment)
        }

        if availableEquipment.isEmpty {
            availableEquipment = ["Bodyweight"]
        }
    }

    var allFocusSelected: Bool {
        Self.focusOptions.allSatisfy { focusMuscles.contains($0) }
    }

    mutating func toggleFocus(_ focus: String) {
        if focusMuscles.contains(focus) {
            focusMuscles.remove(focus)
        } else {
            focusMuscles.insert(focus)
        }
    }

    mutating func toggleAllFocus() {
        if allFocusSelected {
            focusMuscles.removeAll()
        } else {
            focusMuscles = Set(Self.focusOptions)
        }
    }

    func makeProfile() -> UserProfile {
        var profile = UserProfile()
        profile.mainGoal = mainGoal
        profile.experience = experience
        profile.weeklyTrainingDays = weeklyTrainingDays
        profile.preferredSessionLengthMinutes = sessionLengthMinutes
        profile.trainingLocation = trainingLocation
        profile.availableEquipment = normalizedEquipment
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: .now)
        profile.sex = bodyMapPreference.profileSex
        profile.preferredLanguage = preferredLanguage
        return profile
    }

    private var normalizedEquipment: [String] {
        OnboardingLocationCatalog.normalizedEquipment(from: availableEquipment)
    }
}
