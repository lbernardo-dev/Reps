import MuscleMap
import SwiftUI
import UIKit

struct ExerciseAnatomyThumbnail: View {
    let exercise: Exercise
    let gender: BodyGender
    let size: CGFloat
    private let descriptor: ExerciseAnatomyDescriptor
    @State private var renderedImage: UIImage?

    init(exercise: Exercise, gender: BodyGender = .male, size: CGFloat = 72) {
        self.exercise = exercise
        self.gender = gender
        self.size = size
        self.descriptor = ExerciseAnatomyDescriptor(exercise: exercise)
    }

    var body: some View {
        Group {
            if descriptor.muscles.isEmpty {
                cardioFallback
            } else if let image = renderedImage ?? AnatomyThumbnailImageCache.shared.image(for: cacheKey) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AnatomyThumbnailCanvas(
                    gender: gender,
                    primarySide: descriptor.region.side,
                    region: descriptor.region,
                    intensities: descriptor.thumbnailHeatmap
                )
            }
        }
        .frame(width: size, height: size)
        .background(anatomyThumbnailBackground)
        .clipShape(RoundedRectangle(cornerRadius: min(16, size * 0.20), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: min(16, size * 0.20), style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizedFormat("anatomy_muscles_accessibility_format", exercise.name))
        .onAppear {
            guard renderedImage == nil, !descriptor.muscles.isEmpty else { return }
            renderedImage = AnatomyThumbnailImageCache.shared.render(
                key: cacheKey,
                gender: gender,
                primarySide: descriptor.region.side,
                region: descriptor.region,
                size: size,
                intensities: descriptor.thumbnailHeatmap
            )
        }
    }

    private var cacheKey: String {
        return "v7-\(exercise.id.uuidString)-\(gender)-\(Int(size.rounded()))-\(descriptor.region.side)-\(descriptor.cacheKey)"
    }

    private var cardioFallback: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(PulseTheme.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PulseTheme.primary.opacity(0.12))
    }
}

struct MuscleGroupAnatomyThumbnail: View {
    let muscleGroup: String
    var exerciseName: String = ""
    var gender: BodyGender = .male
    var size: CGFloat = 58
    var intensity: Double = 1

    private var descriptor: ExerciseAnatomyDescriptor {
        ExerciseAnatomyDescriptor(muscleGroup: muscleGroup, exerciseName: exerciseName, secondaryMuscles: [])
    }

