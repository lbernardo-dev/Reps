import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                activitySection
                settingsSection
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .screenBackground()
        .navigationTitle(localizedString("notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Recent Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("recent_activity"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            let items = recentActivityItems
            if items.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "notifications_empty_title",
                        message: "notifications_empty_message",
                        systemImage: "bell.slash"
                    )
                    .padding(.vertical, 8)
                }
            } else {
                PulseCard {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            activityRow(item)
                            if idx < items.count - 1 { Divider().padding(.leading, 54) }
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ item: ActivityItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Text(item.date, style: .relative)
                .font(.caption2)
                .foregroundStyle(PulseTheme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Notification Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("settings"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            PulseCard {
                VStack(spacing: 0) {
                    HStack {
                        Label(localizedString("workout_reminders"), systemImage: "alarm.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.userProfile.remindersEnabled },
                            set: { enabled in
                                store.userProfile.remindersEnabled = enabled
                                HapticService.selection()
                                if enabled {
                                    Task { await enableReminders() }
                                } else {
                                    NotificationService.clearWorkoutReminders()
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(PulseTheme.primary)
                    }
                    .padding(14)

                    Divider().padding(.leading, 14)

                    if store.userProfile.socialEnabled {
                        HStack {
                            Label(localizedString("social_activity_notifs"), systemImage: "person.2.fill")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.userProfile.autoShareWorkouts },
                                set: { store.userProfile.autoShareWorkouts = $0 }
                            ))
                            .labelsHidden()
                            .tint(PulseTheme.primary)
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    // MARK: - Activity Items

    private struct ActivityItem {
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let date: Date
    }

    private var recentActivityItems: [ActivityItem] {
        var items: [ActivityItem] = []

        // Streak milestone
        let streak = store.streakDays
        if streak > 0 && streak % 7 == 0 {
            items.append(ActivityItem(
                icon: "flame.fill",
                color: .orange,
                title: localizedFormat("streak_milestone_title", streak),
                subtitle: localizedString("streak_milestone_subtitle"),
                date: Calendar.current.startOfDay(for: .now)
            ))
        }

        // Latest session
        if let last = store.workoutSessions.sorted(by: { $0.date > $1.date }).first {
            items.append(ActivityItem(
                icon: "checkmark.circle.fill",
                color: PulseTheme.primaryBright,
                title: last.workoutTitle,
                subtitle: localizedFormat("session_completed_subtitle", Int(last.durationMinutes)),
                date: last.date
            ))
        }

        // PRs in last 7 days (simple heuristic: recent sessions with high volume)
        let week = Date.now.addingTimeInterval(-7 * 86400)
        let recentCount = store.workoutSessions.filter { $0.date > week }.count
        if recentCount >= 3 {
            items.append(ActivityItem(
                icon: "trophy.fill",
                color: .yellow,
                title: localizedFormat("active_week_title", recentCount),
                subtitle: localizedString("active_week_subtitle"),
                date: .now.addingTimeInterval(-86400)
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private func enableReminders() async {
        do {
            let granted = try await NotificationService.requestAuthorization()
            guard granted else {
                store.userProfile.remindersEnabled = false
                return
            }
            store.refreshNotificationSchedule()
        } catch {
            store.userProfile.remindersEnabled = false
        }
    }
}
