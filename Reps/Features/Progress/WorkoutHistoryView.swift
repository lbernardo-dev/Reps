import SwiftUI

struct WorkoutHistoryView: View {
    let sessions: [WorkoutSession]
    
    @State private var searchText = ""
    @State private var selectedLocationFilter: LocationFilter = .all
    @State private var selectedOriginFilter: OriginFilter = .all
    @State private var selectedTypeFilter: TypeFilter = .all

    enum LocationFilter: String, CaseIterable, Identifiable {
        case all = "Todos"
        case gym = "Gym"
        case home = "Casa"

        var id: String { rawValue }
    }

    enum OriginFilter: String, CaseIterable, Identifiable {
        case all = "Todos"
        case routine = "Rutina"
        case free = "Libre"

        var id: String { rawValue }
    }

    enum TypeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case strength = "Strength"
        case cardio = "Cardio"

        var id: String { rawValue }

        var localizedLabel: String {
            switch self {
            case .all:      localizedString("all")
            case .strength: localizedString("strength_training")
            case .cardio:   localizedString("cardio")
            }
        }
    }

    // Group and filter workouts
    private var filteredAndGroupedSessions: [(month: String, sessions: [WorkoutSession])] {
        var filtered: [WorkoutSession] = []
        for session in self.sessions {
            // Search text filter
            let matchesSearch = searchText.isEmpty ||
                session.workoutTitle.localizedCaseInsensitiveContains(searchText) ||
                (session.notes ?? "").localizedCaseInsensitiveContains(searchText)

            // Location filter
            let matchesLocation: Bool
            switch selectedLocationFilter {
            case .all: matchesLocation = true
            case .gym: matchesLocation = session.location == .gym
            case .home: matchesLocation = session.location == .home
            }

            // Origin filter
            let matchesOrigin: Bool
            switch selectedOriginFilter {
            case .all: matchesOrigin = true
            case .routine: matchesOrigin = session.origin == .routine
            case .free: matchesOrigin = session.origin == .free
            }

            // Type filter
            let matchesType: Bool
            switch selectedTypeFilter {
            case .all:
                matchesType = true
            case .strength:
                matchesType = !session.isRouteSession
            case .cardio:
                matchesType = session.isRouteSession
            }

            if matchesSearch && matchesLocation && matchesOrigin && matchesType {
                filtered.append(session)
            }
        }
        
        // Group by month
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "LLLL yyyy"
        dateFormatter.locale = Locale(identifier: "es")
        
        let grouped = Dictionary(grouping: filtered) { session -> String in
            dateFormatter.string(from: session.date).capitalized
        }
        
        // Sort groups by date
        return grouped.map { key, value in
            (month: key, sessions: value.sorted { $0.date > $1.date })
        }
        .sorted { group1, group2 in
            guard let date1 = dateFormatter.date(from: group1.month.lowercased()),
                  let date2 = dateFormatter.date(from: group2.month.lowercased()) else {
                return false
            }
            return date1 > date2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and Filters Bar
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PulseTheme.secondaryText)
                    TextField("search_by_title_or_notes", text: $searchText)
                        .font(.subheadline)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 10)
                
                // Type filter (activity type)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TypeFilter.allCases) { filter in
                            let isSelected = selectedTypeFilter == filter
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedTypeFilter = filter
                                }
                            } label: {
                                Text(filter.localizedLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isSelected ? .black : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? PulseTheme.accent : PulseTheme.card)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                }

                // Segmented Filters
                HStack(spacing: 10) {
                    // Location filter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("lugar")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                        Picker("lugar", selection: $selectedLocationFilter) {
                            ForEach(LocationFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Origin filter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("training_type")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                        Picker("origen", selection: $selectedOriginFilter) {
                            ForEach(OriginFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.bottom, 12)
            }
            .background(PulseTheme.background)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if filteredAndGroupedSessions.isEmpty {
                        PulseCard {
                            PulseEmptyState(
                                title: searchText.isEmpty && selectedLocationFilter == .all && selectedOriginFilter == .all ? "no_workouts_logged" : "no_results",
                                message: "completed_sessions_match_message",
                                systemImage: "list.clipboard"
                            )
                        }
                        .padding(.top, 20)
                    } else {
                        ForEach(filteredAndGroupedSessions, id: \.month) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.month)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.leading, 6)
                                    .padding(.top, 10)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(group.sessions) { session in
                                        NavigationLink {
                                            WorkoutSessionDetailView(session: session)
                                        } label: {
                                            PulseCard {
                                                WorkoutLogRow(session: session)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.bottom, 116)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .screenBackground()
        .navigationTitle("history")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }
}

struct WorkoutLogRow: View {
    let session: WorkoutSession

    private var exerciseCount: Int {
        FitnessMetrics.completedExerciseLogs(in: session).count
    }

    private var rowIcon: String {
        if session.isRouteSession {
            return session.routeSystemImage
        }
        return session.location == .home ? "house.fill" : "dumbbell.fill"
    }

    private var rowDetailText: String {
        if session.isRouteSession {
            var parts = ["\(session.durationMinutes) min"]
            if let distanceKm = session.distanceKm {
                parts.append(WorkoutHistoryFormat.distanceLowercase(distanceKm))
            }
            if let pace = session.averagePaceSecondsPerKm {
                parts.append(WorkoutHistoryFormat.paceSlashLowercase(pace))
            }
            if let steps = session.steps {
                parts.append("\(Int(steps)) pasos")
            }
            parts.append(session.date.formatted(date: .abbreviated, time: .shortened))
            return parts.joined(separator: " · ")
        }
        return "\(session.durationMinutes) min · \(exerciseCount) ej · \(session.date.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(session.isRouteSession ? PulseTheme.accent.opacity(0.14) : (session.location == .home ? PulseTheme.accent.opacity(0.12) : PulseTheme.accent.opacity(0.12)))
                Image(systemName: rowIcon)
                    .font(.subheadline)
                    .foregroundStyle(session.isRouteSession || session.location == .home ? PulseTheme.accent : PulseTheme.accent)
            }
            .frame(width: 42, height: 42)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(session.isRouteSession ? session.routeKindTitle : session.workoutTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(rowDetailText)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }

}

enum WorkoutHistoryFormat {
    static func distanceLowercase(_ distanceKm: Double) -> String {
        SharedWorkoutSnapshot.routeDistanceText(distanceKm)
    }

    static func distanceUppercase(_ distanceKm: Double, spaced: Bool = false) -> String {
        "\(localizedDecimal(distanceKm, fractionDigits: 2))\(spaced ? " KM" : "KM")"
    }

    static func paceSlashLowercase(_ seconds: Double) -> String {
        SharedWorkoutSnapshot.routePaceText(seconds)
    }

    static func paceAppleStyle(_ seconds: Double, includesUnit: Bool) -> String {
        let value = max(Int(seconds.rounded()), 0)
        let text = "\(value / 60)'\(String(format: "%02d", value % 60))\""
        return includesUnit ? "\(text)/KM" : text
    }

    static func timeText(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded()), 0)
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }

    static func compactNumber(_ value: Double) -> String {
        if value >= 10_000 {
            return "\(localizedDecimal(value / 1_000, fractionDigits: 1))K"
        }
        return "\(Int(value))"
    }

    static func localizedDecimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

