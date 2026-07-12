import SwiftUI

// MARK: - SocialProfileDetailView
//
// A real, navigable profile screen for any user in the social graph (self,
// a friend, or a search/discover result) — the piece that was previously
// missing: tapping a person only expanded an inline comparison card, there
// was no destination to actually visit. Shows the profile header, a
// following/followers/workouts stat row, a "you vs them" comparison when
// viewing someone else, and a 3-column grid of their posts (Instagram-style).

struct SocialProfileDetailView: View {
    @Environment(AppStore.self) private var store
    let username: String

    @State private var profile: SocialProfile?
    @State private var posts: [WorkoutPost] = []
    @State private var followerCount = 0
    @State private var isLoading = true
    @State private var isFollowActionInProgress = false
    @State private var selectedPost: WorkoutPost?

    private var isMe: Bool {
        store.userProfile.socialUsername?.lowercased() == username.lowercased()
    }
    private var isFollowing: Bool {
        store.userProfile.socialFollowingUsernames.contains(username.lowercased())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                if isLoading {
                    PulseCard { PulseSkeleton(height: 140) }
                } else if let profile {
                    profileHeaderCard(profile)
                    if !isMe {
                        comparisonCard(profile)
                    }
                    postsSection
                } else {
                    PulseCard {
                        PulseEmptyState(
                            title: "social_no_results",
                            message: "social_no_results_message",
                            systemImage: "person.slash"
                        )
                        .padding(.vertical, 8)
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 16)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle(Text(verbatim: "@\(username)"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $selectedPost) { post in
            PostDetailSheet(post: post, onProfileTap: {}, onModeratorDelete: {
                posts.removeAll { $0.id == post.id }
            })
            .environment(store)
        }
    }

    // MARK: - Header

    private func profileHeaderCard(_ profile: SocialProfile) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    avatarCircle(data: profile.avatarImageData, username: profile.username, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "@\(profile.username)")
                            .font(.headline)
                        HStack(spacing: 6) {
                            Text(localizedFormat("player_level_abbr_title_format", "\(profile.level)", profile.levelTitle))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(PulseTheme.accent)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(PulseTheme.accent.opacity(0.10))
                                .clipShape(Capsule())
                            Text("\(profile.totalXP) XP")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    Spacer()

                    if profile.isOnline {
                        Text(localizedString("social_online"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(.green.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if !profile.bio.isEmpty || !profile.location.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if !profile.location.isEmpty {
                            Label(profile.location, systemImage: "mappin")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        if !profile.bio.isEmpty {
                            Text(profile.bio)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                    }
                }

                if !profile.activePlanName.isEmpty {
                    Label(profile.activePlanName, systemImage: "calendar.badge.checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(PulseTheme.accent.opacity(0.08))
                        .clipShape(Capsule())
                }

                Divider()

                HStack {
                    statPill(value: "\(profile.followingUsernames.count)", label: localizedString("social_following"))
                    Divider().frame(height: 24)
                    statPill(value: "\(followerCount)", label: localizedString("social_followers"))
                    Divider().frame(height: 24)
                    statPill(value: "\(profile.totalSessions)", label: localizedString("social_workouts"))
                }

                if !isMe {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        HStack {
                            if isFollowActionInProgress {
                                ProgressView().tint(isFollowing ? PulseTheme.accent : .black)
                            } else {
                                Text(localizedString(isFollowing ? "social_following_button" : "social_follow"))
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(isFollowing ? PulseTheme.accent : .black)
                        .background(
                            isFollowing ? PulseTheme.accent.opacity(0.1) : PulseTheme.accent,
                            in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isFollowActionInProgress)
                }
            }
        }
    }

    private func avatarCircle(data: Data?, username: String, size: CGFloat) -> some View {
        ZStack {
            if let d = data, let img = UIImage(data: d) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: size, height: size)
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
            }
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

    // MARK: - Comparison ("you vs them")

    private func comparisonCard(_ profile: SocialProfile) -> some View {
        let xp = store.playerXP
        let lvl = GamificationEngine.playerLevel(for: xp)
        let myName = store.userProfile.socialUsername ?? localizedString("social_you")
        let myAhead = xp > profile.totalXP

        return PulseCard {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: myAhead ? "trophy.fill" : "figure.run")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(myAhead ? PulseTheme.accent : PulseTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString(myAhead ? "social_you_ahead" : "social_they_ahead"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(myAhead ? PulseTheme.accent : PulseTheme.secondaryText)
                        Text(verbatim: "@\(myName) vs @\(profile.username)")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    ShareLink(item: shareText(me: (name: myName, xp: xp), profile: profile)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                HStack {
                    Spacer()
                    Text(verbatim: "@\(myName)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(verbatim: "@\(profile.username)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                compRow(icon: "star.fill", color: PulseTheme.accent, title: "XP",
                        myVal: "\(xp)", theirVal: "\(profile.totalXP)", myWins: xp >= profile.totalXP)
                compRow(icon: "chart.bar.fill", color: PulseTheme.accent, title: localizedString("social_level"),
                        myVal: localizedFormat("player_level_abbr_format", "\(lvl.level)"),
                        theirVal: localizedFormat("player_level_abbr_format", "\(profile.level)"),
                        myWins: lvl.level >= profile.level)
                compRow(icon: "dumbbell.fill", color: PulseTheme.ringStand, title: localizedString("social_sessions"),
                        myVal: "\(store.workoutSessions.count)", theirVal: "\(profile.totalSessions)",
                        myWins: store.workoutSessions.count >= profile.totalSessions)
                compRow(icon: "scalemass.fill", color: PulseTheme.accent, title: localizedString("volume"),
                        myVal: volumeLabel(store.totalVolumeKg), theirVal: volumeLabel(profile.totalVolumeKg),
                        myWins: store.totalVolumeKg >= profile.totalVolumeKg)
                compRow(icon: "flame.fill", color: .orange, title: localizedString("social_streak"),
                        myVal: "\(store.streakDays)d", theirVal: "\(profile.streakDays)d",
                        myWins: store.streakDays >= profile.streakDays)
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

    private func shareText(me: (name: String, xp: Int), profile: SocialProfile) -> String {
        let ahead = me.xp > profile.totalXP
        let key = ahead ? "social_share_ahead" : "social_share_behind"
        return localizedFormat(key, me.name, profile.username, me.xp, profile.totalXP)
    }

    private func volumeLabel(_ kg: Double) -> String {
        let isImperial = store.userProfile.units == .imperial
        let val = isImperial ? kg * 2.20462 : kg
        let suffix = isImperial ? " lb" : " kg"
        return String(format: "%.0f\(suffix)", val)
    }

    // MARK: - Posts grid

    @ViewBuilder
    private var postsSection: some View {
        if posts.isEmpty {
            PulseCard {
                PulseEmptyState(
                    title: "social_feed_empty_title",
                    message: "social_profile_no_posts_message",
                    systemImage: "square.grid.3x3"
                )
                .padding(.vertical, 8)
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                ForEach(posts) { post in
                    Button {
                        HapticService.selection()
                        selectedPost = post
                    } label: {
                        postTile(post)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
    }

    private func postTile(_ post: WorkoutPost) -> some View {
        GeometryReader { proxy in
            ZStack {
                if let firstPhoto = post.photoDataList.first, let img = UIImage(data: firstPhoto) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(PulseTheme.accent.opacity(0.10))
                    VStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(PulseTheme.accent)
                        Text(post.workoutTitle)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                }
                if post.photoDataList.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Data

    private func load() async {
        guard store.userProfile.socialCapabilitiesAllowed else {
            profile = nil
            posts = []
            followerCount = 0
            isLoading = false
            return
        }
        isLoading = true
        async let profileTask = SocialService.shared.fetchMyProfile(username: username)
        async let postsTask = SocialService.shared.fetchPosts(username: username)
        async let countTask = SocialService.shared.fetchFollowerCount(myUsername: username)
        profile = try? await profileTask
        posts = await postsTask
        followerCount = await countTask
        isLoading = false
    }

    private func toggleFollow() async {
        guard store.userProfile.socialCapabilitiesAllowed else { return }
        guard let profile else { return }
        isFollowActionInProgress = true
        do {
            if isFollowing {
                try await SocialService.shared.unfollow(profile)
                store.userProfile.socialFollowingUsernames.removeAll { $0 == username.lowercased() }
            } else {
                try await SocialService.shared.follow(profile, myUsername: store.userProfile.socialUsername ?? "")
                if !store.userProfile.socialFollowingUsernames.contains(username.lowercased()) {
                    store.userProfile.socialFollowingUsernames.append(username.lowercased())
                }
            }
            if let myUsername = store.userProfile.socialUsername {
                let newList = store.userProfile.socialFollowingUsernames
                Task.detached { await SocialService.shared.updateMyFollowingList(myUsername: myUsername, followingUsernames: newList) }
            }
            followerCount = await SocialService.shared.fetchFollowerCount(myUsername: username)
        } catch { /* UI stays consistent */ }
        isFollowActionInProgress = false
    }
}

// MARK: - PostDetailSheet
//
// Full single-post view used when tapping a tile in the profile grid —
// mirrors the feed card but loads its own like/comment state on demand.

private struct PostDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let post: WorkoutPost
    var onProfileTap: () -> Void
    var onModeratorDelete: (() -> Void)? = nil

    @State private var isLiked = false
    @State private var isLiking = false
    @State private var likeCount: Int
    @State private var commentSummary: CommentSummary?
    @State private var showComments = false

    init(post: WorkoutPost, onProfileTap: @escaping () -> Void, onModeratorDelete: (() -> Void)? = nil) {
        self.post = post
        self.onProfileTap = onProfileTap
        self.onModeratorDelete = onModeratorDelete
        _likeCount = State(initialValue: post.likeCount)
    }

    private var displayPost: WorkoutPost {
        var p = post
        p.likeCount = likeCount
        return p
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                WorkoutPostCard(
                    post: displayPost,
                    isLiked: isLiked,
                    isLiking: isLiking,
                    commentSummary: commentSummary,
                    onProfileTap: onProfileTap,
                    onLike: toggleLike,
                    onComment: { showComments = true },
                    onModeratorAction: {
                        onModeratorDelete?()
                        dismiss()
                    }
                )
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 16)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("close")) { dismiss() }
                }
            }
        }
        .task {
            guard store.userProfile.socialCapabilitiesAllowed else { return }
            isLiked = (try? await SocialService.shared.isLiked(post)) ?? false
            commentSummary = await SocialService.shared.commentSummaries(forPosts: [post.id])[post.id]
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
        }
    }

    private func toggleLike() {
        guard store.userProfile.socialCapabilitiesAllowed else { return }
        let wasLiked = isLiked
        isLiking = true
        isLiked = !wasLiked
        likeCount += wasLiked ? -1 : 1
        Task {
            do {
                if wasLiked {
                    try await SocialService.shared.unlikePost(post)
                } else {
                    try await SocialService.shared.likePost(post, likerUsername: store.userProfile.socialUsername ?? "")
                }
            } catch {
                await MainActor.run {
                    isLiked = wasLiked
                    likeCount += wasLiked ? 1 : -1
                }
            }
            await MainActor.run { isLiking = false }
        }
    }
}
