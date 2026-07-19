import Charts
import MuscleMap
import SwiftUI

struct DailySummaryFocusCard: View {
  let readinessLevel: Int
  let todaySessions: [WorkoutSession]
  let dateOfBirth: Date?
  let sessionsToday: Int
  let activeEnergyToday: Int
  let stepsToday: Int
  let exerciseMinutesWeek: Int
  let hasHealthData: Bool
  let hasManualData: Bool
  var onMetricTap: (SummaryMetric) -> Void = { _ in }

  private var readinessColor: Color {
    if readinessLevel >= 70 { return PulseTheme.ringExercise }
    if readinessLevel >= 45 { return PulseTheme.warning }
    return PulseTheme.destructive
  }

  private var headline: String {
    if !hasHealthData && !hasManualData {
      return localizedString("daily_summary_headline_configure_health")
    }
    if sessionsToday > 0 {
      return localizedString("daily_summary_headline_session_today")
    }
    if readinessLevel < 45 {
      return localizedString("daily_summary_headline_reduce_load")
    }
    return localizedString("daily_summary_headline_ready")
  }

  private var workoutSummaryText: String {
    sessionsToday > 0
      ? localizedFormat("daily_summary_workout_count_format", sessionsToday)
      : localizedString("daily_summary_no_workout")
  }

  private var summaryTokens: [InlineMetricTextToken<SummaryMetricRoute>] {
    var tokens: [InlineMetricTextToken<SummaryMetricRoute>] = []

    func words(_ phrase: String) {
      for word in phrase.split(separator: " ") {
        tokens.append(.word(String(word)))
      }
    }

    words("\(workoutSummaryText).")

    guard hasHealthData else {
      words(localizedString("health_metrics_not_synced") + ".")
      return tokens
    }

    tokens.append(.pill(
      icon: TrackedMetric.steps.systemImage,
      value: "\(stepsToday)",
      tint: TrackedMetric.steps.tint,
      destination: SummaryMetricRoute(metric: .steps, range: .today)
    ))
    words(localizedString("steps").lowercased() + ",")
    tokens.append(.pill(
      icon: TrackedMetric.activeEnergy.systemImage,
      value: "\(activeEnergyToday)",
      tint: TrackedMetric.activeEnergy.tint,
      destination: SummaryMetricRoute(metric: .activeEnergy, range: .today)
    ))
    words(localizedString("active_kcal").lowercased() + ".")
    return tokens
  }

  var body: some View {
    GlassMetricCard(domain: .recovery, contentPadding: 18) {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 14) {
          ZStack {
            Circle()
              .stroke(PulseTheme.grouped, lineWidth: 10)
            Circle()
              .trim(from: 0, to: max(0.04, min(Double(readinessLevel) / 100, 1)))
              .stroke(readinessColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
              .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
              Text("\(readinessLevel)")
                .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
              Text("READY")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(PulseTheme.secondaryText)
            }
          }
          .frame(width: 74, height: 74)

          VStack(alignment: .leading, spacing: 6) {
            Text(headline)
              .font(.title3.weight(.black))
              .lineLimit(2)
              .minimumScaleFactor(0.82)
            InlineMetricText(
              tokens: summaryTokens,
              textFont: .subheadline.weight(.semibold),
              pillFont: .system(size: 13, weight: .black, design: .rounded).monospacedDigit(),
              verticalSpacing: 7
            )
          }
        }

        HStack(spacing: 8) {
          Button { onMetricTap(.sessions) } label: {
            DailySignalPill(
              title: localizedString("today_2"),
              value: sessionsToday > 0 ? localizedFormat("short_sessions_count_format", sessionsToday) : localizedString("pending"),
              systemImage: TrackedMetric.sessions.systemImage,
              color: sessionsToday > 0 ? TrackedMetric.sessions.tint : PulseTheme.warning
            )
          }
          .buttonStyle(.plain)

          Button { onMetricTap(activeEnergyToday > 0 ? .activeEnergy : .steps) } label: {
            DailySignalPill(
              title: "Health",
              value: activeEnergyToday > 0 ? "\(activeEnergyToday) kcal" : "\(stepsToday) \(localizedString("steps"))",
              systemImage: activeEnergyToday > 0 ? TrackedMetric.activeEnergy.systemImage : TrackedMetric.steps.systemImage,
              color: activeEnergyToday > 0 ? TrackedMetric.activeEnergy.tint : TrackedMetric.steps.tint
            )
          }
          .buttonStyle(.plain)

          Button { onMetricTap(.sessions) } label: {
            DailySignalPill(
              title: localizedString("week"),
              value: "\(exerciseMinutesWeek) min",
              systemImage: TrackedMetric.exerciseMinutes.systemImage,
              color: TrackedMetric.exerciseMinutes.tint
            )
          }
          .buttonStyle(.plain)
        }

        TodayZoneDistributionPanel(
          sessions: todaySessions,
          dateOfBirth: dateOfBirth
        )
      }
    }
  }
}

