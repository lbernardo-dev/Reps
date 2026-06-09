import Foundation
import UserNotifications

enum NotificationService {
    enum Kind: String {
        case workoutReminder
        case missedWorkoutCheck
        case dailySummary
        case batteryRecoverySuggestion
        case retentionNudge
    }

    struct NotificationTarget: Equatable {
        let kind: Kind
        let scheduledWorkoutID: UUID?
        let scheduledDate: Date?
    }

    private static let workoutReminderPrefix = "workout-reminder-"
    private static let missedWorkoutPrefix = "missed-workout-"
    private static let dailySummaryIdentifier = "daily-summary"
    private static let batterySuggestionIdentifier = "battery-recovery-suggestion"
    private static let retentionNudgePrefix = "retention-nudge-"

    private static let kindKey = "notification_kind"
    private static let scheduledWorkoutIDKey = "scheduled_workout_id"
    private static let scheduledWorkoutDateKey = "scheduled_workout_date"

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
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
        content.title = "Batería de entrenamiento al \(level)%"
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
        content.title = "Entreno programado"
        content.body = "\(scheduledWorkout.workoutDay.title) está planificado para hoy. Regístralo al terminar para mantener calendario y analítica al día."
        content.sound = .default
        content.threadIdentifier = "workouts"
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
        content.title = "¿Has entrenado hoy?"
        content.body = "Si completaste \(scheduledWorkout.workoutDay.title), regístralo ahora para mantener el progreso preciso."
        content.sound = .default
        content.threadIdentifier = "workouts"
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
        content.title = "Resumen diario de Reps"
        content.body = "Revisa entreno, actividad y métricas corporales de hoy."
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

final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationRouter()

    @MainActor
    @Published private(set) var latestTarget: NotificationService.NotificationTarget?

    @MainActor
    func consumeLatestTarget() {
        latestTarget = nil
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let target = NotificationService.notificationTarget(from: response.notification.request.content.userInfo)
        await MainActor.run {
            latestTarget = target
        }
    }
}
