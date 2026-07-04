import Foundation
import UserNotifications

enum NotificationService {
    enum Kind: String, Sendable {
        case workoutReminder
        case missedWorkoutCheck
        case dailySummary
        case batteryRecoverySuggestion
        case retentionNudge
        case personalRecord
        case streakAtRisk
        case achievementUnlocked
        case gymRenewal
    }

    /// User-tappable action surfaced on the notification (long-press / Notification Center).
    enum Action: Equatable, Sendable {
        case open            // default tap
        case logWorkout      // open straight into logging
        case markDone        // mark the scheduled workout complete
        case snooze          // reschedule the reminder ~1h later

        init(actionIdentifier: String) {
            switch actionIdentifier {
            case Identifiers.logWorkoutAction: self = .logWorkout
            case Identifiers.markDoneAction: self = .markDone
            case Identifiers.snoozeAction: self = .snooze
            default: self = .open
            }
        }
    }

    struct NotificationTarget: Equatable, Sendable {
        let kind: Kind
        let scheduledWorkoutID: UUID?
        let scheduledDate: Date?
        var action: Action = .open

        func with(action: Action) -> NotificationTarget {
            NotificationTarget(
                kind: kind,
                scheduledWorkoutID: scheduledWorkoutID,
                scheduledDate: scheduledDate,
                action: action
            )
        }
    }

    enum Identifiers {
        static let workoutReminderCategory = "WORKOUT_REMINDER"
        static let missedWorkoutCategory = "MISSED_WORKOUT"
        static let logWorkoutAction = "LOG_WORKOUT"
        static let markDoneAction = "MARK_DONE"
        static let snoozeAction = "SNOOZE"
    }

    private static let workoutReminderPrefix = "workout-reminder-"
    private static let missedWorkoutPrefix = "missed-workout-"
    private static let dailySummaryIdentifier = "daily-summary"
    private static let batterySuggestionIdentifier = "battery-recovery-suggestion"
    private static let retentionNudgePrefix = "retention-nudge-"
    private static let personalRecordPrefix = "personal-record-"
    private static let streakAtRiskIdentifier = "streak-at-risk"
    private static let achievementPrefix = "achievement-"
    private static let snoozePrefix = "snoozed-"
    private static let gymRenewalPrefix = "gym-renewal-"

    private static let kindKey = "notification_kind"
    private static let scheduledWorkoutIDKey = "scheduled_workout_id"
    private static let scheduledWorkoutDateKey = "scheduled_workout_date"

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// Registers the actionable categories. Call once at launch so taps and
    /// long-press actions resolve correctly (also on cold launch).
    static func registerCategories() {
        let logWorkout = UNNotificationAction(
            identifier: Identifiers.logWorkoutAction,
            title: localizedString("notif_action_log_workout"),
            options: [.foreground]
        )
        let markDone = UNNotificationAction(
            identifier: Identifiers.markDoneAction,
            title: localizedString("notif_action_mark_done"),
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Identifiers.snoozeAction,
            title: localizedString("notif_action_snooze"),
            options: []
        )

        let reminder = UNNotificationCategory(
            identifier: Identifiers.workoutReminderCategory,
            actions: [logWorkout, markDone, snooze],
            intentIdentifiers: [],
            options: []
        )
        let missed = UNNotificationCategory(
            identifier: Identifiers.missedWorkoutCategory,
            actions: [markDone, logWorkout],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([reminder, missed])
    }

    private static let restTimerIdentifier = "rest-timer-end"

    /// Schedules a local alert for the end of the current rest period so the
    /// user gets notified even if the app is suspended in the background.
    /// Replaces any previously scheduled rest alert.
    static func scheduleRestEndNotification(after seconds: Int, nextExerciseName: String? = nil) {
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = localizedString("rest_finished")
        if let nextExerciseName, !nextExerciseName.isEmpty {
            content.body = localizedFormat("next_value_format", nextExerciseName)
        } else {
            content.body = localizedString("next_set_time")
        }
        content.sound = .default
        content.threadIdentifier = "rest-timer"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: restTimerIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelRestEndNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restTimerIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [restTimerIdentifier])
    }