private enum TodayTrainingZone: Int, CaseIterable, Identifiable {
  case one = 0
  case two
  case three
  case four
  case five

  var id: Int { rawValue }

  var color: Color {
    PulseTheme.hrZones[rawValue]
  }

  var label: String {
    switch self {
    case .one: return localizedString("zone_1_label")
    case .two: return localizedString("zone_2_label")
    case .three: return localizedString("zone_3_label")
    case .four: return localizedString("zone_4_label")
    case .five: return localizedString("zone_5_label")
    }
  }

  func lowerBound(maxHR: Double) -> Double {
    [0.0, 0.60, 0.70, 0.80, 0.90][rawValue] * maxHR
  }

  func rangeLabel(maxHR: Double) -> String {
    switch self {
    case .one: return "<\(Int(maxHR * 0.60))BPM"
    case .two: return "\(Int(maxHR * 0.60))-\(Int(maxHR * 0.70))BPM"
    case .three: return "\(Int(maxHR * 0.70))-\(Int(maxHR * 0.80))BPM"
    case .four: return "\(Int(maxHR * 0.80))-\(Int(maxHR * 0.90))BPM"
    case .five: return "\(Int(maxHR * 0.90))+BPM"
    }
  }
}

private struct TodayZoneDistributionPanel: View {
  let sessions: [WorkoutSession]
  let dateOfBirth: Date?

  private func makeHeartRateMinutes(maxHeartRate: Double) -> [Int] {
    var minutes = Array(repeating: 0, count: TodayTrainingZone.allCases.count)

    for session in sessions {
      let points = session.routePoints.filter { $0.heartRate != nil }
      if points.count >= 2 {
        for index in 1..<points.count {
          guard let heartRate = points[index - 1].heartRate else { continue }
          let seconds = points[index].timestamp.timeIntervalSince(points[index - 1].timestamp)
          guard seconds > 0, seconds < 300 else { continue }
          minutes[zoneIndex(forHeartRate: heartRate, maxHeartRate: maxHeartRate)] += max(1, Int((seconds / 60).rounded()))
        }
      } else if let heartRate = session.averageHeartRate, heartRate > 0 {
        minutes[zoneIndex(forHeartRate: heartRate, maxHeartRate: maxHeartRate)] += max(session.durationMinutes, 1)
      }
    }

    return minutes
  }

  private func makeLoadMinutes() -> [Int] {
    var minutes = Array(repeating: 0, count: TodayTrainingZone.allCases.count)

    for session in sessions {
      let completedSets = session.sets.filter(\.completed).count
      minutes[zoneIndex(forLoadIn: session, completedSets: completedSets)] += effectiveMinutes(
        for: session,
        completedSets: completedSets
      )
    }

    return minutes
  }

