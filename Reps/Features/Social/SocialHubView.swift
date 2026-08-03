import SwiftUI

// MARK: - SocialHubView

struct SocialHubView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .feed
    @State private var following: [SocialProfile] = []
    @State private var searchText = ""
    @State private var searchResults: [SocialProfile] = []
    @State private var selectedProfileUsername: String?
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
    @State private var didLoadInitialData = false
    @State private var searchTask: Task<Void, Never>?
    @State private var pendingInvites: [PendingInvite] = []
    @State private var incomingInvites: [SocialProfile] = []
    @State private var toastMessage: String? = nil
    @State private var toastIsError: Bool = false
    @State private var profileToReport: SocialProfile? = nil
    @State private var showReportSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showAdminFullScreen: Bool = false

    private enum Tab { case feed, friends, challenges, discover }

    private static let recentSearchesKey = "social_recent_searches"

    // MARK: - Body

    var body: some View {
        Group {
            if store.userProfile.socialCapabilitiesAllowed {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        myProfileCard

                        if !store.hasProAccess {
                            SocialLimitsPanel(
                                activeChallengesCount: store.activeChallenges.count,
                                onUnlockPro: { showPaywall = true }
                            )
                        }

                        tabPicker

                        switch tab {
                        case .feed: feedSection
                        case .friends: friendsSection
                        case .challenges: challengesSection
                        case .discover: discoverSection
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                    .padding(.bottom, 124)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .sheet(isPresented: $showReportSheet) {
                    if let p = profileToReport {
                        SocialReportSheetView(
                            targetType: "user",
                            targetProfile: p,
                            targetPostID: nil,
                            targetUsername: p.username
                        )
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(presentation: .init(source: .socialLimits))
                        .environment(store)
                }
                .fullScreenCover(isPresented: $showAdminFullScreen) {
                    NavigationStack {
                        SocialModerationAdminView()
                    }
                    .environment(store)
                }
            } else {
                socialAgeBlockedView
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            PulseHeaderBar(
                title: localizedString("social_hub"),
                subtitleKey: "friends_2",
                backAction: { dismiss() },
                hideSocialLink: true
            ) {
                socialHeaderActions
            }
        }
        .task { await loadInitialDataIfNeeded() }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView()
                .repsSheetPresentation()
        }
        .navigationDestination(item: $selectedChallenge) { ch in
            ChallengeDetailView(challenge: ch)
        }
        .navigationDestination(item: $selectedProfileUsername) { username in
            SocialProfileDetailView(username: username)
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
                .repsSheetPresentation()
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
                .environment(store)
                .repsSheetPresentation()
        }
        .sheet(isPresented: $showSocialOnboarding) {
            SocialOnboardingView()
                .environment(store)
                .repsSheetPresentation()
        }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(toastIsError ? .red : PulseTheme.accent)
                    Text(msg)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PulseTheme.card)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var socialAgeBlockedView: some View {
        VStack(spacing: 16) {
            Spacer()
            PulseEmptyState(
                title: "social_age_gate_title",
                message: socialAgeGateMessageKey,
                systemImage: "person.badge.shield.checkmark"
            )
            Button {
                Task {
                    if await store.ensureSocialAgeEligibility() {
                        await loadInitialDataIfNeeded()
                    }
                }
            } label: {
                Label(localizedString("social_age_gate_verify"), systemImage: "checkmark.shield")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PulseTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
    }

    private var socialAgeGateMessageKey: String {
        switch store.userProfile.socialAgeGateStatus {
        case .blockedUnder13:
            "social_age_gate_under_13_message"
        case .sharingDeclined:
            "social_age_gate_declined_message"
        case .unavailable:
            "social_age_gate_unavailable_message"
        case .unknown, .allowed13Plus:
            "social_age_gate_message"
        }
    }

    // MARK: - Header

    private var socialHeaderActions: some View {
        HStack(spacing: 6) {
            Button {
                HapticService.selection()
                Task {
                    guard await store.ensureSocialAgeEligibility() else { return }
                    if store.userProfile.socialUsername == nil {
                        showSocialOnboarding = true
                    } else {
                        showCreatePost = true
                    }
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
                    Task {
                        if await store.ensureSocialAgeEligibility() {
                            showSocialOnboarding = true
                        }
                    }
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

            if store.isCurrentUserManagerOrAdmin {
                Button {
                    HapticService.selection()
                    showAdminFullScreen = true
                } label: {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                        .navigationGlassCircle(.secondary, tint: .red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "social_admin_panel_title"))
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
            VStack(alignment: .leading, spacing: 14) {
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

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: uname.map { "@\($0)" } ?? localizedString("social_username_label"))
                            .font(.headline)
                        Text(localizedFormat("player_level_abbr_title_format", "\(lvl.level)", lvl.title))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(1)
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

                // Use equally sized information tiles instead of content-sized
                // capsules. A long title or the Pro boost can no longer push
                // the remaining profile information out of alignment.
                HStack(spacing: 8) {
                    profileOverviewMetric(
                        value: "\(lvl.level)",
                        label: lvl.title,
                        systemImage: "trophy.fill",
                        color: PulseTheme.accent
                    )
                    profileOverviewMetric(
                        value: "\(xp)",
                        label: "XP",
                        systemImage: "bolt.fill",
                        color: PulseTheme.secondaryText
                    )
                    if store.hasProAccess {
                        profileOverviewMetric(
                            value: "+10%",
                            label: localizedString("social_xp_boost"),
                            systemImage: "sparkles",
                            color: PulseTheme.ringStand,
                            emphasized: true
                        )
                    }
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
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                            .frame(width: 22)
                        Text(plan)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PulseTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .repsSheetPresentation()
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

    private func profileOverviewMetric(
        value: String,
        label: String,
        systemImage: String,
        color: Color,
        emphasized: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(value)
                    .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(emphasized ? PulseTheme.onColor(color) : color)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(emphasized ? PulseTheme.onColor(color).opacity(0.86) : PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            emphasized ? AnyShapeStyle(LinearGradient(colors: [PulseTheme.accent, PulseTheme.ringStand], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(color.opacity(0.10)),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
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
                            Button {
                                HapticService.selection()
                                selectedProfileUsername = friend.username
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .stroke(
                                                LinearGradient(colors: [PulseTheme.accent, PulseTheme.ringStand, .green],
                                                                startPoint: .topLeading, endPoint: .bottomTrailing),
                                                lineWidth: 2.5
                                            )
                                            .frame(width: 56, height: 56)
                                        avatarCircle(data: friend.avatarImageData, username: friend.username, isMe: false, size: 48)
                                    }
                                    Text("@\(friend.username)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .frame(width: 60)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func workoutFeedCard(_ post: WorkoutPost) -> some View {
        WorkoutPostCard(
            post: post,
            isLiked: likedPostIDs.contains(post.id),
            isLiking: likingInProgress.contains(post.id),
            commentSummary: store.commentSummaries[post.id],
            onProfileTap: {
                HapticService.selection()
                selectedProfileUsername = post.ownerUsername
            },
            onLike: { toggleLike(post: post) },
            onComment: { commentsPost = post }
        )
    }

    private func commentCount(_ post: WorkoutPost) -> Int {
        store.commentSummaries[post.id]?.count ?? 0
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
            ForEach(0..<2, id: \.self) { _ in
                PulseCard { PulseSkeleton(height: 60) }
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
                        Text(localizedString("challenge_metric_ch_metric_rawvalue"))
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
            PulseCard { PulseSkeleton(height: 140) }
            PulseCard { PulseSkeleton(height: 180) }
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
                Button {
                    guard !entry.isMe else { return }
                    HapticService.selection()
                    selectedProfileUsername = entry.username
                } label: {
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
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        Button {
            guard !entry.isMe else { return }
            HapticService.selection()
            selectedProfileUsername = entry.username
        } label: {
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
        .buttonStyle(.plain)
    }

    private var friendListCard: some View {
        PulseCard {
            VStack(spacing: 0) {
                ForEach(Array(following.enumerated()), id: \.element.id) { idx, friend in
                    Button {
                        HapticService.selection()
                        selectedProfileUsername = friend.username
                    } label: {
                        friendRow(friend)
                    }
                    .buttonStyle(.plain)
                    if idx < following.count - 1 { Divider() }
                }
            }
        }
    }

    private func friendRow(_ friend: SocialProfile) -> some View {
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

            Image(systemName: "chevron.right")
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
                if !incomingInvites.isEmpty {
                    incomingInvitationsSection
                }
                // Pending invitations
                if !pendingInvites.isEmpty {
                    pendingInvitationsSection
                }
                // Recent searches
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }
                // Suggested athletes
                if !suggestedProfiles.isEmpty {
                    suggestedSection
                } else if isLoadingSuggested {
                    PulseCard { PulseSkeleton(height: 60) }
                } else if recentSearches.isEmpty && pendingInvites.isEmpty && incomingInvites.isEmpty {
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
                        ForEach(searchResults) { profile in
                            searchResultRow(profile) { saveRecentSearch(profile.username) }
                            if profile.id != searchResults.last?.id { Divider() }
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

    // MARK: - Pending Invitations Section

    private var incomingInvitationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localizedString("social_received_invitations"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                Text("\(incomingInvites.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            PulseCard {
                VStack(spacing: 0) {
                    ForEach(Array(incomingInvites.enumerated()), id: \.element.id) { index, profile in
                        incomingInviteRow(profile)
                        if index < incomingInvites.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func incomingInviteRow(_ profile: SocialProfile) -> some View {
        HStack(spacing: 12) {
            Button {
                HapticService.selection()
                selectedProfileUsername = profile.username
            } label: {
                HStack(spacing: 12) {
                    avatarCircle(data: profile.avatarImageData, username: profile.username, isMe: false, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.displayName.isEmpty ? "@\(profile.username)" : profile.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("@\(profile.username)")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                acceptIncomingInvite(profile)
            } label: {
                if followingInProgress.contains(profile.id) {
                    ProgressView().tint(.black).scaleEffect(0.8)
                        .frame(width: 86, height: 32)
                } else {
                    Text(localizedString("social_accept_invitation"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 86, height: 32)
                        .background(PulseTheme.accent)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(followingInProgress.contains(profile.id))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private var pendingInvitationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localizedString("social_pending_invitations"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                Text("\(pendingInvites.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            PulseCard {
                VStack(spacing: 0) {
                    ForEach(Array(pendingInvites.enumerated()), id: \.element.id) { idx, invite in
                        pendingInviteRow(invite)
                        if idx < pendingInvites.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func pendingInviteRow(_ invite: PendingInvite) -> some View {
        HStack(spacing: 12) {
            Button {
                HapticService.selection()
                selectedProfileUsername = invite.username
            } label: {
                HStack(spacing: 12) {
                    avatarCircle(data: invite.avatarImageData, username: invite.username, isMe: false, size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(invite.displayName.isEmpty ? "@\(invite.username)" : invite.displayName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(localizedString("social_pending"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 6) {
                            if !invite.displayName.isEmpty {
                                Text("@\(invite.username)")
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Text(localizedFormat("player_level_abbr_title_format", "\(invite.level)", invite.levelTitle))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                let inviteText = localizedFormat("social_invite_text", invite.username, invite.username)
                ShareLink(item: inviteText) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(localizedString("social_resend_invite"))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(PulseTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    HapticService.selection()
                    removePendingInvite(username: invite.username)
                    let uname = invite.username.lowercased()
                    following.removeAll { $0.username.lowercased() == uname }
                    store.userProfile.socialFollowingUsernames.removeAll { $0 == uname }
                    if let dummyProfile = searchResults.first(where: { $0.username.lowercased() == uname }) ?? following.first(where: { $0.username.lowercased() == uname }) {
                        Task { try? await SocialService.shared.unfollow(dummyProfile) }
                    }
                    showToast(localizedFormat("social_invite_cancelled_format", invite.username))
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(8)
                        .background(PulseTheme.grouped)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func searchResultRow(_ profile: SocialProfile, onTap: @escaping () -> Void = {}) -> some View {
        let alreadyFollowing = following.contains(where: { $0.id == profile.id })
        let isPending = pendingInvites.contains(where: { $0.id == profile.id })
        let inProgress = followingInProgress.contains(profile.id)

        return HStack(spacing: 12) {
            Button {
                HapticService.selection()
                selectedProfileUsername = profile.username
                onTap()
            } label: {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        avatarCircle(data: profile.avatarImageData, username: profile.username, isMe: false, size: 48)
                        if profile.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(PulseTheme.grouped, lineWidth: 2))
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(profile.displayName.isEmpty ? "@\(profile.username)" : profile.displayName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if profile.totalXP > 0 {
                                Text("\(profile.totalXP) XP")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PulseTheme.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 6) {
                            if !profile.displayName.isEmpty {
                                Text("@\(profile.username)")
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Text(localizedFormat("player_level_abbr_title_format", "\(profile.level)", profile.levelTitle))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }

                        if profile.totalSessions > 0 {
                            Text("\(profile.totalSessions) \(localizedString("social_workouts"))")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.secondaryText.opacity(0.8))
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                toggleFollow(profile: profile)
            } label: {
                if inProgress {
                    ProgressView().tint(alreadyFollowing || isPending ? PulseTheme.accent : .black).scaleEffect(0.8)
                        .frame(width: 84, height: 32)
                } else if alreadyFollowing {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(localizedString("social_following_button"))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: 90, height: 32)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
                } else if isPending {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(localizedString("social_pending"))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                    .frame(width: 90, height: 32)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(localizedString("social_follow"))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .frame(width: 84, height: 32)
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

    // MARK: - Toast & Pending Invites Helpers

    private func showToast(_ message: String, isError: Bool = false) {
        toastMessage = message
        toastIsError = isError
        if isError {
            HapticService.notification(.error)
        } else {
            HapticService.notification(.success)
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toastMessage == message {
                withAnimation(.easeInOut(duration: 0.25)) {
                    toastMessage = nil
                }
            }
        }
    }

    private func loadPendingInvites() {
        if let data = UserDefaults.standard.data(forKey: "social_pending_invites_v1"),
           let invites = try? JSONDecoder().decode([PendingInvite].self, from: data) {
            pendingInvites = invites
        }
    }

    private func savePendingInvites() {
        if let data = try? JSONEncoder().encode(pendingInvites) {
            UserDefaults.standard.set(data, forKey: "social_pending_invites_v1")
        }
    }

    private func addPendingInvite(profile: SocialProfile) {
        let invite = PendingInvite(
            username: profile.username,
            displayName: profile.displayName,
            avatarImageData: profile.avatarImageData,
            level: profile.level,
            levelTitle: profile.levelTitle,
            sentAt: Date()
        )
        if !pendingInvites.contains(where: { $0.id == invite.id }) {
            pendingInvites.append(invite)
            savePendingInvites()
        }
    }

    private func removePendingInvite(username: String) {
        pendingInvites.removeAll { $0.id == username.lowercased() }
        savePendingInvites()
    }

    // MARK: - Data loading

    private func loadInitialDataIfNeeded() async {
        guard store.userProfile.socialCapabilitiesAllowed else { return }
        guard !didLoadInitialData else { return }
        didLoadInitialData = true

        _ = await store.restoreSocialProfileIfNeeded()

        loadPendingInvites()

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadFollowing() }
            group.addTask { await loadSuggested() }
            group.addTask { await store.refreshModerationState() }
            if store.feedPosts.isEmpty {
                group.addTask { await store.loadFeed() }
            }
            if store.activeChallenges.isEmpty {
                group.addTask { await store.loadChallenges() }
        }
    }
}


    private func loadSuggested() async {
        guard store.userProfile.socialCapabilitiesAllowed else { return }
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
        guard store.userProfile.socialCapabilitiesAllowed else { return }
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
                    try await SocialService.shared.likePost(post, likerUsername: store.userProfile.socialUsername ?? "")
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
        guard store.userProfile.socialCapabilitiesAllowed else { return }
        isLoadingFollowing = true
        do {
            let usernames = store.userProfile.socialFollowingUsernames
            async let followingTask = SocialService.shared.fetchFollowing(myFollowingUsernames: usernames)
            async let countTask = SocialService.shared.fetchFollowerCount(myUsername: store.userProfile.socialUsername ?? "")
            async let followersTask: [SocialProfile] = (try? await SocialService.shared.fetchFollowerProfiles(
                myUsername: store.userProfile.socialUsername ?? ""
            )) ?? []
            let (f, count, followerProfiles) = try await (followingTask, countTask, followersTask)
            following = f
            followerCount = count
            let outgoing = Set(usernames.map { $0.lowercased() })
            incomingInvites = followerProfiles.filter { !outgoing.contains($0.username.lowercased()) }

            // A reciprocal follow is the receiver's acceptance. Clear the
            // sender-side pending marker as soon as that relationship appears.
            let mutualUsernames = Set(followerProfiles.map { $0.username.lowercased() })
            if pendingInvites.contains(where: { mutualUsernames.contains($0.username.lowercased()) }) {
                pendingInvites.removeAll { mutualUsernames.contains($0.username.lowercased()) }
                savePendingInvites()
            }
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
        guard store.userProfile.socialCapabilitiesAllowed else {
            searchResults = []
            isSearching = false
            return
        }
        let q = searchText
        searchTask?.cancel()
        guard !q.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            guard searchText == q else { return }
            do {
                let results = try await SocialService.shared.searchUsers(query: q)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    guard searchText == q else { return }
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    showToast(error.localizedDescription, isError: true)
                }
            }
        }
    }

    private func toggleFollow(profile: SocialProfile) {
        guard store.userProfile.socialCapabilitiesAllowed else {
            showToast(localizedString("social_age_gate_verify"), isError: true)
            return
        }
        guard let myUsername = store.userProfile.socialUsername, !myUsername.trimmingCharacters(in: .whitespaces).isEmpty else {
            Task {
                if await store.ensureSocialAgeEligibility() {
                    await MainActor.run {
                        showSocialOnboarding = true
                    }
                }
            }
            return
        }

        let alreadyFollowing = following.contains(where: { $0.id == profile.id })
        let isPending = pendingInvites.contains(where: { $0.id == profile.id })
        followingInProgress.insert(profile.id)

        Task {
            do {
                if alreadyFollowing || isPending {
                    try await SocialService.shared.unfollow(profile)
                    await MainActor.run {
                        following.removeAll { $0.id == profile.id }
                        removePendingInvite(username: profile.username)
                        store.userProfile.socialFollowingUsernames.removeAll { $0 == profile.username.lowercased() }
                        showToast(localizedFormat("social_unfollow_success_format", profile.username))
                    }
                } else {
                    if !store.hasProAccess && !SocialLimitsManager.shared.canSendInviteToday(hasProAccess: false) {
                        await MainActor.run {
                            followingInProgress.remove(profile.id)
                            showToast(String(localized: "social_limit_reached_invite_desc"), isError: true)
                            showPaywall = true
                        }
                        return
                    }

                    try await SocialService.shared.follow(profile)
                    await MainActor.run {
                        SocialLimitsManager.shared.recordInviteSent()
                        following.append(profile)
                        let uname = profile.username.lowercased()
                        if !store.userProfile.socialFollowingUsernames.contains(uname) {
                            store.userProfile.socialFollowingUsernames.append(uname)
                        }
                        addPendingInvite(profile: profile)
                        showToast(localizedFormat("social_invite_sent_format", profile.username))
                    }
                }
                let newList = store.userProfile.socialFollowingUsernames
                Task.detached {
                    await SocialService.shared.updateMyFollowingList(myUsername: myUsername, followingUsernames: newList)
                }
            } catch {
                await MainActor.run {
                    showToast(error.localizedDescription, isError: true)
                }
            }
            await MainActor.run { _ = followingInProgress.remove(profile.id) }
        }
    }

    private func acceptIncomingInvite(_ profile: SocialProfile) {
        guard let myUsername = store.userProfile.socialUsername else { return }
        followingInProgress.insert(profile.id)
        Task {
            do {
                try await SocialService.shared.follow(profile)
                await MainActor.run {
                    if !following.contains(where: { $0.id == profile.id }) {
                        following.append(profile)
                    }
                    let normalized = profile.username.lowercased()
                    if !store.userProfile.socialFollowingUsernames.contains(normalized) {
                        store.userProfile.socialFollowingUsernames.append(normalized)
                    }
                    incomingInvites.removeAll { $0.id == profile.id }
                    showToast(localizedFormat("social_invitation_accepted_format", profile.username))
                }
                let newList = store.userProfile.socialFollowingUsernames
                await SocialService.shared.updateMyFollowingList(
                    myUsername: myUsername,
                    followingUsernames: newList
                )
            } catch {
                await MainActor.run { showToast(error.localizedDescription, isError: true) }
            }
            await MainActor.run { _ = followingInProgress.remove(profile.id) }
        }
    }
}
