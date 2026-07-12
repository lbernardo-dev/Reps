import SwiftUI

struct NotificationsView: View {
    private enum InboxTab: Hashable {
        case pending, read
    }

    @Environment(AppStore.self) private var store
    @State private var activeDestination: InboxDestination?
    @State private var selectedTab: InboxTab = .pending
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                tabPicker
                activitySection
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .screenBackground()
        .navigationTitle(localizedString("notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        HapticService.selection()
                        store.markAllActivityEventsAsRead()
                    } label: {
                        Label(localizedString("notifications_mark_all_read"), systemImage: "checkmark.circle")
                    }
                    .disabled(store.pendingActivityEvents.isEmpty)

                    Button(role: .destructive) {
                        HapticService.selection()
                        store.deleteReadActivityEvents()
                    } label: {
                        Label(localizedString("notifications_delete_read"), systemImage: "trash")
                    }
                    .disabled(store.readActivityEvents.isEmpty)

                    Divider()

                    Button {
                        HapticService.selection()
                        showSettings = true
                    } label: {
                        Label(localizedString("notification_settings_title"), systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { store.markBellAsRead() }
        .navigationDestination(isPresented: $showSettings) {
            NotificationSettingsView()
        }
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

    // MARK: - Tabs

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text(pendingTabTitle).tag(InboxTab.pending)
            Text(readTabTitle).tag(InboxTab.read)
        }
        .pickerStyle(.segmented)
    }

    private var pendingTabTitle: String {
        let count = store.pendingActivityEvents.count
        guard count > 0 else { return localizedString("notifications_pending") }
        return "\(localizedString("notifications_pending")) (\(count))"
    }

    private var readTabTitle: String {
        localizedString("notifications_read")
    }

    // MARK: - Activity

    private var activitySection: some View {
        let items = selectedTab == .pending ? store.pendingActivityEvents : store.readActivityEvents

        return Group {
            if items.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: selectedTab == .pending ? "notifications_empty_title" : "notifications_read_empty_title",
                        message: selectedTab == .pending ? "notifications_empty_message" : "notifications_read_empty_message",
                        systemImage: selectedTab == .pending ? "bell.slash" : "tray"
                    )
                    .padding(.vertical, 8)
                }
            } else {
                PulseCard {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            row(for: item)
                            if idx < items.count - 1 { Divider().padding(.leading, 54) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: NotificationEvent) -> some View {
        Group {
            if let destination = item.destination {
                Button {
                    HapticService.selection()
                    if !item.isRead { store.markActivityEventAsRead(item.id) }
                    activeDestination = destination
                } label: {
                    activityRow(item, isTappable: true)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    HapticService.selection()
                    if !item.isRead { store.markActivityEventAsRead(item.id) }
                } label: {
                    activityRow(item, isTappable: false)
                }
                .buttonStyle(.plain)
                .disabled(item.isRead)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticService.selection()
                store.deleteActivityEvent(item.id)
            } label: {
                Label(localizedString("notifications_delete"), systemImage: "trash")
            }

            if item.isRead {
                Button {
                    HapticService.selection()
                    store.markActivityEventAsUnread(item.id)
                } label: {
                    Label(localizedString("notifications_mark_unread"), systemImage: "envelope.badge")
                }
                .tint(PulseTheme.accent)
            } else {
                Button {
                    HapticService.selection()
                    store.markActivityEventAsRead(item.id)
                } label: {
                    Label(localizedString("notifications_mark_read"), systemImage: "checkmark")
                }
                .tint(PulseTheme.ringStand)
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
                if !item.isRead {
                    Circle()
                        .fill(PulseTheme.destructive)
                        .frame(width: 9, height: 9)
                        .offset(x: 16, y: -16)
                }
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
}
