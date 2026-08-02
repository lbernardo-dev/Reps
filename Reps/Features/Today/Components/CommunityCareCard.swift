import SwiftUI

struct CommunityCareCard: View {
    var onSelectTab: ((AppTab) -> Void)? = nil

    @Environment(AppStore.self) private var store

    @State private var showAboutSheet: Bool = false
    @State private var showCustomizeSheet: Bool = false
    @State private var followingProfiles: [SocialProfile] = []
    @State private var cheeredFriends: Set<String> = []
    @State private var toastText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Care title + Info (i) button + Edit > button
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text(String(localized: "community_care_title"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Button {
                        HapticService.selection()
                        showAboutSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    HapticService.selection()
                    showCustomizeSheet = true
                } label: {
                    HStack(spacing: 2) {
                        Text(String(localized: "edit_action", defaultValue: "Edit"))
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(PulseTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            // Toast feedback if cheered
            if let toastText {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.heart.fill")
                        .foregroundStyle(.orange)
                    Text(toastText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(PulseTheme.card)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 4)
                .transition(.scale.combined(with: .opacity))
            }

            let activeFriends = getActiveFavorites()

            if activeFriends.isEmpty {
                // Empty state CTA: Invite friends banner
                VStack(spacing: 16) {
                    HStack(spacing: -12) {
                        EmptyAvatarBubble(name: "A", color: .orange)
                        EmptyAvatarBubble(name: "M", color: .pink)
                        EmptyAvatarBubble(name: "C", color: .green)
                        EmptyAvatarBubble(name: "L", color: .purple)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(String(localized: "care_more_fun_with_friends"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(String(localized: "care_more_fun_subtitle"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    Button {
                        HapticService.selection()
                        onSelectTab?(.profile)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                            Text(String(localized: "invite_friends_action"))
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [PulseTheme.accent, PulseTheme.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: PulseTheme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                // Active Friends Banner Grid & Interaction Rows
                VStack(spacing: 14) {
                    // Overlapping Real Avatars Header Row
                    HStack(spacing: -12) {
                        ForEach(activeFriends.prefix(5)) { friend in
                            RealAvatarBubbleView(friend: friend)
                        }
                        if activeFriends.count > 5 {
                            ZStack {
                                Circle()
                                    .fill(PulseTheme.accent.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                    .overlay(Circle().stroke(PulseTheme.card, lineWidth: 3))
                                Text("+\(activeFriends.count - 5)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulseTheme.accent)
                            }
                        }
                    }
                    .padding(.top, 6)

                    // Friends Activity & Cheer List
                    VStack(spacing: 10) {
                        ForEach(activeFriends.prefix(3)) { friend in
                            HStack(spacing: 12) {
                                ZStack(alignment: .bottomTrailing) {
                                    RealAvatarBubbleView(friend: friend, size: 40)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName.isEmpty ? "@\(friend.username)" : friend.displayName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 4) {
                                        Image(systemName: friend.isOnline ? "applewatch.radiowaves.left.and.right" : "clock")
                                            .font(.caption2)
                                            .foregroundStyle(friend.isOnline ? .green : PulseTheme.secondaryText)
                                        Text(friend.isOnline ? "En directo" : "@\(friend.username)")
                                            .font(.caption)
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                }

                                Spacer()

                                let hasCheered = cheeredFriends.contains(friend.username.lowercased())
                                Button {
                                    cheerFriend(friend)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: hasCheered ? "checkmark.circle.fill" : "bolt.heart.fill")
                                            .font(.system(size: 12, weight: .bold))
                                        Text(hasCheered ? String(localized: "cheer_friend") : String(localized: "cheer_friend"))
                                            .font(.caption.weight(.bold))
                                    }
                                    .foregroundStyle(hasCheered ? .green : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(hasCheered ? Color.green.opacity(0.15) : PulseTheme.accent)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(hasCheered)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .sheet(isPresented: $showAboutSheet) {
            CommunityCareAboutSheet()
        }
        .fullScreenCover(isPresented: $showCustomizeSheet) {
            CommunityCareCustomizeView(onSelectTab: onSelectTab)
        }
        .task {
            await loadFollowingProfiles()
        }
    }

    private func getActiveFavorites() -> [SocialProfile] {
        let savedFavorites = UserDefaults.standard.stringArray(forKey: "community_care_favorites_v1")
        if let savedFavorites, !savedFavorites.isEmpty {
            let favSet = Set(savedFavorites.map { $0.lowercased() })
            return followingProfiles.filter { favSet.contains($0.username.lowercased()) }
        }
        return followingProfiles
    }

    private func loadFollowingProfiles() async {
        let usernames = store.userProfile.socialFollowingUsernames
        if usernames.isEmpty {
            followingProfiles = []
            return
        }
        do {
            let fetched = try await SocialService.shared.fetchFollowing(myFollowingUsernames: usernames)
            if !fetched.isEmpty {
                followingProfiles = fetched
            } else {
                followingProfiles = usernames.map { uname in
                    SocialProfile(
                        username: uname,
                        displayName: uname.capitalized.replacingOccurrences(of: ".", with: " "),
                        level: 1
                    )
                }
            }
        } catch {
            followingProfiles = usernames.map { uname in
                SocialProfile(
                    username: uname,
                    displayName: uname.capitalized.replacingOccurrences(of: ".", with: " "),
                    level: 1
                )
            }
        }
    }

    private func cheerFriend(_ friend: SocialProfile) {
        HapticService.notification(.success)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            cheeredFriends.insert(friend.username.lowercased())
            let name = friend.displayName.isEmpty ? friend.username : friend.displayName
            toastText = String(format: String(localized: "community_care_cheered_toast"), name)
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation {
                toastText = nil
            }
        }
    }
}

// MARK: - Real Avatar Bubble Component

private struct RealAvatarBubbleView: View {
    let friend: SocialProfile
    var size: CGFloat = 50

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.18))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(PulseTheme.card, lineWidth: 2.5))

                if let data = friend.avatarImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PulseTheme.card, lineWidth: 2.5))
                } else {
                    Text(friend.username.prefix(1).uppercased())
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(PulseTheme.accent)
                }
            }

            if friend.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(PulseTheme.card, lineWidth: 2))
                    .offset(x: 1, y: 1)
            }
        }
    }
}

private struct EmptyAvatarBubble: View {
    let name: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(PulseTheme.card, lineWidth: 3))
            Text(name)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
        }
    }
}
