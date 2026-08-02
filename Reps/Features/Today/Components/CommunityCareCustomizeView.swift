import SwiftUI

struct CommunityCareCustomizeView: View {
    var onSelectTab: ((AppTab) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var favorites: [String] = []
    @State private var availableFriends: [SocialProfile] = []
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Header Titles (Fully Localized)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "customize_favorites_title"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(String(localized: "customize_favorites_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 10)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(PulseTheme.accent)
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if availableFriends.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(PulseTheme.accent)

                        VStack(spacing: 6) {
                            Text(String(localized: "community_care_no_friends_title"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)

                            Text(String(localized: "community_care_no_friends_subtitle"))
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            HapticService.selection()
                            dismiss()
                            onSelectTab?(.profile)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text(String(localized: "community_care_find_friends"))
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(availableFriends) { friend in
                            HStack(spacing: 12) {
                                // Real Avatar Image or Initial Circle
                                ZStack {
                                    Circle()
                                        .fill(PulseTheme.accent.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    if let data = friend.avatarImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                    } else {
                                        Text(friend.username.prefix(1).uppercased())
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(PulseTheme.accent)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(friend.displayName.isEmpty ? "@\(friend.username)" : friend.displayName)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if friend.totalXP > 0 {
                                            Text("Lvl \(friend.level)")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundStyle(PulseTheme.accent)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(PulseTheme.accent.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Text("@\(friend.username)")
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { favorites.contains(friend.username.lowercased()) },
                                    set: { isSelected in
                                        let uname = friend.username.lowercased()
                                        if isSelected {
                                            if !favorites.contains(uname) {
                                                favorites.append(uname)
                                            }
                                        } else {
                                            favorites.removeAll { $0 == uname }
                                        }
                                        saveFavorites()
                                    }
                                ))
                                .labelsHidden()
                            }
                            .listRowBackground(PulseTheme.card)
                        }
                        .onMove(perform: moveFavorites)
                    }
                    .listStyle(.insetGrouped)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .background(PulseTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.selection()
                        saveFavorites()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .task {
                await loadRealData()
            }
        }
    }

    private func loadRealData() async {
        isLoading = true
        let saved = UserDefaults.standard.stringArray(forKey: "community_care_favorites_v1") ?? []
        favorites = saved.map { $0.lowercased() }

        let followedUsernames = store.userProfile.socialFollowingUsernames
        if followedUsernames.isEmpty {
            availableFriends = []
            isLoading = false
            return
        }

        do {
            let fetched = try await SocialService.shared.fetchFollowing(myFollowingUsernames: followedUsernames)
            if !fetched.isEmpty {
                availableFriends = fetched
            } else {
                // Fallback to local username stubs if CloudKit is offline/unreachable
                availableFriends = followedUsernames.map { uname in
                    SocialProfile(
                        username: uname,
                        displayName: uname.capitalized.replacingOccurrences(of: ".", with: " "),
                        level: 1
                    )
                }
            }
        } catch {
            availableFriends = followedUsernames.map { uname in
                SocialProfile(
                    username: uname,
                    displayName: uname.capitalized.replacingOccurrences(of: ".", with: " "),
                    level: 1
                )
            }
        }

        // If favorites is empty on first run, enable all friends by default
        if favorites.isEmpty && !availableFriends.isEmpty {
            favorites = availableFriends.map { $0.username.lowercased() }
            saveFavorites()
        }

        isLoading = false
    }

    private func saveFavorites() {
        UserDefaults.standard.set(favorites, forKey: "community_care_favorites_v1")
    }

    private func moveFavorites(from source: IndexSet, to destination: Int) {
        availableFriends.move(fromOffsets: source, toOffset: destination)
        favorites = availableFriends.map { $0.username.lowercased() }
        saveFavorites()
    }
}
