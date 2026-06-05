import MuscleMap
import SwiftUI

struct ExerciseAnatomyThumbnail: View {
    let exercise: Exercise
    var gender: BodyGender = .male
    var size: CGFloat = 72

    private var descriptor: ExerciseAnatomyDescriptor {
        ExerciseAnatomyDescriptor(exercise: exercise)
    }

    var body: some View {
        Group {
            if descriptor.muscles.isEmpty {
                cardioFallback
            } else {
                AnatomyThumbnailCanvas(
                    gender: gender,
                    primarySide: descriptor.region.side,
                    muscles: descriptor.muscles,
                    minimumIntensity: 0.62
                )
            }
        }
        .frame(width: size, height: size)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: min(18, size * 0.22), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: min(18, size * 0.22), style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
        .accessibilityLabel("Musculos trabajados por \(exercise.name)")
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
    var gender: BodyGender = .male
    var size: CGFloat = 58
    var intensity: Double = 1

    private var descriptor: ExerciseAnatomyDescriptor {
        ExerciseAnatomyDescriptor(muscleGroup: muscleGroup, secondaryMuscles: [])
    }

    var body: some View {
        AnatomyThumbnailCanvas(
            gender: gender,
            primarySide: descriptor.region.side,
            muscles: descriptor.muscles,
            minimumIntensity: max(0.35, min(intensity, 1))
        )
        .frame(width: size, height: size)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: min(16, size * 0.25), style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct AnatomyThumbnailCanvas: View {
    let gender: BodyGender
    let primarySide: BodySide
    let muscles: [Muscle]
    var minimumIntensity: Double = 0.55

    var body: some View {
        HStack(spacing: 0) {
            BodyView(gender: gender, side: primarySide, style: .thumbnailAnatomy)
                .heatmap(heatmap, configuration: .thumbnailAnatomy)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            BodyView(gender: gender, side: primarySide == .front ? .back : .front, style: .thumbnailAnatomy)
                .heatmap(heatmap, configuration: .thumbnailAnatomy)
                .opacity(0.42)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .padding(6)
        .clipped()
    }

    private var heatmap: [MuscleIntensity] {
        muscles.map { MuscleIntensity(muscle: $0, intensity: minimumIntensity) }
    }
}

struct ExerciseAnatomyDescriptor {
    let muscles: [Muscle]
    let region: AnatomyRegion

    init(exercise: Exercise) {
        self.init(
            muscleGroup: exercise.muscleGroup,
            secondaryMuscles: exercise.secondaryMuscles + exercise.tags + [exercise.name, exercise.instructions ?? ""]
        )
    }

    init(muscleGroup: String, secondaryMuscles: [String]) {
        let text = ([muscleGroup] + secondaryMuscles).joined(separator: " ").lowercased()
        let focus = ExerciseAnatomyFocus(text: text)
        muscles = focus.muscles
        region = focus.region
    }
}

struct AnatomyRegion {
    let side: BodySide
    let scale: CGFloat
    let anchor: UnitPoint
    let offset: CGSize
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
    case shoulders
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

    init(text: String) {
        if text.contains("cardio") || text.contains("run") || text.contains("bike") || text.contains("rower") {
            self = .cardio
        } else if text.contains("upper body") || text.contains("superior") || text.contains("torso") {
            self = .upperBody
        } else if text.contains("full") {
            self = .fullBody
        } else if text.contains("tricep") || text.contains("pushdown") || text.contains("skullcrusher") || text.contains("skull crusher") {
            self = .triceps
        } else if text.contains("forearm") || text.contains("wrist") {
            self = .forearms
        } else if text.contains("leg curl") || text.contains("hamstring curl") || text.contains("hamstring") || text.contains("romanian") || text.contains("stiff-leg") {
            self = .hamstrings
        } else if text.contains("leg extension") || text.contains("quad") {
            self = .quadriceps
        } else if text.contains("calf") {
            self = .calves
        } else if text.contains("adductor") || text.contains("abductor") {
            self = .adductors
        } else if text.contains("hip flexor") || text.contains("psoas") {
            self = .hipFlexors
        } else if text.contains("glute") || text.contains("hip thrust") {
            self = .glutes
        } else if text.contains("oblique") || text.contains("twist") || text.contains("side plank") {
            self = .obliques
        } else if text.contains("core") || text.contains("ab") || text.contains("crunch") || text.contains("sit-up") || text.contains("plank") || text.contains("climber") {
            self = .core
        } else if text.contains("bicep") || text.contains("curl") {
            self = .biceps
        } else if text.contains("shoulder") || text.contains("delt") || text.contains("overhead") || text.contains("face pull") {
            self = .shoulders
        } else if text.contains("lower back") || text.contains("lumbar") || text.contains("hyperextension") || text.contains("back extension") {
            self = .lowerBack
        } else if text.contains("trap") || text.contains("shrug") {
            self = .traps
        } else if text.contains("lat") || text.contains("pulldown") || text.contains("pull-up") || text.contains("pullup") {
            self = .lats
        } else if text.contains("back") || text.contains("row") || text.contains("pull") || text.contains("deadlift") {
            self = .back
        } else if text.contains("upper chest") || text.contains("incline") {
            self = .chestUpper
        } else if text.contains("lower chest") || text.contains("decline") {
            self = .chestLower
        } else if text.contains("chest") || text.contains("press") || text.contains("push") {
            self = .chest
        } else if text.contains("leg") || text.contains("squat") || text.contains("lunge") {
            self = .legs
        } else if text.contains("arm") {
            self = .upperBody
        } else {
            self = .fullBody
        }
    }

    var muscles: [Muscle] {
        switch self {
        case .upperBody:
            [.chest, .upperChest, .upperBack, .deltoids, .frontDeltoid, .rearDeltoid, .triceps, .biceps, .abs]
        case .chest:
            [.chest, .upperChest, .lowerChest, .frontDeltoid, .triceps]
        case .chestUpper:
            [.upperChest, .frontDeltoid, .triceps]
        case .chestLower:
            [.lowerChest, .triceps]
        case .back:
            [.upperBack, .rhomboids, .trapezius, .lowerBack, .biceps]
        case .lats:
            [.upperBack, .rhomboids, .biceps]
        case .traps:
            [.trapezius, .upperTrapezius, .lowerTrapezius]
        case .lowerBack:
            [.lowerBack]
        case .shoulders:
            [.deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff, .upperTrapezius]
        case .biceps:
            [.biceps]
        case .triceps:
            [.triceps]
        case .forearms:
            [.forearm]
        case .legs:
            [.quadriceps, .innerQuad, .outerQuad, .hamstring, .calves, .adductors]
        case .quadriceps:
            [.quadriceps, .innerQuad, .outerQuad]
        case .hamstrings:
            [.hamstring, .gluteal]
        case .calves:
            [.calves, .tibialis]
        case .adductors:
            [.adductors]
        case .hipFlexors:
            [.hipFlexors]
        case .glutes:
            [.gluteal, .hamstring]
        case .core:
            [.abs, .upperAbs, .lowerAbs, .obliques, .serratus]
        case .obliques:
            [.obliques, .serratus]
        case .fullBody:
            [.chest, .upperBack, .deltoids, .quadriceps, .gluteal, .abs]
        case .cardio:
            []
        }
    }

    var region: AnatomyRegion {
        switch self {
        case .upperBody:
            AnatomyRegion(side: .front, scale: 2.05, anchor: .center, offset: CGSize(width: 0, height: 0.22))
        case .chest, .chestUpper, .chestLower:
            AnatomyRegion(side: .front, scale: 2.55, anchor: .center, offset: CGSize(width: 0, height: 0.29))
        case .back, .lats, .traps, .lowerBack:
            AnatomyRegion(side: .back, scale: 2.45, anchor: .center, offset: CGSize(width: 0, height: 0.25))
        case .shoulders:
            AnatomyRegion(side: .front, scale: 2.50, anchor: .center, offset: CGSize(width: 0, height: 0.28))
        case .biceps, .triceps, .forearms:
            AnatomyRegion(side: .front, scale: 2.15, anchor: .center, offset: CGSize(width: 0, height: 0.12))
        case .legs, .quadriceps, .hamstrings, .calves, .adductors, .hipFlexors:
            AnatomyRegion(side: .front, scale: 1.90, anchor: .bottom, offset: CGSize(width: 0, height: -0.08))
        case .glutes:
            AnatomyRegion(side: .back, scale: 2.05, anchor: .bottom, offset: CGSize(width: 0, height: -0.24))
        case .core, .obliques:
            AnatomyRegion(side: .front, scale: 2.20, anchor: .center, offset: CGSize(width: 0, height: -0.03))
        case .fullBody:
            AnatomyRegion(side: .front, scale: 1.55, anchor: .center, offset: CGSize(width: 0, height: 0))
        case .cardio:
            AnatomyRegion(side: .front, scale: 1, anchor: .center, offset: .zero)
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
        defaultFillColor: Color.white.opacity(0.13),
        strokeColor: Color.black.opacity(0.58),
        strokeWidth: 0.8,
        selectionColor: PulseTheme.primary,
        selectionStrokeColor: PulseTheme.primary,
        selectionStrokeWidth: 1,
        headColor: Color.white.opacity(0.18),
        hairColor: Color.white.opacity(0.08)
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
        PulseTheme.primaryBright,
        PulseTheme.accent
    ])
}