    static func scheduleWorkoutReminder(for scheduledWorkout: ScheduledWorkout) async throws {
        guard let request = workoutReminderRequest(for: scheduledWorkout, now: .now) else {
            return
        }
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleMissedWorkoutCheck(for scheduledWorkout: ScheduledWorkout) async throws {
        guard let request = missedWorkoutRequest(for: scheduledWorkout, now: .now) else {
            return
        }
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleDailySummary(hour: Int = 22, minute: Int = 0) async throws {
        let request = dailySummaryRequest(hour: hour, minute: minute)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleBatteryRecoverySuggestion(level: Int, suggestion: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = localizedFormat("notif_battery_recovery_title_format", level)
        content.body = suggestion
        content.sound = .default
        content.threadIdentifier = "training-battery"
        content.userInfo = [
            kindKey: Kind.batteryRecoverySuggestion.rawValue
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 45 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: batterySuggestionIdentifier,
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleRetentionNudge(title: String, body: String, date: Date, now: Date = .now) async throws {
        guard date > now.addingTimeInterval(60) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "retention"
        content.userInfo = [
            kindKey: Kind.retentionNudge.rawValue
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let request = UNNotificationRequest(
            identifier: "\(retentionNudgePrefix)\(iso8601String(from: date))",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    /// Celebrates a freshly-achieved personal record. Fires a few seconds later
    /// so it lands right after the user finishes (and never while logging).
    static func schedulePersonalRecordCelebration(exerciseName: String, delay: TimeInterval = 4) async throws {
        let content = UNMutableNotificationContent()
        content.title = localizedString("notif_pr_title")
        content.body = localizedFormat("notif_pr_body_format", exerciseName)
        content.sound = .default
        content.threadIdentifier = "achievements"
        content.userInfo = [kindKey: Kind.personalRecord.rawValue]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(personalRecordPrefix)\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    /// Schedules a reminder for the evening of a day where the streak would
    /// otherwise break. Replaces any previously scheduled streak reminder.
    static func scheduleStreakAtRiskReminder(currentStreak: Int, hour: Int = 19, minute: Int = 0, now: Date = .now) async throws {
        guard currentStreak > 0 else { return }
        let fireDate = notificationDate(for: now, hour: hour, minute: minute)
        guard fireDate > now.addingTimeInterval(60) else { return }

        let content = UNMutableNotificationContent()
        content.title = localizedFormat("notif_streak_at_risk_title_format", currentStreak)
        content.body = localizedString("notif_streak_at_risk_body")
        content.sound = .default
        content.threadIdentifier = "streak"
        content.userInfo = [kindKey: Kind.streakAtRisk.rawValue]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: streakAtRiskIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakAtRiskIdentifier])
        try await center.add(request)
    }

    static func cancelStreakAtRiskReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [streakAtRiskIdentifier])
    }

    // MARK: - Gym membership renewal reminders

    /// Schedules a reminder ahead of a gym membership renewal/expiry. Identifier
    /// is stable per pass so re-saving replaces the previous reminder. Fires
    /// `daysBefore` days before `renewalDate` at the given hour.
    static func scheduleGymRenewalReminder(
        passID: UUID,
        gymName: String,
        renewalDate: Date,
        daysBefore: Int = 3,
        hour: Int = 9,
        now: Date = .now
    ) async throws {
        cancelGymRenewalReminder(passID: passID)

        let calendar = Calendar.current
        let dayBefore = calendar.date(byAdding: .day, value: -daysBefore, to: renewalDate) ?? renewalDate
        let fireDate = notificationDate(for: dayBefore, hour: hour, minute: 0)
        guard fireDate > now.addingTimeInterval(60) else { return }

        let content = UNMutableNotificationContent()
        content.title = localizedString("notif_gym_renewal_title")
        content.body = localizedFormat("notif_gym_renewal_body_format", gymName)
        content.sound = .default
        content.threadIdentifier = "gym-renewal"
        content.userInfo = [kindKey: Kind.gymRenewal.rawValue]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: "\(gymRenewalPrefix)\(passID.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    static func cancelGymRenewalReminder(passID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["\(gymRenewalPrefix)\(passID.uuidString)"]
        )
    }

    // MARK: - Leaderboard rank-change notifications

    private static let rankCacheKey = "leaderboard_rank_cache_v1"

    struct LeaderboardSnapshot: Codable {
        let username: String
        let rank: Int
        let xp: Int
    }

    static func checkAndNotifyLeaderboardChanges(
        current: [(username: String, rank: Int, xp: Int)],
        myUsername: String
    ) async {
        guard !myUsername.isEmpty,
              !current.isEmpty,
              await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        else { return }

        let previous: [LeaderboardSnapshot]
        if let data = UserDefaults.standard.data(forKey: rankCacheKey),
           let decoded = try? JSONDecoder().decode([LeaderboardSnapshot].self, from: data) {
            previous = decoded
        } else {
            // First run — just save, no notifications
            saveLeaderboardSnapshot(current)
            return
        }

        let prevDict = Dictionary(uniqueKeysWithValues: previous.map { ($0.username, $0) })
        let myPrev = prevDict[myUsername.lowercased()]
        let myNow = current.first { $0.username == myUsername.lowercased() }

        // Notify: someone entered the podium and overtook me
        for entry in current.prefix(3) where entry.username != myUsername.lowercased() {
            let wasPrev = prevDict[entry.username]
            if wasPrev == nil || (wasPrev?.rank ?? 99) > 3 {
                // This friend just entered the podium
                if let myPrevRank = myPrev?.rank, myPrevRank <= 3,
                   let myNowRank = myNow?.rank, myNowRank > 3 {
                    // I got kicked out of podium
                    try? await scheduleRankChangeNotif(
                        id: "rank_podium_lost",
                        title: localizedString("notif_rank_podium_lost_title"),
                        body: localizedFormat("notif_rank_podium_lost_body", "@\(entry.username)")
                    )
                } else {
                    try? await scheduleRankChangeNotif(
                        id: "rank_friend_podium_\(entry.username)",
                        title: localizedString("notif_rank_friend_podium_title"),
                        body: localizedFormat("notif_rank_friend_podium_body", "@\(entry.username)", entry.rank)
                    )
                }
            }
        }

        // Notify: someone overtook me specifically
        if let myPrevRank = myPrev?.rank, let myNowRank = myNow?.rank, myNowRank > myPrevRank {
            let overtaker = current.first { $0.rank == myNowRank - 1 && $0.username != myUsername.lowercased() }
            if let o = overtaker {
                try? await scheduleRankChangeNotif(
                    id: "rank_overtaken",
                    title: localizedString("notif_rank_overtaken_title"),
                    body: localizedFormat("notif_rank_overtaken_body", "@\(o.username)", myNowRank)
                )
            }
        }

        saveLeaderboardSnapshot(current)
    }

    private static func saveLeaderboardSnapshot(_ entries: [(username: String, rank: Int, xp: Int)]) {
        let snapshots = entries.map { LeaderboardSnapshot(username: $0.username, rank: $0.rank, xp: $0.xp) }
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: rankCacheKey)
        }
    }

    private static func scheduleRankChangeNotif(id: String, title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "leaderboard"
        content.userInfo = [kindKey: Kind.retentionNudge.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        try await center.add(request)
    }

    /// Celebrates a newly unlocked achievement.
    static func scheduleAchievementUnlocked(message: String, delay: TimeInterval = 3) async throws {
        let content = UNMutableNotificationContent()
        content.title = localizedString("notif_achievement_title")
        content.body = message
        content.sound = .default
        content.threadIdentifier = "achievements"
        content.userInfo = [kindKey: Kind.achievementUnlocked.rawValue]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(achievementPrefix)\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    private static let socialPrefix = "social-"

    /// Turns a CloudKit social subscription push into a visible local notification.
    /// `subscriptionID` is the one set in SocialService ("new-follower-…" / "new-like-…" / "new-comment-…").
    static func postCloudKitSocialNotification(subscriptionID: String) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.threadIdentifier = "social"

        if subscriptionID.hasPrefix("new-follower-") {
            content.title = localizedString("notif_new_follower_title")
            content.body = localizedString("notif_new_follower_body")
        } else if subscriptionID.hasPrefix("new-like-") {
            content.title = localizedString("notif_new_like_title")
            content.body = localizedString("notif_new_like_body")
        } else if subscriptionID.hasPrefix("new-comment-") {
            content.title = localizedString("notif_new_comment_title")
            content.body = localizedString("notif_new_comment_body")
        } else {
            return
        }

        // No routing kind: tapping simply opens the app (the social hub is not a
        // root tab), which keeps the launch path free of navigation side effects.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(socialPrefix)\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Celebrates a goal the user just reached. Routes to the progress tab.
    static func scheduleGoalReached(goalTitle: String, delay: TimeInterval = 3) async throws {
        let content = UNMutableNotificationContent()
        content.title = localizedString("notif_goal_reached_title")
        content.body = localizedFormat("notif_goal_reached_body_format", goalTitle)
        content.sound = .default
        content.threadIdentifier = "achievements"
        content.userInfo = [kindKey: Kind.achievementUnlocked.rawValue]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(achievementPrefix)goal-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    /// Re-schedules the notification ~1h later (snooze action handler).
    static func snooze(target: NotificationTarget, delay: TimeInterval = 3600) async {
        let content = UNMutableNotificationContent()
        switch target.kind {
        case .workoutReminder, .missedWorkoutCheck:
            content.title = localizedString("notif_workout_reminder_title")
            content.categoryIdentifier = Identifiers.workoutReminderCategory
        default:
            content.title = localizedString("notif_daily_summary_title")
        }
        content.body = localizedString("notif_streak_at_risk_body")
        content.sound = .default
        content.userInfo = notificationUserInfo(for: target)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(snoozePrefix)\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func reconcileScheduledReminders(
        for scheduledWorkouts: [ScheduledWorkout],
        includeDailySummary: Bool,
        now: Date = .now
    ) async {
        let center = UNUserNotificationCenter.current()
        await clearScheduledReminderRequests(using: center)

        for workout in uniqueUpcomingWorkouts(from: scheduledWorkouts) {
            do {
                if let reminder = workoutReminderRequest(for: workout, now: now) {
                    try await center.add(reminder)
                }
                if let missed = missedWorkoutRequest(for: workout, now: now) {
                    try await center.add(missed)
                }
            } catch {
                continue
            }
        }

        guard includeDailySummary else {
            return
        }

        do {
            try await center.add(dailySummaryRequest(hour: 22, minute: 0))
        } catch {
            return
        }
    }

    static func clearWorkoutReminders() {
        Task {
            await clearAllManagedRequests(using: UNUserNotificationCenter.current())
        }
    }

    static func notificationTarget(from userInfo: [AnyHashable: Any]) -> NotificationTarget? {
        guard let rawKind = userInfo[kindKey] as? String,
              let kind = Kind(rawValue: rawKind) else {
            return nil
        }

        let scheduledWorkoutID = (userInfo[scheduledWorkoutIDKey] as? String).flatMap(UUID.init(uuidString:))
        let scheduledDate = (userInfo[scheduledWorkoutDateKey] as? String).flatMap(date(from:))

        return NotificationTarget(
            kind: kind,
            scheduledWorkoutID: scheduledWorkoutID,
            scheduledDate: scheduledDate
        )
    }

    private static func workoutReminderRequest(
        for scheduledWorkout: ScheduledWorkout,
        now: Date
    ) -> UNNotificationRequest? {
        let fireDate = notificationDate(for: scheduledWorkout.date, hour: 8, minute: 0)
        guard fireDate > now.addingTimeInterval(60) else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = localizedString("notif_workout_reminder_title")
        content.body = localizedFormat("notif_workout_reminder_body_format", scheduledWorkout.workoutDay.title)
        content.sound = .default
        content.threadIdentifier = "workouts"
        content.categoryIdentifier = Identifiers.workoutReminderCategory
        content.userInfo = notificationUserInfo(
            kind: .workoutReminder,
            scheduledWorkout: scheduledWorkout
        )

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: workoutReminderIdentifier(for: scheduledWorkout),
            content: content,
            trigger: trigger
        )
    }

    private static func missedWorkoutRequest(
        for scheduledWorkout: ScheduledWorkout,
        now: Date
    ) -> UNNotificationRequest? {
        let fireDate = notificationDate(for: scheduledWorkout.date, hour: 21, minute: 0)
        guard fireDate > now.addingTimeInterval(60) else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = localizedString("notif_missed_workout_title")
        content.body = localizedFormat("notif_missed_workout_body_format", scheduledWorkout.workoutDay.title)
        content.sound = .default
        content.threadIdentifier = "workouts"
        content.categoryIdentifier = Identifiers.missedWorkoutCategory
        content.userInfo = notificationUserInfo(
            kind: .missedWorkoutCheck,
            scheduledWorkout: scheduledWorkout
        )

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: missedWorkoutIdentifier(for: scheduledWorkout),
            content: content,
            trigger: trigger
        )
    }

    private static func dailySummaryRequest(hour: Int, minute: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = localizedString("notif_daily_summary_title")
        content.body = localizedString("notif_daily_summary_body")
        content.sound = .default
        content.threadIdentifier = "daily-summary"
        content.userInfo = [
            kindKey: Kind.dailySummary.rawValue
        ]

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(
            identifier: dailySummaryIdentifier,
            content: content,
            trigger: trigger
        )
    }

    private static func notificationUserInfo(
        kind: Kind,
        scheduledWorkout: ScheduledWorkout
    ) -> [AnyHashable: Any] {
        [
            kindKey: kind.rawValue,
            scheduledWorkoutIDKey: scheduledWorkout.id.uuidString,
            scheduledWorkoutDateKey: iso8601String(from: scheduledWorkout.date)
        ]
    }

    private static func notificationUserInfo(for target: NotificationTarget) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            kindKey: target.kind.rawValue
        ]
        if let scheduledWorkoutID = target.scheduledWorkoutID {
            userInfo[scheduledWorkoutIDKey] = scheduledWorkoutID.uuidString
        }
        if let scheduledDate = target.scheduledDate {
            userInfo[scheduledWorkoutDateKey] = iso8601String(from: scheduledDate)
        }
        return userInfo
    }

    private static func uniqueUpcomingWorkouts(from scheduledWorkouts: [ScheduledWorkout]) -> [ScheduledWorkout] {
        var seen = Set<String>()

        return scheduledWorkouts
            .filter { $0.status == .scheduled }
            .sorted { $0.date < $1.date }
            .filter { workout in
                let key = semanticWorkoutKey(for: workout)
                return seen.insert(key).inserted
            }
    }

    private static func workoutReminderIdentifier(for scheduledWorkout: ScheduledWorkout) -> String {
        "\(workoutReminderPrefix)\(semanticWorkoutKey(for: scheduledWorkout))"
    }

    private static func missedWorkoutIdentifier(for scheduledWorkout: ScheduledWorkout) -> String {
        "\(missedWorkoutPrefix)\(semanticWorkoutKey(for: scheduledWorkout))"
    }

    private static func semanticWorkoutKey(for scheduledWorkout: ScheduledWorkout) -> String {
        let day = Calendar.current.startOfDay(for: scheduledWorkout.date)
        return "\(iso8601String(from: day))-\(scheduledWorkout.workoutDay.id.uuidString)"
    }

    private static func notificationDate(for baseDate: Date, hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? baseDate
    }

    private static func clearScheduledReminderRequests(using center: UNUserNotificationCenter) async {
        let scheduledIdentifiers = await pendingNotificationRequestIdentifiers(using: center)
            .filter(isScheduledReminderIdentifier(_:))

        center.removePendingNotificationRequests(withIdentifiers: scheduledIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: await deliveredReminderIdentifiers(using: center))
    }

    private static func clearAllManagedRequests(using center: UNUserNotificationCenter) async {
        let managedIdentifiers = await pendingNotificationRequestIdentifiers(using: center)
            .filter(isManagedIdentifier(_:))

        center.removePendingNotificationRequests(withIdentifiers: managedIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: await deliveredManagedIdentifiers(using: center))
    }

    private static func deliveredReminderIdentifiers(using center: UNUserNotificationCenter) async -> [String] {
        await deliveredIdentifiers(using: center, matching: .scheduledReminders)
    }

    private static func deliveredManagedIdentifiers(using center: UNUserNotificationCenter) async -> [String] {
        await deliveredIdentifiers(using: center, matching: .managed)
    }

    private static func deliveredIdentifiers(
        using center: UNUserNotificationCenter,
        matching scope: ManagedIdentifierScope
    ) async -> [String] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                let identifiers = notifications
                    .map(\.request.identifier)
                    .filter { identifier in
                        switch scope {
                        case .scheduledReminders:
                            isScheduledReminderIdentifier(identifier)
                        case .managed:
                            isManagedIdentifier(identifier)
                        }
                    }
                continuation.resume(returning: identifiers)
            }
        }
    }

    private static func pendingNotificationRequestIdentifiers(using center: UNUserNotificationCenter) async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    private static func isScheduledReminderIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(workoutReminderPrefix)
            || identifier.hasPrefix(missedWorkoutPrefix)
            || identifier == dailySummaryIdentifier
    }

    private static func isManagedIdentifier(_ identifier: String) -> Bool {
        isScheduledReminderIdentifier(identifier)
            || identifier == batterySuggestionIdentifier
            || identifier.hasPrefix(retentionNudgePrefix)
            || identifier.hasPrefix(personalRecordPrefix)
            || identifier == streakAtRiskIdentifier
            || identifier.hasPrefix(achievementPrefix)
            || identifier.hasPrefix(snoozePrefix)
    }

    private static func iso8601String(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func date(from string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }

    private enum ManagedIdentifierScope {
        case scheduledReminders
        case managed
    }
}