struct WorkoutSessionDetailView: View {
    @Environment(AppStore.self) private var store
    let session: WorkoutSession
    @State private var shareItem: ShareImageItem?
    @State private var isSharingToFeed = false
    @State private var feedShared = false

    var body: some View {
        Group {
            if session.isRouteSession {
                RouteWorkoutSummaryView(
                    session: session,
                    shareAction: shareSession,
                    shareToFeedAction: shareToFeed,
                    isSharingToFeed: isSharingToFeed,
                    feedShared: feedShared
                )
            } else {
                StrengthWorkoutSummaryView(
                    session: session,
                    shareAction: shareSession,
                    shareToFeedAction: shareToFeed,
                    isSharingToFeed: isSharingToFeed,
                    feedShared: feedShared
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .sheet(item: $shareItem) { item in
            ActivityViewController(activityItems: [item.image])
        }
    }

    private func shareSession() {
        guard store.requireFeature(.shareCards, source: .shareCards) else { return }
        shareItem = ShareImageItem(image: WorkoutShareImageRenderer.render(session: session))
    }

    private func shareToFeed() {
        guard store.userProfile.socialEnabled,
              let uname = store.userProfile.socialUsername else { return }
        let dname = store.userProfile.displayName ?? uname
        isSharingToFeed = true
        Task {
            let img = await WorkoutShareImageRenderer.renderForFeed(session: session)
            guard let data = img.jpegData(compressionQuality: 0.82) else {
                await MainActor.run { isSharingToFeed = false }
                return
            }
            let post = try? await SocialService.shared.publishCustomPost(
                username: uname, displayName: dname,
                caption: session.workoutTitle, photoDataList: [data]
            )
            await MainActor.run {
                if let post { store.feedPosts.insert(post, at: 0) }
                isSharingToFeed = false
                withAnimation { feedShared = true }
            }
        }
    }
}

struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct RouteWorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let session: WorkoutSession
    let shareAction: () -> Void
    var shareToFeedAction: (() -> Void)? = nil
    var isSharingToFeed: Bool = false
    var feedShared: Bool = false
    @State private var showExpandedMap = false

    private var estimatedMaxHR: Double {
        WorkoutHistoryHealthFormat.estimatedMaxHeartRate(for: store.userProfile)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                RouteWorkoutHero(
                    session: session,
                    backAction: { dismiss() },
                    shareAction: shareAction,
                    mapAction: { showExpandedMap = true }
                )

                VStack(alignment: .leading, spacing: 14) {
                    WorkoutDetailsSectionTitle()

                    RouteWorkoutDetailsCard(session: session)

                    if session.averageHeartRate != nil || !session.hrTimeSeries.isEmpty {
                        WorkoutHeartRateCard(session: session)
                    }

                    if !session.hrTimeSeries.isEmpty {
                        WorkoutHeartRateZonesCard(session: session, maxHR: estimatedMaxHR)
                        WorkoutEnduranceFocusCard(session: session, maxHR: estimatedMaxHR)
                    }

                    if !session.elevationTimeSeries.isEmpty {
                        WorkoutElevationCard(session: session)
                    }

                    if !session.routeSplits.isEmpty {
                        RouteWorkoutSplitsCard(splits: session.routeSplits)
                    }

                    if session.isOutdoorRouteSession {
                        RouteWorkoutMapCard(session: session) {
                            showExpandedMap = true
                        }
                    }

                    if let notes = session.notes, !notes.isEmpty {
                        RouteWorkoutNotesCard(notes: notes)
                    }

                    if store.userProfile.socialEnabled, let action = shareToFeedAction {
                        WorkoutFeedShareButton(
                            isSharing: isSharingToFeed,
                            isShared: feedShared,
                            action: action
                        )
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.bottom, 112)
                .offset(y: -8)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .ignoresSafeArea(edges: .top)
        .background(Color.black)
        .sheet(isPresented: $showExpandedMap) {
            RouteWorkoutExpandedMap(session: session)
        }
    }

}

struct StrengthWorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let session: WorkoutSession
    let shareAction: () -> Void
    var shareToFeedAction: (() -> Void)? = nil
    var isSharingToFeed: Bool = false
    var feedShared: Bool = false

    private var exerciseLogs: [ExerciseLog] {
        FitnessMetrics.completedExerciseLogs(in: session)
    }

    private var resolvedTitle: String {
        RepsText.workoutTitle(session.workoutTitle, language: store.userProfile.preferredLanguage)
    }

    private var estimatedMaxHR: Double {
        WorkoutHistoryHealthFormat.estimatedMaxHeartRate(for: store.userProfile)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                StrengthWorkoutHero(
                    session: session,
                    title: resolvedTitle,
                    exerciseCount: exerciseLogs.count,
                    backAction: { dismiss() },
                    shareAction: shareAction
                )

                VStack(alignment: .leading, spacing: 14) {
                    WorkoutDetailsSectionTitle()

                    StrengthWorkoutDetailsCard(session: session, exerciseCount: exerciseLogs.count)

                    if session.averageHeartRate != nil || !session.hrTimeSeries.isEmpty {
                        WorkoutHeartRateCard(session: session)
                    }

                    if !session.hrTimeSeries.isEmpty {
                        WorkoutHeartRateZonesCard(session: session, maxHR: estimatedMaxHR)
                        WorkoutEnduranceFocusCard(session: session, maxHR: estimatedMaxHR)
                    }

                    if !exerciseLogs.isEmpty {
                        StrengthExerciseBreakdownCard(exerciseLogs: exerciseLogs)
                    }

                    if let notes = session.notes, !notes.isEmpty {
                        RouteWorkoutNotesCard(notes: notes)
                    }

                    if store.userProfile.socialEnabled, let action = shareToFeedAction {
                        WorkoutFeedShareButton(
                            isSharing: isSharingToFeed,
                            isShared: feedShared,
                            action: action
                        )
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.bottom, 112)
                .offset(y: -8)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .ignoresSafeArea(edges: .top)
        .background(Color.black)
    }

}

private struct WorkoutDetailsSectionTitle: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("workout_details")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.top, 4)
    }
}

