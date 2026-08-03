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
                        Text(localizedString("edit_action"))
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
                InviteFriendsBanner {
                    HapticService.selection()
                    onSelectTab?(.profile)
                }
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
                                        Text(localizedString("cheer_friend"))
                                            .font(.caption.weight(.bold))
                                    }
                                    .foregroundStyle(hasCheered ? .green : PulseTheme.onColor(PulseTheme.accent))
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

private struct InviteFriendsBanner: View {
    let inviteAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            InviteFriendsArtwork()
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text(String(localized: "care_more_fun_with_friends"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "care_more_fun_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: inviteAction) {
                Label(String(localized: "invite_friends_action"), systemImage: "person.crop.circle.badge.plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(PulseTheme.accent, in: Capsule())
                    .shadow(color: PulseTheme.accent.opacity(0.32), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// A native SF Symbols illustration that echoes the layered Memoji composition
/// used by Apple Health while avoiding a dependency on bundled artwork.
private struct InviteFriendsArtwork: View {
    var body: some View {
        HStack(spacing: -18) {
            InviteFriendAvatar(
                symbol: "person.crop.circle.fill",
                color: Color.orange,
                size: 66,
                badge: "figure.walk"
            )
            .offset(y: 4)

            InviteFriendAvatar(
                symbol: "person.crop.circle.fill",
                color: Color.pink,
                size: 88,
                badge: "applewatch"
            )
            .zIndex(1)

            InviteFriendAvatar(
                symbol: "person.crop.circle.fill",
                color: Color.mint,
                size: 66,
                badge: "heart.fill"
            )
            .offset(y: 4)
        }
        .accessibilityHidden(true)
    }
}

private struct InviteFriendAvatar: View {
    let symbol: String
    let color: Color
    let size: CGFloat
    let badge: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(color.gradient)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(PulseTheme.card, lineWidth: 3))

            Image(systemName: symbol)
                .font(.system(size: size * 0.62, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.92))

            Image(systemName: badge)
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size * 0.36, height: size * 0.36)
                .background(PulseTheme.grouped, in: Circle())
                .overlay(Circle().stroke(PulseTheme.card, lineWidth: 2))
                .offset(x: 2, y: 2)
        }
    }
}
