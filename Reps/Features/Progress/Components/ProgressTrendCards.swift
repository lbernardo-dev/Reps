import Charts
import MuscleMap
import SwiftUI

struct TrendHighlightsCard: View {
  let metrics: [TrendMetric]
  let sessionsThisWeek: Int
  let sessionsGoal: Int
  let volumeThisWeek: Int
  let weekDays: [Bool]

  private var positiveCount: Int {
    metrics.filter { $0.direction == .up }.count
  }

  private var attentionMetric: TrendMetric? {
    metrics.first { $0.direction == .down } ?? metrics.first { $0.direction == .neutral }
  }

  private var leadMetric: TrendMetric? {
    metrics.first { $0.direction == .up } ?? metrics.first
  }

  private var headline: String {
    if positiveCount >= max(2, metrics.count / 2) {
      return localizedString("trend_good_block_headline")
    }
    if let attentionMetric {
      return localizedFormat("trend_priority_headline_format", attentionMetric.title)
    }
    return localizedString("trend_ready_to_compare_headline")
  }

  private var detail: String {
    if let attentionMetric, attentionMetric.direction != .up {
      return localizedFormat("trend_needs_more_data_format", attentionMetric.title)
    }
    return localizedString("trend_compare_recent_weeks_detail")
  }

  var body: some View {
    PulseCard(contentPadding: 18) {
      VStack(alignment: .leading, spacing: 15) {
        HStack(alignment: .top, spacing: 14) {
          VStack(alignment: .leading, spacing: 7) {
            Text(headline)
              .font(.title3.weight(.black))
              .lineLimit(2)
              .minimumScaleFactor(0.82)
            Text(detail)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(PulseTheme.secondaryText)
              .lineLimit(3)
          }

          Spacer(minLength: 8)

          ZStack {
            Circle()
              .stroke(PulseTheme.grouped, lineWidth: 10)
            Circle()
              .trim(from: 0, to: min(Double(positiveCount) / Double(max(metrics.count, 1)), 1))
              .stroke(PulseTheme.ringExercise, style: StrokeStyle(lineWidth: 10, lineCap: .round))
              .rotationEffect(.degrees(-90))
            Text("\(positiveCount)")
              .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
          }
          .frame(width: 70, height: 70)
        }

        HStack(spacing: 10) {
          TrendHighlightPill(
            title: "Mejor senal",
            value: leadMetric?.title ?? "Sin datos",
            detail: leadMetric.map { "\($0.value) \($0.unit)" } ?? "--",
            color: leadMetric?.color ?? PulseTheme.secondaryText
          )
          TrendHighlightPill(
            title: "Fuerza",
            value: "\(sessionsThisWeek)/\(sessionsGoal)",
            detail: "\(volumeThisWeek) kg",
            color: PulseTheme.ringExercise
          )
          TrendHighlightPill(
            title: "Constancia",
            value: "\(weekDays.filter { $0 }.count)/7",
            detail: "dias activos",
            color: PulseTheme.ringStand
          )
        }

        WeekTrendBars(days: weekDays)
      }
    }
  }
}


struct TrendHighlightPill: View {
  let title: String
  let value: String
  let detail: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(PulseTheme.secondaryText)
      Text(value)
        .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.62)
      Text(detail)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(PulseTheme.tertiaryText)
        .lineLimit(1)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}


struct WeekTrendBars: View {
  let days: [Bool]

  var body: some View {
    HStack(alignment: .bottom, spacing: 7) {
      ForEach(0..<7, id: \.self) { index in
        let active = index < days.count && days[index]
        Capsule()
          .fill(active ? PulseTheme.ringExercise : PulseTheme.separator.opacity(0.5))
          .frame(maxWidth: .infinity)
          .frame(height: active ? CGFloat(20 + (index % 3) * 8) : 12)
      }
    }
    .frame(height: 42)
    .accessibilityHidden(true)
  }
}


struct TrendsGridView: View {
  let metrics: [TrendMetric]
  var onSelect: (TrendMetric) -> Void = { _ in }

  var body: some View {
    PulseCard(contentPadding: 16) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text(localizedString("trends"))
            .font(.title2.weight(.bold))
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText.opacity(0.5))
        }

        LazyVGrid(
          columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
          spacing: 16
        ) {
          ForEach(metrics) { metric in
            if metric.metric != nil {
              Button { onSelect(metric) } label: { TrendTile(metric: metric) }
                .buttonStyle(.plain)
            } else {
              TrendTile(metric: metric)
            }
          }
        }
      }
    }
  }
}


struct TrendTile: View {
  let metric: TrendMetric

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      directionView

      VStack(alignment: .leading, spacing: 3) {
        Text(metric.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
          .minimumScaleFactor(0.78)

        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(metric.value)
            .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(metric.color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          Text(metric.unit)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(metric.color.opacity(0.70))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if metric.metric != nil {
        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(PulseTheme.secondaryText.opacity(0.4))
      }
    }
    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
  }

  @ViewBuilder
  private var directionView: some View {
    switch metric.direction {
    case .up:
      directionIcon("chevron.up", color: metric.color)
    case .down:
      directionIcon("chevron.down", color: metric.color)
    case .neutral:
      directionIcon("minus", color: PulseTheme.secondaryText)
    }
  }

  private func directionIcon(_ systemImage: String, color: Color) -> some View {
    Image(systemName: systemImage)
      .font(.system(size: 15, weight: .heavy))
      .foregroundStyle(color)
      .frame(width: 42, height: 42)
      .background(color.opacity(0.13), in: Circle())
  }
}

