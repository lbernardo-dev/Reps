import Charts
import MuscleMap
import SwiftUI

struct TodayChartPoint: Identifiable {
  let id = UUID()
  let label: String
  let value: Double
  let isToday: Bool
}


struct BodyFusionPoint: Identifiable {
  let id = UUID()
  let date: Date
  let activity: Double
  let volume: Double
}


struct TrendMetric: Identifiable {
  enum Direction: Equatable { case up, down, neutral }
  let id = UUID()
  let title: String
  let value: String
  let unit: String
  let direction: Direction
  let color: Color
  /// When set, the tile is tappable and drills into the matching metric.
  var metric: SummaryMetric? = nil
}

enum ProgressSection: String, CaseIterable, Identifiable {
  case general
  case exercises
  case muscles
  case cardio
  case body
  case load

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .general: "general_label"
    case .exercises: "exercises_3"
    case .muscles: "muscles_label"
    case .cardio: "cardio"
    case .body: "body_2"
    case .load: "load"
    }
  }

  var titleKey: String {
    switch self {
    case .general: "general_label"
    case .exercises: "exercises_3"
    case .muscles: "muscles_label"
    case .cardio: "cardio"
    case .body: "body_2"
    case .load: "load"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "chart.bar.fill"
    case .exercises: "chart.line.uptrend.xyaxis"
    case .muscles: "figure.strengthtraining.traditional"
    case .cardio: "figure.run"
    case .body: "scalemass"
    case .load: "waveform.path.ecg"
    }
  }

  var tint: Color {
    switch self {
    case .general: PulseTheme.accent
    case .exercises: PulseTheme.ringStand
    case .muscles: PulseTheme.accent
    case .cardio: PulseTheme.recovery
    case .body: PulseTheme.warning
    case .load: PulseTheme.destructive
    }
  }
}

enum ProgressRange: String, CaseIterable, Identifiable {
  case week
  case month
  case year
  case all

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .week: "week_label"
    case .month: "month_label"
    case .year: "year_label"
    case .all: "all_time_label"
    }
  }

  var subtitle: LocalizedStringKey {
    switch self {
    case .week: "this_week"
    case .month: "this_month"
    case .year: "this_year"
    case .all: "all_time"
    }
  }

  var days: Int {
    switch self {
    case .week: 7
    case .month: 30
    case .year: 365
    case .all: 3650
    }
  }

  var chartUnit: Calendar.Component {
    switch self {
    case .week, .month: .day
    case .year, .all: .month
    }
  }

  var startDate: Date {
    if self == .all { return .distantPast }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
  }
}

enum ProgressDestination: String, Identifiable {
  case exerciseAnalytics
  case workoutHistory
  case personalRecords

  var id: String { rawValue }
}

/// A summary metric that can be tapped to drill into a detail screen
/// (or routed to another tab / specialised screen).
enum SummaryMetric: String, Identifiable {
  case volume
  case sessions
  case steps
  case distance
  case activeEnergy
  case streak
  case oneRepMax

  var id: String { rawValue }
}

