import Charts
import MuscleMap
import SwiftUI

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

/// Graphical, at-a-glance summary of the current week: an adherence ring plus
/// streak, volume and session tiles with week-over-week trend, plus all-time totals row.

struct ProgressHeroCard: View {
  let metrics: ProgressHeroMetrics
  var onTapStreak: (() -> Void)? = nil
  var onTapVolume: (() -> Void)? = nil
  var onTapSessions: (() -> Void)? = nil

  var body: some View {
    PulseCard(contentPadding: 0) {
      VStack(spacing: 0) {
        // ── Header ──────────────────────────────────────
        HStack(alignment: .center, spacing: 8) {
          Label(localizedString("this_week"), systemImage: "calendar")
            .font(.caption.weight(.black))
            .textCase(.uppercase)
            .foregroundStyle(PulseTheme.accent)
          Spacer()
          if let dir = weekDirection {
            HStack(spacing: 3) {
              Image(systemName: dir.icon)
                .font(.system(size: 9, weight: .black))
              Text(dir.label)
                .font(.caption2.weight(.black))
            }
            .foregroundStyle(dir.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(dir.color.opacity(0.14), in: Capsule())
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)

        // ── Three metric mini-cards ──────────────────────
        HStack(spacing: 10) {
          HeroTile(
            systemImage: "flame.fill",
            tint: PulseTheme.accent,
            value: "\(metrics.streak)",
            title: localizedString("streak"),
            subtitle: localizedString("days"),
            trend: nil,
            onTap: onTapStreak
          )
          HeroTile(
            systemImage: "scalemass.fill",
            tint: PulseTheme.ringStand,
            value: volumeText,
            title: localizedString("volume_label"),
            subtitle: nil,
            trend: metrics.volumeDelta.map { HeroTrend(percent: $0) },
            onTap: onTapVolume
          )
          HeroTile(
            systemImage: "dumbbell.fill",
            tint: PulseTheme.accent,
            value: "\(metrics.sessionsThisWeek)",
            title: localizedString("sessions"),
            subtitle: nil,
            trend: metrics.sessionsLastWeek > 0 ? HeroTrend(countDelta: metrics.sessionsDelta) : nil,
            onTap: onTapSessions
          )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)

        // ── 7-day activity strip ─────────────────────────
        WeekActivityStrip(weekStart: metrics.weekStart, activeDays: metrics.weekActivityDays)

        // ── Divider ─────────────────────────────────────
        Divider().padding(.horizontal, 16)

        // ── All-time totals ──────────────────────────────
        HStack(spacing: 0) {
          TotalStatPill(
            label: localizedString("total_sessions"),
            value: "\(metrics.totalSessions)"
          )
          Rectangle()
            .fill(PulseTheme.separator)
            .frame(width: 1, height: 24)
          TotalStatPill(
            label: localizedString("volume_label"),
            value: totalVolumeAllTimeText
          )
          Rectangle()
            .fill(PulseTheme.separator)
            .frame(width: 1, height: 24)
          TotalStatPill(
            label: localizedString("adherence"),
            value: "\(Int(metrics.adherence * 100))%"
          )
        }
        .padding(.vertical, 12)
      }
    }
  }

  private var weekDirection: (icon: String, label: String, color: Color)? {
    let sessionDelta = metrics.sessionsDelta
    let volDelta = metrics.volumeDelta ?? 0
    if sessionDelta > 0 || volDelta > 5 {
      return ("arrow.up.right", "+\(sessionDelta) sessions", PulseTheme.ringStand)
    } else if sessionDelta < 0 || volDelta < -5 {
      return ("arrow.down.right", "\(sessionDelta) sessions", PulseTheme.destructive)
    }
    return nil
  }

  private var volumeText: String {
    let v = metrics.volumeThisWeek
    if v >= 1000 { return String(format: "%.1ft", v / 1000) }
    return "\(Int(v.rounded())) kg"
  }

  private var totalVolumeAllTimeText: String {
    let v = metrics.totalVolumeKg
    if v >= 1000 { return String(format: "%.1ft", v / 1000) }
    return "\(Int(v.rounded())) kg"
  }
}


struct TotalStatPill: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 3) {
      Text(value)
        .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
        .foregroundStyle(.primary)
      Text(label)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
    .frame(maxWidth: .infinity)
  }
}

struct WeekActivityStrip: View {
  let weekStart: Date
  let activeDays: [Bool]

  private struct DayInfo: Identifiable {
    let id: Int
    let label: String
    let active: Bool
    let isToday: Bool
  }