    var body: some View {
        AnatomyThumbnailCanvas(
            gender: gender,
            primarySide: descriptor.region.side,
            region: descriptor.region,
            intensities: descriptor.thumbnailHeatmap(primaryIntensity: max(0.35, min(intensity, 1)))
        )
        .frame(width: size, height: size)
        .background(anatomyThumbnailBackground)
        .clipShape(RoundedRectangle(cornerRadius: min(16, size * 0.25), style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct AnatomyThumbnailCanvas: View {
    let gender: BodyGender
    let primarySide: BodySide
    let region: AnatomyRegion
    let intensities: [MuscleIntensity]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BodyView(gender: gender, side: primarySide == .front ? .back : .front, style: .thumbnailAnatomy)
                    .heatmap(heatmap, configuration: .thumbnailAnatomy)
                    .showSubGroups()
                    .opacity(0.22)
                    .frame(width: proxy.size.width * 0.92, height: proxy.size.height * 1.05)
                    .scaleEffect(max(effectiveScale * 0.86, 1.14), anchor: region.anchor)
                    .offset(x: -proxy.size.width * 0.30, y: proxy.size.height * (region.offset.height + 0.01))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                BodyView(gender: gender, side: primarySide, style: .thumbnailAnatomy)
                    .heatmap(heatmap, configuration: .thumbnailAnatomy)
                    .showSubGroups()
                    .frame(width: proxy.size.width * 0.94, height: proxy.size.height * 1.05)
                    .scaleEffect(effectiveScale, anchor: region.anchor)
                    .offset(x: proxy.size.width * (0.18 + region.offset.width), y: proxy.size.height * region.offset.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var effectiveScale: CGFloat {
        min(max(region.scale, 1.28), 3.18)
    }

    private var heatmap: [MuscleIntensity] {
        intensities
    }
}

@MainActor
private final class AnatomyThumbnailImageCache {
    static let shared = AnatomyThumbnailImageCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func render(
        key: String,
        gender: BodyGender,
        primarySide: BodySide,
        region: AnatomyRegion,
        size: CGFloat,
        intensities: [MuscleIntensity]
    ) -> UIImage? {
        let nsKey = key as NSString
        if let image = cache.object(forKey: nsKey) {
            return image
        }

        let content = AnatomyThumbnailCanvas(
            gender: gender,
            primarySide: primarySide,
            region: region,
            intensities: intensities
        )
        .frame(width: size, height: size)
        .background(anatomyThumbnailBackground)

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else {
            return nil
        }
        cache.setObject(image, forKey: nsKey)
        return image
    }
}

struct ExerciseAnatomyDescriptor {
    let primaryMuscles: [Muscle]
    let secondaryMuscles: [Muscle]
    let muscles: [Muscle]
    let region: AnatomyRegion

    init(exercise: Exercise) {
        let primaryFocus = ExerciseAnatomyFocus(exerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
        let secondaryMuscles = exercise.secondaryMuscles.flatMap { secondary in
            ExerciseAnatomyFocus(exerciseName: exercise.name, muscleGroup: secondary).secondaryMuscles(forPrimary: primaryFocus)
        }
        self.primaryMuscles = primaryFocus.primaryMuscles
        self.secondaryMuscles = Self.unique(secondaryMuscles).filter { !primaryFocus.primaryMuscles.contains($0) }
        muscles = Self.unique(self.primaryMuscles + self.secondaryMuscles)
        region = primaryFocus.region
    }

    init(muscleGroup: String, secondaryMuscles: [String]) {
        self.init(muscleGroup: muscleGroup, exerciseName: "", secondaryMuscles: secondaryMuscles)
    }

    init(muscleGroup: String, exerciseName: String, secondaryMuscles: [String]) {
        let focus = ExerciseAnatomyFocus(muscleGroupOnly: muscleGroup)
        let contextualFocus = ExerciseAnatomyFocus(exerciseName: exerciseName, muscleGroup: muscleGroup)
        let primaryFocus = exerciseName.isEmpty ? focus : contextualFocus
        let secondary = secondaryMuscles.flatMap { ExerciseAnatomyFocus(exerciseName: exerciseName, muscleGroup: $0).secondaryMuscles(forPrimary: primaryFocus) }
        self.primaryMuscles = primaryFocus.primaryMuscles
        self.secondaryMuscles = Self.unique(secondary).filter { !primaryFocus.primaryMuscles.contains($0) }
        muscles = Self.unique(self.primaryMuscles + self.secondaryMuscles)
        region = primaryFocus.region
    }

    var cacheKey: String {
        let primary = primaryMuscles.map { String(describing: $0) }.joined(separator: "-")
        let secondary = secondaryMuscles.map { String(describing: $0) }.joined(separator: "-")
        return "p:\(primary)|s:\(secondary)"
    }

    var thumbnailHeatmap: [MuscleIntensity] {
        thumbnailHeatmap(primaryIntensity: 0.92)
    }

    func thumbnailHeatmap(primaryIntensity: Double) -> [MuscleIntensity] {
        let secondaryIntensity = min(primaryIntensity * 0.42, 0.36)
        return primaryMuscles.map {
            MuscleIntensity(muscle: $0, intensity: primaryIntensity, color: PulseTheme.primaryBright)
        } + secondaryMuscles.map {
            MuscleIntensity(muscle: $0, intensity: secondaryIntensity, color: PulseTheme.primary.opacity(0.40))
        }
    }

    private static func unique(_ muscles: [Muscle]) -> [Muscle] {
        var seen = Set<Muscle>()
        return muscles.filter { seen.insert($0).inserted }
    }
}

struct AnatomyRegion {
    let side: BodySide
    let scale: CGFloat
    let anchor: UnitPoint
    let offset: CGSize
}

struct AnatomyViewport {
    let scale: CGFloat
    let anchor: UnitPoint
    let offset: CGSize
}

enum AnatomyRegionFocus {
    case upperBody
    case chest
    case back
    case traps
    case upperBack
    case lowerBack
    case neck
    case shoulders
    case arms
    case legs
    case quads
    case hamstrings
    case calves
    case adductors
    case glutes
    case core
    case fullBody
    case cardio

    var side: BodySide {
        switch self {
        case .back, .traps, .upperBack, .lowerBack, .hamstrings, .calves, .glutes:
            .back
        default:
            .front
        }
    }

    var thumbnail: AnatomyViewport {
        switch self {
        case .upperBody:
            AnatomyViewport(scale: 2.24, anchor: .center, offset: CGSize(width: -0.01, height: 0.22))
        case .chest:
            AnatomyViewport(scale: 2.90, anchor: .center, offset: CGSize(width: -0.02, height: 0.30))
        case .back, .traps, .upperBack:
            AnatomyViewport(scale: 2.82, anchor: .center, offset: CGSize(width: -0.02, height: 0.25))
        case .lowerBack:
            AnatomyViewport(scale: 2.62, anchor: .center, offset: CGSize(width: -0.02, height: 0.08))
        case .neck:
            AnatomyViewport(scale: 2.95, anchor: .top, offset: CGSize(width: -0.02, height: 0.48))
        case .shoulders:
            AnatomyViewport(scale: 2.82, anchor: .center, offset: CGSize(width: -0.02, height: 0.28))
        case .arms:
            AnatomyViewport(scale: 2.72, anchor: .center, offset: CGSize(width: 0.02, height: 0.15))
        case .legs:
            AnatomyViewport(scale: 2.08, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.10))
        case .quads, .adductors:
            AnatomyViewport(scale: 2.58, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.58))
        case .hamstrings:
            AnatomyViewport(scale: 2.58, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.54))
        case .calves:
            AnatomyViewport(scale: 2.42, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.14))
        case .glutes:
            AnatomyViewport(scale: 3.04, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.98))
        case .core:
            AnatomyViewport(scale: 2.62, anchor: .center, offset: CGSize(width: -0.02, height: 0.00))
        case .fullBody:
            AnatomyViewport(scale: 1.72, anchor: .center, offset: CGSize(width: -0.01, height: 0.01))
        case .cardio:
            AnatomyViewport(scale: 1, anchor: .center, offset: .zero)
        }
    }

    var hero: AnatomyViewport {
        switch self {
        case .chest:
            AnatomyViewport(scale: 1.54, anchor: .center, offset: CGSize(width: -0.02, height: 0.20))
        case .back, .traps, .upperBack, .shoulders:
            AnatomyViewport(scale: 1.48, anchor: .center, offset: CGSize(width: -0.02, height: 0.18))
        case .lowerBack:
            AnatomyViewport(scale: 1.48, anchor: .center, offset: CGSize(width: -0.02, height: 0.12))
        case .arms:
            AnatomyViewport(scale: 1.50, anchor: .center, offset: CGSize(width: 0.00, height: 0.12))
        case .core:
            AnatomyViewport(scale: 1.56, anchor: .center, offset: CGSize(width: -0.02, height: 0.02))
        case .quads, .adductors:
            AnatomyViewport(scale: 1.48, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.04))
        case .hamstrings:
            AnatomyViewport(scale: 1.48, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.00))
        case .calves:
            AnatomyViewport(scale: 1.54, anchor: .bottom, offset: CGSize(width: -0.02, height: -0.08))
        case .glutes:
            AnatomyViewport(scale: 1.62, anchor: .bottom, offset: CGSize(width: -0.02, height: 0.22))
        case .upperBody, .neck, .legs, .fullBody, .cardio:
            thumbnail
        }
    }

    var anatomyRegion: AnatomyRegion {
        let viewport = thumbnail
        return AnatomyRegion(side: side, scale: viewport.scale, anchor: viewport.anchor, offset: viewport.offset)
    }
}

