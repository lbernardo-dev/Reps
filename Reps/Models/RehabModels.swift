import Foundation

/// A small en/es pair for rehab catalog content. The rehab catalog is static,
/// bundled, curated copy (not user data), so it is kept out of
/// `Localizable.xcstrings` and resolved the same way `RepsText` resolves
/// muscle/equipment names: by switching on `preferredLanguage` at read time.
struct RehabLocalizedText: Codable, Hashable {
    var en: String
    var es: String

    func resolved(language: String) -> String {
        language.hasPrefix("es") ? es : en
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
            case .shoulder: RehabLocalizedText(en: "Shoulder", es: "Hombro")
            case .elbow: RehabLocalizedText(en: "Elbow", es: "Codo")
            case .wrist: RehabLocalizedText(en: "Wrist", es: "Muñeca")
            case .knee: RehabLocalizedText(en: "Knee", es: "Rodilla")
            case .ankle: RehabLocalizedText(en: "Ankle / Achilles", es: "Tobillo / Aquiles")
            case .hip: RehabLocalizedText(en: "Hip", es: "Cadera")
            case .lowerBack: RehabLocalizedText(en: "Lower back", es: "Lumbar")
            case .neck: RehabLocalizedText(en: "Neck", es: "Cuello")
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
            case .tendon: RehabLocalizedText(en: "Tendon", es: "Tendón")
            case .joint: RehabLocalizedText(en: "Joint", es: "Articulación")
            case .muscle: RehabLocalizedText(en: "Muscle", es: "Músculo")
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
            case .isometricHold: RehabLocalizedText(en: "Isometric hold", es: "Isométrico mantenido")
            case .eccentric: RehabLocalizedText(en: "Eccentric loading", es: "Carga excéntrica")
            case .mobility: RehabLocalizedText(en: "Controlled mobility", es: "Movilidad controlada")
            case .activation: RehabLocalizedText(en: "Muscle activation", es: "Activación muscular")
            case .stretch: RehabLocalizedText(en: "Stretch", es: "Estiramiento")
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
            case .acute: RehabLocalizedText(en: "Acute phase", es: "Fase aguda")
            case .subacute: RehabLocalizedText(en: "Subacute phase", es: "Fase subaguda")
            case .returnToActivity: RehabLocalizedText(en: "Return to activity", es: "Vuelta a la actividad")
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
