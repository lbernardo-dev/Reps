import AppIntents
import WidgetKit
import SwiftUI

struct RepsFriendsEntry: TimelineEntry {
    let date: Date
    let entries: [SharedLeaderboardEntry]
    let snapshot: SharedWorkoutSnapshot
    let configuredBackgroundColor: WidgetColor
}

struct RepsFriendsProvider: AppIntentTimelineProvider {
    typealias Entry = RepsFriendsEntry
    typealias Intent = RepsWidgetConfigurationIntent

    func placeholder(in context: Context) -> RepsFriendsEntry {
        RepsFriendsEntry(
            date: .now,
            entries: [
                SharedLeaderboardEntry(rank: 1, username: "you", xp: 2100, isMe: true),
                SharedLeaderboardEntry(rank: 2, username: "friend1", xp: 1800, isMe: false),
                SharedLeaderboardEntry(rank: 3, username: "friend2", xp: 1400, isMe: false)
            ],
            snapshot: SharedWorkoutStore.load(),
            configuredBackgroundColor: .system
        )
    }

    func snapshot(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> RepsFriendsEntry {
        RepsFriendsEntry(
            date: .now,
            entries: SharedLeaderboardStore.load(),
            snapshot: SharedWorkoutStore.load(),
            configuredBackgroundColor: configuration.backgroundColor
        )
    }

    func timeline(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> Timeline<RepsFriendsEntry> {
        let entry = RepsFriendsEntry(
            date: .now,
            entries: SharedLeaderboardStore.load(),
            snapshot: SharedWorkoutStore.load(),
            configuredBackgroundColor: configuration.backgroundColor
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct RepsFriendsWidget: Widget {
    let kind = "RepsFriendsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RepsWidgetConfigurationIntent.self, provider: RepsFriendsProvider()) { entry in
            RepsFriendsWidgetView(entry: entry)
        }
        .configurationDisplayName(localizedKey("friends_widget_name"))
        .description(localizedKey("friends_widget_description"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

// MARK: - View

private struct RepsFriendsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsFriendsEntry

    var body: some View {
        let _ = RepsLocalization.use(entry.snapshot.preferredLanguage)
        let backgroundColor = WidgetColor.resolved(
            appColorName: entry.snapshot.widgetAccentColorName,
            widgetBackgroundColor: entry.configuredBackgroundColor
        )
        let theme = backgroundColor.theme
        switch family {
        case .systemSmall: smallView(backgroundColor: backgroundColor, theme: theme)
        default: mediumView(backgroundColor: backgroundColor, theme: theme)
        }
    }

    private func smallView(backgroundColor: WidgetColor, theme: WidgetTheme) -> some View {
        let me = entry.entries.first(where: \.isMe)
        return VStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.tint)
            if let me {
                Text("#\(me.rank)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(theme.foreground)
                Text(localizedFormat("among %@ friends", String(entry.entries.count)))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.secondaryForeground)
                    .multilineTextAlignment(.center)
                Text("\(me.xp) XP")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(theme.tint)
            } else {
                Text("—")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(theme.secondaryForeground)
                Text(localizedKey("widget_open_reps_to_sync"))
                    .font(.system(size: 10))
                    .foregroundStyle(theme.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .repsWidgetBackground(backgroundColor)
        .widgetURL(URL(string: "reps://social"))
    }

    private func mediumView(backgroundColor: WidgetColor, theme: WidgetTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.isDarkBackground ? Color(red: 1.0, green: 0.8, blue: 0.2) : .orange)
                Text(localizedKey("widget_friends_leaderboard"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text(localizedKey("social_by_xp"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.secondaryForeground)
            }
            .padding(.bottom, 10)

            if entry.entries.isEmpty {
                Spacer()
                Text(localizedKey("widget_follow_friends_hint"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(spacing: 6) {
                    ForEach(entry.entries.prefix(4)) { e in
                        leaderboardRow(e, theme: theme)
                    }
                }
            }
        }
        .padding(14)
        .repsWidgetBackground(backgroundColor)
        .widgetURL(URL(string: "reps://social"))
    }

    private func leaderboardRow(_ e: SharedLeaderboardEntry, theme: WidgetTheme) -> some View {
        let medals = ["🥇", "🥈", "🥉"]
        let rankLabel = e.rank <= 3 ? medals[e.rank - 1] : "#\(e.rank)"
        return HStack(spacing: 8) {
            Text(rankLabel)
                .font(.system(size: e.rank <= 3 ? 14 : 11, weight: .bold))
                .frame(width: 22, alignment: .leading)
            Text(e.isMe ? localizedKey("social_you_label") : "@\(e.username)")
                .font(.system(size: 12, weight: e.isMe ? .bold : .regular))
                .foregroundStyle(e.isMe ? theme.tint : theme.foreground)
                .lineLimit(1)
            Spacer()
            Text("\(e.xp) XP")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(e.isMe ? theme.tint : theme.secondaryForeground)
        }
    }
}
