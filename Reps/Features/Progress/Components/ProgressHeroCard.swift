import Foundation

struct ProgressHeroMetrics {
  let streak: Int
  let adherence: Double
  let sessionsThisWeek: Int
  let sessionsLastWeek: Int
  let volumeThisWeek: Double
  let volumeLastWeek: Double
  var totalSessions: Int = 0
  var totalVolumeKg: Double = 0
  var weekStart: Date = .now
  var weekActivityDays: [Bool] = Array(repeating: false, count: 7)

  var volumeDelta: Double? {
    guard volumeLastWeek > 0 else { return nil }
    return (volumeThisWeek - volumeLastWeek) / volumeLastWeek * 100
  }

  var sessionsDelta: Int { sessionsThisWeek - sessionsLastWeek }
}
