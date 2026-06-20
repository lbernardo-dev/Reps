import SwiftUI

struct NotificationsView: View {
    @Environment(AppStore.self) private var store

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
        .onAppear { store.markBellAsRead() }
    }

    // MARK: - Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("recent_activity"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            let items = store.loadActivityEvents()
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
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            activityRow(item)
                            if idx < items.count - 1 { Divider().padding(.leading, 54) }
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ item: NotificationEvent) -> some View {
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

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("settings"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            PulseCard {
                VStack(spacing: 0) {
                    // Workout reminders
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

                    if store.userProfile.socialEnabled {
                        Divider().padding(.leading, 14)

                        // Social activity notifications
                        HStack {
                            Label(localizedString("social_activity_notifs"), systemImage: "person.2.fill")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.userProfile.socialNotificationsEnabled },
                                set: { store.userProfile.socialNotificationsEnabled = $0 }
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

    // MARK: - Helpers

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
