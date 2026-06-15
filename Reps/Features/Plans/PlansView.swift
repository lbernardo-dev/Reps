import SwiftUI

struct PlansView: View {
    @Environment(AppStore.self) private var store
    @State private var showCreatePlan = false
    @State private var showExerciseLibrary = false
    @State private var planToEdit: WorkoutPlan?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            StickyHeaderScaffold(
                title: "plan_3",
                subtitle: "create_and_tune_your_routine",
                accessory: {
                    HeaderAvatarButton(
                        imageData: store.userProfile.avatarImageData,
                        accessibilityLabel: "profile"
                    ) {
                        showProfile = true
                    }
                }
            ) {
                PulseCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("bibliotecas")
                                .font(.headline)
                            Text("find_real_exercises_or_reuse_complete_routines")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)

                            HStack(spacing: 12) {
                                Button {
                                    showExerciseLibrary = true
                                } label: {
                                    LibraryShortcut(
                                        title: "exercises_3",
                                        subtitle: localizedFormat("exercises_available_format", store.exercises.count),
                                        systemImage: "magnifyingglass"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    WorkoutLibraryView()
                                } label: {
                                    LibraryShortcut(
                                        title: "routines_label",
                                        subtitle: localizedFormat("templates_count_format", store.workoutTemplates.count),
                                        systemImage: "list.clipboard"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .stickyHeaderTitle(localizedString("libraries"))

                    PulseCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(localizedString("tools"))
                                .font(.headline)
                            HStack(spacing: 12) {
                                NavigationLink {
                                    OneRepMaxCalculatorView()
                                } label: {
                                    LibraryShortcut(
                                        title: "one_rep_max_calculator",
                                        subtitle: localizedString("estimate_your_max"),
                                        systemImage: "function"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    PlateCalculatorView()
                                } label: {
                                    LibraryShortcut(
                                        title: "weight_plates",
                                        subtitle: localizedString("load_the_bar"),
                                        systemImage: "circle.grid.3x3.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .stickyHeaderTitle(localizedString("tools"))

                    if hasActivePlan {
                        activePlanSection
                            .stickyHeaderTitle(localizedString("active_plan"))
                    } else {
                        emptyPlanSection
                            .stickyHeaderTitle(localizedString("create_plan_2"))
                    }

                    SectionHeader(title: "your_plans_header")
                        .stickyHeaderTitle(localizedString("your_plans"))

                    PulseCard {
                        VStack(spacing: 0) {
                            let inactivePlans = store.plans.filter { $0.id != store.activePlan.id }
                            if inactivePlans.isEmpty {
                                PulseEmptyState(
                                    title: "no_saved_plans",
                                    message: "create_plan_from_templates",
                                    systemImage: "square.stack.3d.up"
                                )
                            }
                            ForEach(inactivePlans) { plan in
                                HStack(spacing: 0) {
                                    Button {
                                        HapticService.selection()
                                        store.activatePlan(plan)
                                    } label: {
                                        PlanRow(plan: plan)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Menu {
                                        Button("activar") {
                                            HapticService.selection()
                                            store.activatePlan(plan)
                                        }
                                        Button("edit_plan") {
                                            planToEdit = plan
                                        }
                                        Button("delete", role: .destructive) {
                                            store.deletePlan(plan)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .contextMenu {
                                    Button("activar") {
                                        HapticService.selection()
                                        store.activatePlan(plan)
                                    }
                                    Button("edit_plan") {
                                        planToEdit = plan
                                    }
                                    Button("delete", role: .destructive) {
                                        store.deletePlan(plan)
                                    }
                                }

                                if plan.id != inactivePlans.last?.id {
                                    Divider().padding(.leading, 72)
                                }
                            }
                        }
                    }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(item: $planToEdit) { plan in
                EditPlanView(plan: plan)
            }
            .navigationDestination(isPresented: $showExerciseLibrary) {
                ExerciseLibraryView()
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func locationTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }

    private var hasActivePlan: Bool {
        !store.activePlan.days.isEmpty
    }

    @ViewBuilder
    private var activePlanSection: some View {
        SectionHeader(title: "active_plan_header")

        PulseCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PulseChip(title: "in_progress_label", isSelected: true)
                    Spacer()
                    Menu {
                        Button("edit_plan") {
                            planToEdit = store.activePlan
                        }
                        Button("deactivate_plan") {
                            store.deactivatePlan(store.activePlan)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("plan_actions")
                }

                Text(store.activePlan.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                HStack(spacing: 16) {
                    Label(locationTitle(store.activePlan.location), systemImage: "dumbbell.fill")
                    Divider().frame(height: 18)
                    Label(localizedFormat("days_per_week_short_format", store.activePlan.daysPerWeek), systemImage: "calendar")
                }
                .foregroundStyle(PulseTheme.secondaryText)

                ProgressView(value: store.activePlan.completion)
                    .tint(PulseTheme.accent)

                HStack {
                    Text(localizedFormat("week_of_total_format", store.activePlan.currentWeek, store.activePlan.totalWeeks))
                    Spacer()
                    Text(localizedFormat("percent_completed_format", Int(store.activePlan.completion * 100)))
                }
                .foregroundStyle(PulseTheme.secondaryText)

                if let targetEventName = store.activePlan.targetEventName,
                   let targetEventDate = store.activePlan.targetEventDate {
                    Divider()
                    PlanTargetEventSummary(
                        eventName: targetEventName,
                        eventDate: targetEventDate
                    )
                }
            }
        }

        PlanMusicCard(plan: store.activePlan) {
            planToEdit = store.activePlan
        }

        SectionHeader(title: "training_days_section")

        PulseCard {
            VStack(spacing: 0) {
                ForEach(store.activePlan.days) { day in
                    NavigationLink {
                        WorkoutDetailView(workout: day)
                    } label: {
                        PlanDayRow(day: day)
                    }
                    .buttonStyle(.plain)

                    if day.id != store.activePlan.days.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyPlanSection: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .foregroundStyle(.white)
                        .background(PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("no_active_plan")
                            .font(.headline)
                        Text("create_your_first_routine_use_a_template_or_open_the_library_to_choose_exercises")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showCreatePlan = true
                    } label: {
                        Label("create_plan", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.black)
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WorkoutLibraryView()
                    } label: {
                        Label("ver_rutinas", systemImage: "list.clipboard")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct LibraryShortcut: View {
    let title: LocalizedStringKey
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 38, height: 38)
                .background(PulseTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            Text(localizedKey(title))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(localizedKey(subtitle))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PlanTargetEventSummary: View {
    let eventName: String
    let eventDate: Date

    private var eventState: (days: Int, weeks: Int) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.startOfDay(for: eventDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (days, max(0, days / 7))
    }

    private var statusText: String {
        let state = eventState
        if state.days > 0 {
            return localizedFormat("days_weeks_remaining_format", state.days, state.weeks)
        }
        if state.days == 0 {
            return localizedString("today_2")
        }
        return localizedString("completed_3")
    }

    private var adviceText: String {
        let state = eventState
        if state.days <= 0 {
            return localizedString("event_reached_review_results_and_prepare_next_block")
        }
        if state.weeks < 6 {
            return localizedString("short_deadline_prioritize_consistency_and_controlled_intensity")
        }
        if state.weeks <= 12 {
            return localizedString("optimal_deadline_progressive_block_window")
        }
        return localizedString("long_deadline_strength_hypertrophy_block")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(PulseTheme.primary)
                Text(localizedFormat("goal_value_format", eventName))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(PulseTheme.primaryBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PulseTheme.primaryBright.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(adviceText)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PlanRow: View {
    let plan: WorkoutPlan

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: plan.location == .home ? "house.fill" : "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 52, height: 52)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name).font(.title3.weight(.bold))
                Text(localizedFormat("days_per_week_short_format", plan.daysPerWeek)).foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

private struct PlanDayRow: View {
    let day: WorkoutDay

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "list.clipboard")
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 42, height: 42)
                .background(PulseTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(day.title)
                    .font(.headline)
                Text(localizedFormat("exercises_duration_format", day.exercises.count, day.durationMinutes))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.vertical, 10)
    }
}

private struct PlanMusicCard: View {
    let plan: WorkoutPlan
    let onEdit: () -> Void
    @Environment(\.openURL) private var openURL
    @StateObject private var musicPlayer = WorkoutAppleMusicPlayer.shared

    private var primaryPlaylist: PlanPlaylist? {
        plan.playlists.first
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("plan_music", systemImage: "music.note.list")
                        .font(.headline)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: plan.playlists.isEmpty ? "plus.circle.fill" : "slider.horizontal.3")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                    }
                    .accessibilityLabel(plan.playlists.isEmpty ? localizedString("add_playlist") : localizedString("edit_playlists"))
                }

                if let primaryPlaylist {
                    HStack(spacing: 12) {
                        PlaylistProviderBadge(provider: primaryPlaylist.provider)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(primaryPlaylist.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(statusTitle(for: primaryPlaylist))
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            playPlaylist(primaryPlaylist)
                        } label: {
                            Image(systemName: playButtonIcon(for: primaryPlaylist))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(primaryPlaylist.provider == .appleMusic ? PulseTheme.appleMusic : PulseTheme.accent)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(localizedString(primaryPlaylist.provider == .appleMusic ? "play_in_reps" : "open_playlist"))
                    }

                    if plan.playlists.count > 1 {
                        Text(localizedFormat("alternative_playlists_count_format", plan.playlists.count - 1))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                } else {
                    Text("add_an_apple_music_playlist_to_start_it_from_the_workout")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                    Button(action: onEdit) {
                        Label("conectar_playlist", systemImage: "link.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private func statusTitle(for playlist: PlanPlaylist) -> String {
        playlist.provider == .appleMusic ? musicPlayer.statusText(for: playlist) : providerTitle(playlist.provider)
    }

    private func playButtonIcon(for playlist: PlanPlaylist) -> String {
        playlist.provider == .appleMusic && musicPlayer.isPlaying(playlist) ? "pause.fill" : "play.fill"
    }

    private func playPlaylist(_ playlist: PlanPlaylist) {
        if playlist.provider == .appleMusic {
            Task {
                await musicPlayer.playOrPause(playlist)
            }
            return
        }

        guard let url = URL(string: playlist.urlString) else {
            return
        }
        openURL(url)
    }
}

private struct PlaylistProviderBadge: View {
    let provider: PlanPlaylist.Provider

    var body: some View {
        Image(systemName: "music.note")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(PulseTheme.appleMusic)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PlanPlaylistEditor: View {
    @Binding var playlists: [PlanPlaylist]
    @Binding var showMusicConnector: Bool
    @State private var title = ""
    @State private var urlString = ""
    @State private var notes = ""

    @State private var showManualForm = false

    var body: some View {
        Section("music") {
            if playlists.isEmpty {
                Text("save_apple_music_playlists_to_open_them_during_workouts")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playlists) { playlist in
                    HStack(spacing: 12) {
                        PlaylistProviderBadge(provider: playlist.provider)
                            .frame(width: 38, height: 38)
                        VStack(alignment: .leading) {
                            Text(playlist.title)
                                .font(.headline)
                            Text(providerTitle(playlist.provider))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            playlists.removeAll { $0.id == playlist.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            Button {
                showMusicConnector = true
            } label: {
                Label("connect_from_library", systemImage: "music.note.list")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundStyle(.white)
                    .background(PulseTheme.appleMusic)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            DisclosureGroup(isExpanded: $showManualForm) {
                VStack(spacing: 12) {
                    TextField("playlist_name", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField("https://music.apple.com/...", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("nota_opcional_fuerza_cardio_focus", text: $notes)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        addPlaylist()
                    } label: {
                        Label("add_manual_playlist", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .foregroundStyle(.white)
                            .background(canAdd ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canAdd)
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            } label: {
                Text("add_manually_by_url")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func addPlaylist() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        playlists.append(
            PlanPlaylist(
                provider: .appleMusic,
                title: trimmedTitle,
                urlString: trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        )
        title = ""
        urlString = ""
        notes = ""
    }
}

private func providerTitle(_ provider: PlanPlaylist.Provider) -> String {
    switch provider {
    case .appleMusic: "Apple Music"
    }
}

private struct PlanExerciseBookmarkTarget: Identifiable {
    let dayIndex: Int
    let exerciseIndex: Int
    var id: String { "\(dayIndex)-\(exerciseIndex)" }
}

private struct PlanExerciseBookmarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bookmarks: [ExerciseMediaBookmark]

    @State private var title = ""
    @State private var source: ExerciseMediaBookmark.Source = .youtube
    @State private var urlString = ""
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var durationMinutes = 0
    @State private var durationSeconds = 0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("exercise_markers") {
                    if bookmarks.isEmpty {
                        Text("save_technique_references_with_exact_minutes_for_this_exercise_within_the_plan")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(bookmarks) { bookmark in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(bookmark.title, systemImage: bookmarkIcon(bookmark.source))
                                    .font(.headline)
                                Spacer()
                                Button(role: .destructive) {
                                    bookmarks.removeAll { $0.id == bookmark.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            Text(bookmark.urlString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack(spacing: 12) {
                                if let timestamp = bookmark.timestampSeconds {
                                    Text(localizedFormat("bookmark_time_format", timestamp / 60, timestamp % 60))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.primary)
                                }
                                if let duration = bookmark.playbackDurationSeconds {
                                    Text(localizedFormat("duration_minutes_seconds_format", duration / 60, duration % 60))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                }

                Section("add") {
                    TextField("qualification", text: $title)
                    Picker("fuente", selection: $source) {
                        ForEach(ExerciseMediaBookmark.Source.allCases) { source in
                            Text(bookmarkSourceTitle(source)).tag(source)
                        }
                    }
                    TextField("url", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Text("video_start_point")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper(localizedFormat("min_minutes_format", minutes), value: $minutes, in: 0...240)
                    Stepper(localizedFormat("seg_seconds_format", seconds), value: $seconds, in: 0...59)

                    Text("playback_duration")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper(localizedFormat("min_duration_format", durationMinutes), value: $durationMinutes, in: 0...60)
                    Stepper(localizedFormat("seg_duration_format", durationSeconds), value: $durationSeconds, in: 0...59)
                    
                    TextField("nota", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        add()
                    } label: {
                        Label("add_bookmark", systemImage: "bookmark.fill")
                    }
                    .disabled(!canAdd)
                }
            }
            .navigationTitle("marcadores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("listo_2") { dismiss() }
                }
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func add() {
        let totalDuration = durationMinutes * 60 + durationSeconds
        bookmarks.append(
            ExerciseMediaBookmark(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
                timestampSeconds: minutes == 0 && seconds == 0 ? nil : minutes * 60 + seconds,
                playbackDurationSeconds: totalDuration > 0 ? totalDuration : nil,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            )
        )
        title = ""
        urlString = ""
        minutes = 0
        seconds = 0
        durationMinutes = 0
        durationSeconds = 0
        note = ""
    }
}

private func bookmarkSourceTitle(_ source: ExerciseMediaBookmark.Source) -> String {
    switch source {
    case .youtube: "YouTube"
    case .youtubeShorts: "YouTube Shorts"
    case .tiktok: "TikTok"
    case .instagram: "Instagram"
    case .other: localizedString("other_label")
    }
}

private func bookmarkIcon(_ source: ExerciseMediaBookmark.Source) -> String {
    switch source {
    case .youtube, .youtubeShorts: "play.rectangle.fill"
    case .tiktok: "music.note.tv"
    case .instagram: "camera.fill"
    case .other: "link"
    }
}

private enum PlanWizardStep: Int, CaseIterable, Identifiable {
    case basics
    case schedule
    case sessions
    case musicReview

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .basics: localizedString("plan_basics")
        case .schedule: localizedString("distribution_schedule")
        case .sessions: localizedString("sessions_setup")
        case .musicReview: localizedString("music_and_review")
        }
    }

    var subtitle: String {
        switch self {
        case .basics: localizedString("plan_basics_description")
        case .schedule: localizedString("plan_schedule_description")
        case .sessions: localizedString("plan_sessions_description")
        case .musicReview: localizedString("plan_music_description")
        }
    }
}

private enum PlanScheduleMode: String, CaseIterable, Identifiable {
    case cycle
    case weekdays

    var id: String { rawValue }
    var title: String { self == .cycle ? localizedString("cycle_plan") : localizedString("weekdays_plan") }
    var description: String {
        self == .cycle
        ? localizedString("cycle_schedule_description")
        : localizedString("fixed_schedule_description")
    }
}

private struct PlanExercisePickerTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var step: PlanWizardStep = .basics
    @State private var planName = ""
    @State private var location: UserProfile.TrainingLocation = .gym
    @State private var daysPerWeek = 4
    @State private var totalWeeks = 8
    @State private var activateImmediately = true
    @State private var scheduleMode: PlanScheduleMode = .cycle
    @State private var selectedWeekdays: Set<Int> = [1, 3, 5, 6]
    @State private var days: [WorkoutDay] = [
        WorkoutDay(title: localizedString("workout_day_a"), subtitle: localizedString("strength"), durationMinutes: 45, exercises: []),
        WorkoutDay(title: localizedString("workout_day_b"), subtitle: localizedString("strength"), durationMinutes: 45, exercises: [])
    ]
    @State private var playlists: [PlanPlaylist] = []
    @State private var pickerTargetDay: Int?
    @State private var showMusicConnector = false
    @State private var hasTargetEvent = false
    @State private var targetEventName = ""
    @State private var targetEventDate = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                wizardHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case .basics:
                            basicsStep
                        case .schedule:
                            scheduleStep
                        case .sessions:
                            sessionsStep
                        case .musicReview:
                            musicReviewStep
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
                .screenBackground()
            }
            .navigationTitle("create_plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button { previousStep() } label: {
                        Label("back_2", systemImage: "chevron.left")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .disabled(step == .basics)
                    .opacity(step == .basics ? 0.45 : 1)

                    Button { nextOrSave() } label: {
                        Label(step == .musicReview ? "Guardar" : "Siguiente", systemImage: step == .musicReview ? "checkmark" : "chevron.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.white)
                            .background(canContinue ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .disabled(!canContinue)
                }
                .padding(20)
                .background(.ultraThinMaterial)
            }
            .sheet(item: pickerBinding) { target in
                PlanExercisePickerSheet(exercises: store.exercises) { exercise in
                    addExercise(exercise, to: target.index)
                    pickerTargetDay = nil
                }
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(PlanWizardStep.allCases) { wizardStep in
                    Capsule()
                        .fill(wizardStep.rawValue <= step.rawValue ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.18))
                        .frame(height: 6)
                }
            }
            Text(step.title).font(.title2.bold())
            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(PulseTheme.background)
    }

    private var basicsStep: some View {
        VStack(spacing: 16) {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("plan_identity").font(.headline)
                    TextField("plan_name", text: $planName)
                        .textFieldStyle(.roundedBorder)
                    Picker("environment_2", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("activate_on_save", isOn: $activateImmediately)
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $hasTargetEvent) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(PulseTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("do_you_have_a_target_event")
                                    .font(.headline)
                                Text("adapt_duration_according_to_deadline")
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }

                    if hasTargetEvent {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("event_name")
                                .font(.caption.bold())
                                .foregroundStyle(PulseTheme.secondaryText)
                            TextField("ex_wedding_vacation_marathon", text: $targetEventName)
                                .textFieldStyle(.roundedBorder)

                            DatePicker(
                                "event_date",
                                selection: $targetEventDate,
                                in: Date.now...,
                                displayedComponents: .date
                            )
                            .font(.subheadline.weight(.semibold))

                            if let advice = targetEventAdvice {
                                Text(advice.text)
                                    .font(.caption)
                                    .foregroundStyle(advice.color)
                                    .padding(10)
                                    .background(advice.color.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .padding(.top, 4)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }

            HStack(spacing: 12) {
                WizardMetricStepper(title: "days_per_week_short", value: $daysPerWeek, range: 1...7)
                WizardMetricStepper(title: "weeks", value: $totalWeeks, range: 1...24)
            }
        }
        .onChange(of: targetEventDate) { _, _ in
            updateWeeksFromEventDate()
        }
        .onChange(of: hasTargetEvent) { _, active in
            if active {
                updateWeeksFromEventDate()
            } else {
                totalWeeks = 8
            }
        }
        .onChange(of: targetEventName) { _, newName in
            if !newName.isEmpty && planName.isEmpty {
                planName = localizedFormat("plan_for_name_format", newName)
            }
        }
    }

    private var scheduleStep: some View {
        VStack(spacing: 16) {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("distribution").font(.headline)
                    Picker("modo", selection: $scheduleMode) {
                        ForEach(PlanScheduleMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(scheduleMode.description)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            if scheduleMode == .weekdays {
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("fixed_days").font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                Button { toggleWeekday(day) } label: {
                                    Text(weekdayTitle(day))
                                        .font(.caption.bold())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .foregroundStyle(selectedWeekdays.contains(day) ? .white : PulseTheme.primary)
                                        .background(selectedWeekdays.contains(day) ? PulseTheme.primary : PulseTheme.primary.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sessionsStep: some View {
        VStack(spacing: 16) {
            ForEach(days.indices, id: \.self) { index in
                SessionBuilderCard(day: $days[index], index: index) {
                    pickerTargetDay = index
                }
            }

            if !sessionsAreReady {
                Label("add_a_title_and_at_least_one_exercise_to_each_session_to_save_a_startable_plan", systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulseTheme.warning)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PulseTheme.warning.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button { addDay() } label: {
                Label("add_session", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(PulseTheme.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                            .stroke(PulseTheme.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
            }
        }
    }

    private var sessionsAreReady: Bool {
        !days.isEmpty
            && days.allSatisfy {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.exercises.isEmpty
            }
    }

    private var musicReviewStep: some View {
        VStack(spacing: 16) {
            PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)
            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("resumen").font(.headline)
                    PlanPreviewDay(title: planName.isEmpty ? localizedString("unnamed_plan") : planName, workout: localizedFormat("sessions_days_format", days.count, daysPerWeek), exercises: days.reduce(0) { $0 + $1.exercises.count })
                    ForEach(days) { day in
                        HStack {
                            Label(day.title, systemImage: sessionTypeIcon(day.sessionType))
                            Spacer()
                            Text(localizedFormat("exercises_count_format", day.exercises.count))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case .basics:
            !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .schedule:
            scheduleMode == .cycle || !selectedWeekdays.isEmpty
        case .sessions:
            sessionsAreReady
        case .musicReview:
            true
        }
    }

    private var pickerBinding: Binding<PlanExercisePickerTarget?> {
        Binding(
            get: { pickerTargetDay.map(PlanExercisePickerTarget.init(index:)) },
            set: { pickerTargetDay = $0?.index }
        )
    }

    private func nextOrSave() {
        if step == .musicReview {
            save()
        } else {
            step = PlanWizardStep(rawValue: step.rawValue + 1) ?? .musicReview
        }
    }

    private func previousStep() {
        step = PlanWizardStep(rawValue: max(step.rawValue - 1, 0)) ?? .basics
    }

    private func addDay() {
        let letter = Character(UnicodeScalar(65 + min(days.count, 25))!)
        days.append(WorkoutDay(title: localizedFormat("day_letter_format", String(letter)), subtitle: localizedString("strength_label"), durationMinutes: 45, exercises: []))
    }

    private func addExercise(_ exercise: Exercise, to dayIndex: Int) {
        guard days.indices.contains(dayIndex) else { return }
        days[dayIndex].exercises.append(
            WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-", restSeconds: 90)
        )
        if days[dayIndex].sessionType == .cardioRun || days[dayIndex].sessionType == .cardioWalk {
            days[dayIndex].sessionType = .mixedRoute
        }
    }

    private func save() {
        let preparedDays = days.enumerated().map { offset, day in
            var copy = day
            if copy.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.title = localizedFormat("session_number_format", offset + 1)
            }
            if copy.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.subtitle = sessionTypeTitle(copy.sessionType)
            }
            return copy
        }
        let plan = WorkoutPlan(
            name: planName.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location,
            daysPerWeek: daysPerWeek,
            currentWeek: 1,
            totalWeeks: totalWeeks,
            completion: 0,
            days: preparedDays,
            playlists: playlists,
            targetEventName: hasTargetEvent ? (targetEventName.isEmpty ? localizedString("event_default") : targetEventName) : nil,
            targetEventDate: hasTargetEvent ? targetEventDate : nil
        )
        store.addPlan(plan, activate: activateImmediately)
        dismiss()
    }

    private func toggleWeekday(_ day: Int) {
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
    }

    private func weekdayTitle(_ day: Int) -> String {
        ["L", "M", "X", "J", "V", "S", "D"][max(0, min(day - 1, 6))]
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }

    private struct EventAdvice {
        let text: String
        let color: Color
        let weeks: Int
    }

    private var targetEventAdvice: EventAdvice? {
        guard hasTargetEvent else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: targetEventDate).day ?? 0
        let weeks = max(1, days / 7)
        
        if weeks < 6 {
            return EventAdvice(
                text: localizedFormat("short_duration_warning_format", weeks, weeks),
                color: PulseTheme.warning,
                weeks: weeks
            )
        } else if weeks <= 12 {
            return EventAdvice(
                text: localizedFormat("optimal_duration_format", weeks, weeks),
                color: PulseTheme.primaryBright,
                weeks: weeks
            )
        } else {
            return EventAdvice(
                text: localizedFormat("long_duration_warning_format", weeks, weeks - 8),
                color: PulseTheme.primary,
                weeks: weeks
            )
        }
    }

    private func updateWeeksFromEventDate() {
        guard hasTargetEvent else { return }
        let days = Calendar.current.dateComponents([.day], from: .now, to: targetEventDate).day ?? 0
        if days > 0 {
            totalWeeks = max(3, min(24, days / 7))
        }
    }
}


struct EditPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let plan: WorkoutPlan

    @State private var name: String
    @State private var location: UserProfile.TrainingLocation
    @State private var daysPerWeek: Int
    @State private var totalWeeks: Int
    @State private var currentWeek: Int
    @State private var days: [WorkoutDay]
    @State private var playlists: [PlanPlaylist]
    @State private var bookmarkTarget: PlanExerciseBookmarkTarget?
    @State private var showMusicConnector = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _name = State(initialValue: plan.name)
        _location = State(initialValue: plan.location)
        _daysPerWeek = State(initialValue: plan.daysPerWeek)
        _totalWeeks = State(initialValue: plan.totalWeeks)
        _currentWeek = State(initialValue: plan.currentWeek)
        _days = State(initialValue: plan.days)
        _playlists = State(initialValue: plan.playlists)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("basic_information") {
                    TextField("plan_name", text: $name)
                    Picker("training_environment", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                }

                Section("calendar_2") {
                    Stepper(value: $daysPerWeek, in: 1...7) {
                        Text(localizedFormat("days_per_week_format", daysPerWeek))
                    }
                    Stepper(localizedFormat("week_n_of_total_format", currentWeek, totalWeeks), value: $currentWeek, in: 1...max(totalWeeks, 1))
                    Stepper(value: $totalWeeks, in: max(currentWeek, 1)...24) {
                        Text(localizedFormat("total_weeks_format", totalWeeks))
                    }
                }

                PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)

                ForEach(days.indices, id: \.self) { dayIndex in
                    Section(localizedFormat("training_day_format", dayIndex + 1)) {
                        TextField("qualification", text: Binding(
                            get: { days[dayIndex].title },
                            set: { days[dayIndex].title = $0 }
                        ))
                        TextField("caption", text: Binding(
                            get: { days[dayIndex].subtitle },
                            set: { days[dayIndex].subtitle = $0 }
                        ))
                        Stepper("\(days[dayIndex].durationMinutes) min", value: Binding(
                            get: { days[dayIndex].durationMinutes },
                            set: { days[dayIndex].durationMinutes = $0 }
                        ), in: 10...180, step: 5)
                        Stepper(localizedFormat("rest_between_exercises_format", days[dayIndex].restBetweenExercisesSeconds), value: Binding(
                            get: { days[dayIndex].restBetweenExercisesSeconds },
                            set: { days[dayIndex].restBetweenExercisesSeconds = $0 }
                        ), in: 0...600, step: 15)

                        ForEach(days[dayIndex].exercises.indices, id: \.self) { exerciseIndex in
                            VStack(alignment: .leading, spacing: 12) {
                                // Row 1 — Name & Trash Button
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(days[dayIndex].exercises[exerciseIndex].exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Text("\(days[dayIndex].exercises[exerciseIndex].exercise.muscleGroup) · \(days[dayIndex].exercises[exerciseIndex].exercise.equipment)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        days[dayIndex].exercises.remove(at: exerciseIndex)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.red.opacity(0.8))
                                            .frame(width: 32, height: 32)
                                            .background(Color.red.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 8) {
                                    // Bookmarks Badge Button
                                    Button {
                                        bookmarkTarget = PlanExerciseBookmarkTarget(dayIndex: dayIndex, exerciseIndex: exerciseIndex)
                                    } label: {
                                        Label("\(days[dayIndex].exercises[exerciseIndex].mediaBookmarks.count) marcadores", systemImage: "bookmark.fill")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(PulseTheme.primary.opacity(0.12))
                                            .foregroundStyle(PulseTheme.primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }

                                Divider()

                                // Metrics grid
                                HStack(spacing: 8) {
                                    CompactStepper(
                                        title: "sets_label",
                                        value: Binding(
                                            get: { days[dayIndex].exercises[exerciseIndex].targetSets },
                                            set: { days[dayIndex].exercises[exerciseIndex].targetSets = $0 }
                                        ),
                                        range: 1...10,
                                        suffix: "",
                                        step: 1
                                    )

                                    CompactStepper(
                                        title: "rest_label",
                                        value: Binding(
                                            get: { days[dayIndex].exercises[exerciseIndex].restSeconds },
                                            set: { days[dayIndex].exercises[exerciseIndex].restSeconds = $0 }
                                        ),
                                        range: 0...600,
                                        suffix: "s",
                                        step: 15
                                    )

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("reps_4")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                        TextField("8-12", text: Binding(
                                            get: { days[dayIndex].exercises[exerciseIndex].repRange },
                                            set: { days[dayIndex].exercises[exerciseIndex].repRange = $0 }
                                        ))
                                        .font(.headline.weight(.bold).monospacedDigit())
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(PulseTheme.grouped)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                            .padding(14)
                            .background(PulseTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .listRowInsets(EditPlanLayout.cardRowInsets)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        VStack(spacing: 0) {
                            Menu {
                                ForEach(store.exercises) { exercise in
                                    Button(exercise.name) {
                                        days[dayIndex].exercises.append(WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-", restSeconds: 90))
                                    }
                                }
                            } label: {
                                PlanEditorActionRow(title: "add_exercise_action", systemImage: "plus", color: PulseTheme.primary)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, EditPlanLayout.actionDividerLeading)

                            Button(role: .destructive) {
                                days.remove(at: dayIndex)
                            } label: {
                                PlanEditorActionRow(title: "delete_day_action", systemImage: "trash", color: .red)
                            }
                            .buttonStyle(.plain)
                            .disabled(days.count == 1)
                        }
                        .padding(.horizontal, EditPlanLayout.cardPadding)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .listRowInsets(EditPlanLayout.cardRowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                Section {
                    Button {
                        days.append(WorkoutDay(title: localizedFormat("workout_number_format", days.count + 1), subtitle: localizedString("strength"), durationMinutes: 45, exercises: []))
                    } label: {
                        Label("add_day", systemImage: "plus")
                    }

                    Menu {
                        ForEach(store.workoutTemplates) { workout in
                            Button(workout.title) {
                                days.append(workout)
                            }
                        }
                    } label: {
                        Label("add_existing_routine", systemImage: "list.clipboard")
                    }
                }
            }
            .navigationTitle("edit_plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: $bookmarkTarget) { target in
                PlanExerciseBookmarkEditor(bookmarks: Binding(
                    get: {
                        guard days.indices.contains(target.dayIndex),
                              days[target.dayIndex].exercises.indices.contains(target.exerciseIndex) else {
                            return []
                        }
                        return days[target.dayIndex].exercises[target.exerciseIndex].mediaBookmarks
                    },
                    set: { newValue in
                        guard days.indices.contains(target.dayIndex),
                              days[target.dayIndex].exercises.indices.contains(target.exerciseIndex) else {
                            return
                        }
                        days[target.dayIndex].exercises[target.exerciseIndex].mediaBookmarks = newValue
                    }
                ))
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private func save() {
        var updated = plan
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.location = location
        updated.daysPerWeek = daysPerWeek
        updated.currentWeek = min(currentWeek, totalWeeks)
        updated.totalWeeks = totalWeeks
        updated.days = days.isEmpty ? plan.days : days
        updated.playlists = playlists
        store.updatePlan(updated)
        dismiss()
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }
}

private enum EditPlanLayout {
    static let cardPadding: CGFloat = 14
    static let cardRowInsets = EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
    static let actionDividerLeading: CGFloat = 56
}

private struct PlanEditorActionRow: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.title2.weight(.medium))
                .frame(width: 38, height: 52)

            Text(localizedKey(title))
                .font(.headline.weight(.regular))

            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct LegacyCreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var planName = ""
    @State private var location: UserProfile.TrainingLocation = .gym
    @State private var daysPerWeek = 4
    @State private var totalWeeks = 8
    @State private var activateImmediately = true
    @State private var workoutTitle = "Full body"
    @State private var selectedExerciseIDs = Set<Exercise.ID>()
    @State private var playlists: [PlanPlaylist] = []
    @State private var showMusicConnector = false

    var body: some View {
        NavigationStack {
            Form {
                Section("basic_information") {
                    TextField("plan_name", text: $planName)
                    Picker("training_environment", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                }

                Section("calendar_2") {
                    Stepper(value: $daysPerWeek, in: 1...7) {
                        Text(localizedFormat("days_per_week_format", daysPerWeek))
                    }
                    Stepper(value: $totalWeeks, in: 1...16) {
                        Text(localizedFormat("total_weeks_format", totalWeeks))
                    }
                    Toggle("activate_on_save", isOn: $activateImmediately)
                }

                PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)

                Section("training_2") {
                    TextField("training_title", text: $workoutTitle)
                    ForEach(store.exercises) { exercise in
                        Button {
                            toggle(exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedExerciseIDs.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedExerciseIDs.contains(exercise.id) ? PulseTheme.primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("vista_previa") {
                    PlanPreviewDay(title: localizedString("workout_a_title"), workout: workoutTitle.isEmpty ? localizedString("full_body") : workoutTitle, exercises: selectedExerciseIDs.count)
                    Text(localizedFormat("reps_will_create_editable_days_from_template_format", daysPerWeek))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("create_plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        save()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        if selectedExerciseIDs.contains(exercise.id) {
            selectedExerciseIDs.remove(exercise.id)
        } else {
            selectedExerciseIDs.insert(exercise.id)
        }
    }

    private func save() {
        let trimmedName = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedExercises = store.exercises.filter { selectedExerciseIDs.contains($0.id) }
        let workoutExercises = (selectedExercises.isEmpty ? Array(store.exercises.prefix(4)) : selectedExercises).map {
            WorkoutExercise(exercise: $0, targetSets: 3, repRange: defaultRepRange(for: $0), previous: "-")
        }
        let baseTitle = workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedString("full_body") : workoutTitle
        let days = (1...daysPerWeek).map { index in
            WorkoutDay(
                title: daysPerWeek == 1 ? baseTitle : "\(baseTitle) \(index)",
                subtitle: location == .home ? localizedString("home_training") : localizedString("strength"),
                durationMinutes: max(35, workoutExercises.count * 10),
                exercises: workoutExercises
            )
        }
        let plan = WorkoutPlan(
            name: trimmedName,
            location: location,
            daysPerWeek: daysPerWeek,
            currentWeek: 1,
            totalWeeks: totalWeeks,
            completion: 0,
            days: days,
            playlists: playlists
        )
        store.addPlan(plan, activate: activateImmediately)
        dismiss()
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }
}

private struct WizardMetricStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizedKey(title))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                HStack {
                    Text("\(value)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.primary)
                    Spacer()
                    Stepper(title, value: $value, in: range)
                        .labelsHidden()
                }
            }
        }
    }
}

private struct SessionBuilderCard: View {
    @Binding var day: WorkoutDay
    let index: Int
    let onAddExercise: () -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(localizedFormat("session_number_format", index + 1), systemImage: sessionTypeIcon(day.sessionType))
                        .font(.headline)
                    Spacer()
                    Text(localizedFormat("exercise_count_format", day.exercises.count))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                TextField("qualification", text: $day.title)
                    .textFieldStyle(.roundedBorder)
                TextField("caption", text: $day.subtitle)
                    .textFieldStyle(.roundedBorder)

                Picker("training_type", selection: $day.sessionType) {
                    ForEach(WorkoutDay.SessionType.allCases) { type in
                        Text(sessionTypeTitle(type)).tag(type)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 12) {
                    CompactStepper(title: "duration_label", value: $day.durationMinutes, range: 10...240, suffix: "min", step: 5)
                    CompactStepper(title: "between_exercises", value: $day.restBetweenExercisesSeconds, range: 0...600, suffix: "s", step: 15)
                }

                if day.sessionType == .cardioRun || day.sessionType == .cardioWalk || day.sessionType == .mixedRoute {
                    Label("this_session_will_show_gps_route_and_map_during_training", systemImage: "map.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(day.exercises.indices, id: \.self) { exerciseIndex in
                    EditableWorkoutExerciseRow(item: $day.exercises[exerciseIndex]) {
                        day.exercises.remove(at: exerciseIndex)
                    }
                }

                Button(action: onAddExercise) {
                    Label("add_from_visual_catalog", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }
}

private struct CompactStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            
            HStack(spacing: 2) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 40)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Text("\(value)\(suffix)")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                
                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 40)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct EditableWorkoutExerciseRow: View {
    @Binding var item: WorkoutExercise
    let onDelete: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1 — identity + delete
            HStack(spacing: 12) {
                ExerciseMediaThumbnail(exercise: item.exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.exercise.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(item.exercise.muscleGroup) · \(item.exercise.equipment)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedFormat("delete_exercise_format", item.exercise.name))
            }

            // Row 2 — metric controls (Series | Descanso | Reps)
            HStack(spacing: 8) {
                // Series
                ExerciseMetricTile(
                    label: "Series",
                    value: "\(item.targetSets)",
                    onDecrement: { item.targetSets = max(1, item.targetSets - 1) },
                    onIncrement: { item.targetSets = min(10, item.targetSets + 1) }
                )

                // Descanso
                ExerciseMetricTile(
                    label: "Descanso",
                    value: "\(item.restSeconds)s",
                    onDecrement: { item.restSeconds = max(0, item.restSeconds - 15) },
                    onIncrement: { item.restSeconds = min(600, item.restSeconds + 15) }
                )

                // Rep range (text input tile)
                VStack(spacing: 4) {
                    Text("reps_4")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)

                    TextField("8-12", text: $item.repRange)
                        .font(.headline.weight(.bold).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(PulseTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .keyboardType(.default)
                        .accessibilityLabel("rep_range")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ExerciseMetricTile: View {
    let label: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(localizedKey(label))
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)

            HStack(spacing: 4) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 44)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedFormat("decrease_label", label))

                Text(value)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(PulseTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 44)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedFormat("increase_label", label))
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct PlanExercisePickerSheet: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var searchText = ""
    @State private var selectedMuscle = "Todos"
    @State private var selectedEquipment = "Todos"
    @State private var selectedType: Exercise.ExerciseType?
    @State private var selectedDifficulty: Exercise.Difficulty?
    @State private var selectedEnvironment: Exercise.Environment?
    @State private var onlyAvailableEquipment = false

    private var muscles: [String] {
        ["Todos"] + Array(Set(exercises.map(\.muscleGroup))).sorted()
    }

    private var equipment: [String] {
        ["Todos"] + Array(Set(exercises.map(\.equipment))).sorted()
    }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchableText = [
                exercise.name,
                exercise.aliases.joined(separator: " "),
                exercise.muscleGroup,
                exercise.secondaryMuscles.joined(separator: " "),
                exercise.equipment,
                exercise.requiredEquipment.joined(separator: " "),
                exercise.tags.joined(separator: " "),
                exercise.instructions ?? ""
            ].joined(separator: " ")
            let matchesQuery = query.isEmpty || searchableText.localizedCaseInsensitiveContains(query)
            let matchesMuscle = selectedMuscle == "Todos" || exercise.muscleGroup == selectedMuscle
            let matchesEquipment = selectedEquipment == "Todos" || exercise.equipment == selectedEquipment
            let matchesType = selectedType == nil || exercise.exerciseType == selectedType
            let matchesDifficulty = selectedDifficulty == nil || exercise.difficulty == selectedDifficulty
            let matchesEnvironment = selectedEnvironment == nil || exercise.environment == selectedEnvironment || exercise.environment == .both
            let matchesAvailableEquipment = !onlyAvailableEquipment || availableEquipmentMatches(exercise)
            return matchesQuery && matchesMuscle && matchesEquipment && matchesType && matchesDifficulty && matchesEnvironment && matchesAvailableEquipment
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("search_by_name_muscle_or_team", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("muscle", selection: $selectedMuscle) {
                                ForEach(muscles, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            Picker("equipo", selection: $selectedEquipment) {
                                ForEach(equipment, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 20)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("training_type", selection: $selectedType) {
                                Text("all").tag(Optional<Exercise.ExerciseType>.none)
                                ForEach(Exercise.ExerciseType.allCases) { type in
                                    Text(type.planPickerTitle).tag(Optional(type))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("difficulty_2", selection: $selectedDifficulty) {
                                Text("any").tag(Optional<Exercise.Difficulty>.none)
                                ForEach(Exercise.Difficulty.allCases) { difficulty in
                                    Text(difficulty.planPickerTitle).tag(Optional(difficulty))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("environment_2", selection: $selectedEnvironment) {
                                Text("any").tag(Optional<Exercise.Environment>.none)
                                ForEach(Exercise.Environment.allCases) { environment in
                                    Text(environment.planPickerTitle).tag(Optional(environment))
                                }
                            }
                            .pickerStyle(.menu)

                            Toggle("mi_equipo", isOn: $onlyAvailableEquipment)
                                .toggleStyle(.button)
                        }
                        .padding(.horizontal, 20)
                    }
                    .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filtered) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                                        .frame(height: 118)
                                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                    Text(exercise.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .background(PulseTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .screenBackground()
            .navigationTitle("choose_exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") { dismiss() }
                }
            }
        }
    }

    private func availableEquipmentMatches(_ exercise: Exercise) -> Bool {
        let equipment = Set(store.userProfile.availableEquipment.map(normalized))
        guard !equipment.isEmpty else {
            return true
        }

        let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
        let normalizedRequired = Set(required.map(normalized))
        return normalizedRequired.contains("bodyweight")
            || normalizedRequired.contains("body only")
            || !normalizedRequired.isDisjoint(with: equipment)
            || equipment.contains(normalized(exercise.equipment))
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

private extension Exercise.ExerciseType {
    var planPickerTitle: String {
        switch self {
        case .strength: localizedString("strength")
        case .cardio: localizedString("cardio")
        case .mobility: localizedString("mobility")
        case .stretching: localizedString("stretching")
        case .hiit: "HIIT"
        }
    }
}

private extension Exercise.Difficulty {
    var planPickerTitle: String {
        switch self {
        case .low: localizedString("beginner")
        case .medium: localizedString("intermediate")
        case .high: localizedString("advanced")
        }
    }
}

private extension Exercise.Environment {
    var planPickerTitle: String {
        switch self {
        case .home: localizedString("home")
        case .gym: localizedString("gym")
        case .both: localizedString("home_gym_label")
        }
    }
}

private func sessionTypeTitle(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: localizedString("strength")
    case .cardioRun: localizedString("cardio_run")
    case .cardioWalk: localizedString("cardio_walk")
    case .mixedRoute: localizedString("mixed_route")
    case .mobility: localizedString("mobility")
    case .free: localizedString("free_session")
    }
}

private func sessionTypeIcon(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: "dumbbell.fill"
    case .cardioRun: "figure.run"
    case .cardioWalk: "figure.walk"
    case .mixedRoute: "map.fill"
    case .mobility: "figure.flexibility"
    case .free: "sparkles"
    }
}

private struct PlanPreviewDay: View {
    let title: String
    let workout: String
    let exercises: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(localizedKey(title)).font(.headline)
                Text(workout).foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Text(localizedFormat("exercises_count_format", exercises))
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }
}
