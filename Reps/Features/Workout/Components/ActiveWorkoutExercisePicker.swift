import AVFoundation
import Combine
import CoreImage
import CoreMotion
import WebKit
import CoreLocation
import MapKit
import MediaPlayer
import MuscleMap
import MusicKit
import PhotosUI
import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let title: String
    let exercises: [Exercise]
    let currentExercise: Exercise?
    let onSelect: (Exercise) -> Void

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

    private var equipmentOptions: [String] {
        ["Todos"] + Array(Set(exercises.map(\.equipment))).sorted()
    }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises.filter { exercise in
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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let currentExercise {
                        replacementHeader(for: currentExercise)
                    }

                    HStack(spacing: 10) {
                        Picker("muscle", selection: $selectedMuscle) {
                            ForEach(muscles, id: \.self) { muscle in
                                Text(muscle == "Todos" ? muscle : RepsText.muscle(muscle, language: store.userProfile.preferredLanguage)).tag(muscle)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("equipo", selection: $selectedEquipment) {
                            ForEach(equipmentOptions, id: \.self) { equipment in
                                Text(equipment == "Todos" ? equipment : RepsText.equipment(equipment, language: store.userProfile.preferredLanguage)).tag(equipment)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .font(.subheadline.weight(.semibold))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("training_type", selection: $selectedType) {
                                Text("all").tag(Optional<Exercise.ExerciseType>.none)
                                ForEach(Exercise.ExerciseType.allCases) { type in
                                    Text(type.localizedTitle).tag(Optional(type))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("difficulty_2", selection: $selectedDifficulty) {
                                Text("any").tag(Optional<Exercise.Difficulty>.none)
                                ForEach(Exercise.Difficulty.allCases) { difficulty in
                                    Text(difficulty.localizedTitle).tag(Optional(difficulty))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("environment_2", selection: $selectedEnvironment) {
                                Text("any").tag(Optional<Exercise.Environment>.none)
                                ForEach(Exercise.Environment.allCases) { environment in
                                    Text(environment.localizedTitle).tag(Optional(environment))
                                }
                            }
                            .pickerStyle(.menu)

                            Toggle("mi_equipo", isOn: $onlyAvailableEquipment)
                                .toggleStyle(.button)
                        }
                    }
                    .font(.subheadline.weight(.semibold))

                    if filteredExercises.isEmpty {
                        PulseEmptyState(
                            title: "Sin ejercicios",
                            message: "Ajusta la búsqueda o los filtros de músculo y equipo para ver más resultados.",
                            systemImage: "magnifyingglass"
                        )
                        .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredExercises) { exercise in
                                Button {
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    ReplacementExerciseRow(
                                        exercise: exercise,
                                        currentExercise: currentExercise,
                                        availableEquipment: store.userProfile.availableEquipment,
                                        gender: store.userProfile.muscleMapGender,
                                        language: store.userProfile.preferredLanguage,
                                        catalog: store.exercises
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 16)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .searchable(text: $searchText, prompt: "Buscar por nombre, músculo o equipo")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") {
                        dismiss()
                    }
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

    private func replacementHeader(for exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            Text("actual")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(PulseTheme.grouped, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)

            ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                        .stroke(PulseTheme.separator, lineWidth: 1)
                )

            VStack(spacing: 4) {
                Text(RepsText.exerciseName(exercise.name, language: store.userProfile.preferredLanguage))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(RepsText.muscle(exercise.muscleGroup, language: store.userProfile.preferredLanguage))
                    .font(.headline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Text("mejores_sustituciones")
                .font(.title3.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }
}

private extension Exercise.ExerciseType {
    var localizedTitle: String {
        switch self {
        case .strength: localizedString("Strength")
        case .cardio: "Cardio"
        case .mobility: localizedString("Mobility")
        case .stretching: localizedString("Stretching")
        case .hiit: "HIIT"
        }
    }
}

private extension Exercise.Difficulty {
    var localizedTitle: String {
        switch self {
        case .low: localizedString("Beginner")
        case .medium: localizedString("Intermediate")
        case .high: localizedString("Advanced")
        }
    }
}

private extension Exercise.Environment {
    var localizedTitle: String {
        switch self {
        case .home: localizedString("Home")
        case .gym: localizedString("Gym")
        case .both: localizedString("Home and gym")
        }
    }
}


struct ReplacementExerciseRow: View {
    let exercise: Exercise
    let currentExercise: Exercise?
    let availableEquipment: [String]
    let gender: BodyGender
    let language: String
    let catalog: [Exercise]

    var body: some View {
        HStack(spacing: 14) {
            ExerciseMediaThumbnail(exercise: exercise, gender: gender, catalog: catalog)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(RepsText.exerciseName(exercise.name, language: language))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(RepsText.equipment(exercise.equipment, language: language))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                if !exercise.requiredEquipment.isEmpty {
                    Text(exercise.requiredEquipment.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(PulseTheme.accent)
                        .lineLimit(1)
                }
                if let reasonText {
                    Label(reasonText, systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.recovery)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let badgeText {
                Text(badgeText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(badgeColor.opacity(0.14), in: Capsule())
                    .lineLimit(1)
            }

            Image(systemName: currentExercise == nil ? "plus.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(currentExercise == nil ? PulseTheme.accent : PulseTheme.secondaryText)
        }
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }

    private var badgeText: String? {
        guard let currentExercise else { return nil }
        if normalized(exercise.equipment) == normalized(currentExercise.equipment) {
            return "Mismo equipo"
        }
        if exercise.trackingType == currentExercise.trackingType {
            return "Esencial"
        }
        return nil
    }

    private var badgeColor: Color {
        guard let currentExercise else { return PulseTheme.ringStand }
        // "Essential" (same tracking model) reads as the strongest match → growth green.
        if normalized(exercise.equipment) != normalized(currentExercise.equipment),
           exercise.trackingType == currentExercise.trackingType {
            return PulseTheme.growth
        }
        return PulseTheme.ringStand
    }

    private var reasonText: String? {
        guard let currentExercise else { return nil }
        let reasons = ExerciseSubstitutionService.matchReasons(
            for: exercise,
            replacing: currentExercise,
            availableEquipment: availableEquipment
        )
        return reasons.isEmpty ? nil : reasons.joined(separator: " · ")
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

