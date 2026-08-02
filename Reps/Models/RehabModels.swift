import Foundation

/// A small en/es pair for rehab catalog content. The rehab catalog is static,
/// bundled, curated copy (not user data), so it is kept out of
/// `Localizable.xcstrings` and resolved the same way `RepsText` resolves
/// muscle/equipment names: by switching on `preferredLanguage` at read time.
struct RehabLocalizedText: Codable, Hashable {
    let key: String

    init(key: String) {
        self.key = key
    }

    func resolved(language: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .main, locale: Locale(identifier: language))
    }
}

/// A single rehabilitation exercise: isometric holds, eccentric loading,
/// controlled mobility, and activation work aimed at tendons, joints, and
/// muscles recovering from injury. Deliberately separate from `Exercise`
/// (which models load/sets/reps for strength training) since the relevant
/// fields here — body region, hold time, pain guidance — don't map onto it.
struct RehabExercise: Codable, Identifiable, Hashable {
    enum BodyRegion: String, Codable, CaseIterable, Identifiable {
        case shoulder
        case elbow
        case wrist
        case knee
        case ankle
        case hip
        case lowerBack
        case neck

        var id: String { rawValue }

        var title: RehabLocalizedText {
            switch self {
            case .shoulder: RehabLocalizedText(key: "rehab_shoulder")
            case .elbow: RehabLocalizedText(key: "rehab_elbow")
            case .wrist: RehabLocalizedText(key: "rehab_wrist")
            case .knee: RehabLocalizedText(key: "rehab_knee")
            case .ankle: RehabLocalizedText(key: "rehab_ankle_achilles")
            case .hip: RehabLocalizedText(key: "rehab_hip")
            case .lowerBack: RehabLocalizedText(key: "rehab_lower_back")
            case .neck: RehabLocalizedText(key: "rehab_neck")
            }
        }

        var systemImage: String {
            switch self {
            case .shoulder: "figure.arms.open"
            case .elbow, .wrist: "hand.raised.fingers.spread"
            case .knee: "figure.walk"
            case .ankle: "shoeprints.fill"
            case .hip: "figure.core.training"
            case .lowerBack: "figure.flexibility"
            case .neck: "person.bust"
            }
        }

        /// Reuses the app's existing `MuscleGroupAnatomyThumbnail` (built on
        /// the bundled `MuscleMap` SPM package) instead of any bespoke or
        /// downloaded artwork — the free-text keyword it already parses.
        var anatomyMuscleGroupKeyword: String {
            switch self {
            case .shoulder: "shoulder"
            case .elbow, .wrist: "forearm"
            case .knee: "quadriceps"
            case .ankle: "calf"
            case .hip: "glute"
            case .lowerBack: "lower back"
            case .neck: "neck"
            }
        }
    }

    enum StructureFocus: String, Codable, CaseIterable, Identifiable {
        case tendon
        case joint
        case muscle

        var id: String { rawValue }

        var title: RehabLocalizedText {
            switch self {
            case .tendon: RehabLocalizedText(key: "rehab_tendon")
            case .joint: RehabLocalizedText(key: "rehab_joint")
            case .muscle: RehabLocalizedText(key: "rehab_muscle")
            }
        }

        var systemImage: String {
            switch self {
            case .tendon: "bolt.horizontal"
            case .joint: "circle.hexagongrid"
            case .muscle: "figure.strengthtraining.functional"
            }
        }
    }

    enum ProtocolType: String, Codable, CaseIterable, Identifiable {
        case isometricHold
        case eccentric
        case mobility
        case activation
        case stretch

        var id: String { rawValue }

        var title: RehabLocalizedText {
            switch self {
            case .isometricHold: RehabLocalizedText(key: "rehab_isometric_hold")
            case .eccentric: RehabLocalizedText(key: "rehab_eccentric_loading")
            case .mobility: RehabLocalizedText(key: "rehab_controlled_mobility")
            case .activation: RehabLocalizedText(key: "rehab_muscle_activation")
            case .stretch: RehabLocalizedText(key: "rehab_stretch")
            }
        }
    }

    enum RecoveryStage: String, Codable, CaseIterable, Identifiable {
        case acute
        case subacute
        case returnToActivity

        var id: String { rawValue }

        var title: RehabLocalizedText {
            switch self {
            case .acute: RehabLocalizedText(key: "rehab_acute_phase")
            case .subacute: RehabLocalizedText(key: "rehab_subacute_phase")
            case .returnToActivity: RehabLocalizedText(key: "rehab_return_to_activity")
            }
        }
    }

    var id: UUID
    var name: RehabLocalizedText
    var bodyRegion: BodyRegion
    var structureFocus: StructureFocus
    var protocolType: ProtocolType
    var stage: RecoveryStage
    var sets: Int
    /// `nil` when the exercise is timed only (isometric holds use `holdSeconds` instead).
    var reps: Int?
    var holdSeconds: Int?
    var restSeconds: Int
    var instructions: [RehabLocalizedText]
    var painGuidance: RehabLocalizedText
    var cautions: [RehabLocalizedText]
    /// One-line evidence basis for the protocol (not a verbatim citation, just
    /// an attribution of the underlying principle).
    var referenceNote: RehabLocalizedText
}

/// A logged execution of a `RehabExercise` — the "History" tab in the
/// exercise detail view. Kept separate from `SetLog`/`ExerciseLog` since it
/// tracks pain, not load.
struct RehabSessionLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var rehabExerciseID: UUID
    var date: Date = .now
    var setsCompleted: Int
    var painLevel: Int
    var notes: String?
}