  private var dayInfos: [DayInfo] {
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: .now)
    return (0..<7).compactMap { offset -> DayInfo? in
      guard let date = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
      let weekday = cal.component(.weekday, from: date)
      return DayInfo(
        id: offset,
        label: cal.veryShortWeekdaySymbols[weekday - 1].uppercased(),
        active: offset < activeDays.count && activeDays[offset],
        isToday: cal.startOfDay(for: date) == todayStart
      )
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(dayInfos) { day in
        VStack(spacing: 5) {
          ZStack {
            Circle()
              .fill(day.active ? PulseTheme.accent : Color.clear)
              .frame(width: 24, height: 24)
            Circle()
              .strokeBorder(
                day.active
                  ? Color.clear
                  : (day.isToday ? PulseTheme.accent.opacity(0.85) : PulseTheme.separator),
                lineWidth: 1.5
              )
              .frame(width: 24, height: 24)
            if day.active {
              Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
            }
          }
          Text(day.label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(
              day.active
                ? PulseTheme.textPrimary
                : (day.isToday ? PulseTheme.textPrimary : PulseTheme.secondaryText)
            )
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}


struct ProgressWeekContextCard: View {
  let sessionsThisWeek: Int
  let volumeThisWeek: Double
  let sessionsLastWeek: Int
  let volumeLastWeek: Double
  let streak: Int

  private var volumeDelta: Double {
    guard volumeLastWeek > 0 else { return 0 }
    return ((volumeThisWeek - volumeLastWeek) / volumeLastWeek) * 100
  }

  private var sessionsDelta: Int { sessionsThisWeek - sessionsLastWeek }

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 12) {
        Label(localizedString("progress_direction"), systemImage: "chart.line.uptrend.xyaxis")
          .font(.caption.weight(.black))
          .foregroundStyle(PulseTheme.accent)
          .textCase(.uppercase)

        HStack(spacing: 16) {
          contextStat(
            icon: "dumbbell.fill",
            value: sessionsDelta >= 0 ? "+\(sessionsDelta)" : "\(sessionsDelta)",
            label: localizedString("vs_last_week"),
            isPositive: sessionsDelta >= 0
          )
          contextStat(
            icon: "scalemass.fill",
            value: String(format: "%+.0f%%", volumeDelta),
            label: localizedString("volume_label"),
            isPositive: volumeDelta >= 0
          )
          contextStat(
            icon: "flame.fill",
            value: "\(streak)d",
            label: localizedString("streak"),
            isPositive: streak > 0
          )
        }
      }
    }
  }

  private func contextStat(icon: String, value: String, label: String, isPositive: Bool) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(isPositive ? PulseTheme.ringStand : PulseTheme.destructive)
        .frame(width: 32, height: 32)
        .background((isPositive ? PulseTheme.ringStand : PulseTheme.destructive).opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(value)
          .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
          .foregroundStyle(isPositive ? PulseTheme.ringStand : PulseTheme.destructive)
        Text(label)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(PulseTheme.secondaryText)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }
}


struct HeroTileDivider: View {
  var body: some View {
    Rectangle()
      .fill(PulseTheme.separator)
      .frame(width: 1, height: 44)
  }
}


struct HeroTrend {
  let isUp: Bool
  let label: String

  init(percent: Double) {
    isUp = percent >= 0
    label = String(format: "%@%.0f%%", percent >= 0 ? "+" : "", percent)
  }

  init(countDelta: Int) {
    isUp = countDelta >= 0
    label = "\(countDelta >= 0 ? "+" : "")\(countDelta)"
  }
}


struct HeroTile: View {
  let systemImage: String
  let tint: Color
  let value: String
  let title: String
  var subtitle: String? = nil
  let trend: HeroTrend?
  var onTap: (() -> Void)? = nil

  var body: some View {
    if let onTap {
      Button {
        HapticService.selection()
        onTap()
      } label: { content }
      .buttonStyle(.plain)
    } else {
      content
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: systemImage)
        .font(.system(size: 14, weight: .black))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

      Text(value)
        .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
        .foregroundStyle(PulseTheme.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.55)

      if let subtitle {
        Text("\(title) \(subtitle)")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(PulseTheme.secondaryText)
          .lineLimit(1)
      } else {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(PulseTheme.secondaryText)
          .lineLimit(1)
      }

      if let trend {
        HStack(spacing: 3) {
          Image(systemName: trend.isUp ? "arrow.up.right" : "arrow.down.right")
            .font(.system(size: 8, weight: .black))
          Text(trend.label)
            .font(.system(size: 10, weight: .black, design: .rounded).monospacedDigit())
        }
        .foregroundStyle(trend.isUp ? PulseTheme.ringStand : PulseTheme.destructive)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
          (trend.isUp ? PulseTheme.ringStand : PulseTheme.destructive).opacity(0.15),
          in: Capsule()
        )
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(PulseTheme.grouped.opacity(0.62))
        .overlay(
          LinearGradient(
            colors: [tint.opacity(0.10), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(tint.opacity(0.20), lineWidth: 1)
    )
    .shadow(color: tint.opacity(0.10), radius: 8, x: 0, y: 4)
  }
}
