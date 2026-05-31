import SwiftUI

struct WatchWorkoutView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        NavigationStack {
            TabView {
                workoutPage
                controlsPage
                gymAndMusicPage
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle(model.snapshot.hasActiveWorkout ? "Reps Live" : "Reps")
        }
    }

    private var workoutPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                headerCard
                exerciseCard
                metricsGrid
            }
            .padding(.horizontal, 4)
        }
    }

    private var controlsPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button {
                    WatchCommandRouter.send(WatchCommand.completeSet.rawValue)
                } label: {
                    Label("Serie hecha", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!model.snapshot.hasActiveWorkout)

                HStack(spacing: 8) {
                    commandButton(.previousExercise, icon: "chevron.backward", tint: .blue)
                    commandButton(model.snapshot.isPaused ? .resume : .pause, icon: model.snapshot.isPaused ? "play.fill" : "pause.fill", tint: model.snapshot.isPaused ? .green : .orange)
                    commandButton(.nextExercise, icon: "chevron.forward", tint: .blue)
                }

                HStack(spacing: 8) {
                    commandButton(.addWater, icon: "waterbottle.fill", tint: .cyan)
                    commandButton(.voiceNote, icon: model.snapshot.hasActiveWorkout ? "mic.fill" : "mic.slash", tint: .red)
                    commandButton(.stop, icon: "stop.fill", tint: .red)
                }

                if let history = model.snapshot.exerciseHistorySummary {
                    WatchInfoCard(icon: "clock.arrow.circlepath", title: "Histórico", value: history, color: .green)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var gymAndMusicPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let title = model.snapshot.musicTitle {
                    WatchInfoCard(
                        icon: model.snapshot.isMusicPlaying == true ? "music.note" : "music.note.list",
                        title: "Música",
                        value: model.snapshot.musicArtist.map { "\(title)\n\($0)" } ?? title,
                        color: .pink
                    )
                    HStack(spacing: 8) {
                        musicButton(.musicPrevious, icon: "backward.fill")
                        musicButton(.musicToggle, icon: "playpause.fill")
                        musicButton(.musicNext, icon: "forward.fill")
                    }
                }

                if let gymName = model.snapshot.gymPassName {
                    WatchInfoCard(
                        icon: model.snapshot.gymCodeType == "barcode" ? "barcode" : "qrcode",
                        title: gymName,
                        value: model.snapshot.gymMembershipID ?? model.snapshot.gymCodeValue ?? "Tarjeta gym",
                        color: .yellow
                    )
                    if let code = model.snapshot.gymCodeValue {
                        Text(code)
                            .font(.caption2.monospaced())
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                WatchInfoCard(icon: "iphone.and.arrow.forward", title: "Sync", value: syncText, color: .green)
            }
            .padding(.horizontal, 4)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.snapshot.planTitle ?? "Plan")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                    Text(model.snapshot.hasActiveWorkout ? model.snapshot.workoutTitle : "Sin sesión activa")
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: model.snapshot.isPaused ? "pause.circle.fill" : "figure.strengthtraining.traditional")
                    .foregroundStyle(model.snapshot.isPaused ? .orange : .green)
            }

            Gauge(value: model.snapshot.progress) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int(model.snapshot.progress * 100))%")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.green)

            HStack {
                Label(model.elapsedSeconds > 0 ? elapsedText : model.snapshot.elapsedText, systemImage: "timer")
                Spacer()
                Label(model.snapshot.remainingText, systemImage: "hourglass")
            }
            .font(.caption2.weight(.semibold))
        }
        .watchCard()
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(exercisePositionText, systemImage: "dumbbell.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
                Spacer()
                Text("\(model.snapshot.currentExerciseCompletedSets ?? 0)/\(model.snapshot.currentExerciseTotalSets ?? 0)")
                    .font(.caption.monospacedDigit().weight(.bold))
            }
            Text(model.snapshot.exerciseName ?? "Esperando ejercicio")
                .font(.headline)
                .lineLimit(2)
            HStack {
                Label(currentSetText, systemImage: "scalemass")
                Spacer()
                Label(model.snapshot.restText, systemImage: "timer.circle")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            if let next = model.snapshot.nextExerciseName, model.snapshot.hasActiveWorkout {
                Text("Siguiente: \(next)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .watchCard()
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            WatchMetric(title: "Volumen", value: "\(model.snapshot.volumeKg)", unit: "kg", icon: "chart.bar.fill", color: .green)
            WatchMetric(title: "Agua", value: String(format: "%.2f", model.snapshot.waterLiters ?? 0), unit: "L", icon: "waterbottle.fill", color: .cyan)
            WatchMetric(title: "Kcal", value: "\(Int(model.snapshot.activeEnergyKcal ?? model.activeEnergy))", unit: "act.", icon: "flame.fill", color: .orange)
            WatchMetric(title: "Pulso", value: model.heartRate.map { "\(Int($0))" } ?? model.snapshot.heartRate.map { "\(Int($0))" } ?? "--", unit: "lpm", icon: "heart.fill", color: .red)
        }
    }

    private var exercisePositionText: String {
        guard let index = model.snapshot.exerciseIndex, let total = model.snapshot.totalExercises else {
            return "Ejercicio"
        }
        return "Ejercicio \(index)/\(total)"
    }

    private var currentSetText: String {
        let weight = model.snapshot.currentSetWeightKg.map { "\(Int($0)) kg" } ?? "--"
        let reps = model.snapshot.currentSetReps.map { "\($0) reps" } ?? "--"
        return "\(weight) x \(reps)"
    }

    private var elapsedText: String {
        SharedWorkoutSnapshot.durationText(model.elapsedSeconds)
    }

    private var syncText: String {
        model.snapshot.hasActiveWorkout ? "Tiempo real u offline\n\(model.snapshot.updatedAt.formatted(date: .omitted, time: .shortened))" : model.snapshot.summary
    }

    private func commandButton(_ command: WatchCommand, icon: String, tint: Color) -> some View {
        Button {
            WatchCommandRouter.send(command.rawValue)
        } label: {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!model.snapshot.hasActiveWorkout && command != .resume)
    }

    private func musicButton(_ command: WatchCommand, icon: String) -> some View {
        Button {
            WatchCommandRouter.send(command.rawValue)
        } label: {
            Image(systemName: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

private struct WatchMetric: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(title) · \(unit)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()
    }
}

private struct WatchInfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text(value)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
        }
        .watchCard()
    }
}

private extension View {
    func watchCard() -> some View {
        self
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
