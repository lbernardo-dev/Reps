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
            Text(localizedString("load"))
              .font(.title2.weight(.bold))
              .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(battery.title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              Text("\(battery.level)%")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(PulseTheme.secondaryText)
            }

            Text("\(Int(workload.fatigueScore.rounded())) fatiga · 7 días")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(PulseTheme.secondaryText)

            Divider().opacity(0.12)

            HStack {
              Text(battery.suggestion)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
              Spacer()
              Text(localizedString("abrir"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.ringStand)
            }
          }

          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(statusColor.opacity(0.16))
            VStack(spacing: 7) {
              Image(systemName: battery.systemImage)
                .font(.system(size: 24, weight: .bold))
              TrainingLoadMiniGauge(level: Double(battery.level) / 100, color: statusColor)
            }
            .foregroundStyle(statusColor)
          }
          .frame(width: 92, height: 118)
        }
      }
    }
    .buttonStyle(.plain)
  }
}


struct TrainingLoadMiniGauge: View {
  let level: Double
  let color: Color

  var body: some View {
    VStack(spacing: 5) {
      ForEach(0..<4, id: \.self) { index in
        Capsule()
          .fill(index < filledSegments ? color : PulseTheme.separator.opacity(0.45))
          .frame(height: 8)
      }
    }
    .frame(width: 58)
  }

  private var filledSegments: Int {
    max(1, min(4, Int((level * 4).rounded(.up))))
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
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
    .background(PulseTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)
  }
}