private enum WorkoutHistoryHealthFormat {
    static func estimatedMaxHeartRate(for profile: UserProfile) -> Double {
        guard let dateOfBirth = profile.dateOfBirth else {
            return 190.0
        }
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? 30
        return max(160.0, 220.0 - Double(age))
    }
}

private struct WorkoutFeedShareButton: View {
    let isSharing: Bool
    let isShared: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSharing {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Image(systemName: isShared ? "checkmark.circle.fill" : "person.2.fill")
                }
                Text(isShared ? localizedString("share_feed_done") : localizedString("share_feed_button"))
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isShared ? Color.green.opacity(0.22) : Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSharing || isShared)
    }
}

struct WorkoutHeroToolbar: View {
    let backAction: () -> Void
    let shareAction: () -> Void
    var mapAction: (() -> Void)?

    var body: some View {
        HStack {
            WorkoutHeroToolbarButton(systemImage: "chevron.left", style: .back, action: backAction)

            Spacer()

            WorkoutHeroToolbarButton(systemImage: "square.and.arrow.up", style: .action, action: shareAction)

            if let mapAction {
                WorkoutHeroToolbarButton(systemImage: "map", style: .action, action: mapAction)
            }
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 54)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct WorkoutHeroToolbarButton: View {
    enum Style {
        case back
        case action
    }

    let systemImage: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: style == .back ? 20 : 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .modifier(WorkoutHeroToolbarButtonBackground(style: style))
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutHeroToolbarButtonBackground: ViewModifier {
    let style: WorkoutHeroToolbarButton.Style

    func body(content: Content) -> some View {
        switch style {
        case .back:
            content.navigationGlassCircle(.secondary)
        case .action:
            content
                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                .navigationGlassCircle(.secondary, tint: .clear)
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

private struct RouteWorkoutHero: View {
    let session: WorkoutSession
    let backAction: () -> Void
    let shareAction: () -> Void
    let mapAction: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RouteWorkoutMapBackdrop(session: session)
                .frame(height: 500)
                .contentShape(Rectangle())
                .allowsHitTesting(session.isOutdoorRouteSession)
                .onTapGesture(perform: mapAction)

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.82),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "location.north.circle")
                        .font(.system(size: 15, weight: .semibold))
                    Text(session.routeLocationText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(.white)

                Text(session.appleFitnessRouteTitle)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(session.distanceKm.map { WorkoutHistoryFormat.distanceUppercase($0) } ?? "--")
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(PulseTheme.ringExercise)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 6) {
                    Text(session.routeDateRangeText)
                    Image(systemName: "applewatch")
                    Text(session.routeSourceText)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.66)

                if session.hasRouteSensorSummary {
                    HStack(spacing: 16) {
                        if let averageHeartRate = session.averageHeartRate {
                            RouteHeroSensor(
                                icon: "heart.fill",
                                iconColor: PulseTheme.ringMove,
                                value: "\(Int(averageHeartRate))",
                                label: "Avg. Heart Rate"
                            )
                        }

                        if let steps = session.steps {
                            RouteHeroSensor(
                                icon: "shoeprints.fill",
                                iconColor: PulseTheme.ringStand,
                                value: WorkoutHistoryFormat.compactNumber(steps),
                                label: "Steps"
                            )
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.bottom, 24)

            WorkoutHeroToolbar(
                backAction: backAction,
                shareAction: shareAction,
                mapAction: session.isOutdoorRouteSession ? mapAction : nil
            )
        }
        .frame(height: 500)
    }

}

struct RouteHeroSensor: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(value)
                    .foregroundStyle(.white)
            }
            .font(.system(size: 20, weight: .semibold, design: .rounded))

            Text(localizedKey(label))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.48))
        }
    }
}