private enum ExerciseAnatomyFocus {
    case upperBody
    case chest
    case chestUpper
    case chestLower
    case back
    case lats
    case traps
    case lowerBack
    case neck
    case shoulders
    case arms
    case biceps
    case triceps
    case forearms
    case legs
    case quadriceps
    case hamstrings
    case calves
    case adductors
    case hipFlexors
    case glutes
    case core
    case obliques
    case fullBody
    case cardio

    init(exerciseName: String, muscleGroup: String) {
        let name = Self.normalized(exerciseName)
        let group = Self.normalized(muscleGroup)

        if Self.hasAny(group, ["cardio"]) || Self.hasAny(name, ["run", "bike", "rower", "treadmill"]) {
            self = .cardio
        } else if Self.hasAny(group, ["upper body", "superior", "torso"]) {
            self = .upperBody
        } else if Self.hasAny(group, ["full", "cuerpo completo"]) {
            self = .fullBody
        } else if Self.hasAny(group, ["chest", "pec", "pecho"]) {
            if Self.hasAny(name, ["incline", "inclinado", "upper chest"]) {
                self = .chestUpper
            } else if Self.hasAny(name, ["decline", "declinado", "lower chest"]) {
                self = .chestLower
            } else {
                self = .chest
            }
        } else if Self.hasAny(group, ["arm", "brazo", "brazos"]) {
            if Self.hasAny(name, ["tricep", "triceps", "pushdown", "skullcrusher", "skull crusher", "extension", "press", "push", "dip"]) {
                self = .triceps
            } else if Self.hasAny(name, ["bicep", "biceps", "curl", "row", "remo", "pull-up", "pullup", "pulldown"]) {
                self = .biceps
            } else if Self.hasAny(name, ["forearm", "antebrazo", "wrist", "muneca"]) {
                self = .forearms
            } else {
                self = .arms
            }
        } else if Self.hasAny(group, ["shoulder", "delt", "hombro", "hombros", "deltoide"]) {
            self = .shoulders
        } else if Self.hasAny(group, ["back", "espalda", "lat", "dorsal"]) {
            if Self.hasAny(name, ["deadlift", "hinge", "peso muerto"]) {
                self = .lowerBack
            } else if Self.hasAny(name, ["shrug", "encogimiento"]) {
                self = .traps
            } else if Self.hasAny(name, ["pulldown", "pull-up", "pullup", "dominada", "lat"]) {
                self = .lats
            } else {
                self = .back
            }
        } else if Self.hasAny(group, ["trap", "trapecio"]) {
            self = .traps
        } else if Self.hasAny(group, ["lower back", "lumbar"]) {
            self = .lowerBack
        } else if Self.hasAny(group, ["neck", "cuello"]) {
            self = .neck
        } else if Self.hasAny(group, ["leg", "pierna", "piernas"]) {
            if Self.hasAny(name, ["leg extension", "extension de pierna", "extension de piernas", "quad", "cuadriceps"]) {
                self = .quadriceps
            } else if Self.hasAny(name, ["leg curl", "hamstring curl", "hamstring", "romanian", "stiff-leg", "isquio"]) {
                self = .hamstrings
            } else if Self.hasAny(name, ["calf", "gemelo", "pantorrilla"]) {
                self = .calves
            } else if Self.hasAny(name, ["abductor"]) {
                self = .glutes
            } else if Self.hasAny(name, ["adductor", "aductor"]) {
                self = .adductors
            } else {
                self = .legs
            }
        } else if Self.hasAny(group, ["quad", "cuadriceps"]) {
            self = .quadriceps
        } else if Self.hasAny(group, ["hamstring", "isquio"]) {
            self = .hamstrings
        } else if Self.hasAny(group, ["calf", "gemelo", "pantorrilla"]) {
            self = .calves
        } else if Self.hasAny(group, ["abductor"]) {
            self = .glutes
        } else if Self.hasAny(group, ["adductor", "aductor"]) {
            self = .adductors
        } else if Self.hasAny(group, ["glute", "gluteo", "gluteos"]) {
            self = .glutes
        } else if Self.hasAny(group, ["core", "abs", "abdominal", "abdominales"]) {
            self = .core
        } else if Self.hasAny(group, ["oblique", "oblicuo"]) {
            self = .obliques
        } else {
            self.init(text: name)
        }
    }

