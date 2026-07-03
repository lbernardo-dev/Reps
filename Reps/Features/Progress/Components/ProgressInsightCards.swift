import Charts
import MuscleMap
import SwiftUI

struct ConsistencyPoint: Identifiable {
  let id = UUID()
  let date: Date
  let count: Int
}


struct MuscleRow: View {
  let point: FitnessMetrics.MuscleVolumePoint

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text(point.muscleGroup)
            .font(.title3.weight(.bold))
          Text(localizedFormat("weekly_sets_of_12_format", point.completedSets))
            .font(.headline.monospacedDigit())
            .foregroundStyle(PulseTheme.secondaryText)
        }
        Spacer()
        Text(growthText)
          .font(.headline)
          .foregroundStyle(
            point.completedSets >= 4 ? PulseTheme.ringStand : PulseTheme.secondaryText)
      }

      HStack(spacing: 14) {
        MuscleGlyph(muscleGroup: point.muscleGroup, intensity: point.targetProgress)
        VolumeSegmentBar(completed: min(point.completedSets, 12))
      }

      HStack {
        Text(point.recommendedRangeText)
        Spacer()
        Text("\(Int(point.totalVolumeKg)) kg")
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(PulseTheme.tertiaryText)
    }
    .padding(18)
    .background(PulseTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
        .stroke(PulseTheme.separator, lineWidth: 1)
    )
  }

  private var growthText: String {
    point.completedSets >= 4 ? localizedString("growth_zone") : localizedFormat("sets_remaining_format", max(4 - point.completedSets, 0))
  }
}


struct InsightRow: View {
  let insight: FitnessMetrics.TrainingInsight

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: insight.systemImage)
        .font(.headline)
        .foregroundStyle(PulseTheme.accent)
        .frame(width: 38, height: 38)
        .background(PulseTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(insight.title)
          .font(.headline)
        Text(insight.message)
          .font(.subheadline)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}


struct StreakBadge: View {
  let days: Int

  var body: some View {
    HStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(
            days > 0
              ? RadialGradient(
                colors: [Color.orange.opacity(0.35), .clear], center: .center, startRadius: 0,
                endRadius: 30)
              : RadialGradient(
                colors: [.clear, .clear], center: .center, startRadius: 0, endRadius: 30)
          )
          .frame(width: 56, height: 56)

        Circle()
          .strokeBorder(days > 0 ? Color.orange.opacity(0.4) : PulseTheme.separator, lineWidth: 2)
          .frame(width: 44, height: 44)

        if days > 0 {
          Image(systemName: "flame.fill")
            .font(.system(size: 29, weight: .bold))
            .foregroundStyle(
              LinearGradient(
                colors: [.yellow, .orange, .red],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
        } else {
          Image(systemName: "flame.fill")
            .font(.system(size: 29, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
        }
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(localizedString("streak"))
          .font(.system(size: 10, weight: .black, design: .rounded))
          .foregroundStyle(PulseTheme.secondaryText)
          .tracking(1.4)

        Text(
          "\(formattedDays) \(days == 1 ? (localizedString("day")) : (localizedString("days")))"
        )
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(days > 0 ? .white : PulseTheme.secondaryText)
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 8)
    .background(
      days > 0
        ? LinearGradient(
          colors: [PulseTheme.warning.opacity(0.12), PulseTheme.warning.opacity(0.04)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(
          colors: [PulseTheme.grouped.opacity(0.4), PulseTheme.grouped.opacity(0.2)],
          startPoint: .top, endPoint: .bottom)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(
          days > 0
            ? LinearGradient(
              colors: [.yellow.opacity(0.3), .orange.opacity(0.4), .red.opacity(0.3)],
              startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [PulseTheme.separator], startPoint: .top, endPoint: .bottom),
          lineWidth: 1.2
        )
    )
    .shadow(color: days > 0 ? Color.orange.opacity(0.12) : Color.clear, radius: 8, x: 0, y: 3)
  }

  private var formattedDays: String {
    if days >= 1000 {
      let kValue = Double(days) / 1000.0
      if kValue.truncatingRemainder(dividingBy: 1.0) == 0 {
        return String(format: "%.0fK", kValue)
      } else {
        return String(format: "%.1fK", kValue)
      }
    }
    return "\(days)"
  }
}

// MARK: - Cardio analytics (pace/distance, pace·HR, efficiency factor)

