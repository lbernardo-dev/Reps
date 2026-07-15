import Charts
import MuscleMap
import SwiftUI

struct CardioAnalyticsPoint: Identifiable {
  let id: UUID
  let date: Date
  let distanceKm: Double
  let paceSecPerKm: Double
  let avgHR: Double?
  let ef: Double?
}


struct CardioAnalyticsCard: View {
  let logs: [CardioLog]
  let dateOfBirth: Date?

  enum Metric: String, CaseIterable, Identifiable {
    case paceDistance
    case paceHR
    case ef
    var id: String { rawValue }
    var title: String {
      switch self {
      case .paceDistance: return localizedString("pace_dist_label")
      case .paceHR: return localizedString("pace_hr_label")
      case .ef: return "EF"
      }
    }
  }

  enum DistanceBucket: String, CaseIterable, Identifiable {
    case all, sub1, r1to5, r5to10, r10to20, r20to40, r40plus
    var id: String { rawValue }
    var title: String {
      switch self {
      case .all: return localizedString("all_label")
      case .sub1: return "<1km"
      case .r1to5: return "1-5km"
      case .r5to10: return "5-10km"
      case .r10to20: return "10-20km"
      case .r20to40: return "20-40km"
      case .r40plus: return "40+km"
      }
    }
    func contains(_ km: Double) -> Bool {
      switch self {
      case .all: return true
      case .sub1: return km < 1
      case .r1to5: return km >= 1 && km < 5
      case .r5to10: return km >= 5 && km < 10
      case .r10to20: return km >= 10 && km < 20
      case .r20to40: return km >= 20 && km < 40
      case .r40plus: return km >= 40
      }
    }
  }

  @State private var metric: Metric = .paceDistance
  @State private var bucket: DistanceBucket = .all

  private var estimatedMaxHR: Double {
    FitnessMetrics.estimatedMaxHeartRate(dateOfBirth: dateOfBirth)
  }

  private var points: [CardioAnalyticsPoint] {
    logs.compactMap { log -> CardioAnalyticsPoint? in
      guard let km = log.distanceKm, km > 0, log.durationMinutes > 0 else { return nil }
      guard bucket.contains(km) else { return nil }
      let minutes = Double(log.durationMinutes)
      let pace = minutes * 60.0 / km
      let ef = log.averageHeartRate.flatMap { hr -> Double? in
        hr > 0 ? (km * 1000.0 / minutes) / hr : nil
      }
      return CardioAnalyticsPoint(
        id: log.id, date: log.date, distanceKm: km,
        paceSecPerKm: pace, avgHR: log.averageHeartRate, ef: ef)
    }
  }

  private func zoneColor(_ hr: Double?) -> Color {
    guard let hr else { return PulseTheme.secondaryText }
    switch hr / estimatedMaxHR {
    case ..<0.6: return PulseTheme.hrZones[0]
    case ..<0.7: return PulseTheme.hrZones[1]
    case ..<0.8: return PulseTheme.hrZones[2]
    case ..<0.9: return PulseTheme.hrZones[3]
    default: return PulseTheme.hrZones[4]
    }
  }

  private static func paceLabel(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "--" }
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("run_analysis")
          .font(.headline)

