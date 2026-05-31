import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func scheduleWorkoutReminder(for scheduledWorkout: ScheduledWorkout) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Entreno programado"
        content.body = "\(scheduledWorkout.workoutDay.title) está planificado para hoy. Regístralo al terminar para mantener calendario y analítica al día."
        content.sound = .default
        content.threadIdentifier = "workouts"

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: scheduledWorkout.date)
        components.hour = 8
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: scheduledWorkout.id.uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleMissedWorkoutCheck(for scheduledWorkout: ScheduledWorkout) async throws {
        let content = UNMutableNotificationContent()
        content.title = "¿Has entrenado hoy?"
        content.body = "Si completaste \(scheduledWorkout.workoutDay.title), regístralo ahora para mantener el progreso preciso."
        content.sound = .default
        content.threadIdentifier = "workouts"

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: scheduledWorkout.date)
        components.hour = 21
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "missed-\(scheduledWorkout.id.uuidString)", content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleDailySummary(hour: Int = 22, minute: Int = 0) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Resumen diario de Reps"
        content.body = "Revisa entreno, actividad y métricas corporales de hoy."
        content.sound = .default
        content.threadIdentifier = "daily-summary"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-summary", content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleBatteryRecoverySuggestion(level: Int, suggestion: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Batería de entrenamiento al \(level)%"
        content.body = suggestion
        content.sound = .default
        content.threadIdentifier = "training-battery"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 45 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "battery-recovery-suggestion", content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func clearWorkoutReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