  var body: some View {
    let maxHeartRate = FitnessMetrics.estimatedMaxHeartRate(dateOfBirth: dateOfBirth)
    let heartRateMinutes = makeHeartRateMinutes(maxHeartRate: maxHeartRate)
    let isUsingHeartRate = heartRateMinutes.contains { $0 > 0 }
    let zoneMinutes = isUsingHeartRate ? heartRateMinutes : makeLoadMinutes()
    let totalMinutes = zoneMinutes.reduce(0, +)

    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Zonas de hoy")
            .font(.subheadline.weight(.black))
          Text(localizedString(isUsingHeartRate ? "heart_rate_zone_label" : "estimated_load_per_session"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(PulseTheme.secondaryText)
        }
        Spacer()
        Text("\(totalMinutes) min")
          .font(.caption.weight(.black).monospacedDigit())
          .foregroundStyle(PulseTheme.secondaryText)
      }

      TodayClassicZoneScale(
        minutes: zoneMinutes,
        indicatorSystemImage: isUsingHeartRate ? "heart.fill" : "bolt.fill"
      )
      .frame(height: 44)

      VStack(spacing: 7) {
        ForEach(TodayTrainingZone.allCases) { zone in
          TodayZoneRow(
            zone: zone,
            minutes: zoneMinutes[zone.rawValue],
            totalMinutes: totalMinutes,
            maxHeartRate: maxHeartRate,
            showHeartRateRange: isUsingHeartRate
          )
        }
      }
    }
    .padding(12)
    .background(PulseTheme.grouped.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func zoneIndex(forHeartRate heartRate: Double, maxHeartRate: Double) -> Int {
    TodayTrainingZone.allCases.last {
      heartRate >= $0.lowerBound(maxHR: maxHeartRate)
    }?.rawValue ?? 0
  }

  private func zoneIndex(forLoadIn session: WorkoutSession, completedSets: Int) -> Int {
    if let rpe = session.sessionRPE {
      switch rpe {
      case ..<3: return 0
      case ..<5: return 1
      case ..<7: return 2
      case ..<9: return 3
      default: return 4
      }
    }

    switch completedSets {
    case 0...2: return 0
    case 3...6: return 1
    case 7...12: return 2
    case 13...18: return 3
    default: return 4
    }
  }

  private func effectiveMinutes(for session: WorkoutSession, completedSets: Int) -> Int {
    let setEstimate = max(completedSets * 2, 1)
    let rawDuration = session.durationMinutes

    if rawDuration <= 0 {
      return min(max(setEstimate, 1), 120)
    }

    if rawDuration > 300 {
      return min(max(setEstimate, 20), 120)
    }

    return min(max(rawDuration, setEstimate), 240)
  }
}

private struct TodayClassicZoneScale: View {
  let minutes: [Int]
  let indicatorSystemImage: String

  private var selectedZone: TodayTrainingZone? {
    guard let maxMinutes = minutes.max(), maxMinutes > 0 else { return nil }
    let index = minutes.firstIndex(of: maxMinutes) ?? 0
    return TodayTrainingZone(rawValue: index)
  }

