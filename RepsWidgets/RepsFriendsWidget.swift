import WidgetKit
import SwiftUI

struct RepsFriendsEntry: TimelineEntry {
    let date: Date
    let entries: [SharedLeaderboardEntry]
}

struct RepsFriendsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RepsFriendsEntry {
        RepsFriendsEntry(date: .now, entries: [
            SharedLeaderboardEntry(rank: 1, username: "you", xp: 2100, isMe: true),
            SharedLeaderboardEntry(rank: 2, username: "friend1", xp: 1800, isMe: false),
            SharedLeaderboardEntry(rank: 3, username: "friend2", xp: 1400, isMe: false)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (RepsFriendsEntry) -> Void) {
        completion(RepsFriendsEntry(date: .now, entries: SharedLeaderboardStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RepsFriendsEntry>) -> Void) {
        let entry = RepsFriendsEntry(date: .now, entries: SharedLeaderboardStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct RepsFriendsWidget: Widget {
    let kind = "RepsFriendsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RepsFriendsProvider()) { entry in
            RepsFriendsWidgetView(entry: entry)
                .containerBackground(Color(uiColor: .systemBackground), for: .widget)
        }
        .configurationDisplayName("friends_widget_name")
        .description("friends_widget_description")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - View

private struct RepsFriendsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsFriendsEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default: mediumView
        }
    }

    private var smallView: some View {
        let me = entry.entries.first(where: \.isMe)
        return ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.10, blue: 0.18), Color(red: 0.05, green: 0.05, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                if let me {
                    Text("#\(me.rank)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("among \(entry.entries.count) friends")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Text("\(me.xp) XP")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                } else {
                    Text("—")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(localizedKey("widget_open_reps_to_sync"))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
        }
    }

    private var mediumView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.10, blue: 0.18), Color(red: 0.05, green: 0.05, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.2))
                    Text(localizedKey("widget_friends_leaderboard"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("by XP")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 10)

                if entry.entries.isEmpty {
                    Spacer()
                    Text(localizedKey("widget_follow_friends_hint"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    VStack(spacing: 6) {
                        ForEach(entry.entries.prefix(4)) { e in
                            leaderboardRow(e)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private func leaderboardRow(_ e: SharedLeaderboardEntry) -> some View {
        let accent = Color(red: 0.4, green: 0.7, blue: 1.0)
        let medals = ["🥇", "🥈", "🥉"]
        let rankLabel = e.rank <= 3 ? medals[e.rank - 1] : "#\(e.rank)"
        return HStack(spacing: 8) {
            Text(rankLabel)
                .font(.system(size: e.rank <= 3 ? 14 : 11, weight: .bold))
                .frame(width: 22, alignment: .leading)
            Text(e.isMe ? "You" : "@\(e.username)")
                .font(.system(size: 12, weight: e.isMe ? .bold : .regular))
                .foregroundStyle(e.isMe ? accent : .white)
                .lineLimit(1)
            Spacer()
            Text("\(e.xp) XP")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(e.isMe ? accent : .white.opacity(0.7))
        }
    }
}
