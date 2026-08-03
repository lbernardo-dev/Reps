import CryptoKit
import PhotosUI
import MuscleMap
import SwiftUI
import UniformTypeIdentifiers

private struct ExerciseLibrarySearchInput: @unchecked Sendable {
    let exercises: [Exercise]
}

private struct ExerciseLibraryFilterInput: @unchecked Sendable {
    let exercises: [Exercise]
    let state: ExerciseLibraryFilterState
    let searchIndex: ExerciseLibrarySearchIndex
}

private struct ExerciseLibraryFilterOutput: @unchecked Sendable {
    let exercises: [Exercise]
}

private actor ExerciseLibraryWorker {
    static let shared = ExerciseLibraryWorker()

    func makeSearchIndex(_ input: ExerciseLibrarySearchInput) -> ExerciseLibrarySearchIndex {
        ExerciseLibrarySearchIndex(exercises: input.exercises)
    }

    func filter(_ input: ExerciseLibraryFilterInput) -> ExerciseLibraryFilterOutput {
        let state = input.state
        let normalizedQuery = ExerciseLibrarySearchIndex.normalized(state.searchText)
        let availableEquipment = Set(state.availableEquipment.map(Self.normalizedEquipment))

        let filtered = input.exercises.filter { exercise in
            if state.selectedPath == .muscles, !state.selectedMuscleSegments.isEmpty {
                let exerciseSegments = MuscleLoadCalculator.segments(for: exercise)
                if let primarySegment = exerciseSegments.first {
                    guard state.selectedMuscleSegments.contains(primarySegment)
                       || (state.selectedMuscleSegments.count > 1 && !Set(exerciseSegments).isDisjoint(with: state.selectedMuscleSegments))
                    else { return false }
                } else {
                    guard !Set(exerciseSegments).isDisjoint(with: state.selectedMuscleSegments) else { return false }
                }
            } else if state.selectedPath == .filters {
                guard state.selectedMuscle == "All" || exercise.muscleGroup == state.selectedMuscle else {
                    return false
                }
            }

            guard state.selectedEquipment == "All" || exercise.equipment == state.selectedEquipment else {
                return false
            }
            guard state.selectedType == nil || exercise.exerciseType == state.selectedType else { return false }
            guard state.selectedDifficulty == nil || exercise.difficulty == state.selectedDifficulty else { return false }
            guard state.selectedEnvironment == nil
                    || exercise.environment == state.selectedEnvironment
                    || exercise.environment == .both
            else { return false }
            guard state.selectedCategory.matches(exercise) else { return false }
            guard !state.onlyAvailableEquipment
                    || Self.matchesAvailableEquipment(exercise, availableEquipment: availableEquipment)
            else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return input.searchIndex.matches(exercise, query: normalizedQuery)
        }

        var seenIDs = Set<UUID>()
        var seenKeys = Set<String>()
        var deduplicated: [Exercise] = []
        for exercise in filtered {
            guard seenIDs.insert(exercise.id).inserted else { continue }
            let key = "\(exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(exercise.equipment.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
            guard seenKeys.insert(key).inserted else { continue }
            deduplicated.append(exercise)
        }

        return ExerciseLibraryFilterOutput(exercises: deduplicated)
    }

    private static func matchesAvailableEquipment(
        _ exercise: Exercise,
        availableEquipment: Set<String>
    ) -> Bool {
        guard !availableEquipment.isEmpty else { return true }
        let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
        let normalizedRequired = Set(required.map(normalizedEquipment))
        return normalizedRequired.contains("bodyweight")
            || normalizedRequired.contains("body only")
            || !normalizedRequired.isDisjoint(with: availableEquipment)
            || availableEquipment.contains(normalizedEquipment(exercise.equipment))
    }

    private static func normalizedEquipment(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    /// True when this view is the root of the Ejercicios tab (no close
    /// button, tab bar stays visible). False when presented as a sheet/push.
    var isTabRoot: Bool = false

    @State private var searchText = ""
    @State private var selectedMuscle = "All"
    @State private var selectedPath = ExerciseLibraryPath.muscles
    @State private var selectedMuscleSegments: Set<MuscleSegment> = []
    @State private var selectedEquipment = "All"
    @State private var selectedType: Exercise.ExerciseType?
    @State private var selectedDifficulty: Exercise.Difficulty?
    @State private var selectedEnvironment: Exercise.Environment?
    @State private var selectedCategory = ExerciseLibraryCategory.all
    @State private var onlyAvailableEquipment = false
    @State private var showAddCustom = false
    @State private var showNotifications = false
    @State private var showEditLayout = false
    @State private var isBodySelectorExpanded = false
    @State private var searchIndex = ExerciseLibrarySearchIndex.empty
    @State private var preparedFilteredExercises: [Exercise] = []
    @State private var isPreparingExerciseResults = false
    @State private var hasPreparedExerciseResults = false
    @State private var exerciseResultTask: Task<Void, Never>?

    private var muscles: [String] {
        ["All"] + Array(Set(store.exercises.map(\.muscleGroup))).sorted()
    }

    private var equipmentOptions: [String] {
        ["All"] + Array(Set(store.exercises.map(\.equipment))).sorted()
    }

    private var filterState: ExerciseLibraryFilterState {
        ExerciseLibraryFilterState(
            selectedPath: selectedPath,
            searchText: searchText,
            selectedMuscle: selectedMuscle,
            selectedMuscleSegments: selectedMuscleSegments,
            selectedEquipment: selectedEquipment,
            selectedType: selectedType,
            selectedDifficulty: selectedDifficulty,
            selectedEnvironment: selectedEnvironment,
            selectedCategory: selectedCategory,
            onlyAvailableEquipment: onlyAvailableEquipment,
            availableEquipment: store.userProfile.availableEquipment
        )
    }

    private var shouldPrepareFilteredExercises: Bool {
        if selectedCategory != .all { return true }
        switch selectedPath {
        case .muscles:
            return !selectedMuscleSegments.isEmpty || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .filters:
            return hasActiveFeatureFilter
        case .rehab:
            return false
        }
    }

    private var exerciseResultLoadingMessages: [String] {
        if RepsLocalization.language == "es" {
            return [
                "Preparando ejercicios...",
                "Aplicando filtros musculares...",
                "Agrupando resultados..."
            ]
        }

        return [
            "Preparing exercises...",
            "Applying muscle filters...",
            "Grouping results..."
        ]
    }

    @MainActor
    private func refreshPreparedExerciseResults(showLoading: Bool = true) {
        exerciseResultTask?.cancel()

        guard shouldPrepareFilteredExercises else {
            preparedFilteredExercises = []
            isPreparingExerciseResults = false
            hasPreparedExerciseResults = false
            return
        }

        if showLoading {
            isPreparingExerciseResults = true
        }

        let input = ExerciseLibraryFilterInput(
            exercises: store.exercises,
            state: filterState,
            searchIndex: searchIndex
        )

        exerciseResultTask = Task(priority: .userInitiated) { @MainActor in
            guard !Task.isCancelled else { return }
            let output = await ExerciseLibraryWorker.shared.filter(input)
            guard !Task.isCancelled else { return }

            withAnimation(.snappy(duration: 0.15)) {
                preparedFilteredExercises = output.exercises
                isPreparingExerciseResults = false
                hasPreparedExerciseResults = true
            }
        }
    }

    private func groupedExercises(from exercises: [Exercise]) -> [(String, [Exercise])] {
        let interval = PerformanceSignpost.begin(
            "exerciseLibrary.groupedExercises",
            "exercises=\(exercises.count)"
        )
        defer {
            PerformanceSignpost.end("exerciseLibrary.groupedExercises", interval)
        }

        let grouped = Dictionary(grouping: exercises, by: \.muscleGroup)
        return grouped.keys.sorted().map { ($0, grouped[$0, default: []].sorted { $0.name < $1.name }) }
    }

    @ViewBuilder
    private var featureFiltersPanel: some View {
        VStack(spacing: 16) {
            CatalogSectionHeader(
                eyebrow: localizedString("characteristics"),
                title: localizedString("filter_by_goal_place_and_material"),
                subtitle: localizedString("combine_type_muscle_group_equipment_and_difficulty_to_narrow_the_catalog")
            )

            ExerciseSearchField(searchText: $searchText)

            categoryScroller

            Picker(localizedString("training_type_0105f54e"), selection: $selectedType) {
                Text(localizedString("all_6a720856")).tag(Optional<Exercise.ExerciseType>.none)
                ForEach(Exercise.ExerciseType.allCases) { type in
                    Text(localizedKey(type.localizedTitle)).tag(Optional(type))
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 0) {
                FilterMenuRow(title: localizedString("muscle_group"), value: displayName(forMuscle: selectedMuscle)) {
                    ForEach(muscles, id: \.self) { muscle in
                        Button(displayName(forMuscle: muscle)) {
                            selectedMuscle = muscle
                        }
                    }
                }

                filterDivider

                FilterMenuRow(title: localizedString("equipment"), value: displayName(forEquipment: selectedEquipment)) {
                    ForEach(equipmentOptions, id: \.self) { equipment in
                        Button(displayName(forEquipment: equipment)) {
                            selectedEquipment = equipment
                        }
                    }
                }

                filterDivider

                FilterMenuRow(title: localizedString("environment"), value: environmentFilterTitle) {
                    Button(localizedString("any_environment_0db63b25")) {
                        selectedEnvironment = nil
                    }
                    ForEach(Exercise.Environment.allCases) { environment in
                        Button(environment.localizedDisplayName) {
                            selectedEnvironment = environment
                        }
                    }
                }

                filterDivider

                FilterMenuRow(title: localizedString("difficulty"), value: difficultyFilterTitle) {
                    Button(localizedString("any_difficulty_324bac01")) {
                        selectedDifficulty = nil
                    }
                    ForEach(Exercise.Difficulty.allCases) { difficulty in
                        Button(difficulty.localizedDisplayName) {
                            selectedDifficulty = difficulty
                        }
                    }
                }

                filterDivider

                Toggle(localizedString("only_my_equipment"), isOn: $onlyAvailableEquipment)
            }
            .padding(16)
            .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(PulseTheme.cardStroke, lineWidth: 1)
            }
        }
    }

    private var rehabPanel: some View {
        VStack(spacing: 14) {
            CatalogSectionHeader(
                eyebrow: localizedString("rehabilitation"),
                title: localizedString("recover_tendons_joints_and_muscles"),
                subtitle: localizedString("use_a_separate_catalog_with_controlled_protocols_pain_guidance_and_recovery_stages")
            )

            NavigationLink {
                RehabLibraryView()
            } label: {
                RehabHeroCard()
            }
            .buttonStyle(PressableCardStyle())

            HStack(spacing: 10) {
                RehabFocusTile(title: localizedString("tendons"), systemImage: "bolt.horizontal", tint: PulseTheme.warning)
                RehabFocusTile(title: localizedString("joints"), systemImage: "circle.hexagongrid", tint: PulseTheme.ringStand)
                RehabFocusTile(title: localizedString("muscles"), systemImage: "figure.strengthtraining.functional", tint: PulseTheme.accent)
            }
        }
    }

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([ExerciseLibraryCategory.all] + resolvedExerciseCategories.visible) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .foregroundStyle(selectedCategory == category ? PulseTheme.onColor(PulseTheme.accent) : PulseTheme.accent)
                            .background(selectedCategory == category ? PulseTheme.accent : PulseTheme.accent.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func exerciseResults(for exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localizedString("exercises"))
                    .font(.title3.weight(.bold))
                Spacer()
                Text("\(exercises.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PulseTheme.accent.opacity(0.12), in: Capsule())
            }

            if isPreparingExerciseResults {
                exerciseResultsLoadingPanel
            } else if exercises.isEmpty {
                PulseEmptyState(
                    title: "no_exercises_found",
                    message: "try_removing_a_filter_or_searching_by_muscle_equipment_or_exercise_name",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .padding(18)
                .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            } else {
                // LazyVStack PLANO: SwiftUI solo instancia las filas visibles en pantalla.
                // ExerciseGroupCard usaba VStack(ForEach) eager → 50+ BodyView activos → crash Metal.
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(flatExerciseRows(from: exercises), id: \.rowID) { row in
                        switch row {
                        case .header(let title, let count):
                            HStack {
                                Text(title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                        case .exercise(let exercise, let isLast):
                            VStack(spacing: 0) {
                                NavigationLink {
                                    ExerciseDetailView(exercise: exercise)
                                } label: {
                                    ExerciseLibraryRow(
                                        exercise: exercise,
                                        language: store.userProfile.preferredLanguage,
                                        gender: store.userProfile.muscleMapGender,
                                        catalog: store.exercises
                                    )
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)

                                if !isLast {
                                    Divider()
                                        .overlay(PulseTheme.separator)
                                        .padding(.leading, 86)
                                }
                            }
                        }
                    }
                }
                .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                        .stroke(PulseTheme.cardStroke, lineWidth: 1)
                }
                .padding(.horizontal, 0)
            }
        }
    }

    // Tipo de fila plana para el LazyVStack
    private enum ExerciseListRow {
        case header(title: String, count: Int)
        case exercise(Exercise, isLast: Bool)

        var rowID: String {
            switch self {
            case .header(let title, _): return "h-\(title)"
            case .exercise(let e, _):  return "e-\(e.id.uuidString)"
            }
        }
    }

    private func flatExerciseRows(from exercises: [Exercise]) -> [ExerciseListRow] {
        var rows: [ExerciseListRow] = []
        for (group, groupExercises) in groupedExercises(from: exercises) {
            rows.append(.header(title: displayName(forMuscle: group), count: groupExercises.count))
            for (idx, exercise) in groupExercises.enumerated() {
                rows.append(.exercise(exercise, isLast: idx == groupExercises.count - 1))
            }
        }
        return rows
    }

    private var exerciseResultsLoadingPanel: some View {
        RepsLoadingView(
            messages: exerciseResultLoadingMessages,
            progress: nil,
            layout: .panel,
            showsPercentage: false
        )
        .frame(minHeight: 220)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var filterDivider: some View {
        Divider()
            .overlay(PulseTheme.separator)
            .padding(.vertical, 10)
    }

    private var hasActiveFeatureFilter: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedMuscle != "All"
            || selectedEquipment != "All"
            || selectedType != nil
            || selectedDifficulty != nil
            || selectedEnvironment != nil
            || selectedCategory != .all
            || onlyAvailableEquipment
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ExercisePathSwitcher(selection: $selectedPath)

                    switch selectedPath {
                    case .muscles:
                        MuscleCatalogPanel(
                            gender: store.userProfile.muscleMapGender,
                            selectedSegments: $selectedMuscleSegments,
                            isBodySelectorExpanded: $isBodySelectorExpanded,
                            resultCount: preparedFilteredExercises.count,
                            isLoadingResults: isPreparingExerciseResults && shouldPrepareFilteredExercises
                        )

                        if selectedMuscleSegments.isEmpty {
                            MuscleShortcutGrid(
                                segments: resolvedMuscleShortcuts.visible,
                                selectedSegments: $selectedMuscleSegments,
                                gender: store.userProfile.muscleMapGender
                            )
                        } else {
                            exerciseResults(for: preparedFilteredExercises)
                        }
                    case .filters:
                        featureFiltersPanel

                        if !hasActiveFeatureFilter {
                            FeatureFilterPrompt()
                        } else {
                            exerciseResults(for: preparedFilteredExercises)
                        }
                    case .rehab:
                        rehabPanel
                    }

                    addCustomExerciseFooterButton

                    SecondaryButton("edit_layout", systemImage: "slider.horizontal.3") {
                        HapticService.selection()
                        showEditLayout = true
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 64)
            }
            .background(PulseTheme.background)
            .sheet(isPresented: $showEditLayout) {
                ExerciseFilterLayoutEditorSheet(
                    visibleCategories: resolvedExerciseCategories.visible,
                    hiddenCategories: resolvedExerciseCategories.hiddenAvailable,
                    visibleMuscles: resolvedMuscleShortcuts.visible,
                    hiddenMuscles: resolvedMuscleShortcuts.hiddenAvailable
                ) { categoryOrder, hiddenCategoryIDs, muscleOrder, hiddenMuscleIDs in
                    store.userProfile.exercisesCategoryOrder = categoryOrder
                    store.userProfile.exercisesHiddenCategoryIDs = hiddenCategoryIDs
                    store.userProfile.exercisesMuscleShortcutOrder = muscleOrder
                    store.userProfile.exercisesHiddenMuscleShortcutIDs = hiddenMuscleIDs
                }
                .repsSheetPresentation()
            }
            .task(id: store.exercises.map(\.id)) {
                await rebuildSearchIndex()
            }
            .onChange(of: filterState) { _, _ in
                refreshPreparedExerciseResults()
            }
            .onChange(of: selectedMuscle) { _, newValue in
                if newValue != "All" { selectedMuscleSegments.removeAll() }
            }
            .onChange(of: selectedMuscleSegments) { _, newValue in
                if !newValue.isEmpty { selectedMuscle = "All" }
            }
            .onChange(of: selectedPath) { _, newValue in
                if newValue == .muscles { selectedMuscle = "All" }
                if newValue == .filters { selectedMuscleSegments.removeAll() }
                if newValue != .filters {
                    // The Characteristics controls below aren't shown outside that tab,
                    // so leaving them set silently narrows results with no visible cause.
                    selectedCategory = .all
                    selectedEquipment = "All"
                    selectedType = nil
                    selectedDifficulty = nil
                    selectedEnvironment = nil
                    onlyAvailableEquipment = false
                }
            }
            .safeAreaInset(edge: .top) {
                PulseHeaderBar(
                    title: localizedString("exercise_library"),
                    subtitleKey: "browse_and_add_movements",
                    backAction: isTabRoot ? nil : { dismiss() }
                ) {
                    HStack(spacing: 6) {
                        Button {
                            HapticService.selection()
                            showNotifications = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                    .navigationGlassCircle(.secondary, tint: .clear)
                                if store.hasUnreadBell {
                                    Circle()
                                        .fill(PulseTheme.destructive)
                                        .frame(width: 9, height: 9)
                                        .offset(x: -1, y: 1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("notifications")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if store.isSyncingExerciseLibrary {
                    RepsLoadingView(
                        messages: [
                            localizedString("updating_exercise_library"),
                            localizedString("completing_media_and_instructions"),
                            localizedString("keeping_your_catalog_ready")
                        ],
                        progress: nil,
                        layout: .compact,
                        showsPercentage: false
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                } else if let message = store.exerciseLibrarySyncMessage {
                    Text(localizedKey(message))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseView()
                    .repsSheetPresentation()
            }
            .onDisappear {
                exerciseResultTask?.cancel()
            }
        }
        .mainTabBarHidden(!isTabRoot)
    }

    private var addCustomExerciseFooterButton: some View {
        Button(action: openAddCustomExercise) {
            HStack(spacing: 12) {
                PulseIconBadge(systemImage: "plus", tint: PulseTheme.accent, size: 44, radius: PulseTheme.compactRadius, isFilled: true)

                Text(localizedString("add_custom_exercise"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(PulseTheme.cardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(localizedString("add_custom_exercise"))
    }

    // MARK: - Layout customization

    private var resolvedExerciseCategories: (visible: [ExerciseLibraryCategory], hiddenAvailable: [ExerciseLibraryCategory]) {
        SectionLayoutResolver.resolve(
            allCases: ExerciseLibraryCategory.allCases.filter { $0 != .all },
            storedOrder: store.userProfile.exercisesCategoryOrder,
            storedHidden: store.userProfile.exercisesHiddenCategoryIDs
        )
    }

    private var resolvedMuscleShortcuts: (visible: [MuscleSegment], hiddenAvailable: [MuscleSegment]) {
        SectionLayoutResolver.resolve(
            allCases: MuscleShortcutGrid.defaultSegments,
            storedOrder: store.userProfile.exercisesMuscleShortcutOrder,
            storedHidden: store.userProfile.exercisesHiddenMuscleShortcutIDs
        )
    }

    private func openAddCustomExercise() {
        showAddCustom = true
    }

    private func displayName(forMuscle muscle: String) -> String {
        guard muscle != "All" else {
            return localizedString("all")
        }
        return ExerciseTextLocalizer.muscle(muscle, language: store.userProfile.preferredLanguage)
    }

    private func displayName(forEquipment equipment: String) -> String {
        guard equipment != "All" else {
            return localizedString("all")
        }
        return ExerciseTextLocalizer.equipment(equipment, language: store.userProfile.preferredLanguage)
    }

    private var environmentFilterTitle: String {
        selectedEnvironment?.localizedDisplayName ?? localizedString("any_environment")
    }

    private var difficultyFilterTitle: String {
        selectedDifficulty?.localizedDisplayName ?? localizedString("any_difficulty")
    }

    private func rebuildSearchIndex() async {
        let input = ExerciseLibrarySearchInput(exercises: store.exercises)
        let index = await ExerciseLibraryWorker.shared.makeSearchIndex(input)
        guard !Task.isCancelled else { return }
        searchIndex = index
        refreshPreparedExerciseResults(showLoading: false)
    }

}

struct ExerciseLibrarySearchIndex: Sendable {
    private let entriesByID: [Exercise.ID: String]

    static let empty = ExerciseLibrarySearchIndex(entriesByID: [:])

    init(exercises: [Exercise]) {
        let interval = PerformanceSignpost.begin(
            "exerciseLibrary.searchIndex",
            "exercises=\(exercises.count)"
        )
        defer {
            PerformanceSignpost.end("exerciseLibrary.searchIndex", interval)
        }

        entriesByID = Dictionary(uniqueKeysWithValues: exercises.map { exercise in
            (
                exercise.id,
                Self.normalized([
                    exercise.name,
                    RepsText.exerciseName(exercise.name, language: "es"),
                    exercise.aliases.joined(separator: " "),
                    exercise.muscleGroup,
                    RepsText.muscle(exercise.muscleGroup, language: "es"),
                    exercise.equipment,
                    RepsText.equipment(exercise.equipment, language: "es"),
                    exercise.requiredEquipment.joined(separator: " "),
                    exercise.tags.joined(separator: " "),
                    exercise.instructions ?? "",
                    exercise.notes ?? ""
                ].joined(separator: " "))
            )
        })
    }

    private init(entriesByID: [Exercise.ID: String]) {
        self.entriesByID = entriesByID
    }

    func matches(_ exercise: Exercise, query: String) -> Bool {
        entriesByID[exercise.id]?.contains(query) == true
    }

    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

private enum ExerciseLibraryPath: String, CaseIterable, Identifiable {
    case muscles
    case filters
    case rehab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .muscles: localizedString("muscles")
        case .filters: localizedString("characteristics_2fa17410")
        case .rehab: localizedString("rehab")
        }
    }

    var subtitle: String {
        switch self {
        case .muscles: localizedString("tap_the_body_model")
        case .filters: localizedString("choose_exact_filters")
        case .rehab: localizedString("recovery_protocols")
        }
    }

    var systemImage: String {
        switch self {
        case .muscles: "figure.arms.open"
        case .filters: "slider.horizontal.3"
        case .rehab: "cross.case.fill"
        }
    }

    var tint: Color {
        switch self {
        case .muscles: PulseTheme.accent
        case .filters: PulseTheme.ringStand
        case .rehab: PulseTheme.warning
        }
    }
}

private struct ExerciseLibraryFilterState: Equatable {
    let selectedPath: ExerciseLibraryPath
    let searchText: String
    let selectedMuscle: String
    let selectedMuscleSegments: Set<MuscleSegment>
    let selectedEquipment: String
    let selectedType: Exercise.ExerciseType?
    let selectedDifficulty: Exercise.Difficulty?
    let selectedEnvironment: Exercise.Environment?
    let selectedCategory: ExerciseLibraryCategory
    let onlyAvailableEquipment: Bool
    let availableEquipment: [String]
}

private struct ExercisePathSwitcher: View {
    @Binding var selection: ExerciseLibraryPath

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ExerciseLibraryPath.allCases) { path in
                Button {
                    HapticService.selection()
                    withAnimation(.snappy(duration: 0.22)) {
                        selection = path
                    }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: path.systemImage)
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(isSelected(path) ? PulseTheme.onColor(path.tint) : path.tint)
                            .background(isSelected(path) ? path.tint : path.tint.opacity(0.12), in: Circle())

                        Text(path.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(path.subtitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.74)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 112)
                    .padding(.horizontal, 6)
                    .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                            .stroke(isSelected(path) ? path.tint.opacity(0.55) : PulseTheme.cardStroke, lineWidth: 1)
                    }
                }
                .buttonStyle(PressableCardStyle())
            }
        }
    }

    private func isSelected(_ path: ExerciseLibraryPath) -> Bool {
        selection == path
    }
}

private struct CatalogSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(PulseTheme.accent)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExerciseSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PulseTheme.secondaryText)
            TextField(localizedString("search_exercises"), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.cardStroke, lineWidth: 1)
        }
    }
}

private struct MuscleCatalogPanel: View {
    let gender: BodyGender
    @Binding var selectedSegments: Set<MuscleSegment>
    @Binding var isBodySelectorExpanded: Bool
    let resultCount: Int
    let isLoadingResults: Bool

    var body: some View {
        VStack(spacing: 16) {
            CatalogSectionHeader(
                eyebrow: localizedString("direct_muscle_selection"),
                title: localizedString("tap_a_muscle_and_browse_matching_exercises"),
                subtitle: localizedString("the_model_highlights_the_selected_region_and_the_catalog_groups_results_by_muscle")
            )

            VStack(spacing: 14) {
                if isBodySelectorExpanded {
                    ExerciseBodyMuscleSelector(gender: gender, selectedSegments: $selectedSegments)

                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            isBodySelectorExpanded = false
                        }
                    } label: {
                        Label(
                            RepsLocalization.language == "es" ? "Ocultar selector corporal" : "Hide body selector",
                            systemImage: "chevron.up"
                        )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        HapticService.selection()
                        withAnimation(.snappy(duration: 0.22)) {
                            isBodySelectorExpanded = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            PulseIconBadge(
                                systemImage: "figure.arms.open",
                                tint: PulseTheme.accent,
                                size: 46,
                                isFilled: true
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(RepsLocalization.language == "es" ? "Abrir selector corporal" : "Open body selector")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(
                                    RepsLocalization.language == "es"
                                        ? "Carga el mapa anatómico interactivo solo cuando lo necesites."
                                        : "Load the interactive anatomy map only when you need it."
                                )
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.down")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(PulseTheme.tertiaryText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Label(resultSummary, systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer()
                    if !selectedSegments.isEmpty {
                        Button(localizedString("clear")) {
                            HapticService.selection()
                            selectedSegments.removeAll()
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                    }
                }
            }
            .padding(16)
            .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(PulseTheme.cardStroke, lineWidth: 1)
            }
        }
    }

    private var resultSummary: String {
        if selectedSegments.isEmpty {
            return localizedString("select_one_or_more_muscles")
        }

        if isLoadingResults {
            return RepsLocalization.language == "es" ? "Preparando resultados..." : "Preparing results..."
        }

        return localizedFormat("exercises_count_format", resultCount)
    }
}

private struct RehabHeroCard: View {
    var body: some View {
        HStack(spacing: 14) {
            PulseIconBadge(systemImage: "figure.walk.motion", tint: PulseTheme.ringStand, size: 54, isFilled: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedString("rehabilitation_library"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(localizedString("browse_protocols_by_region_structure_and_recovery_stage"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(PulseTheme.tertiaryText)
        }
        .padding(16)
        .background(PulseTheme.ringStand.opacity(0.10), in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.ringStand.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct RehabFocusTile: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 84)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.cardStroke, lineWidth: 1)
        }
    }
}

private struct MuscleShortcutGrid: View {
    let segments: [MuscleSegment]
    @Binding var selectedSegments: Set<MuscleSegment>
    let gender: BodyGender

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("muscle_groups"))
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(segments) { segment in
                    Button {
                        HapticService.selection()
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedSegments = [segment]
                        }
                    } label: {
                        VStack(spacing: 8) {
                            MuscleGroupAnatomyThumbnail(
                                segment: segment,
                                gender: gender,
                                size: 64
                            )
                            Text(segment.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 132)
                        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                .stroke(PulseTheme.cardStroke, lineWidth: 1)
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
    }

    static let defaultSegments: [MuscleSegment] = [
        .chest, .deltoids, .upperBack, .biceps, .triceps, .abs, .quads, .glutes, .calves
    ]
}

extension MuscleSegment: CustomizableSection {
    var systemImage: String {
        switch preferredSide {
        case .back: "figure.strengthtraining.traditional"
        case .front: "figure.core.training"
        }
    }
}

/// Exercises' "lighter" Edit Layout: reorder/hide the category filter chips and
/// the muscle shortcut tiles together, in one sheet. `.all` isn't included here —
/// it's the no-filter default and stays pinned first in `categoryScroller`.
private struct ExerciseFilterLayoutEditorSheet: View {
    let onSave: (
        _ categoryOrder: [String], _ hiddenCategoryIDs: [String],
        _ muscleOrder: [String], _ hiddenMuscleIDs: [String]
    ) -> Void

    @State private var visibleCategories: [ExerciseLibraryCategory]
    @State private var hiddenCategories: [ExerciseLibraryCategory]
    @State private var visibleMuscles: [MuscleSegment]
    @State private var hiddenMuscles: [MuscleSegment]
    // A real `@State` binding, not `.constant(.active)` — see SectionCustomization.swift.
    @State private var editMode: EditMode = .active
    @Environment(\.dismiss) private var dismiss

    init(
        visibleCategories: [ExerciseLibraryCategory],
        hiddenCategories: [ExerciseLibraryCategory],
        visibleMuscles: [MuscleSegment],
        hiddenMuscles: [MuscleSegment],
        onSave: @escaping (
            _ categoryOrder: [String], _ hiddenCategoryIDs: [String],
            _ muscleOrder: [String], _ hiddenMuscleIDs: [String]
        ) -> Void
    ) {
        self.onSave = onSave
        _visibleCategories = State(initialValue: visibleCategories)
        _hiddenCategories = State(initialValue: hiddenCategories)
        _visibleMuscles = State(initialValue: visibleMuscles)
        _hiddenMuscles = State(initialValue: hiddenMuscles)
    }

    var body: some View {
        NavigationStack {
            List {
                Section(localizedString("category_filters")) {
                    ForEach(visibleCategories) { category in
                        Label(category.title, systemImage: category.systemImage)
                    }
                    .onMove { visibleCategories.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { indices in
                        hiddenCategories.append(contentsOf: indices.map { visibleCategories[$0] })
                        visibleCategories.remove(atOffsets: indices)
                    }
                }

                Section(localizedString("muscle_groups")) {
                    ForEach(visibleMuscles) { segment in
                        Label(segment.title, systemImage: segment.systemImage)
                    }
                    .onMove { visibleMuscles.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { indices in
                        hiddenMuscles.append(contentsOf: indices.map { visibleMuscles[$0] })
                        visibleMuscles.remove(atOffsets: indices)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            // Both "More" panels live outside the editing List — see
            // SectionCustomization.swift's SectionLayoutEditorSheet for why.
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if !hiddenCategories.isEmpty {
                        MoreSectionPanel(hidden: hiddenCategories) { category in
                            HapticService.selection()
                            hiddenCategories.removeAll { $0.id == category.id }
                            visibleCategories.append(category)
                        }
                    }
                    if !hiddenMuscles.isEmpty {
                        MoreSectionPanel(hidden: hiddenMuscles) { segment in
                            HapticService.selection()
                            hiddenMuscles.removeAll { $0.id == segment.id }
                            visibleMuscles.append(segment)
                        }
                    }
                }
                .padding(.bottom, (hiddenCategories.isEmpty && hiddenMuscles.isEmpty) ? 0 : 4)
            }
            .navigationTitle(localizedString("edit_layout"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("done")) {
                        onSave(
                            visibleCategories.map(\.id), hiddenCategories.map(\.id),
                            visibleMuscles.map(\.id), hiddenMuscles.map(\.id)
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct FeatureFilterPrompt: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PulseIconBadge(systemImage: "slider.horizontal.3", tint: PulseTheme.ringStand, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedString("choose_at_least_one_characteristic"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(localizedString("search_pick_a_category_or_adjust_any_filter_to_load_a_focused_exercise_list"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.cardStroke, lineWidth: 1)
        }
    }
}

private struct ExerciseGroupCard: View {
    let title: String
    let exercises: [Exercise]
    let language: String
    let gender: BodyGender
    let catalog: [Exercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(exercises.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    ExerciseLibraryRow(
                        exercise: exercise,
                        language: language,
                        gender: gender,
                        catalog: catalog
                    )
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                if index < exercises.count - 1 {
                    Divider()
                        .overlay(PulseTheme.separator)
                        .padding(.leading, 88)
                }
            }
        }
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.cardStroke, lineWidth: 1)
        }
    }
}

private enum ExerciseLibraryCategory: String, CaseIterable, Identifiable, CustomizableSection {
    case all
    case withVideo
    case withImage
    case withInstructions
    case home
    case gym
    case bodyweight
    case freeWeights
    case machines
    case cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: localizedString("all_6a720856")
        case .withVideo: localizedString("con_video")
        case .withImage: localizedString("con_foto")
        case .withInstructions: localizedString("con_instrucciones")
        case .home: localizedString("home_70f8bb9a")
        case .gym: localizedString("gym_bc435923")
        case .bodyweight: localizedString("bodyweight_4aa2dcf8")
        case .freeWeights: localizedString("free_weights")
        case .machines: localizedString("machines")
        case .cardio: localizedString("cardio")
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .withVideo: "video.fill"
        case .withImage: "photo.fill"
        case .withInstructions: "text.book.closed.fill"
        case .home: "house"
        case .gym: "dumbbell"
        case .bodyweight: "figure.strengthtraining.traditional"
        case .freeWeights: "scalemass"
        case .machines: "rectangle.connected.to.line.below"
        case .cardio: "heart"
        }
    }

    func matches(_ exercise: Exercise) -> Bool {
        let equipment = exercise.equipment.normalizedExerciseFilterValue
        let required = exercise.requiredEquipment.map(\.normalizedExerciseFilterValue)
        let allEquipment = Set(required + [equipment])

        switch self {
        case .all:
            return true
        case .withVideo:
            let hasLocalVideo = exercise.localVideoURL != nil
            let hasCustomVideo = ExerciseVisualResolver.hasValidCustomVideo(exercise.customVideoData)
            return hasLocalVideo || hasCustomVideo
        case .withImage:
            let hasMediaAsset = exercise.mediaAssetURL != nil
            let hasMediaURL = !(exercise.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasCustomImage = ExerciseVisualResolver.hasValidCustomImage(exercise.customImageData)
            let hasVideoThumb = ExerciseVisualResolver.hasValidCustomImage(exercise.customVideoThumbnailData)
            return hasMediaAsset || hasMediaURL || hasCustomImage || hasVideoThumb
        case .withInstructions:
            return exercise.instructions != nil && !exercise.instructions!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .home:
            return exercise.environment == .home || exercise.environment == .both
        case .gym:
            return exercise.environment == .gym || exercise.environment == .both
        case .bodyweight:
            return allEquipment.contains("bodyweight") || allEquipment.contains("body only")
        case .freeWeights:
            return !allEquipment.isDisjoint(with: ["barbell", "dumbbell", "dumbbells", "kettlebell", "kettlebells"])
        case .machines:
            return allEquipment.contains { value in
                value.contains("machine") || value.contains("cable") || value.contains("lever")
            }
        case .cardio:
            return exercise.exerciseType == .cardio || exercise.muscleGroup.normalizedExerciseFilterValue == "cardio"
        }
    }
}

private enum ExerciseTextLocalizer {
    static func name(_ value: String, language: String = RepsLocalization.language) -> String {
        RepsText.exerciseName(value, language: language)
    }

    static func muscle(_ value: String, language: String = RepsLocalization.language) -> String {
        RepsText.muscle(value, language: language)
    }

    static func equipment(_ value: String, language: String = RepsLocalization.language) -> String {
        RepsText.equipment(value, language: language)
    }
}

private extension Exercise.ExerciseType {
    var localizedTitle: String {
        switch self {
        case .strength: localizedString("strength_24d3e4fd")
        case .cardio: localizedString("cardio")
        case .mobility: localizedString("mobility_1f880bb1")
        case .stretching: localizedString("stretching")
        case .hiit: localizedString("hiit")
        }
    }
}

private extension Exercise.Difficulty {
    var localizedTitle: String {
        switch self {
        case .low: localizedString("beginner_60575a6e")
        case .medium: localizedString("intermediate_b1cfe72f")
        case .high: localizedString("advanced_4d064726")
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .low: localizedString("beginner_60575a6e")
        case .medium: localizedString("intermediate_b1cfe72f")
        case .high: localizedString("advanced_4d064726")
        }
    }
}

private extension Exercise.Environment {
    var localizedTitle: String {
        switch self {
        case .home: localizedString("home_70f8bb9a")
        case .gym: localizedString("gym_bc435923")
        case .both: localizedString("home_and_gym_8df533a4")
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .home: localizedString("home_70f8bb9a")
        case .gym: localizedString("gym_bc435923")
        case .both: localizedString("home_and_gym_8df533a4")
        }
    }
}

private extension String {
    var normalizedExerciseFilterValue: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: Exercise
    let language: String
    let gender: BodyGender
    let catalog: [Exercise]

    var body: some View {
        HStack(spacing: 14) {
            ExerciseMediaThumbnail(exercise: exercise, gender: gender, catalog: catalog)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(ExerciseTextLocalizer.name(exercise.name, language: language))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("\(ExerciseTextLocalizer.muscle(exercise.muscleGroup, language: language)) · \(ExerciseTextLocalizer.equipment(exercise.equipment, language: language))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

}

private struct FilterMenuRow<Content: View>: View {
    let title: String
    let value: String
    let content: Content

    init(title: String, value: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            HStack {
                Text(localizedKey(title))
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(PulseTheme.accent)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ExerciseMetadataChips: View {
    let exercise: Exercise

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MetadataChip(title: exercise.exerciseType.localizedTitle, systemImage: "figure.strengthtraining.traditional")
                MetadataChip(title: exercise.difficulty.localizedTitle, systemImage: "speedometer")
                MetadataChip(title: exercise.environment.localizedTitle, systemImage: "location")
            }
        }
    }
}

private struct MetadataChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(localizedKey(title), systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(PulseTheme.accent)
            .background(PulseTheme.accent.opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct ExerciseActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(localizedKey(title), systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
            .background(PulseTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct InstructionStepRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                .frame(width: 26, height: 26)
                .background(PulseTheme.accent)
                .clipShape(Circle())
            AppleTranslatedText(text)
                .font(.body)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private enum ExerciseInstructionParser {
    static func steps(from instructions: String?) -> [String] {
        guard let instructions else {
            return []
        }

        let cleaned = instructions
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return []
        }

        let numberedPattern = #"(?m)(?:^|\n)\s*\d+[\.\)]\s+"#
        if let regex = try? NSRegularExpression(pattern: numberedPattern) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            let matches = regex.matches(in: cleaned, range: range)
            if matches.count > 1 {
                var steps: [String] = []
                for (index, match) in matches.enumerated() {
                    let start = match.range.location + match.range.length
                    let end = index + 1 < matches.count ? matches[index + 1].range.location : range.length
                    guard start < end,
                          let swiftRange = Range(NSRange(location: start, length: end - start), in: cleaned) else {
                        continue
                    }
                    steps.append(normalize(cleaned[swiftRange]))
                }
                return steps.filter { !$0.isEmpty }
            }
        }

        let lineSteps = cleaned
            .split(whereSeparator: \.isNewline)
            .map(normalize)
            .filter { !$0.isEmpty }
        if lineSteps.count > 1 {
            return lineSteps
        }

        return cleaned
            .split(separator: ". ")
            .map { normalize($0) }
            .filter { !$0.isEmpty }
    }

    private static func normalize<S: StringProtocol>(_ value: S) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

struct ExerciseDetailView: View {
    @Environment(AppStore.self) private var store
    let exercise: Exercise
    
    @State private var selectedTab: ExerciseTab = .instructions
    @State private var showAddToPlan = false
    @State private var showSchedule = false
    @State private var feedbackMessage: String?
    @State private var showBookmarkEditor = false
    @State private var showSecondaryEditor = false
    @State private var showEditCustomExercise = false

    // History and progress state
    @State private var metric = ExerciseProgressMetric.weight
    @State private var selectedHistoryRange = ExerciseHistoryRange.sixMonths

    private enum ExerciseTab: String, CaseIterable, Identifiable {
        case instructions = "instructions"
        case media = "media"
        case info = "info"
        case history = "history"
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .instructions: return localizedString("instructions")
            case .media: return localizedString("multimedia")
            case .info: return localizedString("info")
            case .history: return localizedString("history")
            }
        }
    }

    private var currentExercise: Exercise {
        store.exercises.first(where: { $0.id == exercise.id }) ?? exercise
    }

    /// Custom (user-added) exercises aren't part of the built-in catalog, so
    /// they're the only ones safe to let the user edit in place.
    private var isCustomExercise: Bool {
        !SeedData.exercises.contains(where: { $0.id == currentExercise.id })
    }

    private var instructionSteps: [String] {
        ExerciseInstructionParser.steps(from: currentExercise.localizedInstructions(language: store.userProfile.preferredLanguage))
    }

    private var points: [FitnessMetrics.ExerciseProgressPoint] {
        FitnessMetrics.progressPoints(for: currentExercise, in: store.workoutSessions)
    }

    private var rangedPoints: [FitnessMetrics.ExerciseProgressPoint] {
        points.filter { $0.date >= selectedHistoryRange.startDate }
    }
    
    private var fatigueScore: Int {
        let text = "\(currentExercise.name) \(currentExercise.muscleGroup) \(currentExercise.equipment)".lowercased()
        var score = 1
        if text.contains("barbell") || text.contains("barra") { score += 1 }
        if text.contains("squat") || text.contains("deadlift") || text.contains("press") || text.contains("row") { score += 1 }
        if text.contains("legs") || text.contains("back") || text.contains("full") { score += 1 }
        return min(score, 4)
    }

    private var fatigueDescription: String {
        switch fatigueScore {
        case 1: return localizedString("fatigue_low")
        case 2: return localizedString("fatigue_moderate")
        case 3: return localizedString("fatigue_high")
        default: return localizedString("fatigue_very_high")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // High-Contrast custom tab bar with active spring underlines
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(ExerciseTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Text(tab.localizedTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(selectedTab == tab ? PulseTheme.ringStand : PulseTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                
                                Rectangle()
                                    .fill(selectedTab == tab ? PulseTheme.ringStand : Color.clear)
                                    .frame(height: 3.5)
                                    .clipShape(.rect(cornerRadius: PulseTheme.smallRadius))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .background(PulseTheme.card)
                
                Divider()
                    .overlay(PulseTheme.separator)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .instructions:
                        instructionsTabContent
                    case .media:
                        mediaTabContent
                    case .info:
                        infoTabContent
                    case .history:
                        historyTabContent
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .screenBackground()
        .navigationTitle(localizedString("exercise_20863c83"))
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
        .toolbar {
            if isCustomExercise {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditCustomExercise = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(localizedString("edit"))
                }
            }
        }
        .sheet(isPresented: $showEditCustomExercise) {
            AddCustomExerciseView(existingExercise: currentExercise)
                .environment(store)
                .repsSheetPresentation()
        }
        .sheet(isPresented: $showAddToPlan) {
            AddExerciseToPlanView(exercise: currentExercise) {
                feedbackMessage = localizedString("exercise_added_to_the_active_plan")
            }
            .environment(store)
            .repsSheetPresentation()
        }
        .sheet(isPresented: $showSchedule) {
            ScheduleExerciseView(exercise: currentExercise) {
                feedbackMessage = localizedString("exercise_scheduled")
            }
            .environment(store)
            .repsSheetPresentation()
        }
        .sheet(isPresented: $showBookmarkEditor) {
            ExerciseBookmarkEditor(exercise: currentExercise)
                .environment(store)
                .repsSheetPresentation()
        }
        .sheet(isPresented: $showSecondaryEditor) {
            SecondaryMuscleEditorView(exercise: currentExercise) { weights in
                var updated = currentExercise
                updated.secondaryMuscleWeights = weights
                store.updateExercise(updated)
            }
            .environment(store)
            .repsSheetPresentation()
        }
    }

    // --- TAB CONTENTS ---

    private var mediaTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ExerciseHeroMedia(exercise: currentExercise, gender: store.userProfile.muscleMapGender)

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizedString("hero_media_title"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.primary)
                            Text(localizedString("hero_media_subtitle"))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()

                        if currentExercise.preferredHeroMedia != nil && currentExercise.preferredHeroMedia != .automatic {
                            Button {
                                var updated = currentExercise
                                updated.preferredHeroMedia = .automatic
                                store.updateExercise(updated)
                            } label: {
                                Text(localizedString("reset_auto"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(PulseTheme.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardTitle("videos_gallery")

                    if currentExercise.localVideoURL != nil {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(PulseTheme.grouped)
                                    .frame(width: 70, height: 70)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(PulseTheme.accent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedString("official_catalog_video"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.primary)
                                Text("MP4 HD 1080p")
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()

                            Button {
                                var updated = currentExercise
                                updated.preferredHeroMedia = .catalogVideo
                                store.updateExercise(updated)
                            } label: {
                                HStack(spacing: 4) {
                                    if currentExercise.preferredHeroMedia == .catalogVideo {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(localizedString("active_hero"))
                                    } else {
                                        Text(localizedString("use_in_hero"))
                                    }
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(currentExercise.preferredHeroMedia == .catalogVideo ? PulseTheme.accent : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(currentExercise.preferredHeroMedia == .catalogVideo ? PulseTheme.accent.opacity(0.15) : PulseTheme.grouped)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let customVid = currentExercise.customVideoData, ExerciseVisualResolver.hasValidCustomVideo(customVid) {
                        HStack(spacing: 14) {
                            ZStack {
                                if let thumbData = currentExercise.customVideoThumbnailData, let img = UIImage(data: thumbData) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(PulseTheme.grouped)
                                        .frame(width: 70, height: 70)
                                    Image(systemName: "film")
                                        .font(.system(size: 24))
                                        .foregroundStyle(PulseTheme.accent)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedString("custom_user_video"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.primary)
                                Text(localizedString("saved_offline"))
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    var updated = currentExercise
                                    updated.preferredHeroMedia = .customVideo
                                    store.updateExercise(updated)
                                } label: {
                                    HStack(spacing: 4) {
                                        if currentExercise.preferredHeroMedia == .customVideo {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text(localizedString("active_hero"))
                                        } else {
                                            Text(localizedString("use_in_hero"))
                                        }
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(currentExercise.preferredHeroMedia == .customVideo ? PulseTheme.accent : Color.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(currentExercise.preferredHeroMedia == .customVideo ? PulseTheme.accent.opacity(0.15) : PulseTheme.grouped)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    var updated = currentExercise
                                    updated.customVideoData = nil
                                    updated.customVideoThumbnailData = nil
                                    if updated.preferredHeroMedia == .customVideo {
                                        updated.preferredHeroMedia = .automatic
                                    }
                                    store.updateExercise(updated)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(PulseTheme.warning)
                                        .padding(8)
                                        .background(PulseTheme.warning.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    ExerciseMediaPickerMenu(
                        hasCustomImage: ExerciseVisualResolver.hasValidCustomImage(currentExercise.customImageData),
                        hasCustomVideo: ExerciseVisualResolver.hasValidCustomVideo(currentExercise.customVideoData),
                        onImageCaptured: { data in
                            var updated = currentExercise
                            updated.customImageData = data
                            store.updateExercise(updated)
                        },
                        onVideoCaptured: { data, thumbnail in
                            var updated = currentExercise
                            updated.customVideoData = data
                            updated.customVideoThumbnailData = thumbnail
                            store.updateExercise(updated)
                        },
                        onDeleteImage: {
                            var updated = currentExercise
                            updated.customImageData = nil
                            store.updateExercise(updated)
                        },
                        onDeleteVideo: {
                            var updated = currentExercise
                            updated.customVideoData = nil
                            updated.customVideoThumbnailData = nil
                            store.updateExercise(updated)
                        }
                    ) {
                        Label(localizedString("record_or_add_video"), systemImage: "video.badge.plus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(PulseTheme.accent)
                            .background(PulseTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardTitle("images_and_models")

                    if let mediaURL = currentExercise.mediaAssetURL {
                        HStack(spacing: 14) {
                            RemoteExerciseImage(url: mediaURL) {
                                RoundedRectangle(cornerRadius: 12).fill(PulseTheme.grouped)
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedString("official_catalog_image"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.primary)
                                Text(localizedString("visual_reference"))
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()

                            Button {
                                var updated = currentExercise
                                updated.preferredHeroMedia = .catalogImage
                                store.updateExercise(updated)
                            } label: {
                                HStack(spacing: 4) {
                                    if currentExercise.preferredHeroMedia == .catalogImage {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(localizedString("active_hero"))
                                    } else {
                                        Text(localizedString("use_in_hero"))
                                    }
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(currentExercise.preferredHeroMedia == .catalogImage ? PulseTheme.accent : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(currentExercise.preferredHeroMedia == .catalogImage ? PulseTheme.accent.opacity(0.15) : PulseTheme.grouped)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let customImg = currentExercise.customImageData, let uiImg = UIImage(data: customImg) {
                        HStack(spacing: 14) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedString("custom_user_photo"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.primary)
                                Text(localizedString("saved_offline"))
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    var updated = currentExercise
                                    updated.preferredHeroMedia = .customImage
                                    store.updateExercise(updated)
                                } label: {
                                    HStack(spacing: 4) {
                                        if currentExercise.preferredHeroMedia == .customImage {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text(localizedString("active_hero"))
                                        } else {
                                            Text(localizedString("use_in_hero"))
                                        }
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(currentExercise.preferredHeroMedia == .customImage ? PulseTheme.accent : Color.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(currentExercise.preferredHeroMedia == .customImage ? PulseTheme.accent.opacity(0.15) : PulseTheme.grouped)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    var updated = currentExercise
                                    updated.customImageData = nil
                                    if updated.preferredHeroMedia == .customImage {
                                        updated.preferredHeroMedia = .automatic
                                    }
                                    store.updateExercise(updated)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(PulseTheme.warning)
                                        .padding(8)
                                        .background(PulseTheme.warning.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: 14) {
                        ExerciseAnatomyThumbnail(exercise: currentExercise, gender: store.userProfile.muscleMapGender, size: 70)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizedString("anatomy_model_3d"))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.primary)
                            Text(localizedString("vector_muscles_map"))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()

                        Button {
                            var updated = currentExercise
                            updated.preferredHeroMedia = .anatomyModel
                            store.updateExercise(updated)
                        } label: {
                            HStack(spacing: 4) {
                                if currentExercise.preferredHeroMedia == .anatomyModel {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(localizedString("active_hero"))
                                } else {
                                    Text(localizedString("use_in_hero"))
                                }
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(currentExercise.preferredHeroMedia == .anatomyModel ? PulseTheme.accent : Color.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(currentExercise.preferredHeroMedia == .anatomyModel ? PulseTheme.accent.opacity(0.15) : PulseTheme.grouped)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 16) {
                    CardTitle("bookmarks_and_links")

                    if currentExercise.mediaBookmarks.isEmpty {
                        Text(localizedString("no_bookmarks_added_yet"))
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    } else {
                        ForEach(currentExercise.mediaBookmarks) { bookmark in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.primary)
                                    Text(bookmark.urlString)
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.accent)
                                        .lineLimit(1)
                                }
                                Spacer()

                                Link(destination: URL(string: bookmark.urlString) ?? URL(string: "https://google.com")!) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 18))
                                        .foregroundStyle(PulseTheme.accent)
                                }
                            }
                        }
                    }

                    Button {
                        showBookmarkEditor = true
                    } label: {
                        Label(localizedString("add_link_or_external_video"), systemImage: "link.badge.plus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(PulseTheme.accent)
                            .background(PulseTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private var instructionsTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ExerciseHeroMedia(exercise: currentExercise, gender: store.userProfile.muscleMapGender)

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(currentExercise.localizedName(language: store.userProfile.preferredLanguage))
                        .font(.title2.bold())
                    Text("\(ExerciseTextLocalizer.muscle(currentExercise.muscleGroup, language: store.userProfile.preferredLanguage)) · \(ExerciseTextLocalizer.equipment(currentExercise.equipment, language: store.userProfile.preferredLanguage))")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    ExerciseMetadataChips(exercise: currentExercise)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle("use_this_exercise")
                    Label(trackingLabel, systemImage: "chart.bar.fill")
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button {
                            showAddToPlan = true
                        } label: {
                            ExerciseActionButton(title: localizedString("add_to_plan_8ce82b2f"), systemImage: "plus.rectangle.on.rectangle")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSchedule = true
                        } label: {
                            ExerciseActionButton(title: localizedString("schedule_0a8adac9"), systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.plain)
                    }
                    if let feedbackMessage {
                        Text(feedbackMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle("personalization")
                    HStack(spacing: 10) {
                        ExerciseMediaPickerMenu(
                            hasCustomImage: ExerciseVisualResolver.hasValidCustomImage(currentExercise.customImageData),
                            hasCustomVideo: ExerciseVisualResolver.hasValidCustomVideo(currentExercise.customVideoData),
                            onImageCaptured: { data in
                                var updated = currentExercise
                                updated.customImageData = data
                                store.updateExercise(updated)
                            },
                            onVideoCaptured: { data, thumbnail in
                                var updated = currentExercise
                                updated.customVideoData = data
                                updated.customVideoThumbnailData = thumbnail
                                store.updateExercise(updated)
                            },
                            onDeleteImage: {
                                var updated = currentExercise
                                updated.customImageData = nil
                                store.updateExercise(updated)
                            },
                            onDeleteVideo: {
                                var updated = currentExercise
                                updated.customVideoData = nil
                                updated.customVideoThumbnailData = nil
                                store.updateExercise(updated)
                            }
                        ) {
                            Label(localizedString("cambiar_imagen_o_video"), systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.accent)
                                .background(PulseTheme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }

                        Button {
                            showBookmarkEditor = true
                        } label: {
                            Label(localizedString("marcadores"), systemImage: "bookmark.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.accent)
                                .background(PulseTheme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                    }

                    if ExerciseVisualResolver.hasValidCustomImage(currentExercise.customImageData) {
                        Label(localizedString("imagen_propia_guardada_offline"), systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    if ExerciseVisualResolver.hasValidCustomVideo(currentExercise.customVideoData) {
                        Label(localizedString("video_propio_guardado_offline"), systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    CardTitle("instructions")
                    if instructionSteps.isEmpty {
                        Text(localizedString("this_exercise_does_not_include_detailed_instructions_yet"))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(Array(instructionSteps.enumerated()), id: \.offset) { index, step in
                            InstructionStepRow(index: index + 1, text: step)
                        }
                    }
                    let mistakes = currentExercise.localizedCommonMistakes(language: store.userProfile.preferredLanguage)
                    if !mistakes.isEmpty {
                        Divider()
                        CardTitle("avoid")
                        ForEach(mistakes, id: \.self) { mistake in
                            Label(mistake, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle("reference")
                    if let notes = currentExercise.notes, !notes.isEmpty {
                        Text(notes)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let mediaURL = currentExercise.mediaURL, !mediaURL.isEmpty {
                        Divider()
                        Label(localizedString("execution_reference_image"), systemImage: "photo")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.accent)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(mediaURL)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !currentExercise.mediaBookmarks.isEmpty {
                        Divider()
                        CardTitle("marcadores_multimedia")
                        ForEach(currentExercise.mediaBookmarks) { bookmark in
                            Link(destination: URL(string: bookmark.urlString) ?? URL(string: "https://www.youtube.com")!) {
                                HStack {
                                    Image(systemName: bookmark.source == .instagram ? "camera.fill" : "play.rectangle.fill")
                                        .foregroundStyle(PulseTheme.accent)
                                    VStack(alignment: .leading) {
                                        Text(bookmark.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        if let timestamp = bookmark.timestampSeconds {
                                            Text("\(timestamp / 60):\(String(format: "%02d", timestamp % 60))")
                                                .font(.caption)
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.forward")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                                .padding(10)
                                .background(PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var infoTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(localizedString("anatomy_map"))
                .font(.title3.bold())
            
            ExerciseMuscleInfoPanel(exercise: currentExercise, gender: store.userProfile.muscleMapGender)
            
            Text(localizedString("muscles_worked_896b79db"))
                .font(.headline)
            
            PulseCard {
                VStack(spacing: 0) {
                    ExerciseMuscleTargetRow(
                        title: localizedMuscle(currentExercise.muscleGroup),
                        subtitle: "value_1_direct_work_set",
                        muscleGroup: currentExercise.muscleGroup,
                        exerciseName: currentExercise.name,
                        gender: store.userProfile.muscleMapGender
                    )
                    if !currentExercise.secondaryMuscles.isEmpty {
                        Divider()
                        ForEach(currentExercise.secondaryMuscles, id: \.self) { muscle in
                            let pct = Int((currentExercise.secondaryInvolvement(muscle) * 100).rounded())
                            ExerciseMuscleTargetRow(
                                title: localizedMuscle(muscle),
                                subtitle: localizedFormat("indirect_work_set_format", pct),
                                muscleGroup: muscle,
                                exerciseName: currentExercise.name,
                                gender: store.userProfile.muscleMapGender
                            )
                            if muscle != currentExercise.secondaryMuscles.last {
                                Divider()
                            }
                        }
                    }
                }
            }

            if !currentExercise.secondaryMuscles.isEmpty {
                Button {
                    showSecondaryEditor = true
                } label: {
                    Label(
                        localizedString("edit_secondary_muscles"),
                        systemImage: "slider.horizontal.3"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.ringStand)
                }
            }
            
            ResistanceCurveCard(profile: ResistanceCurveProfile(exercise: currentExercise))
            
            FatigueRatingCard(score: fatigueScore, description: fatigueDescription)
        }
    }

    @ViewBuilder
    private var strengthLevelCard: some View {
        let best1RM = rangedPoints.map(\.estimatedOneRepMaxKg).max() ?? 0
        if let result = StrengthStandards.level(
            exerciseName: currentExercise.name,
            oneRepMaxKg: best1RM,
            bodyWeightKg: store.currentWeight,
            sex: store.userProfile.sex
        ) {
            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(localizedString("strength_level"))
                            .font(.headline)
                        Spacer()
                        Text(result.level.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.onColor(strengthLevelColor(result.level)))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(strengthLevelColor(result.level))
                            .clipShape(Capsule())
                    }
                    SwiftUI.ProgressView(value: result.level.fraction)
                        .tint(strengthLevelColor(result.level))
                    HStack {
                        Text(String(format: localizedString("bodyweight_2"), result.ratio))
                        Spacer()
                        Text("1RM \(Int(best1RM)) kg · \(localizedString("bodyweight")) \(Int(store.currentWeight)) kg")
                    }
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        } else if StrengthStandards.hasStandard(forExerciseName: currentExercise.name),
                  store.currentWeight <= 0 {
            PulseCard {
                HStack(spacing: 10) {
                    Image(systemName: "scalemass")
                        .foregroundStyle(PulseTheme.accent)
                    Text(localizedString("log_your_bodyweight_in_profile_to_see_your_strength_level"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private func strengthLevelColor(_ level: StrengthLevel) -> Color {
        switch level {
        case .beginner: return PulseTheme.secondaryText
        case .novice: return PulseTheme.hrZones[0]
        case .intermediate: return PulseTheme.hrZones[1]
        case .advanced: return .orange
        case .elite: return .red
        }
    }

    private var historyTabContent: some View {
        VStack(spacing: 20) {
            if rangedPoints.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "exercise_not_performed_yet",
                        message: "once_you_log_sets_for_this_exercise_your_performance_trends_will_appear_here",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
            } else {
                HStack(spacing: 14) {
                    MetricCard(title: "best_weight", value: String(format: "%.0f", rangedPoints.map(\.maxWeightKg).max() ?? 0), subtitle: "kg", systemImage: "scalemass", badgeColor: PulseTheme.accent, domain: .strength)
                    MetricCard(title: "estimated_1rm", value: String(format: "%.0f", rangedPoints.map(\.estimatedOneRepMaxKg).max() ?? 0), subtitle: "kg", systemImage: "bolt", badgeColor: PulseTheme.accent, domain: .strength)
                }

                HStack(spacing: 14) {
                    MetricCard(title: "overload", value: String(format: "%.1f", FitnessMetrics.progressiveOverloadDelta(for: rangedPoints)), subtitle: "value_1rm_delta", systemImage: "arrow.up.right", badgeColor: PulseTheme.warning, domain: .strength)
                    MetricCard(title: "avg_volume", value: "\(Int(FitnessMetrics.averageVolumeKg(for: rangedPoints)))", subtitle: "kg_per_session", systemImage: "chart.bar", badgeColor: PulseTheme.ringStand, domain: .strength)
                }

                strengthLevelCard

                Picker("range", selection: $selectedHistoryRange) {
                    ForEach(ExerciseHistoryRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Picker("metrics", selection: $metric) {
                    ForEach(ExerciseProgressMetric.allCases) { metric in
                        Text(metric.localizedTitle).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                PulseCard {
                    ExercisePerformanceChart(
                        points: rangedPoints,
                        metric: metric
                    )
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CardTitle("recent_sessions")
                        ForEach(rangedPoints.reversed()) { point in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(point.workoutTitle).font(.headline)
                                    Text(point.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(metric.valueText(for: point))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            if point.id != rangedPoints.reversed().last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    // --- METRIC AND TRANSLATION HELPERS ---

    private var trackingLabel: String {
        return switch currentExercise.trackingType {
        case .weightReps: localizedString("weight_and_reps")
        case .repsOnly: localizedString("reps_only")
        case .duration: localizedString("duration_4")
        }
    }

    private func localizedMuscle(_ value: String) -> String {
        RepsText.muscle(value, language: store.userProfile.preferredLanguage)
    }
}

private struct ExerciseThumbnail: View {
    let exercise: Exercise
    let size: CGFloat
    var gender: BodyGender = .male

    var body: some View {
        ExerciseMediaThumbnail(exercise: exercise, gender: gender)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: min(16, size * 0.20), style: .continuous))
    }
}

struct ExerciseHeroMedia: View {
    let exercise: Exercise
    let gender: BodyGender
    var height: CGFloat = 320

    @State private var showVideoPlayer = false
    @State private var showFullscreenMedia = false

    private var activeMediaMode: PreferredHeroMedia {
        if let preferred = exercise.preferredHeroMedia, preferred != .automatic {
            switch preferred {
            case .catalogVideo:
                if exercise.localVideoURL != nil { return .catalogVideo }
            case .customVideo:
                if ExerciseVisualResolver.hasValidCustomVideo(exercise.customVideoData) { return .customVideo }
            case .customImage:
                if ExerciseVisualResolver.hasValidCustomImage(exercise.customImageData) { return .customImage }
            case .catalogImage:
                if exercise.mediaAssetURL != nil { return .catalogImage }
            case .anatomyModel:
                return .anatomyModel
            case .automatic:
                break
            }
        }

        if ExerciseVisualResolver.hasValidCustomImage(exercise.customImageData) {
            return .customImage
        } else if let thumbnailData = exercise.customVideoThumbnailData, UIImage(data: thumbnailData) != nil {
            return .customVideo
        } else if exercise.localVideoURL != nil {
            return .catalogVideo
        } else if exercise.mediaAssetURL != nil {
            return .catalogImage
        } else {
            return .anatomyModel
        }
    }

    private var hasGuideVideo: Bool {
        ExerciseVisualResolver.hasValidCustomVideo(exercise.customVideoData)
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack(alignment: .bottomLeading) {
                    switch activeMediaMode {
                    case .customImage:
                        if let data = exercise.customImageData, let image = UIImage(data: data) {
                            ExerciseHeroFillImage(image: image, size: size)
                        } else {
                            ExerciseHeroFallback(exercise: exercise, gender: gender)
                                .frame(width: size.width, height: size.height)
                        }
                    case .customVideo:
                        if let thumbnailData = exercise.customVideoThumbnailData, let image = UIImage(data: thumbnailData) {
                            ExerciseHeroFillImage(image: image, size: size)
                        } else {
                            ExerciseHeroFallback(exercise: exercise, gender: gender)
                                .frame(width: size.width, height: size.height)
                        }
                    case .catalogVideo:
                        if let videoURL = exercise.localVideoURL {
                            ExerciseLoopVideoPlayer(videoURL: videoURL)
                                .frame(width: size.width, height: size.height)
                        } else {
                            ExerciseHeroFallback(exercise: exercise, gender: gender)
                                .frame(width: size.width, height: size.height)
                        }
                    case .catalogImage:
                        if let url = exercise.mediaAssetURL {
                            ExerciseReferenceImage(exercise: exercise, url: url, size: size, gender: gender)
                        } else {
                            ExerciseHeroFallback(exercise: exercise, gender: gender)
                                .frame(width: size.width, height: size.height)
                        }
                    case .anatomyModel, .automatic:
                        ExerciseHeroFallback(exercise: exercise, gender: gender)
                            .frame(width: size.width, height: size.height)
                    }

                    LinearGradient(
                        colors: [PulseTheme.mediaScrimClear, PulseTheme.mediaScrimStrong],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: size.width, height: size.height)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("referencia_visual")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.mediaSubtext)
                        Text(exercise.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PulseTheme.mediaText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: max(size.width - 32, 0), alignment: .leading)
                    }
                    .padding(16)

                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                showFullscreenMedia = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ver a pantalla completa")
                        }
                        Spacer()
                    }
                    .padding(12)
                }
                .frame(width: size.width, height: size.height)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                .clipped()
            }

            if hasGuideVideo && activeMediaMode != .catalogVideo {
                Button {
                    showVideoPlayer = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(PulseTheme.mediaText)
                        .shadow(color: PulseTheme.mediaScrimStrong, radius: 10)
                        .padding(24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("play_guide_video"))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityLabel("Imagen de referencia de \(exercise.name)")
        .sheet(isPresented: $showVideoPlayer) {
            if let videoData = exercise.customVideoData {
                ExerciseGuideVideoPlayerSheet(videoData: videoData, title: exercise.name)
                    .repsSheetPresentation()
            }
        }
        .fullScreenCover(isPresented: $showFullscreenMedia) {
            switch activeMediaMode {
            case .catalogVideo:
                FullscreenExerciseMediaView(
                    title: exercise.name,
                    videoURL: exercise.localVideoURL
                )
            case .customVideo:
                FullscreenExerciseMediaView(
                    title: exercise.name,
                    videoData: exercise.customVideoData
                )
            case .customImage:
                FullscreenExerciseMediaView(
                    title: exercise.name,
                    image: exercise.customImageData.flatMap(UIImage.init(data:))
                )
            case .catalogImage:
                FullscreenExerciseMediaView(
                    title: exercise.name,
                    imageURL: exercise.mediaAssetURL
                )
            case .anatomyModel, .automatic:
                FullscreenExerciseMediaView(
                    title: exercise.name,
                    exercise: exercise,
                    gender: gender
                )
            }
        }
    }
}

private struct ExerciseHeroFillImage: View {
    let image: UIImage
    let size: CGSize

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

struct ExerciseReferenceImage: View {
    let exercise: Exercise
    let url: URL
    let size: CGSize
    let gender: BodyGender
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image {
                ExerciseHeroFillImage(image: image, size: size)
            } else if isLoading {
                ProgressView()
                    .tint(PulseTheme.accent)
                    .frame(width: size.width, height: size.height)
            } else {
                ExerciseHeroFallback(exercise: exercise, gender: gender)
                    .frame(width: size.width, height: size.height)
            }
        }
        .task(id: url) {
            isLoading = true
            image = await ExerciseReferenceImageCache.shared.image(for: url)
            isLoading = false
        }
    }
}

private struct ExerciseHeroFallback: View {
    let exercise: Exercise
    let gender: BodyGender

    var body: some View {
        GeometryReader { proxy in
            let coverSize = max(proxy.size.width, proxy.size.height) * 1.08

            ZStack {
                ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: coverSize)
                    .frame(width: coverSize, height: coverSize)
                    .clipped()

                PulseTheme.accent.opacity(0.08)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

private actor ExerciseReferenceImageCache {
    static let shared = ExerciseReferenceImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let cacheDirectory: URL

    init() {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheDirectory = baseURL.appendingPathComponent("ExerciseReferenceImages", isDirectory: true)
    }

    func image(for url: URL) async -> UIImage? {
        let nsURL = url as NSURL
        if let image = memoryCache.object(forKey: nsURL) {
            return image
        }

        let fileURL = cacheDirectory.appendingPathComponent(cacheKey(for: url)).appendingPathExtension("img")
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: nsURL)
            return image
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                return nil
            }

            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: [.atomic])
            memoryCache.setObject(image, forKey: nsURL)
            return image
        } catch {
            return nil
        }
    }

    private func cacheKey(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct AddExerciseToPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let exercise: Exercise
    let onSaved: () -> Void

    @State private var selectedDayID: WorkoutDay.ID?
    @State private var targetSets = 3
    @State private var repRange: String

    init(exercise: Exercise, onSaved: @escaping () -> Void) {
        self.exercise = exercise
        self.onSaved = onSaved
        _repRange = State(initialValue: Self.defaultRepRange(for: exercise))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("exercise_2") {
                    Text(exercise.name)
                    Text("\(ExerciseTextLocalizer.muscle(exercise.muscleGroup, language: store.userProfile.preferredLanguage)) · \(ExerciseTextLocalizer.equipment(exercise.equipment, language: store.userProfile.preferredLanguage))")
                        .foregroundStyle(.secondary)
                }

                Section("activate_plan") {
                    Picker("workout_day", selection: $selectedDayID) {
                        ForEach(store.activePlan.days) { day in
                            Text(day.title).tag(Optional(day.id))
                        }
                    }
                    Stepper("\(targetSets) sets", value: $targetSets, in: 1...10)
                    TextField("rep_range", text: $repRange)
                }
            }
            .navigationTitle("add_to_plan")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedDayID = selectedDayID ?? store.activePlan.days.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        if let selectedDayID {
                            store.addExerciseToActivePlanDay(
                                exercise,
                                dayID: selectedDayID,
                                targetSets: targetSets,
                                repRange: repRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.defaultRepRange(for: exercise) : repRange
                            )
                            onSaved()
                        }
                        dismiss()
                    }
                    .disabled(selectedDayID == nil)
                }
            }
        }
    }

    static func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }
}

private struct ScheduleExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let exercise: Exercise
    let onSaved: () -> Void

    @State private var date = Date()
    @State private var targetSets = 3
    @State private var repRange: String

    init(exercise: Exercise, onSaved: @escaping () -> Void) {
        self.exercise = exercise
        self.onSaved = onSaved
        _repRange = State(initialValue: AddExerciseToPlanView.defaultRepRange(for: exercise))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("exercise_2") {
                    Text(exercise.name)
                    Text("\(ExerciseTextLocalizer.muscle(exercise.muscleGroup, language: store.userProfile.preferredLanguage)) · \(ExerciseTextLocalizer.equipment(exercise.equipment, language: store.userProfile.preferredLanguage))")
                        .foregroundStyle(.secondary)
                }

                Section("schedule") {
                    DatePicker("training_day_2", selection: $date, displayedComponents: [.date])
                    Stepper("\(targetSets) sets", value: $targetSets, in: 1...10)
                    TextField("rep_range", text: $repRange)
                }
            }
            .navigationTitle("schedule_exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        store.scheduleSingleExercise(
                            exercise,
                            date: date,
                            targetSets: targetSets,
                            repRange: repRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AddExerciseToPlanView.defaultRepRange(for: exercise) : repRange
                        )
                        onSaved()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExerciseMediaBookmarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bookmarks: [ExerciseMediaBookmark]
    var onSave: (() -> Void)? = nil

    @State private var title = ""
    @State private var source: ExerciseMediaBookmark.Source = .other
    @State private var urlString = ""
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var durationMinutes = 0
    @State private var durationSeconds = 0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("marcadores_guardados") {
                    if bookmarks.isEmpty {
                        Text("add_references_from_youtube_shorts_tiktok_or_instagram_to_enrich_your_offline_li")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(bookmarks) { bookmark in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(bookmark.title, systemImage: icon(for: bookmark.source))
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
                                        .foregroundStyle(PulseTheme.accent)
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

                Section("nuevo_marcador") {
                    TextField("quick_title", text: $title)
                    Picker("fuente", selection: $source) {
                        ForEach(ExerciseMediaBookmark.Source.allCases) { source in
                            Text(sourceTitle(source)).tag(source)
                        }
                    }
                    TextField("image_or_video_url", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Text("video_start_point")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper("Min \(minutes)", value: $minutes, in: 0...240)
                    Stepper("Seg \(seconds)", value: $seconds, in: 0...59)
                    
                    Text("playback_duration")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper(value: $durationMinutes, in: 0...60) {
                        Text(localizedFormat("min_duration_stepper_format", durationMinutes))
                    }
                    Stepper(value: $durationSeconds, in: 0...59) {
                        Text(localizedFormat("sec_duration_stepper_format", durationSeconds))
                    }
                    
                    TextField("note_technique_setup_error_to_avoid", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        addBookmark()
                    } label: {
                        Label("add_bookmark", systemImage: "bookmark.fill")
                    }
                    .disabled(!canAdd)
                }
            }
            .navigationTitle("marcadores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onSave {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("save") {
                            onSave()
                            dismiss()
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("listo_2") { dismiss() }
                    }
                }
            }
        }
    }

    private var canAdd: Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return (url.scheme == "https" || url.scheme == "http") && url.host != nil
    }

    private func addBookmark() {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = URL(string: trimmedURL)?.host ?? localizedString("other_label")
        let totalDuration = durationMinutes * 60 + durationSeconds
        bookmarks.append(
            ExerciseMediaBookmark(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackTitle : title.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                urlString: trimmedURL,
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

    private func sourceTitle(_ source: ExerciseMediaBookmark.Source) -> String {
        switch source {
        case .youtube: "YouTube"
        case .youtubeShorts: "YouTube Shorts"
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .other: localizedString("other_label")
        }
    }

    private func icon(for source: ExerciseMediaBookmark.Source) -> String {
        switch source {
        case .youtube, .youtubeShorts: "play.rectangle.fill"
        case .tiktok: "music.note.tv"
        case .instagram: "camera.fill"
        case .other: "link"
        }
    }
}

private struct ExerciseBookmarkEditor: View {
    @Environment(AppStore.self) private var store
    let exercise: Exercise
    @State private var bookmarks: [ExerciseMediaBookmark]

    init(exercise: Exercise) {
        self.exercise = exercise
        _bookmarks = State(initialValue: exercise.mediaBookmarks)
    }

    var body: some View {
        ExerciseMediaBookmarkEditor(bookmarks: $bookmarks) {
            var updated = exercise
            updated.mediaBookmarks = bookmarks
            store.updateExercise(updated)
        }
    }
}

struct AddCustomExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let existingExercise: Exercise?

    @State private var name: String
    @State private var muscleGroup: String
    @State private var equipment: String
    @State private var trackingType: Exercise.TrackingType
    @State private var mediaURL: String
    @State private var instructions: String
    @State private var notes: String
    @State private var customImageData: Data?
    @State private var customVideoData: Data?
    @State private var customVideoThumbnailData: Data?
    @State private var selectedMediaItems: [PhotosPickerItem] = []
    @State private var customMedia: [ExerciseCustomMedia]
    @State private var mediaBookmarks: [ExerciseMediaBookmark]
    @State private var showOnlineLinks = false

    private var isEditing: Bool { existingExercise != nil }

    init(existingExercise: Exercise? = nil) {
        self.existingExercise = existingExercise
        _name = State(initialValue: existingExercise?.name ?? "")
        _muscleGroup = State(initialValue: existingExercise?.muscleGroup ?? "Chest")
        _equipment = State(initialValue: existingExercise?.equipment ?? "Dumbbells")
        _trackingType = State(initialValue: existingExercise?.trackingType ?? .weightReps)
        _mediaURL = State(initialValue: existingExercise?.mediaURL ?? "")
        _instructions = State(initialValue: existingExercise?.instructions ?? "")
        _notes = State(initialValue: existingExercise?.notes ?? "")
        _customImageData = State(initialValue: existingExercise?.customImageData)
        _customVideoData = State(initialValue: existingExercise?.customVideoData)
        _customVideoThumbnailData = State(initialValue: existingExercise?.customVideoThumbnailData)
        _mediaBookmarks = State(initialValue: existingExercise?.mediaBookmarks ?? [])
        var initialCustomMedia = existingExercise?.customMedia ?? []
        // Upgrade a legacy single photo/video in memory the first time it is
        // edited, so attaching another item never discards the original guide.
        if initialCustomMedia.isEmpty, let imageData = existingExercise?.customImageData {
            initialCustomMedia.append(ExerciseCustomMedia(kind: .image, data: imageData))
        }
        if initialCustomMedia.isEmpty || !initialCustomMedia.contains(where: { $0.kind == .video }),
           let videoData = existingExercise?.customVideoData {
            initialCustomMedia.append(ExerciseCustomMedia(
                kind: .video,
                data: videoData,
                thumbnailData: existingExercise?.customVideoThumbnailData
            ))
        }
        _customMedia = State(initialValue: initialCustomMedia)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("exercise_2") {
                    TextField("name_2", text: $name)
                    TextField("muscle_group_2", text: $muscleGroup)
                    TextField("equipment_2", text: $equipment)
                }

                Section("registro") {
                    Picker("training_type", selection: $trackingType) {
                        Text("weight_reps").tag(Exercise.TrackingType.weightReps)
                        Text("reps_4").tag(Exercise.TrackingType.repsOnly)
                        Text("duration_3").tag(Exercise.TrackingType.duration)
                    }
                }

                Section("imagen_y_guia") {
                    if customMedia.isEmpty {
                        if let customImageData, let image = UIImage(data: customImageData) {
                            ExerciseMediaPreviewRow(image: Image(uiImage: image), label: "own_photo") {
                                self.customImageData = nil
                            }
                        }
                        if let customVideoData, ExerciseVisualResolver.hasValidCustomVideo(customVideoData) {
                            ExerciseMediaPreviewRow(
                                image: customVideoThumbnailData.flatMap(UIImage.init(data:)).map(Image.init(uiImage:)),
                                systemImage: "video.fill",
                                label: "own_video"
                            ) {
                                self.customVideoData = nil
                                self.customVideoThumbnailData = nil
                            }
                        }
                    } else {
                        ForEach(customMedia) { media in
                            ExerciseMediaPreviewRow(
                                image: previewImage(for: media),
                                systemImage: media.kind == .video ? "video.fill" : "photo",
                                label: media.kind == .video ? "own_video" : "own_photo"
                            ) {
                                removeCustomMedia(media)
                            }
                        }
                    }

                    MediaSourceMenu(
                        maxSelectionCount: 10,
                        photoPickerItems: $selectedMediaItems,
                        matching: .any(of: [.images, .videos]),
                        onCameraCapture: { image in
                            if let data = image.jpegData(compressionQuality: 0.8) {
                                customMedia.append(ExerciseCustomMedia(kind: .image, data: data))
                                synchronizeLegacyCustomMedia()
                            }
                        },
                        onVideoCapture: { data, thumbnail in
                            customMedia.append(ExerciseCustomMedia(
                                kind: .video,
                                data: data,
                                thumbnailData: thumbnail?.jpegData(compressionQuality: 0.7)
                            ))
                            synchronizeLegacyCustomMedia()
                        }
                    ) {
                        Label("attach_photo_or_video", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedMediaItems) { _, items in
                        guard !items.isEmpty else { return }
                        Task { await importMedia(items) }
                    }

                    TextField("image_or_video_url", text: $mediaURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Button {
                        showOnlineLinks = true
                    } label: {
                        Label(
                            localizedFormat("bookmarks_count_format", mediaBookmarks.count),
                            systemImage: "link.badge.plus"
                        )
                    }
                    TextField("instructions", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("notes_2", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isEditing ? localizedString("edit") : localizedString("own_exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        var updated = existingExercise ?? Exercise(name: name, muscleGroup: muscleGroup, equipment: equipment)
                        updated.name = name
                        updated.muscleGroup = muscleGroup
                        updated.equipment = equipment
                        updated.trackingType = trackingType
                        updated.mediaURL = mediaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : mediaURL
                        updated.customImageData = customImageData
                        updated.customVideoData = customVideoData
                        updated.customVideoThumbnailData = customVideoThumbnailData
                        updated.customMedia = customMedia
                        updated.mediaBookmarks = mediaBookmarks
                        updated.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions
                        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                        if isEditing {
                            store.updateExercise(updated)
                        } else {
                            store.addExercise(updated)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showOnlineLinks) {
            ExerciseMediaBookmarkEditor(bookmarks: $mediaBookmarks)
        }
    }

    private func previewImage(for media: ExerciseCustomMedia) -> Image? {
        let data = media.kind == .video ? media.thumbnailData : media.data
        return data.flatMap(UIImage.init(data:)).map(Image.init(uiImage:))
    }

    private func removeCustomMedia(_ media: ExerciseCustomMedia) {
        customMedia.removeAll { $0.id == media.id }
        synchronizeLegacyCustomMedia()
    }

    private func importMedia(_ items: [PhotosPickerItem]) async {
        var imported: [ExerciseCustomMedia] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else { continue }
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                let temporaryURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("reps-custom-exercise-\(UUID().uuidString).mov")
                try? data.write(to: temporaryURL)
                let thumbnail = await VideoThumbnail.generate(from: temporaryURL)
                try? FileManager.default.removeItem(at: temporaryURL)
                imported.append(ExerciseCustomMedia(
                    kind: .video,
                    data: data,
                    thumbnailData: thumbnail?.jpegData(compressionQuality: 0.7)
                ))
            } else if UIImage(data: data) != nil {
                imported.append(ExerciseCustomMedia(kind: .image, data: data))
            }
        }

        guard !imported.isEmpty else {
            selectedMediaItems = []
            return
        }
        customMedia.append(contentsOf: imported)
        synchronizeLegacyCustomMedia()
        selectedMediaItems = []
    }

    private func synchronizeLegacyCustomMedia() {
        if let image = customMedia.first(where: { $0.kind == .image }) {
            customImageData = image.data
        } else {
            customImageData = nil
        }
        if let video = customMedia.first(where: { $0.kind == .video }) {
            customVideoData = video.data
            customVideoThumbnailData = video.thumbnailData
        } else {
            customVideoData = nil
            customVideoThumbnailData = nil
        }
    }
}

private struct ExerciseMediaPreviewRow: View {
    var image: Image?
    var systemImage: String = "photo"
    let label: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: systemImage)
                        .foregroundStyle(PulseTheme.accent)
                }
            }
            .frame(width: 44, height: 44)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipped()

            Text(localizedString(label))
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
        }
    }
}

private struct SecondaryMuscleEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let onSave: ([String: Double]) -> Void

    @State private var weights: [String: Double]

    init(exercise: Exercise, onSave: @escaping ([String: Double]) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        var initial: [String: Double] = [:]
        for muscle in exercise.secondaryMuscles {
            initial[muscle] = exercise.secondaryInvolvement(muscle)
        }
        _weights = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    Text(localizedString("set_how_much_each_secondary_muscle_counts_toward_volume_and_weekly_sets_per_musc"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                        PulseCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(ExerciseTextLocalizer.muscle(muscle, language: store.userProfile.preferredLanguage))
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(((weights[muscle] ?? Exercise.defaultSecondaryInvolvement) * 100).rounded()))%")
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(PulseTheme.ringStand)
                                }
                                Slider(
                                    value: Binding(
                                        get: { weights[muscle] ?? Exercise.defaultSecondaryInvolvement },
                                        set: { weights[muscle] = $0 }
                                    ),
                                    in: 0...1,
                                    step: 0.05
                                )
                                .tint(PulseTheme.ringStand)
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 20)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle(localizedString("secondary_muscles"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("save")) {
                        onSave(weights)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
