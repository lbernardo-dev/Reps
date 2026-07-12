import Foundation

/// Engagement engine: evaluates the user's training state and emits
/// follow-up / control / evolution / planning notifications.
///
/// Two delivery channels, kept deliberately separate so we never spam:
///   • In-app inbox (the bell) — always populated; silent, just badges the bell.
///   • System notifications   — only scheduled for *future* delivery and only
///     when reminders are enabled, so they reach the user when the app is closed.
///
/// Every check is de-duplicated via UserDefaults buckets so re-entering the app
/// many times a day never produces duplicate entries.
extension AppStore {

    private enum EngineKey {
        static let inactivity = "engine_inactivity_bucket_v1"
        static let weeklyRecap = "engine_weekly_recap_week_v1"
        static let deload = "engine_deload_day_v1"
        static let goalPrefix = "engine_goal_reached_"
    }

    /// Call on every foreground transition. Cheap; all heavy work is guarded by
    /// de-dup buckets so it does real work at most once per relevant period.
    func runEngagementChecks(now: Date = .now) {
        evaluateInactivity(now: now)
        evaluateWeeklyRecap(now: now)
        evaluateDeloadSuggestion(now: now)
        evaluateGoalsReached(now: now)
    }

    // MARK: - Compliance / adherence — inactivity

    private func evaluateInactivity(now: Date) {
        guard userProfile.onboardingCompleted else { return }
        guard let lastSession = workoutSessions.map(\.date).max() else { return }

        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastSession),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        // Only nudge at meaningful milestones, once per (milestone, day).
        let milestones = [3, 5, 7, 14, 21, 30]
        guard milestones.contains(days) else { return }

        let bucket = "\(days)-\(dayKey(now))"
        guard consumeBucket(EngineKey.inactivity, value: bucket) else { return }

        saveActivityEvent(
            icon: "figure.run",
            colorName: "orange",
            title: localizedString("notif_inactivity_title"),
            subtitle: localizedFormat("notif_inactivity_body_format", days),
            date: now,
            category: .coaching
        )

