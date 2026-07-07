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
      let shape = RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)

      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .center, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("load"))
              .font(.title2.weight(.bold))
              .foregroundStyle(.primary)

            Text(battery.title)
              .font(.system(size: 22, weight: .heavy, design: .rounded))
              .foregroundStyle(statusColor)
              .lineLimit(2)
              .minimumScaleFactor(0.78)
              .fixedSize(horizontal: false, vertical: true)

            Text("\(Int(workload.fatigueScore.rounded())) fatiga · 7 días")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(PulseTheme.secondaryText)
          }
          .layoutPriority(1)

          Spacer(minLength: 10)

          LiquidCapsuleGauge(
            level: battery.level,
            color: statusColor,
            size: CGSize(width: 58, height: 132),
            showsLabel: true
          )
          .frame(width: 76, height: 148, alignment: .trailing)
        }

        Divider().opacity(0.12)

        HStack(alignment: .center, spacing: 12) {
          Text(battery.suggestion)
            .font(.subheadline)
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: false, vertical: true)

          Spacer(minLength: 12)

          Text(localizedString("abrir"))
            .font(.subheadline.weight(.bold))
            .foregroundStyle(PulseTheme.ringStand)
            .lineLimit(1)
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(batteryBackgroundGradient, in: shape)
      .overlay {
        shape.stroke(PulseTheme.cardStroke, lineWidth: 0.8)
      }
      .shadow(color: PulseTheme.surfaceShadow, radius: 7, x: 0, y: 3)
    }
    .buttonStyle(.plain)
  }

  private var batteryBackgroundGradient: LinearGradient {
    let level = max(0, min(Double(battery.level) / 100, 1))
    let fill = max(0.08, min(level, 0.96))
    let leadingOpacity = 0.18 + (level * 0.18)
    let fillOpacity = 0.10 + (level * 0.14)

    return LinearGradient(
      stops: [
        .init(color: statusColor.opacity(leadingOpacity), location: 0),
        .init(color: statusColor.opacity(fillOpacity), location: fill),
        .init(color: PulseTheme.card.opacity(0.96), location: min(fill + 0.18, 1)),
        .init(color: PulseTheme.card, location: 1)
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
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
