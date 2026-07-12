import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                remindersSection
                categoriesSection
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .screenBackground()
        .navigationTitle(localizedString("notification_settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Push reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("notification_settings_push_header"))
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
                        .tint(PulseTheme.accent)
                    }
                    .padding(14)
                }
            }
        }
    }

    // MARK: - Inbox categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("notification_settings_categories_header"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            Text(localizedString("notification_settings_categories_footer"))
                .font(.caption)
                .foregroundStyle(PulseTheme.tertiaryText)
                .padding(.horizontal, 4)

            PulseCard {
                VStack(spacing: 0) {
                    ForEach(Array(visibleCategories.enumerated()), id: \.element) { idx, category in
                        categoryRow(category)
                        if idx < visibleCategories.count - 1 { Divider().padding(.leading, 54) }
                    }
                }
            }
        }
    }

    private var visibleCategories: [NotificationCategory] {
        var categories: [NotificationCategory] = [.workout, .achievement, .coaching]
        if store.userProfile.socialEnabled, store.userProfile.socialCapabilitiesAllowed {
            categories.append(.social)
        }
        return categories
    }

    private func categoryRow(_ category: NotificationCategory) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PulseTheme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.localizedTitle)
                    .font(.subheadline.weight(.semibold))
                Text(category.localizedSubtitle)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.isCategoryNotificationsEnabled(category) },
                set: { enabled in
                    HapticService.selection()
                    store.setCategoryNotificationsEnabled(category, enabled)
                }
            ))
            .labelsHidden()
            .tint(PulseTheme.accent)
        }
        .padding(14)
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
