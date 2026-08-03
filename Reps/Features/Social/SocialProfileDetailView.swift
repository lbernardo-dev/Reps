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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let username: String

    @State private var profile: SocialProfile?
    @State private var posts: [WorkoutPost] = []
    @State private var followerCount = 0
    @State private var isLoading = true
    @State private var isFollowActionInProgress = false
    @State private var selectedPost: WorkoutPost?
    @State private var showReportSheet: Bool = false
    @State private var isConnectionAccepted = false

    private var isMe: Bool {
        store.userProfile.socialUsername?.lowercased() == username.lowercased()
    }
    private var hasOutgoingRelationship: Bool {
        store.userProfile.socialFollowingUsernames.contains(username.lowercased())
    }
    private var relationshipButtonKey: String {
        if isConnectionAccepted { return "social_following_button" }
        if hasOutgoingRelationship { return "social_pending" }
        return "social_follow"
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
            .padding(.top, 12)
        }
        .contentMargins(.top, 48, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle(Text(verbatim: "@\(username)"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $selectedPost) { post in
            PostDetailSheet(post: post, onProfileTap: {}, onPostChanged: { changedPost in
                if let changedPost {
                    if let index = posts.firstIndex(where: { $0.id == changedPost.id }) {
                        posts[index] = changedPost
                    }
                    selectedPost = changedPost
                } else {
                    posts.removeAll { $0.id == post.id }
                    selectedPost = nil
                }
            })
            .environment(store)
            .repsSheetPresentation()
        }
        .sheet(isPresented: $showReportSheet) {
            if let p = profile {
                SocialReportSheetView(
                    targetType: "user",
                    targetProfile: p,
                    targetPostID: nil,
                    targetUsername: p.username
                )
            }
        }
        .toolbar {
            if !isMe {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showReportSheet = true
                        } label: {
                            Label(String(localized: "social_report_user_btn"), systemImage: "flag")
                        }
                        Button(role: .destructive) {
                            Task {
                                if await store.blockSocialUser(username) {
                                    profile = nil
                                    posts = []
                                }
                            }
                        } label: {
                            Label(localizedString("social_block_user"), systemImage: "person.crop.circle.badge.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.bold))
                            .foregroundStyle(PulseTheme.accentOnCard)
                    }
                    .accessibilityLabel(Text("more"))
                }
            }
        }
    }

    // MARK: - Header

    private func profileHeaderCard(_ profile: SocialProfile) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    avatarCircle(data: profile.avatarImageData, username: profile.username, size: 72)
                        .overlay(alignment: .bottomTrailing) {
                            if profile.isOnline {
                                Circle()
                                    .fill(PulseTheme.semanticHealth)
                                    .frame(width: 15, height: 15)
                                    .overlay { Circle().stroke(PulseTheme.card, lineWidth: 3) }
                                    .accessibilityHidden(true)
                            }
                        }

                    VStack(alignment: .leading, spacing: 7) {
                        Text(verbatim: "@\(profile.username)")
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                levelBadge(profile)
                                xpLabel(profile.totalXP)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                levelBadge(profile)
                                xpLabel(profile.totalXP)
                            }
                        }

                        if profile.isOnline {
                            Label(localizedString("social_online"), systemImage: "circle.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(PulseTheme.semanticHealth)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)

                if !profile.bio.isEmpty || !profile.location.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if !profile.bio.isEmpty {
                            Text(profile.bio)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !profile.location.isEmpty {
                            Label(profile.location, systemImage: "mappin.and.ellipse")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }

                if !profile.activePlanName.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.accentOnCard)
                            .frame(width: 28, height: 28)
                            .background(PulseTheme.accent.opacity(0.12), in: Circle())
                        Text(profile.activePlanName)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PulseTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .combine)
                }

                Divider()

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        statPill(value: "\(profile.followingUsernames.count)", label: localizedString("social_following"))
                        Divider()
                        statPill(value: "\(followerCount)", label: localizedString("social_followers"))
                        Divider()
                        statPill(value: "\(profile.totalSessions)", label: localizedString("social_workouts"))
                    }
                } else {
                    HStack(spacing: 0) {
                        statPill(value: "\(profile.followingUsernames.count)", label: localizedString("social_following"))
                        Divider().frame(height: 30)
                        statPill(value: "\(followerCount)", label: localizedString("social_followers"))
                        Divider().frame(height: 30)
                        statPill(value: "\(profile.totalSessions)", label: localizedString("social_workouts"))
                    }
                }

                if !isMe {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        HStack(spacing: 8) {
                            if isFollowActionInProgress {
                                ProgressView().tint(hasOutgoingRelationship ? PulseTheme.accentOnCard : .black)
                            } else {
                                Image(systemName: isConnectionAccepted ? "checkmark" : (hasOutgoingRelationship ? "clock" : "person.badge.plus"))
                                    .font(.subheadline.weight(.bold))
                                Text(localizedString(relationshipButtonKey))
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(hasOutgoingRelationship ? PulseTheme.accentOnCard : .black)
                        .background(
                            hasOutgoingRelationship ? PulseTheme.accent.opacity(0.10) : PulseTheme.accent,
                            in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        )
                        .overlay {
                            if hasOutgoingRelationship {
                                RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                    .stroke(PulseTheme.accent.opacity(0.30), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFollowActionInProgress)
                }
            }
        }
    }

    private func levelBadge(_ profile: SocialProfile) -> some View {
        Text(localizedFormat("player_level_abbr_title_format", "\(profile.level)", profile.levelTitle))
            .font(.caption2.weight(.bold))
            .foregroundStyle(PulseTheme.accentOnCard)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(PulseTheme.accent.opacity(0.11), in: Capsule())
            .lineLimit(1)
    }

    private func xpLabel(_ xp: Int) -> some View {
        Text("\(xp) XP")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(1)
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
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: - Comparison ("you vs them")

    private enum ComparisonOutcome {
        case mine
        case theirs
        case tied
    }

    private struct ComparisonMetric: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let title: String
        let myValue: String
        let theirValue: String
        let outcome: ComparisonOutcome
    }

    private func comparisonCard(_ profile: SocialProfile) -> some View {
        let xp = store.playerXP
        let lvl = GamificationEngine.playerLevel(for: xp)
        let myName = store.userProfile.socialUsername ?? localizedString("social_you")
        let myAhead = xp >= profile.totalXP
        let metrics = [
            ComparisonMetric(
                id: "xp",
                icon: "star.fill",
                color: PulseTheme.accentOnCard,
                title: "XP",
                myValue: "\(xp)",
                theirValue: "\(profile.totalXP)",
                outcome: comparisonOutcome(xp, profile.totalXP)
            ),
            ComparisonMetric(
                id: "level",
                icon: "chart.bar.fill",
                color: PulseTheme.accentOnCard,
                title: localizedString("social_level"),
                myValue: localizedFormat("player_level_abbr_format", "\(lvl.level)"),
                theirValue: localizedFormat("player_level_abbr_format", "\(profile.level)"),
                outcome: comparisonOutcome(lvl.level, profile.level)
            ),
            ComparisonMetric(
                id: "sessions",
                icon: "dumbbell.fill",
                color: PulseTheme.ringStand,
                title: localizedString("social_sessions"),
                myValue: "\(store.workoutSessions.count)",
                theirValue: "\(profile.totalSessions)",
                outcome: comparisonOutcome(store.workoutSessions.count, profile.totalSessions)
            ),
            ComparisonMetric(
                id: "volume",
                icon: "scalemass.fill",
                color: PulseTheme.accentOnCard,
                title: localizedString("volume"),
                myValue: volumeLabel(store.totalVolumeKg),
                theirValue: volumeLabel(profile.totalVolumeKg),
                outcome: comparisonOutcome(store.totalVolumeKg, profile.totalVolumeKg)
            ),
            ComparisonMetric(
                id: "streak",
                icon: "flame.fill",
                color: PulseTheme.semanticWarning,
                title: localizedString("social_streak"),
                myValue: "\(store.streakDays)d",
                theirValue: "\(profile.streakDays)d",
                outcome: comparisonOutcome(store.streakDays, profile.streakDays)
            ),
        ]

        return PulseCard(contentPadding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    PulseIconBadge(
                        systemImage: myAhead ? "trophy.fill" : "figure.run",
                        tint: myAhead ? PulseTheme.accentOnCard : PulseTheme.secondaryText,
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString(myAhead ? "social_you_ahead" : "social_they_ahead"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(myAhead ? PulseTheme.accentOnCard : .primary)
                        Text(verbatim: "@\(myName) vs @\(profile.username)")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    ShareLink(item: shareText(me: (name: myName, xp: xp), profile: profile)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(PulseTheme.accentOnCard)
                            .frame(width: 44, height: 44)
                            .background(PulseTheme.grouped.opacity(0.7), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("share"))
                }
                .padding(16)

                Divider()

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        ForEach(metrics) { metric in
                            accessibleComparisonRow(metric, myName: myName, theirName: profile.username)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        comparisonColumnHeader(myName: myName, theirName: profile.username)

                        ForEach(metrics) { metric in
                            comparisonRow(metric, myName: myName, theirName: profile.username)
                        }
                    }
                }
            }
        }
    }

    private func comparisonColumnHeader(myName: String, theirName: String) -> some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            comparisonParticipantHeader(localizedString("social_you_label"), username: myName, emphasized: true)
            comparisonParticipantHeader("@\(theirName)", username: nil, emphasized: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PulseTheme.grouped.opacity(0.45))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(localizedString("social_you_label")): @\(myName), @\(theirName)")
    }

    private func comparisonParticipantHeader(_ title: String, username: String?, emphasized: Bool) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(emphasized ? PulseTheme.accentOnCard : .primary)
                .lineLimit(1)
            if let username {
                Text(verbatim: "@\(username)")
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(width: 84)
    }

    private func comparisonRow(_ metric: ComparisonMetric, myName: String, theirName: String) -> some View {
        HStack(spacing: 8) {
            Label {
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: metric.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(metric.color)
                    .frame(width: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            comparisonValue(metric.myValue, isWinner: metric.outcome == .mine)
            comparisonValue(metric.theirValue, isWinner: metric.outcome == .theirs)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 44) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(comparisonAccessibilityValue(metric, myName: myName, theirName: theirName))
    }

    private func accessibleComparisonRow(_ metric: ComparisonMetric, myName: String, theirName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(metric.title, systemImage: metric.icon)
                .font(.headline)
                .foregroundStyle(metric.color)

            HStack(spacing: 10) {
                accessibleComparisonValue(
                    participant: localizedString("social_you_label"),
                    value: metric.myValue,
                    isWinner: metric.outcome == .mine
                )
                accessibleComparisonValue(
                    participant: "@\(theirName)",
                    value: metric.theirValue,
                    isWinner: metric.outcome == .theirs
                )
            }
        }
        .padding(12)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(comparisonAccessibilityValue(metric, myName: myName, theirName: theirName))
    }

    private func comparisonValue(_ value: String, isWinner: Bool) -> some View {
        HStack(spacing: 4) {
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(.subheadline.weight(isWinner ? .bold : .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(isWinner ? PulseTheme.accentOnCard : PulseTheme.secondaryText)
        .frame(width: 84)
        .frame(minHeight: 34)
        .background(
            isWinner ? PulseTheme.accent.opacity(0.11) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func accessibleComparisonValue(participant: String, value: String, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(participant)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            HStack(spacing: 5) {
                if isWinner {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                Text(value)
                    .font(.headline.monospacedDigit())
            }
            .foregroundStyle(isWinner ? PulseTheme.accentOnCard : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            isWinner ? PulseTheme.accent.opacity(0.11) : PulseTheme.grouped.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func comparisonAccessibilityValue(_ metric: ComparisonMetric, myName: String, theirName: String) -> String {
        let leader: String
        switch metric.outcome {
        case .mine:
            leader = localizedString("social_you_ahead")
        case .theirs:
            leader = localizedString("social_they_ahead")
        case .tied:
            leader = ""
        }
        return "@\(myName): \(metric.myValue). @\(theirName): \(metric.theirValue). \(leader)"
    }

    private func comparisonOutcome<T: Comparable>(_ mine: T, _ theirs: T) -> ComparisonOutcome {
        if mine > theirs { return .mine }
        if mine < theirs { return .theirs }
        return .tied
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(localizedString("social_workouts"))
                        .font(.headline)
                    Spacer()
                    Text("\(posts.count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PulseTheme.grouped, in: Capsule())
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2),
                    ],
                    spacing: 2
                ) {
                    ForEach(posts) { post in
                        Button {
                            HapticService.selection()
                            selectedPost = post
                        } label: {
                            postTile(post)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(post.workoutTitle)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            }
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
        let normalized = username.lowercased()
        let blocked = Set(store.userProfile.socialBlockedUsernames.map { $0.lowercased() })
        guard !blocked.contains(normalized), !store.bannedUsernames.contains(normalized) else {
            profile = nil
            posts = []
            followerCount = 0
            isLoading = false
            return
        }
        isLoading = true
        let myUsername = store.userProfile.socialUsername ?? ""
        async let profileTask = SocialService.shared.fetchMyProfile(username: username)
        async let countTask = SocialService.shared.fetchFollowerCount(myUsername: username)
        async let incomingTask: [SocialProfile] = (try? await SocialService.shared.fetchFollowerProfiles(myUsername: myUsername)) ?? []
        profile = try? await profileTask
        let incoming = await incomingTask
        isConnectionAccepted = hasOutgoingRelationship && incoming.contains {
            $0.username.caseInsensitiveCompare(username) == .orderedSame
        }
        posts = (isMe || isConnectionAccepted) ? await SocialService.shared.fetchPosts(username: username) : []
        followerCount = await countTask
        isLoading = false
    }

    private func toggleFollow() async {
        guard store.userProfile.socialCapabilitiesAllowed else { return }
        guard let profile else { return }
        guard let myUsername = store.userProfile.socialUsername, !myUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isFollowActionInProgress = true
        let hadOutgoingRelationship = hasOutgoingRelationship
        do {
            if hadOutgoingRelationship {
                try await SocialService.shared.unfollow(profile)
                store.userProfile.socialFollowingUsernames.removeAll { $0 == username.lowercased() }
                isConnectionAccepted = false
                posts = []
                HapticService.notification(.success)
            } else {
                try await SocialService.shared.follow(profile)
                if !store.userProfile.socialFollowingUsernames.contains(username.lowercased()) {
                    store.userProfile.socialFollowingUsernames.append(username.lowercased())
                }
                let incoming = (try? await SocialService.shared.fetchFollowerProfiles(myUsername: myUsername)) ?? []
                isConnectionAccepted = incoming.contains {
                    $0.username.caseInsensitiveCompare(username) == .orderedSame
                }
                posts = isConnectionAccepted ? await SocialService.shared.fetchPosts(username: username) : []
                HapticService.notification(.success)
            }
            let newList = store.userProfile.socialFollowingUsernames
            Task.detached { await SocialService.shared.updateMyFollowingList(myUsername: myUsername, followingUsernames: newList) }
            followerCount = await SocialService.shared.fetchFollowerCount(myUsername: username)
        } catch {
            HapticService.notification(.error)
        }
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
    var onPostChanged: ((WorkoutPost?) -> Void)? = nil

    @State private var isLiked = false
    @State private var isLiking = false
    @State private var likeCount: Int
    @State private var commentSummary: CommentSummary?
    @State private var showComments = false

    init(post: WorkoutPost, onProfileTap: @escaping () -> Void, onPostChanged: ((WorkoutPost?) -> Void)? = nil) {
        self.post = post
        self.onProfileTap = onProfileTap
        self.onPostChanged = onPostChanged
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
                    onPostChanged: { changedPost in
                        onPostChanged?(changedPost)
                        if changedPost == nil {
                            dismiss()
                        }
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
                .repsSheetPresentation()
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