  var body: some View {
    GeometryReader { geometry in
      let spacing: CGFloat = 5
      let segmentWidth = max(0, (geometry.size.width - spacing * 4) / 5)
      let pillWidth = min(124, geometry.size.width * 0.42)

      ZStack(alignment: .topLeading) {
        HStack(spacing: spacing) {
          ForEach(TodayTrainingZone.allCases) { zone in
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(zone.color)
              .frame(maxWidth: .infinity)
              .opacity(selectedZone == nil || selectedZone == zone ? 1 : 0.58)
          }
        }
        .frame(height: 32)

        if let selectedZone {
          let center = (segmentWidth / 2) + CGFloat(selectedZone.rawValue) * (segmentWidth + spacing)
          let x = min(max(center - pillWidth / 2, 0), max(0, geometry.size.width - pillWidth))

          HStack(spacing: 6) {
            Image(systemName: indicatorSystemImage)
              .font(.system(size: 12, weight: .black))
            Text("ZONA \(selectedZone.rawValue + 1)")
              .font(.system(size: 15, weight: .black, design: .rounded))
              .lineLimit(1)
              .minimumScaleFactor(0.78)
          }
          .foregroundStyle(PulseTheme.onColor(selectedZone.color))
          .frame(width: pillWidth, height: 32)
          .background(selectedZone.color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
          .offset(x: x)

          ZonePointer()
            .fill(.white)
            .frame(width: 14, height: 8)
            .offset(x: min(max(center - 7, 0), max(0, geometry.size.width - 14)), y: 32)
        }
      }
    }
  }
}

private struct ZonePointer: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

private struct TodayZoneRow: View {
  let zone: TodayTrainingZone
  let minutes: Int
  let totalMinutes: Int
  let maxHeartRate: Double
  let showHeartRateRange: Bool

  private var progress: Double {
    guard totalMinutes > 0 else { return 0 }
    return Double(minutes) / Double(totalMinutes)
  }

  var body: some View {
    HStack(spacing: 8) {
      Text("Z\(zone.rawValue + 1)")
        .font(.caption.weight(.black))
        .foregroundStyle(zone.color)
        .frame(width: 22, alignment: .leading)

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(PulseTheme.secondaryText.opacity(0.12))
          Capsule()
            .fill(zone.color)
            .frame(width: max(minutes > 0 ? 7 : 0, geometry.size.width * progress))
        }
      }
      .frame(height: 7)

      Text("\(minutes)m")
        .font(.caption.weight(.bold).monospacedDigit())
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .frame(width: 44, alignment: .trailing)

      if showHeartRateRange {
        Text(zone.rangeLabel(maxHR: maxHeartRate))
          .font(.caption2.weight(.semibold).monospacedDigit())
          .foregroundStyle(PulseTheme.tertiaryText)
          .frame(width: 74, alignment: .trailing)
      }
    }
    .frame(height: 16)
  }
}


struct DailySignalPill: View {
  let title: String
  let value: String
  let systemImage: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Image(systemName: systemImage)
        .font(.caption.weight(.black))
        .foregroundStyle(color)
      Text(value)
        .font(.system(size: 13, weight: .black, design: .rounded).monospacedDigit())
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(title)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(PulseTheme.secondaryText)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}



