import SwiftUI

// MARK: - SocialHubView

struct SocialHubView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .friends
    @State private var following: [SocialProfile] = []
    @State private var searchText = ""
    @State private var searchResults: [SocialProfile] = []
    @State private var selectedFriend: SocialProfile?
    @State private var isLoadingFollowing = false
    @State private var isSearching = false
    @State private var followingInProgress: Set<String> = []
    @State private var followerCount = 0
    @State private var loadError: String?
    @State private var showEditProfile = false

    private enum Tab { case friends, discover }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                navBar
                myProfileCard
                tabPicker

                switch tab {
                case .friends: friendsSection
                case .discover: discoverSection
                }

                if let friend = selectedFriend {
                    friendComparisonCard(friend: friend)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.bottom, 60)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadFollowing() }
        .onAppear {
            if let pending = store.pendingSocialSearch {
                store.pendingSocialSearch = nil
                searchText = pending
                tab = .discover
                scheduleSearch()
            }
        }
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        HStack {
            Button {
                HapticService.selection()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold))
                    Text(localizedString("profile")).font(.headline)
                }
                .foregroundStyle(PulseTheme.primary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(localizedString("friends_2"))
                .font(.system(size: 19, weight: .bold, design: .rounded))
            Spacer()
            if let uname = store.userProfile.socialUsername {
                let inviteText = localizedFormat("social_invite_text", uname, uname)
                ShareLink(item: inviteText) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PulseTheme.primary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).opacity(0)
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: - My Profile Card

    private var myProfileCard: some View {
        let xp = GamificationEngine.totalXP(
            sessions: store.workoutSessions,
            cardioLogs: store.combinedCardioLogs,
            bodyMetrics: store.bodyMetrics,
            progressPhotos: store.progressPhotos,
            streakDays: store.streakDays,
            totalVolumeKg: store.totalVolumeKg
        )
        let lvl = GamificationEngine.playerLevel(for: xp)
        let uname = store.userProfile.socialUsername ?? "—"
        let bio = store.userProfile.socialBio
        let loc = store.userProfile.socialLocation
        let plan = store.activePlan.name
        return PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(PulseTheme.primary.opacity(0.12))
                            .frame(width: 56, height: 56)
                        if let data = store.userProfile.avatarImageData,
                           let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg)
                                .resizable().scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        } else {
                            Text(String(uname.prefix(1)).uppercased())
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(PulseTheme.primary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("@\(uname)")
                            .font(.headline)
                        HStack(spacing: 6) {
                            Text("Lv.\(lvl.level) · \(lvl.title)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(PulseTheme.primary)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(PulseTheme.primary.opacity(0.10))
                                .clipShape(Capsule())
                            Text("\(xp) XP")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    Spacer()

                    Button {
                        showEditProfile = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(8)
                            .background(PulseTheme.grouped)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if !bio.isEmpty || !loc.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if !loc.isEmpty {
                            Label(loc, systemImage: "mappin")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        if !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                }

                if !plan.isEmpty {
                    Label(plan, systemImage: "calendar.badge.checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.primary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(PulseTheme.primary.opacity(0.08))
                        .clipShape(Capsule())
                }

                Divider()

                HStack {
                    statPill(value: "\(following.count)", label: localizedString("social_following"))
                    Divider().frame(height: 24)
                    statPill(value: "\(followerCount)", label: localizedString("social_followers"))
                    Divider().frame(height: 24)
                    statPill(value: "\(store.workoutSessions.count)", label: localizedString("social_workouts"))
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditSocialProfileView()
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: localizedString("friends_2"), value: .friends)
            tabButton(title: localizedString("social_discover"), value: .discover)
        }
        .padding(3)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tabButton(title: String, value: Tab) -> some View {
        Button {
            HapticService.selection()
            withAnimation(.snappy(duration: 0.2)) { tab = value }
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tab == value ? .primary : PulseTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    tab == value
                        ? AnyShapeStyle(PulseTheme.card)
                        : AnyShapeStyle(Color.clear),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Friends Section

    @ViewBuilder
    private var friendsSection: some View {
        if isLoadingFollowing {
            PulseCard {
                HStack {
                    Spacer()
                    ProgressView().tint(PulseTheme.primary)
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        } else if following.isEmpty {
            PulseCard {
                PulseEmptyState(
                    title: "social_no_friends_yet",
                    message: "social_no_friends_message",
                    systemImage: "person.2"
                )
                .padding(.vertical, 8)
            }
        } else {
            PulseCard {
                VStack(spacing: 0) {
                    ForEach(Array(following.enumerated()), id: \.element.id) { idx, friend in
                        Button {
                            HapticService.selection()
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedFriend = selectedFriend?.id == friend.id ? nil : friend
                            }
                        } label: {
                            friendRow(friend, isSelected: selectedFriend?.id == friend.id)
                        }
                        .buttonStyle(.plain)

                        if idx < following.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func friendRow(_ friend: SocialProfile, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PulseTheme.primary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Text(String(friend.username.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("@\(friend.username)")
                        .font(.subheadline.weight(.semibold))
                    if !friend.location.isEmpty {
                        Text("· \(friend.location)")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                if !friend.bio.isEmpty {
                    Text(friend.bio)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                } else {
                    HStack(spacing: 4) {
                        Text("Lv.\(friend.level)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.primary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(PulseTheme.primary.opacity(0.1))
                            .clipShape(Capsule())
                        Text(friend.levelTitle)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(friend.totalXP) XP")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                Text("\(friend.totalSessions) \(localizedString("social_workouts"))")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PulseTheme.secondaryText.opacity(0.5))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - Discover Section

    @ViewBuilder
    private var discoverSection: some View {
        VStack(spacing: 12) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PulseTheme.secondaryText)
                    .font(.subheadline)
                TextField(localizedString("social_search_placeholder"),
                          text: $searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .onChange(of: searchText) { _, _ in scheduleSearch() }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PulseTheme.secondaryText)
                    }.buttonStyle(.plain)
                }
                if isSearching {
                    ProgressView().scaleEffect(0.8).tint(PulseTheme.primary)
                }
            }
            .padding(10)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            if searchText.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "social_find_friends",
                        message: "social_find_friends_message",
                        systemImage: "magnifyingglass"
                    )
                    .padding(.vertical, 8)
                }
            } else if searchResults.isEmpty && !isSearching {
                PulseCard {
                    PulseEmptyState(
                        title: "social_no_results",
                        message: "social_no_results_message",
                        systemImage: "person.slash"
                    )
                    .padding(.vertical, 8)
                }
            } else if !searchResults.isEmpty {
                PulseCard {
                    VStack(spacing: 0) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { idx, profile in
                            searchResultRow(profile)
                            if idx < searchResults.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func searchResultRow(_ profile: SocialProfile) -> some View {
        let alreadyFollowing = following.contains(where: { $0.id == profile.id })
        let inProgress = followingInProgress.contains(profile.id)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text(String(profile.username.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(profile.username)")
                    .font(.subheadline.weight(.semibold))
                Text("Lv.\(profile.level) · \(profile.levelTitle)")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            Spacer()

            Button {
                toggleFollow(profile: profile)
            } label: {
                if inProgress {
                    ProgressView().tint(.white).scaleEffect(0.8)
                        .frame(width: 72)
                } else if alreadyFollowing {
                    Text(localizedString("social_following_button"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.primary)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(PulseTheme.primary.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text(localizedString("social_follow"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(PulseTheme.primary)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(inProgress)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - Friend Comparison Card

    private func friendComparisonCard(friend: SocialProfile) -> some View {
        let xp = GamificationEngine.totalXP(
            sessions: store.workoutSessions,
            cardioLogs: store.combinedCardioLogs,
            bodyMetrics: store.bodyMetrics,
            progressPhotos: store.progressPhotos,
            streakDays: store.streakDays,
            totalVolumeKg: store.totalVolumeKg
        )
        let lvl = GamificationEngine.playerLevel(for: xp)
        let myName = store.userProfile.socialUsername ?? localizedString("social_you")
        let myAhead = xp > friend.totalXP

        return PulseCard {
            VStack(spacing: 16) {
                // Verdict
                HStack(spacing: 10) {
                    Image(systemName: myAhead ? "trophy.fill" : "figure.run")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(myAhead ? PulseTheme.accent : PulseTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(myAhead
                             ? localizedString("social_you_ahead")
                             : localizedString("social_they_ahead"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(myAhead ? PulseTheme.accent : PulseTheme.secondaryText)
                        Text("@\(myName) vs @\(friend.username)")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    // Share
                    ShareLink(item: shareText(me: (name: myName, xp: xp, lvl: lvl.level, sessions: store.workoutSessions.count), friend: friend)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PulseTheme.primary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // Column headers
                HStack {
                    Spacer()
                    Text("@\(myName)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("@\(friend.username)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Rows
                compRow(icon: "star.fill", color: PulseTheme.accent,
                        title: "XP",
                        myVal: "\(xp)", theirVal: "\(friend.totalXP)",
                        myWins: xp >= friend.totalXP)
                compRow(icon: "chart.bar.fill", color: PulseTheme.primary,
                        title: localizedString("social_level"),
                        myVal: "Lv.\(lvl.level)", theirVal: "Lv.\(friend.level)",
                        myWins: lvl.level >= friend.level)
                compRow(icon: "dumbbell.fill", color: PulseTheme.primaryBright,
                        title: localizedString("social_sessions"),
                        myVal: "\(store.workoutSessions.count)", theirVal: "\(friend.totalSessions)",
                        myWins: store.workoutSessions.count >= friend.totalSessions)
                compRow(icon: "scalemass.fill", color: PulseTheme.accent,
                        title: "Volumen",
                        myVal: volumeLabel(store.totalVolumeKg), theirVal: volumeLabel(friend.totalVolumeKg),
                        myWins: store.totalVolumeKg >= friend.totalVolumeKg)
                compRow(icon: "flame.fill", color: .orange,
                        title: localizedString("social_streak"),
                        myVal: "\(store.streakDays)d", theirVal: "\(friend.streakDays)d",
                        myWins: store.streakDays >= friend.streakDays)
            }
        }
    }

    private func compRow(icon: String, color: Color, title: String, myVal: String, theirVal: String, myWins: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(myVal)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(myWins ? PulseTheme.primary : .primary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(theirVal)
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(!myWins ? PulseTheme.primary : PulseTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 3)
    }

    private func volumeLabel(_ kg: Double) -> String {
        kg >= 1000 ? String(format: "%.0fk", kg / 1000) : String(format: "%.0f", kg)
    }

    private func shareText(
        me: (name: String, xp: Int, lvl: Int, sessions: Int),
        friend: SocialProfile
    ) -> String {
        let ahead = me.xp > friend.totalXP
        let key = ahead ? "social_share_ahead" : "social_share_behind"
        return localizedFormat(key, me.name, friend.username, me.xp, friend.totalXP)
    }

    // MARK: - Data loading

    private func loadFollowing() async {
        isLoadingFollowing = true
        do {
            let usernames = store.userProfile.socialFollowingUsernames
            let f = try await SocialService.shared.fetchFollowing(myFollowingUsernames: usernames)
            following = f
            followerCount = f.count
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingFollowing = false
    }

    private func scheduleSearch() {
        let q = searchText
        guard !q.isEmpty else { searchResults = []; return }
        isSearching = true
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard searchText == q else { return }
            do {
                let results = try await SocialService.shared.searchUsers(query: q)
                await MainActor.run {
                    guard searchText == q else { return }
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run { isSearching = false }
            }
        }
    }

    private func toggleFollow(profile: SocialProfile) {
        let alreadyFollowing = following.contains(where: { $0.id == profile.id })
        followingInProgress.insert(profile.id)
        Task {
            do {
                if alreadyFollowing {
                    try await SocialService.shared.unfollow(profile)
                    await MainActor.run {
                        following.removeAll { $0.id == profile.id }
                        if selectedFriend?.id == profile.id { selectedFriend = nil }
                        store.userProfile.socialFollowingUsernames.removeAll { $0 == profile.username.lowercased() }
                    }
                } else {
                    try await SocialService.shared.follow(profile)
                    await MainActor.run {
                        following.append(profile)
                        let uname = profile.username.lowercased()
                        if !store.userProfile.socialFollowingUsernames.contains(uname) {
                            store.userProfile.socialFollowingUsernames.append(uname)
                        }
                    }
                }
            } catch {
                // Silently fail — UI stays consistent
            }
            await MainActor.run { _ = followingInProgress.remove(profile.id) }
        }
    }
}
