import SwiftUI

struct ChallengeDetailView: View {
    @Environment(AppStore.self) private var store
    let challenge: SocialChallenge

    @State private var participants: [ChallengeParticipation] = []
    @State private var isLoading = false
    @State private var isJoining = false
    @State private var hasJoined = false
    @State private var joinError: String?

    private var myUsername: String? { store.userProfile.socialUsername?.lowercased() }
    private var isParticipating: Bool {
        hasJoined || participants.contains(where: { $0.participantUsername.lowercased() == myUsername })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                if !participants.isEmpty { leaderboardCard }
                if !isParticipating { joinCard }
                if let e = joinError {
                    Text(e).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 16)
        }
        .screenBackground()
        .navigationTitle(Text(challenge.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadParticipants() }
    }

    private var headerCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: metricIcon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedString("challenge_metric_\(challenge.metric.rawValue)"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.accent)
                            .textCase(.uppercase)
                        Text(challenge.title)
                            .font(.headline)
                    }
                    Spacer()
                }

                if !challenge.description.isEmpty {
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(challenge.startDate))
                            .font(.subheadline.weight(.semibold))
                        Text("challenge_start")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(challenge.endDate))
                            .font(.subheadline.weight(.semibold))
                        Text("challenge_end")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(challenge.participantCount)")
                            .font(.subheadline.weight(.bold))
                        Text("challenge_participants")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var leaderboardCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(PulseTheme.accent)
                        .font(.subheadline.weight(.bold))
                    Text("challenge_leaderboard")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    if isLoading { ProgressView().scaleEffect(0.7) }
                }

                ForEach(Array(participants.prefix(10).enumerated()), id: \.element.id) { idx, p in
                    let isMe = p.participantUsername.lowercased() == myUsername
                    HStack(spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.caption.weight(.black).monospacedDigit())
                            .foregroundStyle(idx < 3 ? PulseTheme.accent : PulseTheme.secondaryText)
                            .frame(width: 22)
                        Text(p.participantDisplayName)
                            .font(.subheadline.weight(isMe ? .bold : .regular))
                            .lineLimit(1)
                        if isMe {
                            Text("challenge_you")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(PulseTheme.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(PulseTheme.accent)
                        }
                        Spacer()
                        Text(formatValue(p.currentValue))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isMe ? PulseTheme.primary : PulseTheme.secondaryText)
                    }
                    if idx < min(participants.count, 10) - 1 {
                        Divider().padding(.leading, 32)
                    }
                }
            }
        }
    }

    private var joinCard: some View {
        PulseCard {
            VStack(spacing: 12) {
                Text("challenge_join_prompt")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await joinChallenge() }
                } label: {
                    HStack(spacing: 8) {
                        if isJoining {
                            ProgressView().scaleEffect(0.8).tint(.black)
                        } else {
                            Image(systemName: "flag.fill")
                        }
                        Text("challenge_join")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PulseTheme.accent, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isJoining)
            }
        }
    }

    private var metricIcon: String {
        switch challenge.metric {
        case .volumeKg: return "scalemass.fill"
        case .streak:   return "flame.fill"
        case .prCount:  return "medal.fill"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func formatValue(_ v: Double) -> String {
        switch challenge.metric {
        case .volumeKg: return String(format: "%.0f kg", v)
        case .streak:   return String(format: "%.0f sessions", v)
        case .prCount:  return String(format: "%.0f PRs", v)
        }
    }

    private func loadParticipants() async {
        isLoading = true
        participants = await SocialService.shared.fetchParticipants(challengeID: challenge.id)
        isLoading = false
    }

    private func joinChallenge() async {
        guard let uname = myUsername else { return }
        let dname = store.userProfile.displayName ?? uname
        isJoining = true
        joinError = nil
        do {
            try await SocialService.shared.joinChallenge(challenge.id, username: uname, displayName: dname)
            hasJoined = true
            await loadParticipants()
        } catch {
            joinError = error.localizedDescription
        }
        isJoining = false
    }
}