struct BodyHealthFusionPanel: View {
  let steps: Int
  let activeKcal: Int
  let exerciseMinutes: Int
  let sessions: Int
  let volumeKg: Int
  let hrv: Double?
  let restingHeartRate: Double?
  let fatigueScore: Double
  let dataPoints: [BodyFusionPoint]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(localizedString("health_training"), systemImage: "point.3.connected.trianglepath.dotted")
          .font(.headline)
        Spacer()
        Text(localizedFormat("fatigue_score_format", "\(Int(fatigueScore.rounded()))"))
          .font(.caption.weight(.black).monospacedDigit())
          .foregroundStyle(fatigueScore > 65 ? PulseTheme.destructive : PulseTheme.ringExercise)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background((fatigueScore > 65 ? PulseTheme.destructive : PulseTheme.ringExercise).opacity(0.12), in: Capsule())
      }

      Chart(dataPoints) { point in
        BarMark(
          x: .value(localizedString("date"), point.date, unit: .day),
          y: .value("Health", normalizedActivity(point.activity))
        )
        .foregroundStyle(PulseTheme.ringMove)
        .position(by: .value("source", "Health"))

        BarMark(
          x: .value(localizedString("date"), point.date, unit: .day),
          y: .value("Manual", normalizedVolume(point.volume))
        )
        .foregroundStyle(PulseTheme.ringExercise)
        .position(by: .value("source", "Manual"))
      }
      .frame(height: 128)
      .allowsHitTesting(false)
      .chartYAxis(.hidden)
      .chartXAxis {
        AxisMarks(values: .stride(by: .day)) { value in
          AxisValueLabel(format: .dateTime.weekday(.narrow))
            .foregroundStyle(PulseTheme.tertiaryText)
        }
      }

      LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
        SignalMetricTile(title: localizedString("activity"), value: "\(activeKcal)", subtitle: localizedFormat("steps_count_format", steps), systemImage: TrackedMetric.activeEnergy.systemImage, color: TrackedMetric.activeEnergy.tint)
        SignalMetricTile(title: localizedString("exercise"), value: "\(exerciseMinutes)", subtitle: "min Health", systemImage: TrackedMetric.exerciseMinutes.systemImage, color: TrackedMetric.exerciseMinutes.tint)
        SignalMetricTile(title: localizedString("strength"), value: "\(sessions)", subtitle: "\(volumeKg) kg \(localizedString("volume").lowercased())", systemImage: TrackedMetric.sessions.systemImage, color: TrackedMetric.sessions.tint)
        SignalMetricTile(
          title: localizedString("recovery"),
          value: hrv.map { "\(Int($0)) ms" } ?? "--",
          subtitle: restingHeartRate.map { "\(Int($0)) \(localizedString("resting_hr"))" } ?? localizedString("no_resting_hr"),
          systemImage: TrackedMetric.hrv.systemImage,
          color: TrackedMetric.hrv.tint
        )
      }
    }
  }

  private func normalizedActivity(_ value: Double) -> Double {
    min(max(value / 900.0, 0), 1)
  }

  private func normalizedVolume(_ value: Double) -> Double {
    min(max(value / 12_000.0, 0), 1)
  }
}



struct SignalMetricTile: View {
  let title: String
  let value: String
  let subtitle: String
  let systemImage: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Image(systemName: systemImage)
        .font(.caption.weight(.black))
        .foregroundStyle(color)
      Text(value)
        .font(.system(size: 19, weight: .black, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.62)
      Text(title)
        .font(.caption.weight(.black))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(subtitle)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.66)
    }
    .padding(11)
    .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
    .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}


struct SummaryRingsHeroCard: View {
  let moveProgress: Double
  let exerciseProgress: Double
  let standProgress: Double
  let moveLabel: String
  let moveValue: String
  let moveGoal: String
  let exerciseLabel: String
  let exerciseValue: String
  let exerciseGoal: String
  let exerciseCaption: String
  let standLabel: String
  let standValue: String
  let standGoal: String
  let weeklyDays: [Bool]
  let weekStart: Date
  let dailyPoints: [BodyFusionPoint]
  let onTapMove: () -> Void
  let onTapExercise: () -> Void
  let onTapStand: () -> Void

  private var weekEnd: Date {
    Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
  }