        Picker("metrics", selection: $metric) {
          ForEach(Metric.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(DistanceBucket.allCases) { option in
              let selected = bucket == option
              Button {
                bucket = option
              } label: {
                Text(option.title)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(selected ? PulseTheme.onColor(PulseTheme.accent) : PulseTheme.secondaryText)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(selected ? PulseTheme.accent : PulseTheme.grouped)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }

        if points.isEmpty {
          PulseEmptyState(
            title: "no_enough_data",
            message: "record_runs_with_distance_message",
            systemImage: "chart.dots.scatter"
          )
        } else {
          chart
            .frame(height: 200)
            .allowsHitTesting(false)

          if metric != .ef {
            HStack(spacing: 12) {
              ForEach(Array(zip(["Z1", "Z2", "Z3", "Z4", "Z5"],
                                [0.55, 0.65, 0.75, 0.85, 0.95])), id: \.0) { name, frac in
                HStack(spacing: 4) {
                  Circle().fill(zoneColor(frac * estimatedMaxHR)).frame(width: 8, height: 8)
                  Text(name).font(.caption2).foregroundStyle(PulseTheme.secondaryText)
                }
              }
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var chart: some View {
    switch metric {
    case .paceDistance:
      Chart(points) { point in
        PointMark(
          x: .value(localizedString("distance_label"), point.distanceKm),
          y: .value(localizedString("pace_label"), point.paceSecPerKm)
        )
        .foregroundStyle(zoneColor(point.avgHR))
      }
      .chartYAxis { axisPaceMarks }
      .chartXAxisLabel("km")
    case .paceHR:
      Chart(points.filter { $0.avgHR != nil }) { point in
        PointMark(
          x: .value(localizedString("avg_hr_label"), point.avgHR ?? 0),
          y: .value(localizedString("pace_label"), point.paceSecPerKm)
        )
        .foregroundStyle(zoneColor(point.avgHR))
      }
      .chartYAxis { axisPaceMarks }
      .chartXAxisLabel("ppm")
    case .ef:
      Chart(points.filter { $0.ef != nil }.sorted { $0.date < $1.date }) { point in
        LineMark(
          x: .value(localizedString("date_label"), point.date),
          y: .value("EF", point.ef ?? 0)
        )
        .foregroundStyle(PulseTheme.ringStand)
        PointMark(
          x: .value(localizedString("date_label"), point.date),
          y: .value("EF", point.ef ?? 0)
        )
        .foregroundStyle(PulseTheme.accent)
      }
      .chartYAxisLabel("m/min · ppm")
    }
  }

  private var axisPaceMarks: some AxisContent {
    AxisMarks { value in
      AxisGridLine()
      AxisValueLabel {
        if let seconds = value.as(Double.self) {
          Text(Self.paceLabel(seconds))
        }
      }
    }
  }
}

// MARK: - HR zone duration (time-in-zone aggregated by each session's average HR)


struct HRZoneDurationCard: View {
  let logs: [CardioLog]
  let dateOfBirth: Date?

  private struct Zone: Identifiable {
    let id: Int
    let name: String
    let color: Color
  }

  private var zones: [Zone] {
    (0..<5).map { Zone(id: $0, name: localizedString("zone_\($0 + 1)_label"), color: PulseTheme.hrZones[$0]) }
  }

  private var estimatedMaxHR: Double {
    FitnessMetrics.estimatedMaxHeartRate(dateOfBirth: dateOfBirth)
  }

  private func zoneIndex(_ hr: Double) -> Int {
    switch hr / estimatedMaxHR {
    case ..<0.6: return 0
    case ..<0.7: return 1
    case ..<0.8: return 2
    case ..<0.9: return 3
    default: return 4
    }
  }

  private var minutesByZone: [Int] {
    var mins = [0, 0, 0, 0, 0]
    for log in logs {
      guard let hr = log.averageHeartRate, hr > 0 else { continue }
      mins[zoneIndex(hr)] += log.durationMinutes
    }
    return mins
  }

  var body: some View {
    let mins = minutesByZone
    let total = mins.reduce(0, +)
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("time_in_hr_zones")
          .font(.headline)

        if total == 0 {
          PulseEmptyState(
            title: "no_hr_data",
            message: "log_cardio_with_hr_message",
            systemImage: "heart"
          )
        } else {
          GeometryReader { geo in
            HStack(spacing: 2) {
              ForEach(zones) { zone in
                let frac = Double(mins[zone.id]) / Double(total)
                Rectangle()
                  .fill(zone.color)
                  .frame(width: max(geo.size.width * frac, frac > 0 ? 3 : 0))
              }
            }
            .clipShape(Capsule())
          }
          .frame(height: 14)

          ForEach(zones) { zone in
            HStack(spacing: 10) {
              Circle().fill(zone.color).frame(width: 10, height: 10)
              Text(zone.name).font(.subheadline)
              Spacer()
              Text("\(mins[zone.id]) min")
                .font(.subheadline.weight(.semibold).monospacedDigit())
              Text("(\(Int((Double(mins[zone.id]) / Double(total) * 100).rounded()))%)")
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(width: 46, alignment: .trailing)
            }
          }

          Text("estimated_from_each_session_average_hr")
            .font(.caption2)
            .foregroundStyle(PulseTheme.secondaryText)
        }
      }
    }
  }
}

// MARK: - Pro insights teaser
