import SwiftUI

// MARK: - SocialHubView

struct SocialHubView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .feed
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
    @State private var likedPostIDs: Set<String> = []
    @State private var likingInProgress: Set<String> = []
    @State private var suggestedProfiles: [SocialProfile] = []
    @State private var isLoadingSuggested = false
    @State private var recentSearches: [String] = []
    @State private var commentsPost: WorkoutPost? = nil
    @State private var showCreatePost = false
    @State private var showCreateChallenge = false
    @State private var showSocialOnboarding = false
    @State private var selectedChallenge: SocialChallenge? = nil

    private enum Tab { case feed, friends, challenges, discover }

    private static let recentSearchesKey = "social_recent_searches"

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                myProfileCard
                tabPicker

                switch tab {
                case .feed: feedSection
                case .friends: friendsSection
                case .challenges: challengesSection
                case .discover: discoverSection
                }

                if let friend = selectedFriend {
                    friendComparisonCard(friend: friend)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.bottom, 124)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            PulseHeaderBar(
                title: localizedString("social_hub"),
                subtitleKey: "friends_2"
            ) {
                socialHeaderActions
            }
        }
        .task { await loadFollowing(); await loadSuggested() }
        .task { if store.feedPosts.isEmpty { await store.loadFeed() } }
        .task { if store.activeChallenges.isEmpty { await store.loadChallenges() } }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView()
        }
        .navigationDestination(item: $selectedChallenge) { ch in
            ChallengeDetailView(challenge: ch)
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .feed {
                store.markFeedAsRead()
                if store.feedPosts.isEmpty { Task { await store.loadFeed() } }
            }
        }
        .onAppear {
            recentSearches = (UserDefaults.standard.stringArray(forKey: Self.recentSearchesKey) ?? [])
            if let pending = store.pendingSocialSearch {
                store.pendingSocialSearch = nil
                searchText = pending
                tab = .discover
                scheduleSearch()
            } else if store.userProfile.socialFollowingUsernames.isEmpty {
                tab = .discover
            }
            // Subscribe to push notifications for social activity
            if let uname = store.userProfile.socialUsername,
               store.userProfile.socialNotificationsEnabled {
                Task.detached { await SocialService.shared.subscribeToSocialActivity(myUsername: uname) }
            }
        }
        .sheet(item: $commentsPost) { post in
            CommentsView(post: post)
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
                .environment(store)
        }
        .sheet(isPresented: $showSocialOnboarding) {
            SocialOnboardingView()
                .environment(store)
        }
    }

    // MARK: - Header

    private var socialHeaderActions: some View {
        HStack(spacing: 6) {
            Button {
                HapticService.selection()
                if store.userProfile.socialUsername == nil {
                    showSocialOnboarding = true
                } else {
                    showCreatePost = true
                }
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                    .navigationGlassCircle(.secondary, tint: .clear)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizedString("post_new"))

            if let uname = store.userProfile.socialUsername {
                let inviteText = localizedFormat("social_invite_text", uname, uname)
                ShareLink(item: inviteText) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                        .navigationGlassCircle(.secondary, tint: .clear)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("share"))
            } else {
                Button {
                    HapticService.selection()
                    showSocialOnboarding = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                        .navigationGlassCircle(.secondary, tint: .clear)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("connect_with_friends"))
            }
        }
    }

    // MARK: - My Profile Card

    private var myProfileCard: some View {
        let xp = store.playerXP
        let lvl = GamificationEngine.playerLevel(for: xp)
        let uname = store.userProfile.socialUsername
        let bio = store.userProfile.socialBio
        let loc = store.userProfile.socialLocation
        let plan = store.activePlan.name
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now.addingTimeInterval(-604_800)
        let weekSessions = store.workoutSessions.filter { $0.date >= weekStart }
        let weekVolume = Int(FitnessMetrics.totalVolumeKg(for: weekSessions))
        return PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(PulseTheme.accent.opacity(0.12))
                            .frame(width: 56, height: 56)
                        if let data = store.userProfile.avatarImageData,
                           let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg)
                                .resizable().scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        } else if let uname {
                            Text(String(uname.prefix(1)).uppercased())
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(PulseTheme.accent)
                        } else {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(PulseTheme.accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: uname.map { "@\($0)" } ?? localizedString("social_username_label"))
                            .font(.headline)
                        HStack(spacing: 6) {
                            Text(localizedFormat("player_level_abbr_title_format", "\(lvl.level)", lvl.title))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(PulseTheme.accent)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(PulseTheme.accent.opacity(0.10))
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
                        .foregroundStyle(PulseTheme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(PulseTheme.accent.opacity(0.08))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    socialTrainingMetric(
                        value: "\(weekSessions.count)",
                        label: localizedString("this_week"),
                        systemImage: "figure.strengthtraining.traditional",
                        color: PulseTheme.accent
                    )
                    socialTrainingMetric(
                        value: "\(weekVolume)",
                        label: localizedString("volume_2"),
                        systemImage: "scalemass.fill",
                        color: PulseTheme.ringStand
                    )
                    socialTrainingMetric(
                        value: "\(store.streakDays)",
                        label: localizedString("streak"),
                        systemImage: "flame.fill",
                        color: PulseTheme.ringMove
                    )
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

    private func socialTrainingMetric(value: String, label: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            tabButton(title: localizedString("social_feed"), value: .feed)
            tabButton(title: localizedString("friends_2"), value: .friends)
            tabButton(title: localizedString("challenge_tab"), value: .challenges)
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

    // MARK: - Feed Section

    @ViewBuilder
    private var feedSection: some View {
        if store.isFeedLoading {
            ForEach(0..<4, id: \.self) { _ in
                PulseCard { PulseSkeleton(height: 100) }
            }
        } else if store.feedPosts.isEmpty {
            PulseCard {
                PulseEmptyState(
                    title: "social_feed_empty_title",
                    message: "social_feed_empty_message",
                    systemImage: "newspaper"
                )
                .padding(.vertical, 8)
            }
        } else {
            if !following.filter({ $0.isOnline }).isEmpty {
                activeFriendsStrip
            }
            ForEach(store.feedPosts) { post in
                workoutFeedCard(post)
            }
        }
    }

    private var activeFriendsStrip: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(PulseTheme.card, lineWidth: 1))
                    Text(localizedString("active_now"))
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(.green)
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(following.filter { $0.isOnline }) { friend in
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottomTrailing) {
                                    avatarCircle(data: friend.avatarImageData, username: friend.username, isMe: false, size: 48)
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 13, height: 13)
                                        .overlay(Circle().stroke(PulseTheme.card, lineWidth: 2))
                                }
                                Text("@\(friend.username)")
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(width: 56)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func workoutFeedCard(_ post: WorkoutPost) -> some View {
        let isLiked = likedPostIDs.contains(post.id)
        let isLiking = likingInProgress.contains(post.id)
        let isRecent = post.createdAt.timeIntervalSinceNow > -7200 // within 2 hours
        return PulseCard(contentPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Header ──────────────────────────────────────
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(PulseTheme.accent.opacity(0.10)).frame(width: 42, height: 42)
                        Text(String(post.ownerUsername.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("@\(post.ownerUsername)")
                            .font(.subheadline.weight(.semibold))
                        Text(post.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    if isRecent {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red, in: Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // ── Workout title ────────────────────────────────
                Text(post.workoutTitle)
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 14)

                // ── Stats chips row ──────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if post.durationSeconds > 0 {
                            feedStatChip(icon: "clock.fill", value: durationLabel(post.durationSeconds), color: PulseTheme.accent)
                        }
                        if post.volumeKg > 0 {
                            feedStatChip(icon: "scalemass.fill", value: volumeLabel(post.volumeKg), color: PulseTheme.ringStand)
                        }
                        if !post.exerciseNames.isEmpty {
                            feedStatChip(icon: "dumbbell.fill", value: "\(post.exerciseNames.count) ex", color: PulseTheme.accent)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.vertical, 8)

                // ── Caption ──────────────────────────────────────
                if let cap = post.caption, !cap.isEmpty, cap != post.workoutTitle {
                    Text(cap)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                }

                // ── Exercise chips ────────────────────────────────
                if !post.exerciseNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(post.exerciseNames.prefix(5), id: \.self) { name in
                                Text(name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(PulseTheme.accent.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            if post.exerciseNames.count > 5 {
                                Text("+\(post.exerciseNames.count - 5)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(PulseTheme.grouped)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .padding(.bottom, 6)
                }

                // ── Photos ────────────────────────────────────────
                if !post.photoDataList.isEmpty {
                    feedPhotoGrid(post.photoDataList)
                        .padding(.horizontal, 0)
                }

                // ── Divider + action bar ─────────────────────────
                Divider()
                HStack(spacing: 0) {
                    // Like
                    Button {
                        toggleLike(post: post)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isLiked ? PulseTheme.destructive : PulseTheme.secondaryText)
                            if post.likeCount > 0 {
                                Text("\(post.likeCount)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .opacity(isLiking ? 0.5 : 1)
                    .disabled(isLiking)

                    Divider().frame(height: 20)

                    // Comments
                    Button {
                        commentsPost = post
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            if commentCount(post) > 0 {
                                Text("\(commentCount(post))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }

                // ── Comments preview (Instagram-style) ───────────
                commentsPreview(post)
            }
        }
    }

    private func commentCount(_ post: WorkoutPost) -> Int {
        store.commentSummaries[post.id]?.count ?? 0
    }

    @ViewBuilder
    private func commentsPreview(_ post: WorkoutPost) -> some View {
        if let summary = store.commentSummaries[post.id], summary.count > 0 {
            VStack(alignment: .leading, spacing: 3) {
                if summary.count > 1 {
                    Text(localizedFormat("comments_view_all", summary.count))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                if let last = summary.lastComment {
                    Text("@\(last.ownerUsername) \(last.text)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { commentsPost = post }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
    }

    private func feedStatChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }

    private func feedPhotoGrid(_ photoList: [Data]) -> some View {
        let count = photoList.count
        let images = photoList.compactMap { UIImage(data: $0) }
        return Group {
            if count == 1, let img = images.first {
                singlePhoto(img)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: min(count, 2)), spacing: 2) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: count == 2 ? 140 : 100)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func singlePhoto(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable().scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func durationLabel(_ seconds: Int) -> String {
        let m = seconds / 60
        return m > 0 ? "\(m) min" : "—"
    }

    private func volumeLabel(_ kg: Double) -> String {
        let isImperial = store.userProfile.units == .imperial
        let val = isImperial ? kg * 2.20462 : kg
        let suffix = isImperial ? " lb" : " kg"
        return String(format: "%.0f\(suffix)", val)
    }

    // MARK: - Friends Section

    private struct LeaderboardEntry {
        let rank: Int
        let username: String
        let xp: Int
        let isMe: Bool
        let avatarImageData: Data?
        let isOnline: Bool
    }

    private var leaderboardEntries: [LeaderboardEntry] {
        let myXP = store.playerXP
        let myUsername = store.userProfile.socialUsername ?? ""
        var all: [(String, Int, Bool, Data?, Bool)] = following.map {
            ($0.username, $0.totalXP, false, $0.avatarImageData, $0.isOnline)
        }
        if !myUsername.isEmpty {
            all.append((myUsername, myXP, true, store.userProfile.avatarImageData, true))
        }
        return all
            .sorted { $0.1 > $1.1 }
            .enumerated()
            .map { idx, e in
                LeaderboardEntry(rank: idx + 1, username: e.0, xp: e.1,
                                 isMe: e.2, avatarImageData: e.3, isOnline: e.4)
            }
    }

    @ViewBuilder
    private func avatarCircle(data: Data?, username: String, isMe: Bool, size: CGFloat) -> some View {
        ZStack {
            if let d = data, let img = UIImage(data: d) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(isMe ? PulseTheme.accent.opacity(0.15) : PulseTheme.accent.opacity(0.08))
                    .frame(width: size, height: size)
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                    .foregroundStyle(isMe ? PulseTheme.accent : PulseTheme.accent)
            }
        }
    }

    // MARK: - Challenges Section

    @ViewBuilder
    private var challengesSection: some View {
        HStack {
            Text("challenge_tab")
                .font(.headline)
            Spacer()
            if store.userProfile.socialUsername != nil {
                Button {
                    HapticService.selection()
                    showCreateChallenge = true
                } label: {
                    Label("challenge_create", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }

        if store.isChallengesLoading {
            PulseCard {
                HStack { Spacer(); ProgressView().tint(PulseTheme.accent); Spacer() }
                    .padding(.vertical, 20)
            }
        } else if store.activeChallenges.isEmpty {
            PulseCard {
                PulseEmptyState(
                    title: "challenge_empty_title",
                    message: "challenge_empty_message",
                    systemImage: "flag"
                )
                .padding(.vertical, 8)
            }
        } else {
            ForEach(store.activeChallenges) { ch in
                challengeRow(ch)
            }
        }
    }

    private func challengeRow(_ ch: SocialChallenge) -> some View {
        let daysLeft = Int(ch.endDate.timeIntervalSinceNow / 86400)
        let iconName = ch.metric == .volumeKg ? "scalemass.fill" : ch.metric == .streak ? "flame.fill" : "medal.fill"
        let iconGradient = ch.isActive
            ? LinearGradient(colors: [PulseTheme.accent, PulseTheme.ringStand], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [PulseTheme.secondaryText.opacity(0.4), PulseTheme.secondaryText.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        return Button {
            HapticService.selection()
            selectedChallenge = ch
        } label: {
            PulseCard {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ch.isActive ? .black : .white)
                        .frame(width: 36, height: 36)
                        .background(iconGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(ch.title)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                        Text(localizedString("challenge_metric_\(ch.metric.rawValue)"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        if ch.isActive {
                            Text(localizedString("challenge_active"))
                                .font(.caption2.weight(.heavy))
                                .textCase(.uppercase)
                                .foregroundStyle(PulseTheme.recovery)
                        } else {
                            Text(localizedString("challenge_ended"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Text(localizedFormat("challenge_participants_count", ch.participantCount))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                        if daysLeft > 0 && ch.isActive {
                            Text(localizedFormat("days_remaining_format", daysLeft))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var friendsSection: some View {
        if isLoadingFollowing {
            PulseCard {
                HStack { Spacer(); ProgressView().tint(PulseTheme.accent); Spacer() }
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
            leaderboardCard
            friendListCard
        }
    }

    private var leaderboardCard: some View {
        let entries = leaderboardEntries
        let top = Array(entries.prefix(3))
        let rest = Array(entries.dropFirst(3))
        return PulseCard {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(PulseTheme.accent)
                        .font(.subheadline.weight(.bold))
                    Text(localizedString("social_leaderboard"))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(localizedString("social_by_xp"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                // Podium (up to 3)
                if top.count >= 2 {
                    podiumView(entries: top)
                    if !rest.isEmpty { Divider() }
                }

                // Ranked table for positions 4+
                if !rest.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(rest.enumerated()), id: \.element.rank) { idx, entry in
                            leaderboardRow(entry)
                            if idx < rest.count - 1 { Divider().padding(.leading, 36) }
                        }
                    }
                }
            }
        }
    }

    private func podiumView(entries: [LeaderboardEntry]) -> some View {
        let order: [Int]
        switch entries.count {
        case 1: order = [0]
        case 2: order = [1, 0]
        default: order = [1, 0, 2]
        }
        let medals = ["🥇", "🥈", "🥉"]
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(order, id: \.self) { i in
                let entry = entries[i]
                let isFirst = i == 0
                VStack(spacing: 4) {
                    Text(medals[i])
                        .font(.system(size: isFirst ? 26 : 20))
                    let sz: CGFloat = isFirst ? 52 : 42
                    ZStack(alignment: .bottomTrailing) {
                        avatarCircle(data: entry.avatarImageData, username: entry.username,
                                     isMe: entry.isMe, size: sz)
                        if entry.isOnline {
                            Circle().fill(.green).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                        }
                    }
                    Text(entry.isMe ? localizedString("social_you_label") : "@\(entry.username)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(entry.isMe ? PulseTheme.accent : .primary)
                        .lineLimit(1)
                    Text("\(entry.xp) XP")
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, isFirst ? 8 : 0)
            }
        }
        .padding(.vertical, 4)
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: 10) {
            Text("#\(entry.rank)")
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(width: 26, alignment: .trailing)
            ZStack(alignment: .bottomTrailing) {
                avatarCircle(data: entry.avatarImageData, username: entry.username,
                             isMe: entry.isMe, size: 30)
                if entry.isOnline {
                    Circle().fill(.green).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                }
            }
            Text(entry.isMe ? localizedString("social_you_label") : "@\(entry.username)")
                .font(.subheadline.weight(entry.isMe ? .bold : .regular))
                .foregroundStyle(entry.isMe ? PulseTheme.accent : .primary)
                .lineLimit(1)
            Spacer()
            if entry.isOnline && !entry.isMe {
                Text(localizedString("social_online"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.green.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text("\(entry.xp) XP")
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(entry.isMe ? PulseTheme.accent : PulseTheme.accent)
        }
        .padding(.vertical, 8)
    }

    private var friendListCard: some View {
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

    private func friendRow(_ friend: SocialProfile, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                avatarCircle(data: friend.avatarImageData, username: friend.username, isMe: false, size: 44)
                if friend.isOnline {
                    Circle().fill(.green).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.5))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("@\(friend.username)")
                        .font(.subheadline.weight(.semibold))
                    if friend.isOnline {
                        Text(localizedString("social_online"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.green.opacity(0.12))
                            .clipShape(Capsule())
                    } else if !friend.location.isEmpty {
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
                        Text(localizedFormat("player_level_abbr_format", "\(friend.level)"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.accent)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(PulseTheme.accent.opacity(0.1))
                            .clipShape(Capsule())
                        Text(friend.levelTitle)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
                if friend.streakDays > 0 {
                    HStack(spacing: 3) {
                        Text("🔥")
                            .font(.system(size: 10))
                        Text("\(friend.streakDays)d")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.orange.opacity(0.10))
                    .clipShape(Capsule())
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
                TextField(localizedString("social_search_placeholder"), text: $searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .onChange(of: searchText) { _, new in
                        scheduleSearch()
                        if new.isEmpty { searchResults = [] }
                    }
                if !searchText.isEmpty {
                    Button { searchText = ""; searchResults = [] } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PulseTheme.secondaryText)
                    }.buttonStyle(.plain)
                }
                if isSearching {
                    ProgressView().scaleEffect(0.8).tint(PulseTheme.accent)
                }
            }
            .padding(10)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            if searchText.isEmpty {
                // Recent searches
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }
                // Suggested athletes
                if !suggestedProfiles.isEmpty {
                    suggestedSection
                } else if recentSearches.isEmpty {
                    PulseCard {
                        PulseEmptyState(
                            title: "social_find_friends",
                            message: "social_find_friends_message",
                            systemImage: "magnifyingglass"
                        )
                        .padding(.vertical, 8)
                    }
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
                            Button {
                                saveRecentSearch(profile.username)
                            } label: {
                                searchResultRow(profile)
                            }
                            .buttonStyle(.plain)
                            if idx < searchResults.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Searches

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localizedString("social_recent_searches"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                Button(localizedString("social_clear_searches")) {
                    recentSearches = []
                    UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.accent)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            PulseCard {
                VStack(spacing: 0) {
                    ForEach(Array(recentSearches.enumerated()), id: \.element) { idx, q in
                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(width: 18)
                            Button {
                                searchText = q
                                scheduleSearch()
                            } label: {
                                Text("@\(q)")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Button {
                                recentSearches.removeAll { $0 == q }
                                UserDefaults.standard.set(recentSearches, forKey: Self.recentSearchesKey)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PulseTheme.secondaryText.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        if idx < recentSearches.count - 1 { Divider().padding(.leading, 42) }
                    }
                }
            }
        }
    }

    // MARK: - Suggested Athletes

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("social_suggested"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            PulseCard {
                VStack(spacing: 0) {
                    ForEach(Array(suggestedProfiles.enumerated()), id: \.element.id) { idx, profile in
                        searchResultRow(profile)
                        if idx < suggestedProfiles.count - 1 { Divider() }
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
                Text(localizedFormat("player_level_abbr_title_format", "\(profile.level)", profile.levelTitle))
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
                        .foregroundStyle(PulseTheme.accent)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(PulseTheme.accent.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text(localizedString("social_follow"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(PulseTheme.accent)
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
        let xp = store.playerXP
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
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // Column headers
                HStack {
                    Spacer()
                    Text("@\(myName)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
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
                compRow(icon: "chart.bar.fill", color: PulseTheme.accent,
                        title: localizedString("social_level"),
                        myVal: localizedFormat("player_level_abbr_format", "\(lvl.level)"), theirVal: localizedFormat("player_level_abbr_format", "\(friend.level)"),
                        myWins: lvl.level >= friend.level)
                compRow(icon: "dumbbell.fill", color: PulseTheme.ringStand,
                        title: localizedString("social_sessions"),
                        myVal: "\(store.workoutSessions.count)", theirVal: "\(friend.totalSessions)",
                        myWins: store.workoutSessions.count >= friend.totalSessions)
                compRow(icon: "scalemass.fill", color: PulseTheme.accent,
                        title: localizedString("volume"),
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
                .foregroundStyle(myWins ? PulseTheme.accent : .primary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(theirVal)
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(!myWins ? PulseTheme.accent : PulseTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 3)
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

    private func loadSuggested() async {
        isLoadingSuggested = true
        do {
            let profiles = try await SocialService.shared.fetchSuggested(
                myUsername: store.userProfile.socialUsername ?? "",
                followingUsernames: store.userProfile.socialFollowingUsernames,
                followingProfiles: following
            )
            suggestedProfiles = profiles
        } catch {}
        isLoadingSuggested = false
    }

    private func saveRecentSearch(_ username: String) {
        let q = username.lowercased()
        var searches = recentSearches.filter { $0 != q }
        searches.insert(q, at: 0)
        if searches.count > 5 { searches = Array(searches.prefix(5)) }
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: Self.recentSearchesKey)
    }


    private func toggleLike(post: WorkoutPost) {
        let wasLiked = likedPostIDs.contains(post.id)
        likingInProgress.insert(post.id)
        if wasLiked {
            likedPostIDs.remove(post.id)
        } else {
            likedPostIDs.insert(post.id)
        }
        Task {
            do {
                if wasLiked {
                    try await SocialService.shared.unlikePost(post)
                } else {
                    try await SocialService.shared.likePost(post)
                }
            } catch {
                await MainActor.run {
                    // Revert optimistic update on failure
                    if wasLiked { likedPostIDs.insert(post.id) } else { likedPostIDs.remove(post.id) }
                }
            }
            await MainActor.run { _ = likingInProgress.remove(post.id) }
        }
    }

    private func loadFollowing() async {
        isLoadingFollowing = true
        do {
            let usernames = store.userProfile.socialFollowingUsernames
            async let followingTask = SocialService.shared.fetchFollowing(myFollowingUsernames: usernames)
            async let countTask = SocialService.shared.fetchFollowerCount(myUsername: store.userProfile.socialUsername ?? "")
            let (f, count) = try await (followingTask, countTask)
            following = f
            followerCount = count
            Task.detached { [f] in await store.checkLeaderboardChanges(following: f) }
            saveLeaderboardToWidget(following: f)
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingFollowing = false
    }

    private func saveLeaderboardToWidget(following: [SocialProfile]) {
        let myXP = store.playerXP
        let myUsername = store.userProfile.socialUsername ?? ""
        var all: [(String, Int, Bool)] = following.map { ($0.username, $0.totalXP, false) }
        if !myUsername.isEmpty { all.append((myUsername, myXP, true)) }
        let sorted = all.sorted { $0.1 > $1.1 }
        let entries = sorted.enumerated().map { idx, e in
            SharedLeaderboardEntry(rank: idx + 1, username: e.0, xp: e.1, isMe: e.2)
        }
        SharedLeaderboardStore.save(entries)
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
                // Update own SocialProfile.followingUsernames so friend-of-friend works
                if let myUsername = store.userProfile.socialUsername {
                    let newList = store.userProfile.socialFollowingUsernames
                    Task.detached {
                        await SocialService.shared.updateMyFollowingList(myUsername: myUsername, followingUsernames: newList)
                    }
                }
            } catch {
                // Silently fail — UI stays consistent
            }
            await MainActor.run { _ = followingInProgress.remove(profile.id) }
        }
    }
}
