import Charts
import MuscleMap
import SwiftUI

struct CompetitiveSummaryCard: View {
  let summary: AnalyticsEngine.CompetitiveSummary

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("competitive_diagnostics")
              .font(.headline)
            Text("adherence_volume_and_stall_signals_against_the_active_plan")
              .font(.subheadline)
              .foregroundStyle(PulseTheme.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Text("\(Int(summary.completionRate * 100))%")
            .font(.title2.monospacedDigit().weight(.bold))
            .foregroundStyle(summary.completionRate >= 0.75 ? PulseTheme.recovery : PulseTheme.warning)
        }

        ProgressView(value: summary.completionRate)
          .tint(summary.completionRate >= 0.75 ? PulseTheme.recovery : PulseTheme.warning)

        HStack(spacing: 10) {
          MetricInline(
            title: "plan",
            value: "\(summary.completedWorkouts)/\(max(summary.plannedWorkouts, 1))")
          MetricInline(
            title: "volume_label",
            value: "\(summary.actualWeeklySets)/\(summary.targetWeeklySets)")
          MetricInline(
            title: "alerts_label",
            value: "\(summary.undertrainedMuscles.count + summary.overtrainedMuscles.count + summary.stalledExercises.count)")
        }

        if !summary.undertrainedMuscles.isEmpty || !summary.overtrainedMuscles.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(summary.undertrainedMuscles.prefix(2)) { point in
              CompetitiveMuscleGapRow(
                point: point,
                title: localizedFormat("muscle_gap_under_format", point.muscleGroup, point.sets),
                color: PulseTheme.warning
              )
            }
            ForEach(summary.overtrainedMuscles.prefix(2)) { point in
              CompetitiveMuscleGapRow(
                point: point,
                title: localizedFormat("muscle_gap_over_format", point.muscleGroup, point.sets),
                color: PulseTheme.destructive
              )
            }
          }
        }
      }
    }
  }
}


struct CompetitiveMuscleGapRow: View {
  let point: AnalyticsEngine.MuscleTargetPoint
  let title: String
  let color: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: point.kind == localizedString("muscle_target_kind_missing") ? "arrow.down.circle.fill" : "exclamationmark.triangle.fill")
        .font(.subheadline)
        .foregroundStyle(color)
        .frame(width: 28, height: 28)
        .background(color.opacity(0.12))
        .clipShape(Circle())
      Text(title)
        .font(.subheadline.weight(.semibold))
      Spacer()
    }
  }
}


struct StalledExerciseRow: View {
  let stall: AnalyticsEngine.ExerciseStall

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "pause.circle.fill")
        .font(.headline)
        .foregroundStyle(PulseTheme.warning)
        .frame(width: 38, height: 38)
        .background(PulseTheme.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(stall.exercise.name)
          .font(.headline)
        Text(localizedFormat("stall_summary_format", stall.loggedSessions, Int(stall.previousBestEstimatedOneRepMaxKg), Int(stall.latestEstimatedOneRepMaxKg)))
          .font(.subheadline)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()
    }
    .padding(.vertical, 4)
  }
}


struct CompetitiveRecommendationRow: View {
  let recommendation: AnalyticsEngine.CompetitiveRecommendation
  let onExecute: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: recommendation.systemImage)
        .font(.headline)
        .foregroundStyle(PulseTheme.accent)
        .frame(width: 38, height: 38)
        .background(PulseTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(recommendation.title)
          .font(.headline)
        Text(recommendation.message)
          .font(.subheadline)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
        if recommendation.action != .none {
          Button(action: onExecute) {
            Label(actionTitle, systemImage: "arrow.forward.circle.fill")
              .font(.caption.weight(.bold))
              .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
              .padding(.horizontal, 12)
              .frame(height: 32)
              .background(PulseTheme.accent)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .padding(.top, 4)
        }
      }
    }
  }

  private var actionTitle: String {
    switch recommendation.action {
    case .scheduleUndertrainedMuscle:
      return localizedString("schedule_focus")
    case .scheduleDeloadExercise:
      return localizedString("schedule_deload")
    case .reviewPlan:
      return localizedString("review_plan")
    case .scheduleRecovery:
      return localizedString("schedule_recovery")
    case .none:
      return ""
    }
  }
}