extension Notification.Name {
    static let repsNotificationTargetReady = Notification.Name("RepsNotificationTargetReady")
}

private final class NotificationCompletionBox: @unchecked Sendable {
    private let completion: () -> Void

    init(_ completion: @escaping () -> Void) {
        self.completion = completion
    }

    @MainActor
    func call() {
        completion()
    }
}

private final class NotificationPresentationCompletionBox: @unchecked Sendable {
    private let completion: (UNNotificationPresentationOptions) -> Void

    init(_ completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        self.completion = completion
    }

    @MainActor
    func call(_ options: UNNotificationPresentationOptions) {
        completion(options)
    }
}

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationRouter()

    @MainActor
    private var pendingTargets: [NotificationService.NotificationTarget] = []

    @MainActor
    func drainPendingTargets() -> [NotificationService.NotificationTarget] {
        let targets = pendingTargets
        pendingTargets.removeAll()
        return targets
    }

    @MainActor
    private func enqueue(_ target: NotificationService.NotificationTarget) {
        pendingTargets.append(target)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .repsNotificationTargetReady, object: nil)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let completion = NotificationPresentationCompletionBox(completionHandler)
        DispatchQueue.main.async {
            completion.call(self.presentationOptions)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let target = NotificationService.notificationTarget(from: userInfo)
        let action = NotificationService.Action(actionIdentifier: response.actionIdentifier)
        let actionID = response.actionIdentifier
        let categoryID = response.notification.request.content.categoryIdentifier
        let requestID = response.notification.request.identifier
        let completion = NotificationCompletionBox(completionHandler)

        Task {
            await handle(
                target: target,
                action: action,
                actionID: actionID,
                categoryID: categoryID,
                requestID: requestID
            )
            await completion.call()
        }
    }

    private var presentationOptions: UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    private func handle(
        target: NotificationService.NotificationTarget?,
        action: NotificationService.Action,
        actionID: String,
        categoryID: String,
        requestID: String
    ) async {
        // Crash breadcrumb: tapping a notification launches/foregrounds the app,
        // and this is exactly the path that has been terminating silently. The
        // trail is attached to the next crash report so we can see how far we got.
        await MainActor.run {
            TelemetryService.shared.setCrashKey("notification", forKey: "launch_source")
            TelemetryService.shared.breadcrumb("notif.did_receive", [
                "action_id": actionID,
                "category": categoryID,
                "identifier": requestID
            ])
        }

        // Snooze never needs the app UI: reschedule directly and stop.
        if action == .snooze {
            if let target {
                await NotificationService.snooze(target: target)
            }
            return
        }

        guard let target else {
            await MainActor.run {
                TelemetryService.shared.breadcrumb("notif.no_target")
            }
            return
        }

        let resolved = target.with(action: action)
        await enqueue(resolved)
    }
}
