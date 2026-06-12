import MuscleMap
import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var store: AppStore
    let workout: WorkoutDay
    
    @State private var selectedWorkout: WorkoutDay
    @Namespace private var animation

    init(workout: WorkoutDay) {
        self.workout = workout
        self._selectedWorkout = State(initialValue: workout)
    }

    private var totalTargetSets: Int {
        selectedWorkout.exercises.reduce(0) { $0 + $1.targetSets }
    }

    private var equipmentSummary: [String] {
        Array(Set(selectedWorkout.exercises.map(\.exercise.equipment))).sorted().prefix(5).map { RepsText.equipment($0, language: store.userProfile.preferredLanguage) }
    }

    private var parentPlan: WorkoutPlan? {
        if store.activePlan.days.contains(where: { $0.id == workout.id }) {
            return store.activePlan
        }
        return store.plans.first { plan in
            plan.days.contains(where: { $0.id == workout.id })
        }
    }

    private var progressionRecommendations: [SmartProgressionAdvisor.Recommendation] {
        SmartProgressionAdvisor.recommendations(
            for: selectedWorkout,
            sessions: store.workoutSessions,
            weightIncrementKg: store.userProfile.weightIncrementKg,
            limit: 4
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                heroCard
                exerciseListCard
                ProgressionRecommendationCard(
                    recommendations: progressionRecommendations,
                    language: store.userProfile.preferredLanguage,
                    title: store.userProfile.preferredLanguage.hasPrefix("es") ? "Plan de progresión" : "Progression Plan"
                )
                
                let adjustWord = store.userProfile.preferredLanguage.hasPrefix("es")
                    ? "El entrenamiento se adaptará según tu rendimiento."
                    : "The workout will adjust based on your performance."
                Text(adjustWord)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                preparationCard
            }
            .padding(20)
            .safeAreaPadding(.top, 8)
            .padding(.bottom, 96)
        }
        .screenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
        .onChange(of: workout) { _, newWorkout in
            selectedWorkout = newWorkout
        }
        .safeAreaInset(edge: .bottom) {
            let startWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "Iniciar entrenamiento" : "Start Workout"
            NavigationLink {
                ActiveWorkoutView(workout: selectedWorkout)
            } label: {
                Label(startWord, systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(.black)
                    .background(PulseTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(20)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [PulseTheme.background.opacity(0), PulseTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let plan = parentPlan {
                Text(plan.name.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PulseTheme.primaryBright)
                    .tracking(1.5)
            }
            dayStrip
        }
    }

    private var dayStrip: some View {
        let days = parentPlan?.days ?? [workout]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { day in
                    let isSelected = day.id == selectedWorkout.id
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedWorkout = day
                        }
                    } label: {
                        Text(RepsText.workoutTitle(day.title, language: store.userProfile.preferredLanguage))
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(isSelected ? .black : PulseTheme.secondaryText)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(.white)
                                        .matchedGeometryEffect(id: "activeDayTab", in: animation)
                                } else {
                                    Capsule()
                                        .fill(PulseTheme.grouped.opacity(0.6))
                                }
                            }
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? .clear : PulseTheme.separator.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private var heroCard: some View {
        let isSpanish = store.userProfile.preferredLanguage.hasPrefix("es")
        let todayWord = isSpanish ? "Entrenamiento de hoy" : "Today's Workout"
        let exercisesWord = isSpanish ? "ejercicios" : "exercises"
        let minutesWord = isSpanish ? "minutos" : "minutes"
        
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Header badge
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PulseTheme.primaryBright)
                    Text(isSpanish ? "ACTIVO" : "ACTIVE")
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(PulseTheme.primaryBright)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PulseTheme.primaryBright.opacity(0.12), in: Capsule())
                
                Text(todayWord)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                // Stat capsules
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 11))
                            .foregroundStyle(PulseTheme.primary)
                        Text("\(selectedWorkout.exercises.count) \(exercisesWord)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04), in: Capsule())
                    
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                            .foregroundStyle(PulseTheme.accent)
                        Text("\(selectedWorkout.durationMinutes) \(minutesWord)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04), in: Capsule())
                }
                .foregroundStyle(.white)
                
                // Equipment scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(equipmentSummary, id: \.self) { equipment in
                            HStack(spacing: 4) {
                                Image(systemName: RepsText.equipmentIcon(equipment))
                                    .font(.system(size: 9))
                                    .foregroundStyle(PulseTheme.primaryBright)
                                Text(equipment)
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.04), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                            .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }
            }

            WorkoutMusclePreview(exercises: selectedWorkout.exercises.map(\.exercise), gender: store.userProfile.muscleMapGender)
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                .shadow(color: PulseTheme.primaryBright.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    PulseTheme.card,
                    Color(red: 0.10, green: 0.12, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            PulseTheme.primaryBright.opacity(0.12),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }

    private var preparationCard: some View {
        let prepWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "Preparación" : "Preparation"
        let photoWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "Fotos de sesión" : "Session Photos"
        let notesWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "Notas" : "Notes"
        let audioWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "Audio/Dictado" : "Audio/Dictation"
        
        return PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(prepWord, systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(equipmentSummary, id: \.self) { equipment in
                            Label(equipment, systemImage: RepsText.equipmentIcon(equipment))
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(PulseTheme.grouped)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }

                HStack(spacing: 10) {
                    Label(photoWord, systemImage: "camera.fill")
                    Label(notesWord, systemImage: "note.text")
                    Label(audioWord, systemImage: "mic.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
    }

    private var exerciseListCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(selectedWorkout.exercises.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        ExerciseProgressView(exercise: item.exercise)
                    } label: {
                        WorkoutExercisePreviewRow(
                            index: index + 1,
                            item: item,
                            gender: store.userProfile.muscleMapGender,
                            language: store.userProfile.preferredLanguage
                        )
                    }
                    .buttonStyle(.plain)

                    if item.id != selectedWorkout.exercises.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var averageRest: Int {
        guard !selectedWorkout.exercises.isEmpty else { return 90 }
        return selectedWorkout.exercises.reduce(0) { $0 + $1.restSeconds } / selectedWorkout.exercises.count
    }
}

private struct WorkoutExercisePreviewRow: View {
    let index: Int
    let item: WorkoutExercise
    let gender: BodyGender
    let language: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ExerciseMediaThumbnail(exercise: item.exercise, gender: gender)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text("\(index). \(RepsText.exerciseName(item.exercise.name, language: language))")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                let setsOfWord = language.hasPrefix("es") ? "series de" : "sets of"
                Text("\(item.targetSets) \(setsOfWord) \(item.repRange)")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.callout.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(width: 24, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }
}

private struct WorkoutMusclePreview: View {
    let exercises: [Exercise]
    let gender: BodyGender

    @State private var selectedSide: BodySide = .front

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                bodyLayer(side: .back, in: proxy.size)
                bodyLayer(side: .front, in: proxy.size)

                HStack(spacing: 0) {
                    sideTapZone(.front)
                    sideTapZone(.back)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    PulseTheme.grouped.opacity(0.86),
                    Color.white.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.primaryBright.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel("Resumen muscular del entrenamiento")
    }

    private func bodyLayer(side: BodySide, in size: CGSize) -> some View {
        let isSelected = selectedSide == side
        return BodyView(gender: gender, side: side, style: .repsDark)
            .heatmap(heatmap, configuration: .repsVolume)
            .frame(width: size.width * 0.66, height: size.height * 1.05)
            .allowsHitTesting(false)
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .opacity(isSelected ? 1 : 0.62)
            .saturation(isSelected ? 1.08 : 0.72)
            .brightness(isSelected ? 0 : -0.10)
            .shadow(color: selectedTint.opacity(isSelected ? 0.28 : 0.05), radius: isSelected ? 20 : 8, x: 0, y: 10)
        .offset(
            x: side == .front ? -size.width * 0.16 : size.width * 0.16,
            y: isSelected ? -4 : 12
        )
        .zIndex(isSelected ? 2 : 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: selectedSide)
        .accessibilityLabel(sideLabel(side))
    }

    private func sideTapZone(_ side: BodySide) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    selectedSide = side
                }
            }
            .accessibilityLabel(sideLabel(side))
            .accessibilityAddTraits(.isButton)
    }

    private var heatmap: [MuscleIntensity] {
        let descriptors = exercises.map(ExerciseAnatomyDescriptor.init(exercise:))
        var scores: [Muscle: Double] = [:]
        for descriptor in descriptors {
            for muscle in descriptor.primaryMuscles {
                scores[muscle, default: 0] += 1
            }
            for muscle in descriptor.secondaryMuscles {
                scores[muscle, default: 0] += 0.35
            }
        }
        let maxScore = max(scores.values.max() ?? 1, 1)

        return scores.map { muscle, score in
            let load = score / maxScore
            return MuscleIntensity(muscle: muscle, intensity: 0.42 + (load * 0.58))
        }
    }

    private var selectedTint: Color {
        let maxLoad = heatmap.map(\.intensity).max() ?? 0.72
        if maxLoad > 0.86 {
            return PulseTheme.accent
        }
        if maxLoad > 0.64 {
            return PulseTheme.primaryBright
        }
        return PulseTheme.primary
    }

    private func sideLabel(_ side: BodySide) -> String {
        side == .front ? "FRONT" : "BACK"
    }
}

private struct WorkoutStatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ExerciseImageStack: View {
    let exercises: [Exercise]
    var gender: BodyGender = .male

    var body: some View {
        ZStack {
            ForEach(Array(exercises.prefix(3).enumerated()), id: \.element.id) { offset, exercise in
                ExerciseMediaThumbnail(exercise: exercise, gender: gender)
                    .frame(width: 96, height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white, lineWidth: 3)
                    )
                    .rotationEffect(.degrees(Double(offset - 1) * 8))
                    .offset(x: CGFloat(offset - 1) * 22, y: CGFloat(offset) * 4)
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ExerciseChip: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(PulseTheme.grouped)
            .clipShape(Capsule())
    }
}

// Centralized mapping helpers are now located in RepsText (PulseTheme.swift)
