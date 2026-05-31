import PhotosUI
import MuscleMap
import SwiftUI
import Charts

struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var searchText = ""
    @State private var selectedMuscle = "All"
    @State private var selectedEquipment = "All"
    @State private var selectedType: Exercise.ExerciseType?
    @State private var selectedDifficulty: Exercise.Difficulty?
    @State private var selectedEnvironment: Exercise.Environment?
    @State private var selectedCategory = ExerciseLibraryCategory.all
    @State private var onlyAvailableEquipment = false
    @State private var showAddCustom = false

    private var muscles: [String] {
        ["All"] + Array(Set(store.exercises.map(\.muscleGroup))).sorted()
    }

    private var equipmentOptions: [String] {
        ["All"] + Array(Set(store.exercises.map(\.equipment))).sorted()
    }

    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
    }

    private var filteredExercises: [Exercise] {
        store.exercises.filter { exercise in
            let searchableText = [
                exercise.name,
                exercise.aliases.joined(separator: " "),
                exercise.muscleGroup,
                exercise.equipment,
                exercise.requiredEquipment.joined(separator: " "),
                exercise.tags.joined(separator: " "),
                exercise.instructions ?? "",
                exercise.notes ?? ""
            ].joined(separator: " ")
            let matchesSearch = searchText.isEmpty || searchableText.localizedStandardContains(searchText)
            let matchesMuscle = selectedMuscle == "All" || exercise.muscleGroup == selectedMuscle
            let matchesEquipment = selectedEquipment == "All" || exercise.equipment == selectedEquipment
            let matchesType = selectedType == nil || exercise.exerciseType == selectedType
            let matchesDifficulty = selectedDifficulty == nil || exercise.difficulty == selectedDifficulty
            let matchesEnvironment = selectedEnvironment == nil || exercise.environment == selectedEnvironment || exercise.environment == .both
            let matchesCategory = selectedCategory.matches(exercise)
            let matchesAvailableEquipment = !onlyAvailableEquipment || availableEquipmentMatches(exercise)
            return matchesSearch
                && matchesMuscle
                && matchesEquipment
                && matchesType
                && matchesDifficulty
                && matchesEnvironment
                && matchesCategory
                && matchesAvailableEquipment
        }
    }

    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises, by: \.muscleGroup)
        return grouped.keys.sorted().map { ($0, grouped[$0, default: []].sorted { $0.name < $1.name }) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ExerciseLibraryCategory.allCases) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Label(category.title, systemImage: category.systemImage)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .foregroundStyle(selectedCategory == category ? .white : PulseTheme.primary)
                                        .background(selectedCategory == category ? PulseTheme.primary : PulseTheme.primary.opacity(0.10))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Picker(ui(en: "Training type", es: "Tipo"), selection: $selectedType) {
                        Text(ui(en: "All", es: "Todo")).tag(Optional<Exercise.ExerciseType>.none)
                        ForEach(Exercise.ExerciseType.allCases) { type in
                            Text(type.localizedTitle).tag(Optional(type))
                        }
                    }
                    .pickerStyle(.segmented)

                    FilterMenuRow(title: ui(en: "Muscle group", es: "Grupo muscular"), value: displayName(forMuscle: selectedMuscle)) {
                        ForEach(muscles, id: \.self) { muscle in
                            Button(displayName(forMuscle: muscle)) {
                                selectedMuscle = muscle
                            }
                        }
                    }

                    FilterMenuRow(title: ui(en: "Equipment", es: "Equipamiento"), value: displayName(forEquipment: selectedEquipment)) {
                        ForEach(equipmentOptions, id: \.self) { equipment in
                            Button(displayName(forEquipment: equipment)) {
                                selectedEquipment = equipment
                            }
                        }
                    }

                    FilterMenuRow(title: ui(en: "Environment", es: "Entorno"), value: environmentFilterTitle) {
                        Button(ui(en: "Any environment", es: "Cualquier entorno")) {
                            selectedEnvironment = nil
                        }
                        ForEach(Exercise.Environment.allCases) { environment in
                            Button(environment.localizedString(language: store.userProfile.preferredLanguage)) {
                                selectedEnvironment = environment
                            }
                        }
                    }

                    FilterMenuRow(title: ui(en: "Difficulty", es: "Dificultad"), value: difficultyFilterTitle) {
                        Button(ui(en: "Any difficulty", es: "Cualquier dificultad")) {
                            selectedDifficulty = nil
                        }
                        ForEach(Exercise.Difficulty.allCases) { difficulty in
                            Button(difficulty.localizedString(language: store.userProfile.preferredLanguage)) {
                                selectedDifficulty = difficulty
                            }
                        }
                    }

                    Toggle(ui(en: "Only my equipment", es: "Solo mi equipamiento"), isOn: $onlyAvailableEquipment)
                }

                if filteredExercises.isEmpty {
                    Section {
                        PulseEmptyState(
                            title: isSpanish ? "No hay ejercicios" : "No exercises found",
                            message: isSpanish ? "Prueba a quitar filtros o busca por músculo, equipo o nombre." : "Try removing a filter or searching by muscle, equipment, or exercise name.",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }
                } else {
                    ForEach(groupedExercises, id: \.0) { group, exercises in
                        Section(displayName(forMuscle: group)) {
                            ForEach(exercises) { exercise in
                                NavigationLink {
                                    ExerciseDetailView(exercise: exercise)
                                } label: {
                                    ExerciseLibraryRow(
                                        exercise: exercise,
                                        language: store.userProfile.preferredLanguage,
                                        gender: store.userProfile.muscleMapGender
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text(ui(en: "Search exercises", es: "Buscar ejercicios")))
            .navigationTitle(ui(en: "Exercise Library", es: "Biblioteca de ejercicios"))
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                if store.isSyncingExerciseLibrary {
                    RepsLoadingView(
                        messages: [
                            ui(en: "Updating exercise library...", es: "Actualizando biblioteca de ejercicios..."),
                            ui(en: "Completing media and instructions...", es: "Completando medios e instrucciones..."),
                            ui(en: "Keeping your catalog ready...", es: "Preparando tu catálogo...")
                        ],
                        progress: nil,
                        layout: .compact,
                        showsPercentage: false
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                } else if let message = store.exerciseLibrarySyncMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(ui(en: "Close", es: "Cerrar")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCustom = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseView()
            }
        }
        .mainTabBarHidden()
    }

    private func availableEquipmentMatches(_ exercise: Exercise) -> Bool {
        let equipment = Set(store.userProfile.availableEquipment.map(normalizedEquipment))
        guard !equipment.isEmpty else {
            return true
        }

        let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
        let normalizedRequired = Set(required.map(normalizedEquipment))
        return normalizedRequired.contains("bodyweight")
            || normalizedRequired.contains("body only")
            || !normalizedRequired.isDisjoint(with: equipment)
            || equipment.contains(normalizedEquipment(exercise.equipment))
    }

    private func normalizedEquipment(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private func displayName(forMuscle muscle: String) -> String {
        guard muscle != "All" else {
            return store.userProfile.preferredLanguage.hasPrefix("es") ? "Todo" : "All"
        }
        return ExerciseTextLocalizer.muscle(muscle, language: store.userProfile.preferredLanguage)
    }

    private func displayName(forEquipment equipment: String) -> String {
        guard equipment != "All" else {
            return store.userProfile.preferredLanguage.hasPrefix("es") ? "Todo" : "All"
        }
        return ExerciseTextLocalizer.equipment(equipment, language: store.userProfile.preferredLanguage)
    }

    private var environmentFilterTitle: String {
        selectedEnvironment?.localizedString(language: store.userProfile.preferredLanguage) ?? (store.userProfile.preferredLanguage.hasPrefix("es") ? "Cualquier entorno" : "Any environment")
    }

    private var difficultyFilterTitle: String {
        selectedDifficulty?.localizedString(language: store.userProfile.preferredLanguage) ?? (store.userProfile.preferredLanguage.hasPrefix("es") ? "Cualquier dificultad" : "Any difficulty")
    }

    private func ui(en: String, es: String) -> String {
        isSpanish ? es : en
    }
}

private enum ExerciseLibraryCategory: String, CaseIterable, Identifiable {
    case all
    case home
    case gym
    case bodyweight
    case freeWeights
    case machines
    case cardio

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .home: "Home"
        case .gym: "Gym"
        case .bodyweight: "Bodyweight"
        case .freeWeights: "Free weights"
        case .machines: "Machines"
        case .cardio: "Cardio"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
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
    static func muscle(_ value: String, language: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        guard language.hasPrefix("es") else {
            return canonicalMuscle(value)
        }

        return switch value.normalizedExerciseFilterValue {
        case "arms": "Brazos"
        case "back": "Espalda"
        case "cardio": "Cardio"
        case "chest": "Pecho"
        case "core", "abdominals": "Core"
        case "full body": "Cuerpo completo"
        case "glutes": "Glúteos"
        case "legs": "Piernas"
        case "neck": "Cuello"
        case "shoulders": "Hombros"
        default: value
        }
    }

    static func equipment(_ value: String, language: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        guard language.hasPrefix("es") else {
            return canonicalEquipment(value)
        }

        return switch value.normalizedExerciseFilterValue {
        case "barbell": "Barra"
        case "body only", "bodyweight": "Peso corporal"
        case "cable": "Polea"
        case "cardio machine": "Máquina de cardio"
        case "dumbbell", "dumbbells": "Mancuernas"
        case "kettlebell", "kettlebells": "Kettlebells"
        case "machine", "machines": "Máquina"
        case "other": "Otro"
        case "resistance band": "Banda elástica"
        default: value
        }
    }

    private static func canonicalMuscle(_ value: String) -> String {
        switch value.normalizedExerciseFilterValue {
        case "abdominals": "Core"
        default: value
        }
    }

    private static func canonicalEquipment(_ value: String) -> String {
        switch value.normalizedExerciseFilterValue {
        case "body only": "Bodyweight"
        case "dumbbell": "Dumbbells"
        case "kettlebell": "Kettlebells"
        default: value
        }
    }
}

private extension Exercise.ExerciseType {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .strength: "Strength"
        case .cardio: "Cardio"
        case .mobility: "Mobility"
        case .stretching: "Stretching"
        case .hiit: "HIIT"
        }
    }
}

private extension Exercise.Difficulty {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .low: "Beginner"
        case .medium: "Intermediate"
        case .high: "Advanced"
        }
    }

    func localizedString(language: String) -> String {
        guard language.hasPrefix("es") else {
            return switch self {
            case .low: "Beginner"
            case .medium: "Intermediate"
            case .high: "Advanced"
            }
        }

        return switch self {
        case .low: "Principiante"
        case .medium: "Intermedio"
        case .high: "Avanzado"
        }
    }
}

private extension Exercise.Environment {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .gym: "Gym"
        case .both: "Home and gym"
        }
    }

    func localizedString(language: String) -> String {
        guard language.hasPrefix("es") else {
            return switch self {
            case .home: "Home"
            case .gym: "Gym"
            case .both: "Home and gym"
            }
        }

        return switch self {
        case .home: "Casa"
        case .gym: "Gimnasio"
        case .both: "Casa y gimnasio"
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

    var body: some View {
        HStack(spacing: 16) {
            ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: 72)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name).font(.headline)
                    .lineLimit(2)
                Text("\(ExerciseTextLocalizer.muscle(exercise.muscleGroup, language: language)) · \(ExerciseTextLocalizer.equipment(exercise.equipment, language: language))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !exercise.secondaryMuscles.isEmpty {
                    Text(exercise.secondaryMuscles.map { ExerciseTextLocalizer.muscle($0, language: language) }.joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
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
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(PulseTheme.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.primary)
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
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(PulseTheme.primary)
            .background(PulseTheme.primary.opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct ExerciseActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(PulseTheme.primary)
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
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(PulseTheme.primary)
                .clipShape(Circle())
            Text(text)
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
    @EnvironmentObject private var store: AppStore
    let exercise: Exercise
    
    @State private var selectedTab: ExerciseTab = .instructions
    @State private var showAddToPlan = false
    @State private var showSchedule = false
    @State private var feedbackMessage: String?
    @State private var customImageItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPermissionDenied = false
    @State private var showBookmarkEditor = false

    // History and progress state
    @State private var metric = ProgressMetric.weight
    @State private var selectedHistoryRange = ExerciseHistoryRange.sixMonths

    private enum ExerciseTab: String, CaseIterable, Identifiable {
        case instructions = "Instrucciones"
        case info = "Información"
        case history = "Historial"
        var id: String { rawValue }
        
        func localizedTitle(isSpanish: Bool) -> String {
            switch self {
            case .instructions: return isSpanish ? "Instrucciones" : "Instructions"
            case .info: return isSpanish ? "Información" : "Info"
            case .history: return isSpanish ? "Historial" : "History"
            }
        }
    }

    private enum ProgressMetric: String, CaseIterable, Identifiable {
        case weight = "Peso"
        case reps = "Reps"
        case volume = "Volumen"
        case oneRepMax = "1RM"
        case sets = "Series"
        var id: String { rawValue }
        
        func localizedTitle(isSpanish: Bool) -> String {
            guard isSpanish else {
                switch self {
                case .weight: return "Weight"
                case .reps: return "Reps"
                case .volume: return "Volume"
                case .oneRepMax: return "1RM"
                case .sets: return "Sets"
                }
            }
            return rawValue
        }
    }

    private enum ExerciseHistoryRange: String, CaseIterable, Identifiable {
        case week = "1S"
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "12M"
        case max = "MAX"
        var id: String { rawValue }

        var startDate: Date {
            let calendar = Calendar.current
            switch self {
            case .week: return calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
            case .month: return calendar.date(byAdding: .month, value: -1, to: .now) ?? .distantPast
            case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: .now) ?? .distantPast
            case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: .now) ?? .distantPast
            case .year: return calendar.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
            case .max: return .distantPast
            }
        }
    }

    private var currentExercise: Exercise {
        store.exercises.first(where: { $0.id == exercise.id }) ?? exercise
    }

    private var instructionSteps: [String] {
        ExerciseInstructionParser.steps(from: currentExercise.instructions)
    }

    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
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
        guard isSpanish else {
            switch fatigueScore {
            case 1: return "Low fatigue: stable or local movement, easy to recover from."
            case 2: return "Moderate fatigue: requires technical control but generally manageable."
            case 3: return "High fatigue: multi-joint or high loads, manage volume carefully."
            default: return "Very high fatigue: compound unstable movement with heavy stabilizer demands."
            }
        }
        switch fatigueScore {
        case 1: return "Baja fatiga: movimiento local o estable, fácil de recuperar."
        case 2: return "Fatiga moderada: requiere control técnico pero suele ser recuperable."
        case 3: return "Alta fatiga: varias articulaciones o cargas altas, conviene gestionar volumen."
        default: return "Fatiga muy alta: compuesto inestable con varios grupos musculares y alta demanda de estabilización."
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
                                Text(tab.localizedTitle(isSpanish: isSpanish))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(selectedTab == tab ? PulseTheme.primaryBright : PulseTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                
                                Rectangle()
                                    .fill(selectedTab == tab ? PulseTheme.primaryBright : Color.clear)
                                    .frame(height: 3.5)
                                    .cornerRadius(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .background(PulseTheme.card)
                
                Divider()
                    .overlay(Color.white.opacity(0.08))
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .instructions:
                        instructionsTabContent
                    case .info:
                        infoTabContent
                    case .history:
                        historyTabContent
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .screenBackground()
        .navigationTitle(ui(en: "Exercise", es: "Ejercicio"))
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
        .sheet(isPresented: $showAddToPlan) {
            AddExerciseToPlanView(exercise: currentExercise) {
                feedbackMessage = String(localized: "Exercise added to the active plan.")
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showSchedule) {
            ScheduleExerciseView(exercise: currentExercise) {
                feedbackMessage = String(localized: "Exercise scheduled.")
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showBookmarkEditor) {
            ExerciseBookmarkEditor(exercise: currentExercise)
                .environmentObject(store)
        }
        .onChange(of: customImageItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                var updated = currentExercise
                updated.customImageData = data
                store.updateExercise(updated)
                customImageItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    var updated = currentExercise
                    updated.customImageData = data
                    store.updateExercise(updated)
                }
            }
            .ignoresSafeArea()
        }
        .alert("Permiso denegado", isPresented: $showPermissionDenied) {
            Button("Abrir Ajustes") {
                PermissionService.shared.openSettings()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(PermissionService.shared.deniedMessage ?? "El acceso a la cámara está bloqueado. Actívalo en Ajustes.")
        }
    }

    // --- TAB CONTENTS ---

    private var instructionsTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ExerciseHeroMedia(exercise: currentExercise)

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(currentExercise.name)
                        .font(.largeTitle.bold())
                        .lineLimit(3)
                        .minimumScaleFactor(0.74)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(ExerciseTextLocalizer.muscle(currentExercise.muscleGroup, language: store.userProfile.preferredLanguage)) · \(ExerciseTextLocalizer.equipment(currentExercise.equipment, language: store.userProfile.preferredLanguage))")
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    ExerciseMetadataChips(exercise: currentExercise)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(ui(en: "Use this exercise", es: "Usar este ejercicio")).font(.headline)
                    Label(trackingLabel, systemImage: "chart.bar.fill")
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button {
                            showAddToPlan = true
                        } label: {
                            ExerciseActionButton(title: ui(en: "Add to plan", es: "Añadir a plan"), systemImage: "plus.rectangle.on.rectangle")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSchedule = true
                        } label: {
                            ExerciseActionButton(title: ui(en: "Schedule", es: "Programar"), systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.plain)
                    }
                    if let feedbackMessage {
                        Text(feedbackMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personalización").font(.headline)
                    HStack(spacing: 10) {
                        Menu {
                            if CameraPicker.isAvailable {
                                Button {
                                    Task {
                                        let granted = await PermissionService.shared.requestCamera()
                                        if granted {
                                            showCamera = true
                                        } else {
                                            showPermissionDenied = true
                                        }
                                    }
                                } label: {
                                    Label("Tomar foto", systemImage: "camera.fill")
                                }
                            } else {
                                #if targetEnvironment(simulator)
                                Button {
                                    if let image = UIImage(systemName: "figure.strengthtraining.traditional") {
                                        if let data = image.jpegData(compressionQuality: 0.8) {
                                            var updated = currentExercise
                                            updated.customImageData = data
                                            store.updateExercise(updated)
                                        }
                                        HapticService.notification(.success)
                                    }
                                } label: {
                                    Label("Simular foto", systemImage: "camera.badge.ellipsis")
                                }
                                #endif
                            }

                            PhotosPicker(selection: $customImageItem, matching: .images) {
                                Label("Elegir de galería", systemImage: "photo.on.rectangle")
                            }

                            if currentExercise.customImageData != nil {
                                Button(role: .destructive) {
                                    var updated = currentExercise
                                    updated.customImageData = nil
                                    store.updateExercise(updated)
                                } label: {
                                    Label("Eliminar foto propia", systemImage: "trash")
                                }
                            }
                        } label: {
                            Label("Cambiar imagen", systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.primary)
                                .background(PulseTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }

                        Button {
                            showBookmarkEditor = true
                        } label: {
                            Label("Marcadores", systemImage: "bookmark.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.primary)
                                .background(PulseTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                    }

                    if currentExercise.customImageData != nil {
                        Label("Imagen propia guardada offline", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(ui(en: "Instructions", es: "Instrucciones")).font(.headline)
                    if instructionSteps.isEmpty {
                        Text(ui(en: "This exercise does not include detailed instructions yet.", es: "Este ejercicio todavía no incluye instrucciones detalladas."))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(Array(instructionSteps.enumerated()), id: \.offset) { index, step in
                            InstructionStepRow(index: index + 1, text: step)
                        }
                    }
                    if !currentExercise.commonMistakes.isEmpty {
                        Divider()
                        Text(ui(en: "Avoid", es: "Evita")).font(.headline)
                        ForEach(currentExercise.commonMistakes, id: \.self) { mistake in
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
                    Text(ui(en: "Reference", es: "Referencia")).font(.headline)
                    if let notes = currentExercise.notes, !notes.isEmpty {
                        Text(notes)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let mediaURL = currentExercise.mediaURL, !mediaURL.isEmpty {
                        Divider()
                        Label(ui(en: "Execution reference image", es: "Imagen de referencia"), systemImage: "photo")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.primary)
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
                        Text("Marcadores multimedia").font(.headline)
                        ForEach(currentExercise.mediaBookmarks) { bookmark in
                            Link(destination: URL(string: bookmark.urlString) ?? URL(string: "https://www.youtube.com")!) {
                                HStack {
                                    Image(systemName: bookmark.source == .instagram ? "camera.fill" : "play.rectangle.fill")
                                        .foregroundStyle(PulseTheme.primary)
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
            Text(ui(en: "Anatomy Map", es: "Mapa Anatómico"))
                .font(.title3.bold())
            
            ExerciseMuscleInfoPanel(exercise: currentExercise, gender: store.userProfile.muscleMapGender)
            
            Text(ui(en: "Muscles Worked", es: "Músculos Trabajados"))
                .font(.headline)
            
            PulseCard {
                VStack(spacing: 0) {
                    ExerciseMuscleTargetRow(
                        title: localizedMuscle(currentExercise.muscleGroup),
                        subtitle: isSpanish ? "1 serie de trabajo directo" : "1 direct work set",
                        exercise: currentExercise,
                        gender: store.userProfile.muscleMapGender
                    )
                    if !currentExercise.secondaryMuscles.isEmpty {
                        Divider()
                        ForEach(currentExercise.secondaryMuscles, id: \.self) { muscle in
                            ExerciseMuscleTargetRow(
                                title: localizedMuscle(muscle),
                                subtitle: isSpanish ? "0,35 series indirectas" : "0.35 indirect work set",
                                exercise: currentExercise,
                                gender: store.userProfile.muscleMapGender
                            )
                            if muscle != currentExercise.secondaryMuscles.last {
                                Divider()
                            }
                        }
                    }
                }
            }
            
            ResistanceCurveCard(profile: ResistanceCurveProfile(exercise: currentExercise))
            
            FatigueRatingCard(score: fatigueScore, description: fatigueDescription)
        }
    }

    private var historyTabContent: some View {
        VStack(spacing: 20) {
            if rangedPoints.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: isSpanish ? "Ejercicio todavía no realizado" : "Exercise not performed yet",
                        message: isSpanish ? "Cuando completes series de este ejercicio aparecerán aquí sus tendencias de peso, volumen, repeticiones y 1RM." : "Once you log sets for this exercise, your performance trends will appear here.",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
            } else {
                HStack(spacing: 14) {
                    MetricCard(title: isSpanish ? "Mejor peso" : "Best weight", value: String(format: "%.0f", rangedPoints.map(\.maxWeightKg).max() ?? 0), subtitle: "kg", systemImage: "scalemass", badgeColor: PulseTheme.primary)
                    MetricCard(title: isSpanish ? "1RM estimada" : "Estimated 1RM", value: String(format: "%.0f", rangedPoints.map(\.estimatedOneRepMaxKg).max() ?? 0), subtitle: "kg", systemImage: "bolt", badgeColor: PulseTheme.accent)
                }

                HStack(spacing: 14) {
                    MetricCard(title: isSpanish ? "Sobrecarga" : "Overload", value: String(format: "%.1f", FitnessMetrics.progressiveOverloadDelta(for: rangedPoints)), subtitle: isSpanish ? "cambio 1RM" : "1RM delta", systemImage: "arrow.up.right", badgeColor: PulseTheme.warning)
                    MetricCard(title: isSpanish ? "Volumen medio" : "Avg Volume", value: "\(Int(FitnessMetrics.averageVolumeKg(for: rangedPoints)))", subtitle: "kg/sesión", systemImage: "chart.bar", badgeColor: PulseTheme.primaryBright)
                }

                Picker("Rango", selection: $selectedHistoryRange) {
                    ForEach(ExerciseHistoryRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Métrica", selection: $metric) {
                    ForEach(ProgressMetric.allCases) { metric in
                        Text(metric.localizedTitle(isSpanish: isSpanish)).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                PulseCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(isSpanish ? "Actividad" : "Activity").font(.headline)
                        Chart(rangedPoints) { point in
                            LineMark(
                                x: .value("Fecha", point.date),
                                y: .value(metric.localizedTitle(isSpanish: isSpanish), value(for: point))
                            )
                            .foregroundStyle(PulseTheme.primary)
                            PointMark(
                                x: .value("Fecha", point.date),
                                y: .value(metric.localizedTitle(isSpanish: isSpanish), value(for: point))
                            )
                            .foregroundStyle(PulseTheme.accent)
                        }
                        .frame(height: 220)
                    }
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isSpanish ? "Sesiones recientes" : "Recent sessions").font(.headline)
                        ForEach(rangedPoints.reversed()) { point in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(point.workoutTitle).font(.headline)
                                    Text(point.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(value(for: point))) \(metric.localizedTitle(isSpanish: isSpanish))")
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
        let spanish = store.userProfile.preferredLanguage.hasPrefix("es")
        return switch currentExercise.trackingType {
        case .weightReps: spanish ? "Peso y repeticiones" : "Weight and reps"
        case .repsOnly: spanish ? "Solo repeticiones" : "Reps only"
        case .duration: spanish ? "Duración" : "Duration"
        }
    }

    private func ui(en: String, es: String) -> String {
        isSpanish ? es : en
    }

    private func value(for point: FitnessMetrics.ExerciseProgressPoint) -> Double {
        switch metric {
        case .weight:
            return point.maxWeightKg
        case .reps:
            return Double(point.maxReps)
        case .volume:
            return point.totalVolumeKg
        case .oneRepMax:
            return point.estimatedOneRepMaxKg
        case .sets:
            return Double(point.completedSets)
        }
    }

    private func localizedMuscle(_ value: String) -> String {
        guard store.userProfile.preferredLanguage.hasPrefix("es") else { return value }
        return switch value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased() {
        case "arms": "Brazos"
        case "back": "Espalda"
        case "cardio": "Cardio"
        case "chest": "Pecho"
        case "core", "abdominals": "Core"
        case "full body": "Cuerpo completo"
        case "glutes": "Glúteos"
        case "legs": "Piernas"
        case "neck": "Cuello"
        case "shoulders": "Hombros"
        default: value
        }
    }
}

private struct ExerciseThumbnail: View {
    let exercise: Exercise
    let size: CGFloat
    var gender: BodyGender = .male

    var body: some View {
        ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: size)
    }
}

struct ExerciseHeroMedia: View {
    let exercise: Exercise
    var height: CGFloat = 320

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                if let data = exercise.customImageData,
                   let image = UIImage(data: data) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .blur(radius: 18, opaque: true)
                            .opacity(0.45)
                            .clipped()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .clipped()
                    }
                } else if let url = exercise.mediaAssetURL {
                    ExerciseReferenceImage(url: url, size: size)
                } else {
                    fallback
                        .frame(width: size.width, height: size.height)
                }

                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: size.width, height: size.height)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Referencia visual")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.78))
                    Text(exercise.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: max(size.width - 32, 0), alignment: .leading)
                }
                .padding(16)
            }
            .frame(width: size.width, height: size.height)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityLabel("Imagen grande de referencia de \(exercise.name)")
    }

    private var fallback: some View {
        ZStack {
            PulseTheme.primary.opacity(0.10)
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 48, weight: .bold))
                Text("Sin imagen offline")
                    .font(.headline)
                Text("Sincroniza la biblioteca abierta para cargar referencias visuales.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .foregroundStyle(PulseTheme.primary)
        }
    }
}

struct ExerciseReferenceImage: View {
    let url: URL
    let size: CGSize

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                ZStack {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .blur(radius: 18, opaque: true)
                        .saturation(0.88)
                        .opacity(0.48)
                        .clipped()

                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height, alignment: .center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .clipped()
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            case .failure:
                ExerciseHeroFallback()
                    .frame(width: size.width, height: size.height)
            case .empty:
                ProgressView()
                    .tint(PulseTheme.primary)
                    .frame(width: size.width, height: size.height)
            @unknown default:
                ExerciseHeroFallback()
                    .frame(width: size.width, height: size.height)
            }
        }
    }
}

private struct ExerciseHeroFallback: View {
    var body: some View {
        ZStack {
            PulseTheme.primary.opacity(0.10)
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 48, weight: .bold))
                Text("Sin imagen offline")
                    .font(.headline)
                Text("Sincroniza la biblioteca abierta para cargar referencias visuales.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .foregroundStyle(PulseTheme.primary)
        }
    }
}

private struct AddExerciseToPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

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
                Section("Exercise") {
                    Text(exercise.name)
                    Text("\(ExerciseTextLocalizer.muscle(exercise.muscleGroup, language: store.userProfile.preferredLanguage)) · \(ExerciseTextLocalizer.equipment(exercise.equipment, language: store.userProfile.preferredLanguage))")
                        .foregroundStyle(.secondary)
                }

                Section("Active plan") {
                    Picker("Workout day", selection: $selectedDayID) {
                        ForEach(store.activePlan.days) { day in
                            Text(day.title).tag(Optional(day.id))
                        }
                    }
                    Stepper("\(targetSets) sets", value: $targetSets, in: 1...10)
                    TextField("Rep range", text: $repRange)
                }
            }
            .navigationTitle("Add to plan")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedDayID = selectedDayID ?? store.activePlan.days.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
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
    @EnvironmentObject private var store: AppStore

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
                Section("Exercise") {
                    Text(exercise.name)
                    Text("\(ExerciseTextLocalizer.muscle(exercise.muscleGroup, language: store.userProfile.preferredLanguage)) · \(ExerciseTextLocalizer.equipment(exercise.equipment, language: store.userProfile.preferredLanguage))")
                        .foregroundStyle(.secondary)
                }

                Section("Schedule") {
                    DatePicker("Training day", selection: $date, displayedComponents: [.date])
                    Stepper("\(targetSets) sets", value: $targetSets, in: 1...10)
                    TextField("Rep range", text: $repRange)
                }
            }
            .navigationTitle("Schedule exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
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

private struct ExerciseBookmarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let exercise: Exercise

    @State private var bookmarks: [ExerciseMediaBookmark]
    @State private var title = ""
    @State private var source: ExerciseMediaBookmark.Source = .youtube
    @State private var urlString = ""
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var durationMinutes = 0
    @State private var durationSeconds = 0
    @State private var note = ""

    init(exercise: Exercise) {
        self.exercise = exercise
        _bookmarks = State(initialValue: exercise.mediaBookmarks)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Marcadores guardados") {
                    if bookmarks.isEmpty {
                        Text("Añade referencias de YouTube, Shorts, TikTok o Instagram para enriquecer tu biblioteca offline.")
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
                                    Text("Marcador \(timestamp / 60):\(String(format: "%02d", timestamp % 60))")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.primary)
                                }
                                if let duration = bookmark.playbackDurationSeconds {
                                    Text("Duración \(duration / 60)m \(duration % 60)s")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                }

                Section("Nuevo marcador") {
                    TextField("Título rápido", text: $title)
                    Picker("Fuente", selection: $source) {
                        ForEach(ExerciseMediaBookmark.Source.allCases) { source in
                            Text(sourceTitle(source)).tag(source)
                        }
                    }
                    TextField("URL del video o post", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Text("Punto de inicio en video")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper("Min \(minutes)", value: $minutes, in: 0...240)
                    Stepper("Seg \(seconds)", value: $seconds, in: 0...59)
                    
                    Text("Duración de reproducción")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper("Min Duración \(durationMinutes)", value: $durationMinutes, in: 0...60)
                    Stepper("Seg Duración \(durationSeconds)", value: $durationSeconds, in: 0...59)
                    
                    TextField("Nota: técnica, setup, error a evitar...", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        addBookmark()
                    } label: {
                        Label("Añadir marcador", systemImage: "bookmark.fill")
                    }
                    .disabled(!canAdd)
                }
            }
            .navigationTitle("Marcadores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        var updated = exercise
                        updated.mediaBookmarks = bookmarks
                        store.updateExercise(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func addBookmark() {
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

    private func sourceTitle(_ source: ExerciseMediaBookmark.Source) -> String {
        switch source {
        case .youtube: "YouTube"
        case .youtubeShorts: "YouTube Shorts"
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .other: "Otro"
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

struct AddCustomExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var name = ""
    @State private var muscleGroup = "Chest"
    @State private var equipment = "Dumbbells"
    @State private var trackingType: Exercise.TrackingType = .weightReps
    @State private var mediaURL = ""
    @State private var instructions = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Ejercicio") {
                    TextField("Nombre", text: $name)
                    TextField("Grupo muscular", text: $muscleGroup)
                    TextField("Equipamiento", text: $equipment)
                }

                Section("Registro") {
                    Picker("Tipo", selection: $trackingType) {
                        Text("Peso + reps").tag(Exercise.TrackingType.weightReps)
                        Text("Reps").tag(Exercise.TrackingType.repsOnly)
                        Text("Duracion").tag(Exercise.TrackingType.duration)
                    }
                }

                Section("Imagen y guia") {
                    TextField("URL de imagen o video", text: $mediaURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Instrucciones", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Ejercicio propio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        store.addExercise(
                            Exercise(
                                name: name,
                                muscleGroup: muscleGroup,
                                equipment: equipment,
                                trackingType: trackingType,
                                mediaURL: mediaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : mediaURL,
                                instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
