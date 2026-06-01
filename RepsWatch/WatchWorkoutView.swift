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
            VStack(spacing: 12) {
                Button {
                    WatchCommandRouter.send(WatchCommand.completeSet.rawValue)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Serie hecha")
                            .font(.system(.headline, design: .rounded).bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        model.snapshot.hasActiveWorkout ?
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.68, blue: 0.37), Color(red: 0.18, green: 0.8, blue: 0.44)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(model.snapshot.hasActiveWorkout ? .white : .white.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(model.snapshot.hasActiveWorkout ? Color.green.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: model.snapshot.hasActiveWorkout ? Color.green.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(!model.snapshot.hasActiveWorkout)
                .opacity(model.snapshot.hasActiveWorkout ? 1.0 : 0.4)

                HStack(spacing: 12) {
                    commandButton(.previousExercise, icon: "chevron.backward", tint: .blue)
                    commandButton(model.snapshot.isPaused ? .resume : .pause, icon: model.snapshot.isPaused ? "play.fill" : "pause.fill", tint: model.snapshot.isPaused ? .green : .orange)
                    commandButton(.nextExercise, icon: "chevron.forward", tint: .blue)
                }
                .padding(.vertical, 4)

                HStack(spacing: 12) {
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
                    HStack(spacing: 12) {
                        musicButton(.musicPrevious, icon: "backward.fill")
                        musicButton(.musicToggle, icon: "playpause.fill")
                        musicButton(.musicNext, icon: "forward.fill")
                    }
                    .padding(.bottom, 6)
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
                            .background(.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }

                WatchInfoCard(icon: "iphone.and.arrow.forward", title: "Sincronización", value: syncText, color: .green)
            }
            .padding(.horizontal, 4)
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.snapshot.planTitle?.uppercased() ?? "PLAN DE ENTRENAMIENTO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.33, green: 0.86, blue: 0.32), .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
                
                Text(model.snapshot.hasActiveWorkout ? model.snapshot.workoutTitle : "Sin sesión activa")
                    .font(.system(.body, design: .rounded).bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                HStack(spacing: 8) {
                    Label(model.elapsedSeconds > 0 ? elapsedText : model.snapshot.elapsedText, systemImage: "timer")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(model.snapshot.remainingText, systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            
            Spacer()
            
            if model.snapshot.hasActiveWorkout {
                GlassProgressCircle(progress: model.snapshot.progress)
            } else {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.04))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.33, green: 0.86, blue: 0.32))
                }
            }
        }
        .watchCard()
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(exercisePositionText.uppercased(), systemImage: "dumbbell.fill")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.33, green: 0.86, blue: 0.32))
                Spacer()
                if model.snapshot.hasActiveWorkout {
                    Text("\(model.snapshot.currentExerciseCompletedSets ?? 0)/\(model.snapshot.currentExerciseTotalSets ?? 0) series")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(model.snapshot.exerciseName ?? "Esperando ejercicio")
                .font(.system(.body, design: .rounded).bold())
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            
            HStack {
                Label(currentSetText, systemImage: "scalemass")
                Spacer()
                if let rest = model.snapshot.restSeconds, rest > 0 {
                    Label(model.snapshot.restText, systemImage: "timer.circle")
                        .foregroundStyle(.orange)
                } else {
                    Label("Sin descanso", systemImage: "timer.circle")
                }
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            
            if let rest = model.snapshot.restSeconds, rest > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("Descanso: \(model.snapshot.restText)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    Button {
                        WatchCommandRouter.send(WatchCommand.completeSet.rawValue)
                    } label: {
                        Text("Saltar")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            if let next = model.snapshot.nextExerciseName, model.snapshot.hasActiveWorkout {
                Text("Siguiente: \(next)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .watchCard()
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            WatchMetric(title: "Volumen", value: "\(model.snapshot.volumeKg)", unit: "kg", icon: "chart.bar.fill", color: Color(red: 0.33, green: 0.86, blue: 0.32))
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
        let isEnabled = model.snapshot.hasActiveWorkout || command == .resume
        return Button {
            WatchCommandRouter.send(command.rawValue)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(isEnabled ? 0.12 : 0.04))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(tint.opacity(isEnabled ? 0.25 : 0.08), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.35)
    }

    private func musicButton(_ command: WatchCommand, icon: String) -> some View {
        Button {
            WatchCommandRouter.send(command.rawValue)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.pink)
                .frame(width: 44, height: 44)
                .background(Color.pink.opacity(0.1))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.pink.opacity(0.2), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct GlassProgressCircle: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 4.5)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(progress, 1.0))))
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.33, green: 0.86, blue: 0.32), .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .frame(width: 44, height: 44)
    }
}

private struct WatchMetric: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Text("\(title) · \(unit)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard(borderColor: color.opacity(0.16))
    }
}

private struct WatchInfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
            }
            Spacer()
        }
        .watchCard(borderColor: color.opacity(0.12))
    }
}

private extension View {
    func watchCard(borderColor: Color = .white.opacity(0.08)) -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}
