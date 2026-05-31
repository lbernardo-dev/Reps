import MuscleMap
import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var store: AppStore
    let workout: WorkoutDay

    private var totalTargetSets: Int {
        workout.exercises.reduce(0) { $0 + $1.targetSets }
    }

    private var equipmentSummary: [String] {
        Array(Set(workout.exercises.map(\.exercise.equipment))).sorted().prefix(5).map { RepsText.equipment($0, language: store.userProfile.preferredLanguage) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                dayStrip
                heroCard
                exerciseListCard
                Text("The workout will adjust based on your performance.")
                    .font(.headline)
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
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                ActiveWorkoutView(workout: workout)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(.black)
                    .background(.white)
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

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                Text(RepsText.workoutTitle(workout.title, language: store.userProfile.preferredLanguage))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                let otherDays = store.userProfile.preferredLanguage.hasPrefix("es")
                    ? ["Día 2", "Día 3", "Día 4"]
                    : ["Day 2", "Day 3", "Day 4"]
                ForEach(otherDays, id: \.self) { title in
                    Text(title)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var heroCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Workout")
                    .font(.title2.weight(.bold))
                HStack(spacing: 18) {
                    let exercisesWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "ejercicios" : "exercises"
                    Label("\(workout.exercises.count) \(exercisesWord)", systemImage: "figure.strengthtraining.traditional")
                    let minutesWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "minutos" : "minutes"
                    Label("\(workout.durationMinutes) \(minutesWord)", systemImage: "timer")
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)

                HStack(spacing: 8) {
                    ForEach(equipmentSummary.prefix(3), id: \.self) { equipment in
                        Text(equipment)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(PulseTheme.grouped, in: Capsule())
                    }
                }
            }

            Spacer(minLength: 8)

            WorkoutMusclePreview(exercises: workout.exercises.map(\.exercise), gender: store.userProfile.muscleMapGender)
                .frame(width: 120, height: 120)
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            WorkoutStatTile(title: "Exercises", value: "\(workout.exercises.count)", icon: "list.bullet.rectangle")
            WorkoutStatTile(title: "Sets", value: "\(totalTargetSets)", icon: "checklist")
            WorkoutStatTile(title: "Rest", value: "\(averageRest)s", icon: "hourglass")
        }
    }

    private var preparationCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Preparation", systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(equipmentSummary, id: \.self) { equipment in
                            Label(equipment, systemImage: RepsText.equipmentIcon(equipment))
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(PulseTheme.grouped)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }

                HStack(spacing: 10) {
                    Label("Session Photos", systemImage: "camera.fill")
                    Label("Notes", systemImage: "note.text")
                    Label("Audio/Dictation", systemImage: "mic.fill")
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
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, item in
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

                    if item.id != workout.exercises.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var averageRest: Int {
        guard !workout.exercises.isEmpty else { return 90 }
        return workout.exercises.reduce(0) { $0 + $1.restSeconds } / workout.exercises.count
    }
}

private struct WorkoutExercisePreviewRow: View {
    let index: Int
    let item: WorkoutExercise
    let gender: BodyGender
    let language: String

    var body: some View {
        HStack(spacing: 12) {
            ExerciseMediaThumbnail(exercise: item.exercise, gender: gender)
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

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

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

private struct WorkoutMusclePreview: View {
    let exercises: [Exercise]
    let gender: BodyGender

    private var muscles: [Muscle] {
        Array(Set(exercises.flatMap { ExerciseAnatomyDescriptor(exercise: $0).muscles }))
    }

    var body: some View {
        HStack(spacing: 4) {
            BodyView(gender: gender, side: .front, style: .repsDark)
                .heatmap(heatmap, configuration: .repsVolume)
            BodyView(gender: gender, side: .back, style: .repsDark)
                .heatmap(heatmap, configuration: .repsVolume)
        }
        .padding(8)
        .background(PulseTheme.grouped.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityLabel("Resumen muscular del entrenamiento")
    }

    private var heatmap: [MuscleIntensity] {
        muscles.map { MuscleIntensity(muscle: $0, intensity: 0.72) }
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
