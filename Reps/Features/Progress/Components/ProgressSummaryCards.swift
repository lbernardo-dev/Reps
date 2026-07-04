import Charts
import MuscleMap
import SwiftUI

struct DailySummaryFocusCard: View {
  let summary: String
  let readinessLevel: Int
  let sessionsToday: Int
  let activeEnergyToday: Int
  let stepsToday: Int
  let exerciseMinutesWeek: Int
  let hasHealthData: Bool
  let hasManualData: Bool
  let onOpenWorkout: () -> Void
  let onOpenCalendar: () -> Void

  private var readinessColor: Color {
    if readinessLevel >= 70 { return PulseTheme.ringExercise }
    if readinessLevel >= 45 { return PulseTheme.warning }
    return PulseTheme.destructive
  }

  private var headline: String {
    if !hasHealthData && !hasManualData {
      return "Configura Health o registra una sesión"
    }
    if sessionsToday > 0 {
      return "Sesión registrada hoy"
    }
    if readinessLevel < 45 {
      return "Hoy conviene bajar la carga"
    }
    return "Listo para entrenar con criterio"
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
            Text(summary)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(PulseTheme.secondaryText)
              .lineLimit(3)
              .minimumScaleFactor(0.82)
          }
        }

        HStack(spacing: 8) {
          DailySignalPill(
            title: "Hoy",
            value: sessionsToday > 0 ? "\(sessionsToday) ses." : "pendiente",
            systemImage: "checkmark.circle.fill",
            color: sessionsToday > 0 ? PulseTheme.ringExercise : PulseTheme.warning
          )
          DailySignalPill(
            title: "Health",
            value: activeEnergyToday > 0 ? "\(activeEnergyToday) kcal" : "\(stepsToday) pasos",
            systemImage: "heart.text.square.fill",
            color: PulseTheme.ringMove
          )
          DailySignalPill(
            title: "Semana",
            value: "\(exerciseMinutesWeek) min",
            systemImage: "figure.run",
            color: PulseTheme.ringStand
          )
        }

        HStack(spacing: 10) {
          Button(action: onOpenWorkout) {
            Label("Entrenar", systemImage: "play.fill")
              .font(.subheadline.weight(.black))
              .foregroundStyle(.black)
              .frame(maxWidth: .infinity)
              .frame(height: 42)
              .background(PulseTheme.ringExercise, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)

          Button(action: onOpenCalendar) {
            Label("Plan", systemImage: "calendar")
              .font(.subheadline.weight(.black))
              .foregroundStyle(.white.opacity(0.86))
              .frame(maxWidth: .infinity)
              .frame(height: 42)
              .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
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
        Label("Health + entrenamiento", systemImage: "point.3.connected.trianglepath.dotted")
          .font(.headline)
        Spacer()
        Text("\(Int(fatigueScore.rounded())) fatiga")
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
        SignalMetricTile(title: "Actividad", value: "\(activeKcal)", subtitle: "\(steps) pasos", systemImage: "flame.fill", color: PulseTheme.ringMove)
        SignalMetricTile(title: "Ejercicio", value: "\(exerciseMinutes)", subtitle: "min Health", systemImage: "figure.run", color: PulseTheme.ringExercise)
        SignalMetricTile(title: "Fuerza", value: "\(sessions)", subtitle: "\(volumeKg) kg volumen", systemImage: "dumbbell.fill", color: PulseTheme.accent)
        SignalMetricTile(
          title: "Recuperación",
          value: hrv.map { "\(Int($0)) ms" } ?? "--",
          subtitle: restingHeartRate.map { "\(Int($0)) lpm reposo" } ?? "sin FC reposo",
          systemImage: "heart.fill",
          color: PulseTheme.ringStand
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
  let onTapMove: () -> Void
  let onTapExercise: () -> Void
  let onTapStand: () -> Void

  var body: some View {
    PulseCard(contentPadding: 16) {
      VStack(alignment: .leading, spacing: 16) {
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
            Text("Ritmo semanal")
              .font(.caption.weight(.black))
              .foregroundStyle(PulseTheme.secondaryText)
            Spacer()
            Text("\(weeklyDays.filter { $0 }.count)/7")
              .font(.caption.weight(.black).monospacedDigit())
              .foregroundStyle(PulseTheme.ringStand)
          }
          WeekRingStrip(days: weeklyDays)
        }
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
        goalCaption: "vs semana previa",
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
        action: onTapExercise
      )
      Divider().opacity(0.10)
      RingsMetricRow(
        color: PulseTheme.ringStand,
        label: standLabel,
        value: standValue,
        unit: standGoal,
        progress: standProgress,
        goalCaption: "dias activos",
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


struct RingsMetricRow: View {
  let color: Color
  let label: String
  let value: String
  let unit: String
  let progress: Double
  let goalCaption: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 10) {
          Circle()
            .fill(color)
            .frame(width: 10, height: 10)
          Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
          Spacer()
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
              .font(.system(size: 23, weight: .heavy, design: .rounded).monospacedDigit())
              .foregroundStyle(color)
              .lineLimit(1)
              .minimumScaleFactor(0.62)
            if !unit.isEmpty {
              Text(unit)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            }
          }
          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(PulseTheme.secondaryText.opacity(0.4))
        }

        HStack(spacing: 8) {
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(PulseTheme.grouped)
              Capsule()
                .fill(color)
                .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
          }
          .frame(height: 5)
          .opacity(progress > 0 ? 1 : 0.55)

          Text(goalCaption)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(PulseTheme.tertiaryText)
            .lineLimit(1)
        }
      }
      .padding(.vertical, 13)
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
  let title: LocalizedStringKey
  let value: String
  let detail: String

  var body: some View {
    PulseCard(contentPadding: 14) {
      VStack(alignment: .leading, spacing: 10) {
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
      .frame(minHeight: 144)
    }
  }
}


struct TodayBarChartCard: View {
  let icon: String
  let color: Color
  let title: LocalizedStringKey
  let value: String
  let unit: String
  let chartData: [TodayChartPoint]
  var showsChevron: Bool = false

  var body: some View {
    let hasVisibleData = chartData.contains { $0.value > 0 }
    let maxValue = max(chartData.map(\.value).max() ?? 0, 1)

    PulseCard(contentPadding: 14) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 7) {
          Image(systemName: icon)
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(color)
          Text(localizedKey(title))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
          if showsChevron {
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(PulseTheme.secondaryText.opacity(0.4))
          }
        }

        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text(value)
            .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
            .foregroundStyle(.primary)
          Text(unit)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
        }

        Group {
          if hasVisibleData {
            Chart(chartData) { point in
              BarMark(
                x: .value("day", point.label),
                y: .value("val", point.value)
              )
              .foregroundStyle(point.isToday ? color : color.opacity(0.28))
              .cornerRadius(3)
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
        .frame(height: 72)
      }
      .frame(minHeight: 144, alignment: .top)
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
