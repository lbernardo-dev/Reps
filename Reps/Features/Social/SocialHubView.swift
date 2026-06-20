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

    private enum Tab { case friends, discover }
    private var isES: Bool { RepsLocalization.language.hasPrefix("es") }

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
                    Text(isES ? "Perfil" : "Profile").font(.headline)
                }
                .foregroundStyle(PulseTheme.primary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(isES ? "Amigos" : "Friends")
                .font(.system(size: 19, weight: .bold, design: .rounded))
            Spacer()
            Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).opacity(0)
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
        return PulseCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PulseTheme.primary.opacity(0.12))
                        .frame(width: 52, height: 52)
                    if let data = store.userProfile.avatarImageData,
                       let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg)
                            .resizable().scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .bold))
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
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(PulseTheme.primary.opacity(0.10))
                            .clipShape(Capsule())
                        Text("\(xp) XP")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(following.count)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(isES ? "seguidos" : "following")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(width: 54)

                VStack(spacing: 2) {
                    Text("\(followerCount)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(isES ? "seguidores" : "followers")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(width: 60)
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: isES ? "Amigos" : "Friends", value: .friends)
            tabButton(title: isES ? "Descubrir" : "Discover", value: .discover)
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
                    title: isES ? "Sin amigos aún" : "No friends yet",
                    message: isES
                        ? "Busca a tus amigos en la pestaña Descubrir y síguelos para comparar progreso."
                        : "Search for your friends in Discover and follow them to compare progress.",
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
                    .frame(width: 40, height: 40)
                Text(String(friend.username.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(friend.username)")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text("Lv.\(friend.level)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.primary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(PulseTheme.primary.opacity(0.1))
                        .clipShape(Capsule())
                    Text(friend.levelTitle)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(friend.totalXP) XP")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                Text("\(friend.totalSessions) \(isES ? "ses" : "sessions")")
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
                TextField(isES ? "Buscar por @usuario" : "Search by @username",
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
                        title: isES ? "Busca amigos" : "Find friends",
                        message: isES
                            ? "Escribe un username para encontrar a tu amigo en la comunidad Reps."
                            : "Type a username to find your friend in the Reps community.",
                        systemImage: "magnifyingglass"
                    )
                    .padding(.vertical, 8)
                }
            } else if searchResults.isEmpty && !isSearching {
                PulseCard {
                    PulseEmptyState(
                        title: isES ? "Sin resultados" : "No results",
                        message: isES
                            ? "No se encontró ningún usuario con ese nombre."
                            : "No user found with that username.",
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
                    Text(isES ? "Siguiendo" : "Following")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.primary)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(PulseTheme.primary.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text(isES ? "Seguir" : "Follow")
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
        let myName = store.userProfile.socialUsername ?? (isES ? "Tú" : "You")
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
                             ? (isES ? "VAS GANANDO 🏆" : "YOU'RE AHEAD 🏆")
                             : (isES ? "ELLOS VAN ADELANTE" : "THEY'RE AHEAD"))
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
                        title: isES ? "Nivel" : "Level",
                        myVal: "Lv.\(lvl.level)", theirVal: "Lv.\(friend.level)",
                        myWins: lvl.level >= friend.level)
                compRow(icon: "dumbbell.fill", color: PulseTheme.primaryBright,
                        title: isES ? "Sesiones" : "Sessions",
                        myVal: "\(store.workoutSessions.count)", theirVal: "\(friend.totalSessions)",
                        myWins: store.workoutSessions.count >= friend.totalSessions)
                compRow(icon: "scalemass.fill", color: PulseTheme.accent,
                        title: "Volumen",
                        myVal: volumeLabel(store.totalVolumeKg), theirVal: volumeLabel(friend.totalVolumeKg),
                        myWins: store.totalVolumeKg >= friend.totalVolumeKg)
                compRow(icon: "flame.fill", color: .orange,
                        title: isES ? "Racha" : "Streak",
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
        if isES {
            return ahead
                ? "🏆 @\(me.name) vs @\(friend.username) en Reps — ¡Voy ganando! (\(me.xp) XP vs \(friend.totalXP) XP). #RepsFitness"
                : "⚡ @\(me.name) vs @\(friend.username) en Reps — ¡Voy a alcanzarte! (\(me.xp) XP vs \(friend.totalXP) XP). #RepsFitness"
        } else {
            return ahead
                ? "🏆 @\(me.name) vs @\(friend.username) on Reps — I'm ahead! (\(me.xp) XP vs \(friend.totalXP) XP). #RepsFitness"
                : "⚡ @\(me.name) vs @\(friend.username) on Reps — Coming for you! (\(me.xp) XP vs \(friend.totalXP) XP). #RepsFitness"
        }
    }

    // MARK: - Data loading

    private func loadFollowing() async {
        isLoadingFollowing = true
        do {
            async let followingTask = SocialService.shared.fetchFollowing()
            async let countTask = SocialService.shared.fetchFollowerCount()
            let (f, c) = try await (followingTask, countTask)
            following = f
            followerCount = c
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
                    }
                } else {
                    try await SocialService.shared.follow(profile)
                    await MainActor.run { following.append(profile) }
                }
            } catch {
                // Silently fail — UI stays consistent
            }
            await MainActor.run { followingInProgress.remove(profile.id) }
        }
    }
}
