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
        self.init(muscleGroup: exercise.muscleGroup, secondaryMuscles: exercise.secondaryMuscles + exercise.tags + [exercise.name])
    }

    init(muscleGroup: String, secondaryMuscles: [String]) {
        let text = ([muscleGroup] + secondaryMuscles).joined(separator: " ").lowercased()
        let group = ExerciseAnatomyGroup(text: text)
        muscles = group.muscles
        region = group.region
    }
}

struct AnatomyRegion {
    let side: BodySide
    let scale: CGFloat
    let anchor: UnitPoint
    let offset: CGSize
}

private enum ExerciseAnatomyGroup {
    case upperBody
    case chest
    case back
    case shoulders
    case arms
    case legs
    case glutes
    case core
    case fullBody
    case cardio

    init(text: String) {
        if text.contains("cardio") || text.contains("run") || text.contains("bike") || text.contains("rower") {
            self = .cardio
        } else if text.contains("upper") || text.contains("superior") || text.contains("torso") {
            self = .upperBody
        } else if text.contains("full") {
            self = .fullBody
        } else if text.contains("glute") || text.contains("hip thrust") {
            self = .glutes
        } else if text.contains("leg") || text.contains("quad") || text.contains("hamstring") || text.contains("calf") || text.contains("squat") || text.contains("lunge") {
            self = .legs
        } else if text.contains("core") || text.contains("ab") || text.contains("plank") || text.contains("climber") {
            self = .core
        } else if text.contains("arm") || text.contains("bicep") || text.contains("tricep") || text.contains("curl") || text.contains("extension") {
            self = .arms
        } else if text.contains("shoulder") || text.contains("delt") || text.contains("overhead") || text.contains("face pull") {
            self = .shoulders
        } else if text.contains("back") || text.contains("lat") || text.contains("row") || text.contains("pull") || text.contains("deadlift") {
            self = .back
        } else if text.contains("chest") || text.contains("press") || text.contains("push") {
            self = .chest
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
        case .back:
            [.upperBack, .rhomboids, .trapezius, .lowerBack, .biceps]
        case .shoulders:
            [.deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff, .upperTrapezius]
        case .arms:
            [.biceps, .triceps, .forearm]
        case .legs:
            [.quadriceps, .innerQuad, .outerQuad, .hamstring, .calves, .adductors]
        case .glutes:
            [.gluteal, .hamstring]
        case .core:
            [.abs, .upperAbs, .lowerAbs, .obliques, .serratus]
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
        case .chest:
            AnatomyRegion(side: .front, scale: 2.55, anchor: .center, offset: CGSize(width: 0, height: 0.29))
        case .back:
            AnatomyRegion(side: .back, scale: 2.45, anchor: .center, offset: CGSize(width: 0, height: 0.25))
        case .shoulders:
            AnatomyRegion(side: .front, scale: 2.50, anchor: .center, offset: CGSize(width: 0, height: 0.28))
        case .arms:
            AnatomyRegion(side: .front, scale: 2.15, anchor: .center, offset: CGSize(width: 0, height: 0.12))
        case .legs:
            AnatomyRegion(side: .front, scale: 1.90, anchor: .bottom, offset: CGSize(width: 0, height: -0.08))
        case .glutes:
            AnatomyRegion(side: .back, scale: 2.05, anchor: .bottom, offset: CGSize(width: 0, height: -0.24))
        case .core:
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