  private var rangeText: String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.setLocalizedDateFormatFromTemplate("d MMM")
    return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
  }

  var body: some View {
    PulseCard(contentPadding: 16) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 3) {
            Text(localizedString("weekly_summary"))
              .font(.headline.weight(.black))
            Text(localizedFormat("weekly_range_format", rangeText))
              .font(.caption.weight(.bold))
              .foregroundStyle(PulseTheme.secondaryText)
          }
          Spacer()
          Text("\(weeklyDays.filter { $0 }.count)/7")
            .font(.caption.weight(.black).monospacedDigit())
            .foregroundStyle(PulseTheme.ringStand)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(PulseTheme.ringStand.opacity(0.12), in: Capsule())
        }

        ViewThatFits(in: .horizontal) {
          HStack(alignment: .center, spacing: 14) {
            ringsView(width: 112, lineWidth: 13, gap: 4)
            metricsStack
              .frame(maxWidth: .infinity)
          }

          VStack(spacing: 18) {
            ringsView(width: 190, lineWidth: 20, gap: 7)
            metricsStack
          }
        }

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(localizedString("weekly_rhythm"))
              .font(.caption.weight(.black))
              .foregroundStyle(PulseTheme.secondaryText)
            Spacer()
            Text("\(weeklyDays.filter { $0 }.count)/7")
              .font(.caption.weight(.black).monospacedDigit())
              .foregroundStyle(PulseTheme.ringStand)
          }
          WeekRingStrip(days: weeklyDays)
        }

        WeeklyDistributionPanel(
          points: dailyPoints,
          activeDays: weeklyDays,
          weekStart: weekStart
        )
      }
    }
  }

  private var metricsStack: some View {
    VStack(spacing: 0) {
      RingsMetricRow(
        color: PulseTheme.ringMove,
        label: moveLabel,
        value: moveValue,
        unit: moveGoal,
        progress: moveProgress,
        goalCaption: localizedString("vs_previous_week"),
        icon: "scalemass.fill",
        action: onTapMove
      )
      Divider().opacity(0.10)
      RingsMetricRow(
        color: PulseTheme.ringExercise,
        label: exerciseLabel,
        value: exerciseValue,
        unit: exerciseGoal,
        progress: exerciseProgress,
        goalCaption: exerciseCaption,
        icon: "dumbbell.fill",
        action: onTapExercise
      )
      Divider().opacity(0.10)
      RingsMetricRow(
        color: PulseTheme.ringStand,
        label: standLabel,
        value: standValue,
        unit: standGoal,
        progress: standProgress,
        goalCaption: localizedString("active_days"),
        icon: "calendar.badge.clock",
        action: onTapStand
      )
    }
  }

  private func ringsView(width: CGFloat, lineWidth: CGFloat, gap: CGFloat) -> some View {
    RepsActivityRings(
      rings: RepsActivityRings.Ring.default(
        moveProgress: moveProgress,
        exerciseProgress: exerciseProgress,
        standProgress: standProgress
      ),
      lineWidth: lineWidth,
      gap: gap
    )
    .frame(width: width, height: width)
  }
}

private struct WeeklyDistributionPanel: View {
  let points: [BodyFusionPoint]
  let activeDays: [Bool]
  let weekStart: Date

