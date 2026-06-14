import MuscleMap
import SwiftUI

// MARK: - Shared zone semantics

/// Single source of truth for the weekly-volume zones used across Progress, the
/// active workout and the finish summary. Blue (maintaining) → green (growing) → yellow (focus).
enum MuscleZone: CaseIterable, Identifiable {
    case maintaining
    case growing
    case focus

    var id: String { String(describing: self) }

    init(sets: Double) {
        switch sets {
        case ..<4: self = .maintaining
        case 4..<10: self = .growing
        default: self = .focus
        }
    }

    var color: Color {
        switch self {
        case .maintaining: PulseTheme.primary
        case .growing: PulseTheme.growth
        case .focus: PulseTheme.warning
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .maintaining: "zone_maintaining"
        case .growing: "zone_growing"
        case .focus: "zone_focus"
        }
    }
}

extension MuscleLoad {
    var zone: MuscleZone { MuscleZone(sets: totalSets) }
}

// MARK: - Per-exercise weekly volume

/// Weekly-set context for one exercise: how many sets its primary muscle has seen this
/// rolling week (prior sessions + the live session), and how many this exercise contributes now.
struct ExerciseWeeklyVolume {
    let segment: MuscleSegment
    let weeklySets: Double
    let sessionDelta: Int

    var muscleTitle: String { segment.title }
    var load: MuscleLoad {
        MuscleLoad(segment: segment, actualSets: weeklySets, predictedSets: 0, totalVolumeKg: 0)
    }
}

enum MuscleVolumeService {
    /// Combines completed history (not yet including the live draft) with the in-progress
    /// drafts so the in-workout strip updates live as sets are checked off.
    static func weeklyVolume(
        for exercise: Exercise,
        completedSessions: [WorkoutSession],
        activeDrafts: [ExerciseSessionDraft],
        startDate: Date
    ) -> ExerciseWeeklyVolume? {
        guard let segment = MuscleLoadCalculator.segments(for: exercise).first else { return nil }

        let base = MuscleLoadCalculator.loads(
            sessions: completedSessions,
            plannedWorkout: .freeWorkout,
            startDate: startDate,
            includePrediction: false
        ).first { $0.segment == segment }?.actualSets ?? 0

        var sessionSets = 0.0
        var exerciseDelta = 0
        for draft in activeDrafts {
            let completed = draft.sets.filter(\.completed).count
            guard completed > 0,
                  MuscleLoadCalculator.segments(for: draft.workoutExercise.exercise).first == segment
            else { continue }
            sessionSets += Double(completed)
            if draft.workoutExercise.exercise.id == exercise.id {
                exerciseDelta += completed
            }
        }

        return ExerciseWeeklyVolume(
            segment: segment,
            weeklySets: base + sessionSets,
            sessionDelta: exerciseDelta
        )
    }
}

// MARK: - In-workout volume strip

/// Mirrors the competitor's in-set volume feedback: live weekly-set count for the muscle
/// being trained, the growth-zone gap and an "aim for more sets next time" intent toggle.
struct InWorkoutVolumeStrip: View {
    let volume: ExerciseWeeklyVolume
    @Binding var aimForMore: Bool

    private var load: MuscleLoad { volume.load }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(volume.muscleTitle)
                    .font(.headline.weight(.bold))
                Spacer()
                if volume.sessionDelta > 0 {
                    Text("+\(volume.sessionDelta) ")
                        .foregroundStyle(PulseTheme.primaryBright)
                        + Text("sets_suffix")
                        .foregroundStyle(PulseTheme.primaryBright)
                }
            }
            .font(.subheadline.weight(.bold))

            HStack(alignment: .firstTextBaseline) {
                (Text("\(load.displaySets)")
                    .foregroundStyle(.primary)
                 + Text("of_12_weekly_sets")
                    .foregroundStyle(PulseTheme.secondaryText))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text(load.setsToGrowthZoneText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            RepsProgressiveSegmentBar(value: load.totalSets, height: 18, spacing: 5)

            Divider().overlay(PulseTheme.separator)

            Toggle(isOn: $aimForMore) {
                Label {
                    Text("aim_for_more_sets")
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.primaryBright)
                }
            }
            .tint(PulseTheme.growth)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }
}

// MARK: - Finish-summary muscle map

struct MuscleZoneLegend: View {
    var body: some View {
        HStack(spacing: 18) {
            ForEach(MuscleZone.allCases) { zone in
                HStack(spacing: 6) {
                    Circle()
                        .fill(zone.color)
                        .frame(width: 9, height: 9)
                    Text(zone.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }
}

/// Body heatmap + zone legend shown on the finish screen, reusing the Progress heatmap so
/// the colours mean exactly the same thing the athlete saw in their weekly map.
struct SessionMuscleSummaryCard: View {
    let loads: [MuscleLoad]
    let gender: BodyGender
    let workedMuscleCount: Int
    let durationText: String

    var body: some View {
        VStack(spacing: 14) {
            InteractiveBodyHeatmap(loads: loads, gender: gender, selectedSegment: .constant(nil))
                .frame(height: 300)
                .allowsHitTesting(false)

            MuscleZoneLegend()

            HStack {
                Label {
                    (Text("\(workedMuscleCount) ").foregroundStyle(.primary)
                     + Text("muscles_trained_count").foregroundStyle(PulseTheme.secondaryText))
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(PulseTheme.growth)
                }
                Spacer()
                Label(durationText, systemImage: "timer")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(18)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }
}