    init(muscleGroupOnly muscleGroup: String) {
        self.init(exerciseName: "", muscleGroup: muscleGroup)
    }

    init(text: String) {
        let text = Self.normalized(text)
        if Self.hasAny(text, ["cardio", "run", "bike", "rower", "treadmill"]) {
            self = .cardio
        } else if Self.hasAny(text, ["upper body", "superior", "torso"]) {
            self = .upperBody
        } else if Self.hasAny(text, ["full", "cuerpo completo"]) {
            self = .fullBody
        } else if Self.hasAny(text, ["tricep", "triceps", "pushdown", "skullcrusher", "skull crusher"]) {
            self = .triceps
        } else if Self.hasAny(text, ["forearm", "antebrazo", "wrist", "muneca"]) {
            self = .forearms
        } else if Self.hasAny(text, ["leg curl", "hamstring curl", "hamstring", "romanian", "stiff-leg", "isquio"]) {
            self = .hamstrings
        } else if Self.hasAny(text, ["leg extension", "extension de pierna", "extension de piernas", "quad", "cuadriceps"]) {
            self = .quadriceps
        } else if Self.hasAny(text, ["calf", "gemelo", "pantorrilla"]) {
            self = .calves
        } else if Self.hasAny(text, ["abductor"]) {
            self = .glutes
        } else if Self.hasAny(text, ["adductor", "aductor"]) {
            self = .adductors
        } else if Self.hasAny(text, ["hip flexor", "psoas"]) {
            self = .hipFlexors
        } else if Self.hasAny(text, ["glute", "gluteo", "gluteos", "hip thrust"]) {
            self = .glutes
        } else if Self.hasAny(text, ["oblique", "oblicuo", "twist", "side plank"]) {
            self = .obliques
        } else if Self.hasAny(text, ["core", "abs", "abdominal", "abdominales", "crunch", "sit-up", "plank", "climber"]) {
            self = .core
        } else if Self.hasAny(text, ["bicep", "biceps", "curl"]) {
            self = .biceps
        } else if Self.hasAny(text, ["shoulder", "delt", "hombro", "hombros", "overhead", "face pull"]) {
            self = .shoulders
        } else if Self.hasAny(text, ["lower back", "lumbar", "hyperextension", "back extension"]) {
            self = .lowerBack
        } else if Self.hasAny(text, ["neck", "cuello"]) {
            self = .neck
        } else if Self.hasAny(text, ["trap", "trapecio", "shrug"]) {
            self = .traps
        } else if Self.hasAny(text, ["lat", "dorsal", "pulldown", "pull-up", "pullup"]) {
            self = .lats
        } else if Self.hasAny(text, ["back", "espalda", "row", "remo", "pull", "deadlift"]) {
            self = .back
        } else if Self.hasAny(text, ["upper chest", "incline", "inclinado"]) {
            self = .chestUpper
        } else if Self.hasAny(text, ["lower chest", "decline", "declinado"]) {
            self = .chestLower
        } else if Self.hasAny(text, ["chest", "pec", "pecho", "press", "push"]) {
            self = .chest
        } else if Self.hasAny(text, ["leg", "pierna", "squat", "sentadilla", "lunge"]) {
            self = .legs
        } else if Self.hasAny(text, ["arm", "brazo", "brazos"]) {
            self = .arms
        } else {
            self = .fullBody
        }
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func hasAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { term in
            text.range(of: normalized(term), options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var primaryMuscles: [Muscle] {
        switch self {
        case .upperBody:
            [.chest, .upperBack, .deltoids, .triceps, .biceps]
        case .chest:
            [.chest]
        case .chestUpper:
            [.upperChest]
        case .chestLower:
            [.lowerChest]
        case .back:
            [.upperBack, .rhomboids, .trapezius]
        case .lats:
            [.upperBack, .rhomboids]
        case .traps:
            [.trapezius]
        case .lowerBack:
            [.lowerBack]
        case .neck:
            [.neck]
        case .shoulders:
            [.deltoids, .frontDeltoid, .rearDeltoid]
        case .arms:
            [.biceps, .triceps, .forearm]
        case .biceps:
            [.biceps]
        case .triceps:
            [.triceps]
        case .forearms:
            [.forearm]
        case .legs:
            [.quadriceps, .hamstring, .gluteal]
        case .quadriceps:
            [.quadriceps]
        case .hamstrings:
            [.hamstring]
        case .calves:
            [.calves, .tibialis]
        case .adductors:
            [.adductors]
        case .hipFlexors:
            [.hipFlexors]
        case .glutes:
            [.gluteal]
        case .core:
            [.abs]
        case .obliques:
            [.obliques]
        case .fullBody:
            [.chest, .upperBack, .deltoids, .quadriceps, .gluteal, .abs]
        case .cardio:
            []
        }
    }

    var muscles: [Muscle] {
        primaryMuscles
    }

    func secondaryMuscles(forPrimary primary: ExerciseAnatomyFocus) -> [Muscle] {
        switch self {
        case .legs where primary == .glutes:
            [.hamstring, .quadriceps]
        case .core:
            [.abs, .obliques]
        case .arms where [.chest, .chestUpper, .chestLower, .shoulders].contains(primary):
            [.triceps]
        case .arms where [.back, .lats, .traps].contains(primary):
            [.biceps]
        case .shoulders where [.chest, .chestUpper, .chestLower].contains(primary):
            [.frontDeltoid, .deltoids]
        case .legs:
            [.quadriceps, .hamstring, .gluteal]
        case .glutes where primary == .legs:
            [.gluteal]
        default:
            primaryMuscles
        }
    }

    var region: AnatomyRegion {
        regionFocus.anatomyRegion
    }

    private var regionFocus: AnatomyRegionFocus {
        switch self {
        case .upperBody: .upperBody
        case .chest, .chestUpper, .chestLower: .chest
        case .back, .lats: .back
        case .traps: .traps
        case .lowerBack: .lowerBack
        case .neck: .neck
        case .shoulders: .shoulders
        case .arms, .biceps, .triceps, .forearms: .arms
        case .legs: .legs
        case .quadriceps, .hipFlexors: .quads
        case .hamstrings: .hamstrings
        case .calves: .calves
        case .adductors: .adductors
        case .glutes: .glutes
        case .core, .obliques: .core
        case .fullBody: .fullBody
        case .cardio: .cardio
        }
    }
}

extension UserProfile {
    var muscleMapGender: BodyGender {
        sex == .female ? .female : .male
    }
}

private extension BodyViewStyle {
    static let thumbnailAnatomy = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.22),
        strokeColor: Color.white.opacity(0.24),
        strokeWidth: 0.7,
        selectionColor: PulseTheme.primaryBright,
        selectionStrokeColor: PulseTheme.primaryBright,
        selectionStrokeWidth: 1.1,
        headColor: Color.white.opacity(0.26),
        hairColor: Color.white.opacity(0.16)
    )
}

private extension HeatmapConfiguration {
    static let thumbnailAnatomy = HeatmapConfiguration(
        colorScale: .repsThumbnail,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.60
    )
}

private extension HeatmapColorScale {
    static let repsThumbnail = HeatmapColorScale(colors: [
        PulseTheme.primary,
        PulseTheme.primary.opacity(0.92),
        PulseTheme.primaryBright
    ])
}

private var anatomyThumbnailBackground: some ShapeStyle {
    LinearGradient(
        colors: [
            Color(red: 0.11, green: 0.12, blue: 0.14),
            Color(red: 0.04, green: 0.05, blue: 0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