  private var normalizedPoints: [BodyFusionPoint] {
    if points.count == 7 { return points }

    let calendar = Calendar.current
    let byDay = Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
    return (0..<7).compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
      let day = calendar.startOfDay(for: date)
      if let existing = byDay[day]?.first { return existing }
      return BodyFusionPoint(date: day, activity: 0, volume: 0)
    }
  }

  private var maxVolume: Double {
    max(normalizedPoints.map(\.volume).max() ?? 0, 1)
  }

  private var maxActivity: Double {
    max(normalizedPoints.map(\.activity).max() ?? 0, 1)
  }

  private var sessionValues: [Double] {
    activeDays.enumerated().map { index, isActive in
      guard index < normalizedPoints.count else { return 0 }
      return isActive ? 1 : 0
    }
  }

  private var activeDaysLabel: String {
    let count = activeDays.filter { $0 }.count
    return count == 1 ? localizedString("day_singular") : localizedFormat("days_count_format", count)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(localizedString("daily_distribution"))
          .font(.caption.weight(.black))
          .foregroundStyle(PulseTheme.secondaryText)
        Spacer()
        Text(localizedString("week_monday_sunday"))
          .font(.caption2.weight(.black))
          .foregroundStyle(PulseTheme.tertiaryText)
      }

      VStack(spacing: 10) {
        WeeklySparkMetricRow(
          title: localizedString("volume"),
          total: "\(Int(normalizedPoints.map(\.volume).reduce(0, +))) kg",
          color: PulseTheme.ringMove,
          values: normalizedPoints.map { $0.volume / maxVolume },
          dayDates: normalizedPoints.map(\.date),
          footer: localizedString("recorded_load")
        )

        WeeklySparkMetricRow(
          title: localizedString("sessions_2"),
          total: activeDaysLabel,
          color: PulseTheme.ringExercise,
          values: sessionValues,
          dayDates: normalizedPoints.map(\.date),
          footer: localizedString("workout_days")
        )

        WeeklySparkMetricRow(
          title: localizedString("activity"),
          total: "\(Int(normalizedPoints.map(\.activity).reduce(0, +))) kcal",
          color: PulseTheme.ringStand,
          values: normalizedPoints.map { $0.activity / maxActivity },
          dayDates: normalizedPoints.map(\.date),
          footer: localizedString("weekly_health")
        )
      }
    }
    .padding(12)
    .background(PulseTheme.grouped.opacity(0.46), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct WeeklySparkMetricRow: View {
  let title: String
  let total: String
  let color: Color
  let values: [Double]
  let dayDates: [Date]
  let footer: String

  private let segmentCount = 6
  private let chartHeight: CGFloat = 34
  private let dayLabelHeight: CGFloat = 13

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 1) {
          Text(title)
            .font(.caption.weight(.black))
            .foregroundStyle(.primary)
          Text(footer)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(PulseTheme.tertiaryText)
        }
        Spacer()
        Text(total)
          .font(.caption.weight(.black).monospacedDigit())
          .foregroundStyle(color)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }

      HStack(alignment: .bottom, spacing: 5) {
        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
          let clamped = min(max(value, 0), 1)
          let activeSegments = Int((clamped * Double(segmentCount)).rounded(.up))

          VStack(spacing: 3) {
            ForEach((0..<segmentCount).reversed(), id: \.self) { segment in
              Capsule()
                .fill(segment < activeSegments ? segmentColor(for: segment) : PulseTheme.secondaryText.opacity(0.12))
                .frame(height: 4)
            }
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(dayLabel(for: index))
          .accessibilityValue(Int(clamped * 100).formatted(.percent))
        }
      }
      .frame(height: chartHeight, alignment: .bottom)

      HStack(spacing: 5) {
        ForEach(Array(dayDates.enumerated()), id: \.offset) { index, date in
          Text(dayInitial(for: date))
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(index == todayIndex ? color : PulseTheme.tertiaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: dayLabelHeight, alignment: .top)
      .padding(.top, 1)
    }
  }

  private var todayIndex: Int? {
    let today = Calendar.current.startOfDay(for: .now)
    return dayDates.firstIndex { Calendar.current.startOfDay(for: $0) == today }
  }

  private func dayInitial(for date: Date) -> String {
    let weekday = Calendar.current.component(.weekday, from: date)
    let symbols = Calendar.current.veryShortWeekdaySymbols
    guard symbols.indices.contains(weekday - 1) else { return "" }
    return symbols[weekday - 1].uppercased()
  }

  private func dayLabel(for index: Int) -> String {
    guard index < dayDates.count else { return title }
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.setLocalizedDateFormatFromTemplate("EEEE d MMM")
    return "\(title), \(formatter.string(from: dayDates[index]))"
  }

  private func segmentColor(for segment: Int) -> Color {
    let ratio = Double(segment + 1) / Double(segmentCount)

    switch ratio {
    case ..<0.34:
      return PulseTheme.ringExercise.opacity(0.88)
    case ..<0.51:
      return PulseTheme.ringMove
    case ..<0.68:
      return PulseTheme.warning.opacity(0.92)
    case ..<0.84:
      return PulseTheme.warning
    default:
      return PulseTheme.semanticEffort
    }
  }
}


struct RingsMetricRow: View {
  let color: Color
  let label: String
  let value: String
  let unit: String
  let progress: Double
  let goalCaption: String
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        // Icon on the left (glass circular background)
        Image(systemName: icon)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(color)
          .frame(width: 32, height: 32)
          .background(color.opacity(0.12), in: Circle())

