import SwiftUI

struct NotificationsView: View {
    @Environment(AppStore.self) private var store
    @State private var activeDestination: InboxDestination?

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
        .navigationDestination(item: $activeDestination) { destination in
            switch destination {
            case .workoutHistory:
                WorkoutHistoryView(sessions: store.workoutSessions.sorted { $0.date > $1.date })
            case .personalRecords:
                PersonalRecordsView()
            case .session(let id):
                if let session = store.workoutSessions.first(where: { $0.id.uuidString == id }) {
                    WorkoutSessionDetailView(session: session)
                } else {
                    WorkoutHistoryView(sessions: store.workoutSessions.sorted { $0.date > $1.date })
                }
            case .socialProfile(let username):
                SocialProfileDetailView(username: username)
            }
        }
    }

    // MARK: - Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("recent_activity"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            let items = store.activityEvents
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
                            if let destination = item.destination {
                                Button {
                                    HapticService.selection()
                                    activeDestination = destination
                                } label: {
                                    activityRow(item, isTappable: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                activityRow(item, isTappable: false)
                            }
                            if idx < items.count - 1 { Divider().padding(.leading, 54) }
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ item: NotificationEvent, isTappable: Bool) -> some View {
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
                    .foregroundStyle(.primary)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.tertiaryText)
                if isTappable {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
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
                        .tint(PulseTheme.accent)
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
                            .tint(PulseTheme.accent)
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
