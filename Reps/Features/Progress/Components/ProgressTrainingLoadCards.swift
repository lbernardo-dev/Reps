import Charts
import MuscleMap
import SwiftUI

struct TrainingLoadOverviewCard: View {
  let battery: FitnessMetrics.TrainingBatteryStatus
  let workload: AnalyticsEngine.WorkloadSummary
  let onTap: () -> Void

  private var statusColor: Color {
    switch battery.state {
    case .charged:
      return PulseTheme.ringExercise
    case .steady:
      return Color(red: 0.56, green: 0.43, blue: 1.0)
    case .low:
      return PulseTheme.warning
    case .critical:
      return PulseTheme.destructive
    }
  }

  var body: some View {
    Button(action: onTap) {
      PulseCard(contentPadding: 18) {
        HStack(alignment: .center, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text(localizedString("load"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
              Image(systemName: battery.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(statusColor)
            }

            Text(battery.title)
              .font(.system(size: 22, weight: .heavy, design: .rounded))
              .foregroundStyle(statusColor)
              .lineLimit(2)
              .minimumScaleFactor(0.78)
              .fixedSize(horizontal: false, vertical: true)

            Text("\(Int(workload.fatigueScore.rounded())) fatiga · 7 días")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(PulseTheme.secondaryText)

            Divider().opacity(0.12)

            HStack {
              Text(battery.suggestion)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
              Spacer()
              Text(localizedString("abrir"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.ringStand)
                .lineLimit(1)
            }
          }
          .layoutPriority(1)

          ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(statusColor.opacity(0.12))
            LiquidCapsuleGauge(
              level: battery.level,
              color: statusColor,
              size: CGSize(width: 52, height: 96),
              showsLabel: true
            )
          }
          .frame(width: 92, height: 118)
        }
      }
    }
    .buttonStyle(.plain)
  }
}


struct ExerciseProgressRow: View {
  let exercise: Exercise
  @Environment(AppStore.self) private var store

  private var points: [FitnessMetrics.ExerciseProgressPoint] {
    FitnessMetrics.progressPoints(for: exercise, in: store.workoutSessions)
  }

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.headline)
        .foregroundStyle(PulseTheme.accent)
        .frame(width: 42, height: 42)
        .background(PulseTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        Text(exercise.name)
          .font(.headline)
        Text(
          "\(points.count) logged days · \(Int(points.map(\.totalVolumeKg).reduce(0, +))) kg volume"
        )
        .font(.subheadline)
        .foregroundStyle(PulseTheme.secondaryText)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(PulseTheme.secondaryText)
    }
    .padding(.vertical, 8)
  }
}


struct MetricInline: View {
  let title: LocalizedStringKey
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(localizedKey(title))
        .font(.caption.weight(.semibold))
        .foregroundStyle(PulseTheme.secondaryText)
      Text(value)
        .font(.headline.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PulseTheme.grouped)
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
  }
}


struct AnalyticsShortcutCard: View {
  let title: LocalizedStringKey
  let subtitle: String
  let systemImage: String

  var body: some View {
    PulseCard(minHeight: 138, contentPadding: 16) {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: systemImage)
        .font(.headline)
        .foregroundStyle(PulseTheme.accent)
        .frame(width: 42, height: 42)
        .background(PulseTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
      Text(localizedKey(title))
        .font(.headline)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(PulseTheme.secondaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