        // Label and caption under it
        VStack(alignment: .leading, spacing: 2) {
          Text(label)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          
          Text(goalCaption)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(PulseTheme.tertiaryText)
            .lineLimit(1)
        }

        Spacer()

        // Value
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(value)
            .font(.system(size: 19, weight: .black, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          
          if !unit.isEmpty {
            Text(unit)
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(PulseTheme.secondaryText)
              .lineLimit(1)
          }
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(PulseTheme.secondaryText.opacity(0.4))
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}


struct WeekRingStrip: View {
  let days: [Bool]

  var body: some View {
    HStack(spacing: 7) {
      ForEach(0..<7, id: \.self) { index in
        Capsule()
          .fill(index < days.count && days[index] ? PulseTheme.ringStand : PulseTheme.separator.opacity(0.45))
          .frame(maxWidth: .infinity)
          .frame(height: 9)
      }
    }
    .accessibilityHidden(true)
  }
}


struct TodayMetricCard: View {
  let icon: String
  let color: Color
  let title: String
  let value: String
  let detail: String

  var body: some View {
    PulseCard(contentPadding: 14) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: icon)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(PulseTheme.secondaryText.opacity(0.32))
        }

        Text(value)
          .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
          .foregroundStyle(.primary)
          .lineLimit(1)
          .minimumScaleFactor(0.65)

        VStack(alignment: .leading, spacing: 2) {
          Text(localizedKey(title))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
          Text(detail)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(PulseTheme.tertiaryText)
        }

        Spacer(minLength: 0)

        Capsule()
          .fill(color.opacity(value == "0" ? 0.18 : 0.92))
          .frame(height: 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: 148)
    }
  }
}


struct TodayBarChartCard: View {
  let icon: String
  let color: Color
  let title: String
  let value: String
  let unit: String
  let chartData: [TodayChartPoint]
  var showsChevron: Bool = false

  var body: some View {
    let hasVisibleData = chartData.contains { $0.value > 0 }
    let maxValue = max(chartData.map(\.value).max() ?? 0, 1)

    PulseCard(contentPadding: 14) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 7) {
          Image(systemName: icon)
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(color)
          Text(localizedKey(title))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .layoutPriority(1)
          if showsChevron {
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(PulseTheme.secondaryText.opacity(0.4))
          }
        }

        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(value)
            .font(.system(size: 32, weight: .black, design: .rounded).monospacedDigit())
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.60)
          Text(unit)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: 0)

        Group {
          if hasVisibleData {
            Chart(chartData) { point in
              BarMark(
                x: .value("day", point.label),
                y: .value("val", point.value)
              )
              .foregroundStyle(point.isToday ? color : color.opacity(0.28))
              .clipShape(.rect(cornerRadius: PulseTheme.smallRadius))
            }
            .allowsHitTesting(false)
            .chartYScale(domain: 0...(maxValue * 1.18))
            .chartYAxis(.hidden)
            .chartXAxis {
              AxisMarks { value in
                AxisValueLabel {
                  if let s = value.as(String.self) {
                    Text(s)
                      .font(.system(size: 9, weight: .semibold))
                      .foregroundStyle(PulseTheme.tertiaryText)
                  }
                }
              }
            }
          } else {
            EmptyMetricBars(color: color, labels: chartData.map(\.label))
          }
        }
        .frame(height: 48)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: 148)
    }
  }
}


struct EmptyMetricBars: View {
  let color: Color
  var labels: [String] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .bottom, spacing: 7) {
        ForEach(0..<7, id: \.self) { index in
          Capsule()
            .fill(index == 6 ? color.opacity(0.26) : PulseTheme.separator.opacity(0.34))
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(16 + (index % 4) * 8))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

      HStack {
        ForEach(0..<7, id: \.self) { index in
          Text(labels.indices.contains(index) ? labels[index] : "")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(PulseTheme.tertiaryText)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .accessibilityHidden(true)
  }
}