        guard userProfile.remindersEnabled else { return }
        let fireDate = nextMorning(after: now, hour: 9)
        let captured = days
        Task {
            try? await NotificationService.scheduleRetentionNudge(
                title: localizedString("notif_inactivity_title"),
                body: localizedFormat("notif_inactivity_body_format", captured),
                date: fireDate
            )
        }
    }

    // MARK: - Compliance + evolution — weekly recap

    private func evaluateWeeklyRecap(now: Date) {
        guard userProfile.onboardingCompleted else { return }
        let calendar = Calendar.current
        let weekKey = isoWeekKey(now)
        // Fire once per ISO week, and never on the very first day so there is a
        // full previous week to summarise.
        guard consumeBucket(EngineKey.weeklyRecap, value: weekKey) else { return }

        guard let lastWeekInterval = previousWeekInterval(now: now, calendar: calendar) else { return }
        let lastWeekSessions = workoutSessions.filter { lastWeekInterval.contains($0.date) }
        guard !lastWeekSessions.isEmpty else { return }

        let volume = FitnessMetrics.totalVolumeKg(for: lastWeekSessions)
        let volumeText = formattedVolume(volume)
        saveActivityEvent(
            icon: "calendar.badge.checkmark",
            colorName: "primaryBright",
            title: localizedString("inbox_weekly_recap_title"),
            subtitle: localizedFormat("inbox_weekly_recap_subtitle_format", lastWeekSessions.count, volumeText),
            date: now,
            destination: .workoutHistory,
            category: .coaching
        )

        // Evolution: volume trend vs the week before that.
        if let priorInterval = weekInterval(weeksAgo: 2, now: now, calendar: calendar) {
            let priorVolume = FitnessMetrics.totalVolumeKg(for: workoutSessions.filter { priorInterval.contains($0.date) })
            if priorVolume > 0 {
                let delta = Int(((volume - priorVolume) / priorVolume) * 100)
                if delta >= 10 {
                    saveActivityEvent(
                        icon: "chart.line.uptrend.xyaxis",
                        colorName: "primaryBright",
                        title: localizedString("inbox_volume_up_title"),
                        subtitle: localizedFormat("inbox_volume_up_subtitle_format", delta),
                        date: now,
                        destination: .workoutHistory,
                        category: .coaching
                    )
                }
            }
        }
    }

    // MARK: - Planning — deload suggestion

    private func evaluateDeloadSuggestion(now: Date) {
        guard userProfile.onboardingCompleted else { return }
        let battery = trainingBattery
        // Persistently high load = low recovery battery.
        guard battery.level <= 35 else { return }
        guard consumeBucket(EngineKey.deload, value: dayKey(now)) else { return }

        saveActivityEvent(
            icon: "bolt.heart",
            colorName: "yellow",
            title: localizedString("notif_deload_title"),
            subtitle: localizedString("notif_deload_body"),
            date: now,
            category: .coaching
        )

        guard userProfile.remindersEnabled else { return }
        let fireDate = now.addingTimeInterval(3 * 3600)
        Task {
            try? await NotificationService.scheduleRetentionNudge(
                title: localizedString("notif_deload_title"),
                body: localizedString("notif_deload_body"),
                date: fireDate
            )
        }
    }

    // MARK: - Evolution — goals reached

    private func evaluateGoalsReached(now: Date) {
        for goal in goals where goal.target > 0 && goal.current >= goal.target {
            let key = EngineKey.goalPrefix + goal.id.uuidString
            guard !UserDefaults.standard.bool(forKey: key) else { continue }
            UserDefaults.standard.set(true, forKey: key)

            saveActivityEvent(
                icon: "target",
                colorName: "primaryBright",
                title: localizedString("notif_goal_reached_title"),
                subtitle: localizedFormat("notif_goal_reached_body_format", goal.title),
                date: now,
                category: .achievement
            )

            guard userProfile.remindersEnabled else { continue }
            let title = goal.title
            Task {
                try? await NotificationService.scheduleGoalReached(goalTitle: title)
            }
        }
    }

    // MARK: - Evolution — personal record (called at workout-finish time)

    func recordPersonalRecordEvent(exerciseName: String, date: Date) {
        saveActivityEvent(
            icon: "rosette",
            colorName: "yellow",
            title: localizedString("inbox_pr_title"),
            subtitle: localizedFormat("notif_pr_body_format", exerciseName),
            date: date,
            destination: .personalRecords,
            category: .achievement
        )
    }

    // MARK: - Helpers

    private func consumeBucket(_ key: String, value: String) -> Bool {
        guard UserDefaults.standard.string(forKey: key) != value else { return false }
        UserDefaults.standard.set(value, forKey: key)
        return true
    }

    private func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func isoWeekKey(_ date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-W\(c.weekOfYear ?? 0)"
    }

    private func nextMorning(after date: Date, hour: Int) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = 0
        let today = calendar.date(from: comps) ?? date
        if today > date.addingTimeInterval(60) { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? date.addingTimeInterval(3600)
    }

    private func previousWeekInterval(now: Date, calendar: Calendar) -> DateInterval? {
        weekInterval(weeksAgo: 1, now: now, calendar: calendar)
    }

    private func weekInterval(weeksAgo: Int, now: Date, calendar: Calendar) -> DateInterval? {
        guard let target = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) else { return nil }
        return calendar.dateInterval(of: .weekOfYear, for: target)
    }

    private func formattedVolume(_ kg: Double) -> String {
        let usesMetric = userProfile.units == .metric
        let value = usesMetric ? kg : kg * 2.2046226218
        let unit = usesMetric ? "kg" : "lb"
        if value >= 1000 {
            return String(format: "%.1ft %@", value / 1000, unit)
        }
        return String(format: "%.0f %@", value, unit)
    }
}
