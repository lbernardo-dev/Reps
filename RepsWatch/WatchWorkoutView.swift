import SwiftUI

private enum WatchDestination: Hashable {
    case session
    case controls
    case progress
    case metrics
    case utilities

    var title: String {
        switch self {
        case .session:
            return "Sesión"
        case .controls:
            return "Controles"
        case .progress:
            return "Progreso"
        case .metrics:
            return "Métricas"
        case .utilities:
            return "Extras"
        }
    }
}

struct WatchWorkoutView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        NavigationStack {
            homePage
                .navigationTitle(model.snapshot.hasActiveWorkout ? "Reps Live" : "Reps")
                .navigationDestination(for: WatchDestination.self) { destination in
                    destinationView(for: destination)
                        .navigationTitle(destination.title)
                }
        }
    }

    private var homePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                homeStatusCard
                navigationGrid
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 10)
        }
    }

    private var navigationGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            NavigationLink(value: WatchDestination.session) {
                WatchNavigationTile(title: "Sesión", subtitle: sessionTileSubtitle, icon: "figure.strengthtraining.traditional", color: accentColor)
            }
            .buttonStyle(.plain)

            NavigationLink(value: WatchDestination.controls) {
                WatchNavigationTile(title: "Controles", subtitle: model.snapshot.hasActiveWorkout ? "Acciones rápidas" : "Iniciar ruta", icon: "slider.horizontal.3", color: .orange)
            }
            .buttonStyle(.plain)

            NavigationLink(value: WatchDestination.progress) {
                WatchNavigationTile(title: "Progreso", subtitle: "\(Int(model.snapshot.weeklyCompletion * 100))% semana", icon: "chart.line.uptrend.xyaxis", color: .green)
            }
            .buttonStyle(.plain)

            NavigationLink(value: WatchDestination.metrics) {
                WatchNavigationTile(title: model.snapshot.isRouteWorkout ? "Ruta" : "Timers", subtitle: model.snapshot.isRouteWorkout ? routeDistanceText : liveElapsedText, icon: model.snapshot.isRouteWorkout ? "point.topleft.down.curvedto.point.bottomright.up" : "timer", color: .blue)
            }
            .buttonStyle(.plain)

            NavigationLink(value: WatchDestination.utilities) {
                WatchNavigationTile(title: "Extras", subtitle: utilitiesTileSubtitle, icon: "ellipsis.circle.fill", color: .pink)
            }
            .buttonStyle(.plain)
        }
    }

    private var homeStatusCard: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: model.snapshot.hasActiveWorkout ? "applewatch.radiowaves.left.and.right" : "figure.strengthtraining.traditional")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.snapshot.hasActiveWorkout ? model.snapshot.workoutTitle : "Reps")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(homeStatusText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .watchCard(borderColor: accentColor.opacity(0.12))
    }

    @ViewBuilder
    private func destinationView(for destination: WatchDestination) -> some View {
        switch destination {
        case .session:
            summaryPage
        case .controls:
            controlsPage
        case .progress:
            progressPage
        case .metrics:
            if model.snapshot.isRouteWorkout {
                routePage
            } else {
                timersPage
            }
        case .utilities:
            gymAndMusicPage
        }
    }

    private var summaryPage: some View {
        ScrollView {
            if model.snapshot.hasActiveWorkout {
                VStack(alignment: .leading, spacing: 9) {
                    liveHeroCard
                    evolutionCard
                    if model.snapshot.isRouteWorkout {
                        routeLiveCard
                    } else {
                        exerciseCard
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    liveHeroCard
                    evolutionCard
                    inactiveControlsState
                    WatchInfoCard(icon: "iphone.and.arrow.forward", title: "Sincronización", value: syncText, color: .green)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            }
        }
    }

    private var controlsPage: some View {
        ScrollView {
            if model.snapshot.hasActiveWorkout {
                VStack(spacing: 12) {
                    if model.snapshot.isRouteWorkout {
                        routeControls
                    } else {
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
                                LinearGradient(
                                    colors: [Color(red: 0.15, green: 0.68, blue: 0.37), Color(red: 0.18, green: 0.8, blue: 0.44)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.green.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 12) {
                            commandButton(.previousExercise, icon: "chevron.backward", tint: .blue)
                            commandButton(model.snapshot.isPaused ? .resume : .pause, icon: model.snapshot.isPaused ? "play.fill" : "pause.fill", tint: model.snapshot.isPaused ? .green : .orange)
                            commandButton(.nextExercise, icon: "chevron.forward", tint: .blue)
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            commandButton(.addWater, icon: "waterbottle.fill", tint: .cyan)
                            commandButton(.voiceNote, icon: "mic.fill", tint: .red)
                            commandButton(.stop, icon: "stop.fill", tint: .red)
                        }
                    }

                    if let history = model.snapshot.exerciseHistorySummary {
                        WatchInfoCard(icon: "clock.arrow.circlepath", title: "Histórico", value: history, color: .green)
                    }

                    if let next = model.snapshot.nextExerciseName {
                        WatchInfoCard(icon: "arrow.forward.circle.fill", title: "Siguiente", value: next, color: .blue)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                inactiveControlsState
            }
        }
    }

    private var timersPage: some View {
        ScrollView {
            if model.snapshot.hasActiveWorkout {
                VStack(alignment: .leading, spacing: 9) {
                    timersHeader
                    restTimerCard
                    metricsGrid
                    WatchInfoCard(icon: "arrow.left.arrow.right", title: "Ejercicios", value: exerciseFlowText, color: .blue)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    WatchInfoCard(icon: "timer", title: "Timers", value: "Los cronómetros de sesión, descanso y volumen aparecen al iniciar un entreno.", color: accentColor)
                    metricsGrid
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            }
        }
    }

    private var routePage: some View {
        ScrollView {
            if model.snapshot.hasActiveWorkout {
                VStack(alignment: .leading, spacing: 9) {
                    routeLiveCard
                    routeMetricsGrid
                    if model.snapshot.isOutdoorRoute != false {
                        WatchInfoCard(
                            icon: "map.fill",
                            title: "GPS",
                            value: "\(model.snapshot.routePointCount ?? 0) puntos recibidos del iPhone",
                            color: .blue
                        )
                    } else {
                        WatchInfoCard(
                            icon: "figure.run.treadmill",
                            title: "Cinta",
                            value: "Sin mapa ni puntos GPS",
                            color: .blue
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
            } else {
                inactiveControlsState
            }
        }
    }

    private var progressPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                progressHeroCard

                WatchProgressRow(
                    title: "Sesión",
                    value: sessionProgressValue,
                    detail: sessionProgressDetail,
                    progress: model.snapshot.progress,
                    color: accentColor
                )

                WatchProgressRow(
                    title: "Semana",
                    value: "\(Int(model.snapshot.weeklyCompletion * 100))%",
                    detail: weeklyProgressDetail,
                    progress: model.snapshot.weeklyCompletion,
                    color: .green
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    WatchMetric(title: "Racha", value: "\(model.snapshot.streakDays)", unit: model.snapshot.streakDays == 1 ? "día" : "días", icon: "flame.fill", color: .orange)
                    WatchMetric(title: "Batería", value: "\(model.snapshot.trainingBatteryLevel)", unit: "%", icon: model.snapshot.trainingBatterySystemImage, color: batteryColor)
                    WatchMetric(title: "Volumen", value: "\(model.snapshot.volumeKg)", unit: "kg", icon: "chart.bar.fill", color: accentColor)
                    WatchMetric(title: "Series", value: "\(model.snapshot.completedSets)/\(model.snapshot.totalSets)", unit: "hechas", icon: "checkmark.seal.fill", color: .green)
                }

                if model.snapshot.isRouteWorkout {
                    routeProgressCard
                } else {
                    strengthProgressCard
                }

                if let nextWorkout = model.snapshot.nextWorkoutDayName {
                    WatchInfoCard(
                        icon: "calendar.badge.clock",
                        title: "Próximo entreno",
                        value: model.snapshot.nextWorkoutDayDescription.map { "\(nextWorkout)\n\($0)" } ?? nextWorkout,
                        color: .blue
                    )
                }

                WatchInfoCard(
                    icon: model.snapshot.trainingBatterySystemImage,
                    title: model.snapshot.trainingBatteryTitle,
                    value: model.snapshot.trainingBatterySuggestion.isEmpty ? model.snapshot.summary : model.snapshot.trainingBatterySuggestion,
                    color: batteryColor
                )
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 10)
        }
    }

    private var inactiveControlsState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            VStack(spacing: 5) {
                Text("Sin sesión activa")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Inicia caminata o carrera aquí, o sincroniza un entreno abierto desde el iPhone.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            VStack(spacing: 8) {
                Button {
                    model.startStandaloneRouteWorkout(activity: .walking)
                } label: {
                    Label("Caminata", systemImage: "figure.walk")
                        .font(.system(.headline, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.green)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    model.startStandaloneRouteWorkout(activity: .running)
                } label: {
                    Label("Carrera", systemImage: "figure.run")
                        .font(.system(.headline, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(accentColor.opacity(0.16))
                        .foregroundStyle(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            WatchInfoCard(
                icon: "iphone",
                title: "Sin móvil",
                value: "El reloj guarda la ruta y la vuelca a Reps cuando vuelva a conectar.",
                color: accentColor
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 12)
    }

    private var gymAndMusicPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let history = model.snapshot.exerciseHistorySummary {
                    WatchInfoCard(
                        icon: "clock.arrow.circlepath",
                        title: "Ejercicio anterior",
                        value: history,
                        color: .green
                    )
                }

                if let next = model.snapshot.nextExerciseName {
                    WatchInfoCard(
                        icon: "arrow.forward.circle.fill",
                        title: "Ejercicio siguiente",
                        value: next,
                        color: .blue
                    )
                }

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

    private var progressHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                WatchMiniRing(
                    value: model.snapshot.weeklyCompletion,
                    label: "\(Int(model.snapshot.weeklyCompletion * 100))%",
                    caption: "semana",
                    color: .green
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Progreso")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(progressSummaryText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .watchCard(borderColor: Color.green.opacity(0.18))
    }

    private var strengthProgressCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Fuerza", systemImage: "dumbbell.fill")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                Spacer()
                Text("\(model.snapshot.completedSets)/\(model.snapshot.totalSets)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            WatchProgressRow(
                title: model.snapshot.exerciseName ?? "Ejercicio",
                value: currentExerciseSetValue,
                detail: model.snapshot.nextExerciseName.map { "Siguiente: \($0)" } ?? "Completa series para alimentar tu historial.",
                progress: currentExerciseProgress,
                color: accentColor
            )

            if let history = model.snapshot.exerciseHistorySummary {
                WatchInfoCard(icon: "clock.arrow.circlepath", title: "Histórico", value: history, color: .green)
            }
        }
        .watchCard(borderColor: accentColor.opacity(0.14))
    }

    private var routeProgressCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(model.snapshot.isOutdoorRoute == false ? "Cardio en cinta" : "Cardio exterior", systemImage: model.snapshot.isOutdoorRoute == false ? "figure.run.treadmill" : "map.fill")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                Spacer()
                Text(routePaceText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                WatchMetric(title: "Distancia", value: String(format: "%.2f", routeDistanceKm), unit: "km", icon: "point.topleft.down.curvedto.point.bottomright.up", color: accentColor)
                WatchMetric(title: "Pasos", value: routeSteps.map { "\(Int($0))" } ?? "--", unit: "", icon: "shoeprints.fill", color: .green)
                WatchMetric(title: "Velocidad", value: routeSpeedKmh.map { String(format: "%.1f", $0) } ?? "--", unit: "km/h", icon: "gauge.with.needle", color: .blue)
                WatchMetric(title: "GPS", value: "\(model.snapshot.routePointCount ?? model.routePointCount)", unit: "pts", icon: "location.fill", color: .orange)
            }
        }
        .watchCard(borderColor: accentColor.opacity(0.14))
    }

    private var liveHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                        Text(sessionStateText)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                    }

                    Text(model.snapshot.hasActiveWorkout ? model.snapshot.workoutTitle : "Sin sesión activa")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 4)

                if model.snapshot.hasActiveWorkout {
                    GlassProgressCircle(progress: model.snapshot.progress, color: accentColor)
                } else {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.05))
                            .frame(width: 42, height: 42)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(accentColor)
                    }
                }
            }

            if let planTitle = model.snapshot.planTitle, !planTitle.isEmpty {
                Text(planTitle.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
            }

            ProgressView(value: model.snapshot.progress)
                .progressViewStyle(LinearTintProgressStyle(color: accentColor))

            HStack(spacing: 6) {
                WatchTimePill(title: "Tiempo", value: liveElapsedText, icon: "timer", color: accentColor)
                WatchTimePill(title: "Restante", value: model.snapshot.remainingText, icon: "hourglass", color: .orange)
            }
        }
        .watchCard()
    }

    private var evolutionCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Evolución", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                Spacer()
                Text("\(Int(model.snapshot.weeklyCompletion * 100))% semana")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 10) {
                WatchMiniRing(
                    value: model.snapshot.weeklyCompletion,
                    label: "\(model.snapshot.streakDays)",
                    caption: model.snapshot.streakDays == 1 ? "día" : "días",
                    color: .orange
                )

                VStack(alignment: .leading, spacing: 6) {
                    Label("\(model.snapshot.trainingBatteryLevel)% \(model.snapshot.trainingBatteryTitle)", systemImage: model.snapshot.trainingBatterySystemImage)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(batteryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(model.snapshot.trainingBatterySuggestion.isEmpty ? model.snapshot.summary : model.snapshot.trainingBatterySuggestion)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.86)
                }
            }
        }
        .watchCard(borderColor: accentColor.opacity(0.14))
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(exercisePositionText.uppercased(), systemImage: "dumbbell.fill")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Spacer()
                if model.snapshot.hasActiveWorkout {
                    Text("\(model.snapshot.currentExerciseCompletedSets ?? 0)/\(model.snapshot.currentExerciseTotalSets ?? 0) series")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(model.snapshot.exerciseName ?? "Esperando ejercicio")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            WatchSetRow(value: currentSetText, color: accentColor)
            
            if let rest = model.snapshot.restSeconds, rest > 0 {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Label("Descanso", systemImage: "hourglass")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.orange)
                        Spacer()
                        if let endDate = model.snapshot.restEndDate {
                            Text(endDate, style: .timer)
                                .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        } else {
                            Text(model.snapshot.restText)
                                .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(.orange)
                        }
                    }

                    ProgressView(value: model.snapshot.restProgress)
                        .progressViewStyle(LinearTintProgressStyle(color: .orange))

                    Button {
                        WatchCommandRouter.send(WatchCommand.completeSet.rawValue)
                    } label: {
                        Text("Saltar")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.16))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(9)
                .background(Color.orange.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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

    private var routeLiveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(model.snapshot.isOutdoorRoute == false ? "Cinta en vivo" : "Ruta en vivo", systemImage: model.snapshot.isOutdoorRoute == false ? "figure.run.treadmill" : "figure.walk")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                Spacer()
                Text(model.snapshot.isPaused ? "PAUSA" : (model.snapshot.isOutdoorRoute == false ? "CINTA" : "GPS"))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(model.snapshot.isPaused ? .orange : accentColor)
            }

            Text(routeDistanceText)
                .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 6) {
                WatchTimePill(title: "Tiempo", value: liveElapsedText, icon: "timer", color: accentColor)
                WatchTimePill(title: "Ritmo", value: routePaceText, icon: "speedometer", color: .orange)
            }

            ProgressView(value: routeTimeProgress)
                .progressViewStyle(LinearTintProgressStyle(color: accentColor))

            Text(model.snapshot.isPaused ? pausedRouteHelpText : liveRouteHelpText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .watchCard(borderColor: accentColor.opacity(0.18))
    }

    private var routeControls: some View {
        VStack(spacing: 12) {
            Button {
                model.toggleRoutePause()
            } label: {
                Label(model.snapshot.isPaused ? "Reanudar" : "Pausar", systemImage: model.snapshot.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(model.snapshot.isPaused ? Color.green : Color.orange)
                    .foregroundStyle(model.snapshot.isPaused ? .black : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                commandButton(.addWater, icon: "waterbottle.fill", tint: .cyan)
                commandButton(.voiceNote, icon: "mic.fill", tint: .red)
                Button {
                    model.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 46, height: 46)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.25), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }

            WatchInfoCard(icon: "applewatch", title: "Fuente", value: model.isStandaloneRouteWorkout ? "El reloj registra ruta, pasos, distancia, pulso y kcal; Reps lo importará al reconectar." : "El reloj lee pulso, kcal, pasos y distancia en vivo; el iPhone mantiene la ruta y el mapa.", color: .blue)
        }
    }

    private var timersHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Timers", systemImage: "timer")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                Spacer()
                Text(sessionStateText)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            HStack(spacing: 6) {
                WatchTimePill(title: "Sesión", value: liveElapsedText, icon: "stopwatch.fill", color: accentColor)
                WatchTimePill(title: "Queda", value: model.snapshot.remainingText, icon: "hourglass.bottomhalf.filled", color: .orange)
            }

            HStack(spacing: 6) {
                WatchTimePill(title: "Agua", value: String(format: "%.2f L", model.snapshot.waterLiters ?? 0), icon: "waterbottle.fill", color: .cyan)
                WatchTimePill(title: "Pausa", value: SharedWorkoutSnapshot.durationText(model.snapshot.pausedSeconds), icon: "pause.circle.fill", color: .yellow)
            }
        }
        .watchCard()
    }

    @ViewBuilder
    private var restTimerCard: some View {
        if let rest = model.snapshot.restSeconds, rest > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Descanso activo", systemImage: "hourglass")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(model.snapshot.restText)
                        .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                ProgressView(value: model.snapshot.restProgress)
                    .progressViewStyle(LinearTintProgressStyle(color: .orange))

                HStack(spacing: 8) {
                    WatchTimePill(title: "Total", value: SharedWorkoutSnapshot.durationText(model.snapshot.restDurationSeconds ?? 0), icon: "clock", color: .orange)
                    Button {
                        WatchCommandRouter.send(WatchCommand.completeSet.rawValue)
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.orange)
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.13))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .watchCard(borderColor: Color.orange.opacity(0.22))
        } else {
            WatchInfoCard(icon: "hourglass", title: "Descanso", value: "Sin descanso activo. Completa una serie para iniciar el siguiente timer.", color: .orange)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            WatchMetric(title: "Volumen", value: "\(model.snapshot.volumeKg)", unit: "kg", icon: "chart.bar.fill", color: accentColor)
            WatchMetric(title: "Agua", value: String(format: "%.2f", model.snapshot.waterLiters ?? 0), unit: "L", icon: "waterbottle.fill", color: .cyan)
            WatchMetric(title: "Kcal", value: "\(Int(model.snapshot.activeEnergyKcal ?? model.activeEnergy))", unit: "act.", icon: "flame.fill", color: .orange)
            WatchMetric(title: "Pulso", value: model.heartRate.map { "\(Int($0))" } ?? model.snapshot.heartRate.map { "\(Int($0))" } ?? "--", unit: "lpm", icon: "heart.fill", color: .red)
        }
    }

    private var routeMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            WatchMetric(title: "Distancia", value: String(format: "%.2f", routeDistanceKm), unit: "km", icon: "point.topleft.down.curvedto.point.bottomright.up", color: accentColor)
            WatchMetric(title: "Ritmo", value: routePaceText, unit: "", icon: "speedometer", color: .orange)
            WatchMetric(title: "Velocidad", value: routeSpeedKmh.map { String(format: "%.1f", $0) } ?? "--", unit: "km/h", icon: "gauge.with.needle", color: .blue)
            WatchMetric(title: "Pasos", value: routeSteps.map { "\(Int($0))" } ?? "--", unit: "", icon: "shoeprints.fill", color: .green)
            WatchMetric(title: "Kcal", value: "\(Int(model.snapshot.activeEnergyKcal ?? model.activeEnergy))", unit: "act.", icon: "flame.fill", color: .orange)
            WatchMetric(title: "Pulso", value: model.heartRate.map { "\(Int($0))" } ?? model.snapshot.heartRate.map { "\(Int($0))" } ?? "--", unit: "lpm", icon: "heart.fill", color: .red)
        }
    }

    private var accentColor: Color {
        switch model.snapshot.widgetAccentColorName.lowercased() {
        case "green":
            return Color(red: 0.33, green: 0.86, blue: 0.32)
        case "orange":
            return Color(red: 1.0, green: 0.60, blue: 0.14)
        case "purple":
            return Color(red: 0.52, green: 0.14, blue: 0.86)
        case "red":
            return Color(red: 0.93, green: 0.24, blue: 0.22)
        case "yellow":
            return Color(red: 1.0, green: 0.80, blue: 0.14)
        default:
            return Color(red: 0.23, green: 0.52, blue: 0.96)
        }
    }

    private var batteryColor: Color {
        let level = model.snapshot.trainingBatteryLevel
        if level >= 75 { return Color(red: 0.33, green: 0.86, blue: 0.32) }
        if level >= 40 { return Color(red: 1.0, green: 0.80, blue: 0.14) }
        if level >= 20 { return Color(red: 1.0, green: 0.60, blue: 0.14) }
        return Color(red: 0.93, green: 0.24, blue: 0.22)
    }

    private var sessionStateText: String {
        if !model.snapshot.hasActiveWorkout {
            return "SIN SESIÓN"
        }
        if (model.snapshot.restSeconds ?? 0) > 0 {
            return "DESCANSO"
        }
        return model.snapshot.isPaused ? "PAUSA" : "EN CURSO"
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

    private var liveElapsedText: String {
        if model.snapshot.hasActiveWorkout {
            return model.snapshot.elapsedText
        }
        return elapsedText
    }

    private var routeDistanceText: String {
        String(format: "%.2f km", routeDistanceKm)
    }

    private var routePaceText: String {
        guard let pace = routePaceSecondsPerKm, pace.isFinite, pace > 0 else {
            return "--"
        }
        return "\(Int(pace) / 60):\(String(format: "%02d", Int(pace) % 60))/km"
    }

    private var pausedRouteHelpText: String {
        if model.snapshot.isOutdoorRoute == false {
            return "Pausado desde el iPhone o reloj. Reanuda para seguir sumando sensores."
        }
        return "Pausado desde el iPhone o reloj. Reanuda para seguir sumando ruta."
    }

    private var liveRouteHelpText: String {
        if model.snapshot.isOutdoorRoute == false {
            return "Consulta tiempo, distancia estimada, pasos y pulso sin mapa GPS."
        }
        return "Consulta distancia, ritmo y pulso sin esperar al resumen final."
    }

    private var routeDistanceKm: Double {
        model.routeDistanceKm ?? model.snapshot.routeDistanceKm ?? 0
    }

    private var routePaceSecondsPerKm: Double? {
        model.routePaceSecondsPerKm ?? model.snapshot.routePaceSecondsPerKm
    }

    private var routeSpeedKmh: Double? {
        model.routeSpeedKmh ?? model.snapshot.routeSpeedKmh
    }

    private var routeSteps: Double? {
        model.routeSteps ?? model.snapshot.routeSteps
    }

    private var routeTimeProgress: Double {
        guard let remaining = model.snapshot.estimatedRemainingSeconds else {
            return 0
        }
        let total = model.snapshot.elapsedSeconds + remaining
        guard total > 0 else { return 0 }
        return min(max(Double(model.snapshot.elapsedSeconds) / Double(total), 0), 1)
    }

    private var elapsedText: String {
        SharedWorkoutSnapshot.durationText(model.elapsedSeconds)
    }

    private var syncText: String {
        model.snapshot.hasActiveWorkout ? "Tiempo real u offline\n\(model.snapshot.updatedAt.formatted(date: .omitted, time: .shortened))" : model.snapshot.summary
    }

    private var exerciseFlowText: String {
        let previous = model.snapshot.exerciseHistorySummary.map { "Anterior: \($0)" }
        let current = model.snapshot.exerciseName.map { "Actual: \($0)" }
        let next = model.snapshot.nextExerciseName.map { "Siguiente: \($0)" }
        return [previous, current, next].compactMap(\.self).joined(separator: "\n")
    }

    private var homeStatusText: String {
        if model.snapshot.hasActiveWorkout {
            return model.snapshot.isPaused ? "Sesión pausada" : "Sesión activa"
        }
        if let nextWorkout = model.snapshot.nextWorkoutDayName {
            return "Próximo: \(nextWorkout)"
        }
        return model.snapshot.summary
    }

    private var sessionTileSubtitle: String {
        if model.snapshot.hasActiveWorkout {
            return "\(model.snapshot.completedSets)/\(model.snapshot.totalSets) series"
        }
        return model.snapshot.nextWorkoutDayName ?? "Resumen"
    }

    private var utilitiesTileSubtitle: String {
        if model.snapshot.musicTitle != nil {
            return "Música"
        }
        if model.snapshot.gymPassName != nil {
            return "Gym pass"
        }
        return "Sync"
    }

    private var progressSummaryText: String {
        if model.snapshot.hasActiveWorkout {
            return "\(model.snapshot.workoutTitle): \(model.snapshot.completedSets) de \(model.snapshot.totalSets) series completadas."
        }
        if let nextWorkout = model.snapshot.nextWorkoutDayName {
            return "Semana al \(Int(model.snapshot.weeklyCompletion * 100))%. Próximo: \(nextWorkout)."
        }
        return model.snapshot.summary
    }

    private var sessionProgressValue: String {
        guard model.snapshot.totalSets > 0 else {
            return model.snapshot.hasActiveWorkout ? "En curso" : "Sin sesión"
        }
        return "\(Int(model.snapshot.progress * 100))%"
    }

    private var sessionProgressDetail: String {
        if model.snapshot.totalSets > 0 {
            return "\(model.snapshot.completedSets) de \(model.snapshot.totalSets) series · \(model.snapshot.volumeKg) kg"
        }
        if model.snapshot.hasActiveWorkout {
            return model.snapshot.isRouteWorkout ? "Cardio en curso · \(routeDistanceText)" : "Entreno sincronizado desde el iPhone."
        }
        return model.snapshot.nextWorkoutDayDescription ?? "Inicia un entreno para ver avance en directo."
    }

    private var weeklyProgressDetail: String {
        let streak = model.snapshot.streakDays == 1 ? "1 día de racha" : "\(model.snapshot.streakDays) días de racha"
        if let nextWorkout = model.snapshot.nextWorkoutDayName {
            return "\(streak) · Próximo: \(nextWorkout)"
        }
        return streak
    }

    private var currentExerciseSetValue: String {
        guard let completed = model.snapshot.currentExerciseCompletedSets,
              let total = model.snapshot.currentExerciseTotalSets,
              total > 0 else {
            return "--"
        }
        return "\(completed)/\(total)"
    }

    private var currentExerciseProgress: Double {
        guard let completed = model.snapshot.currentExerciseCompletedSets,
              let total = model.snapshot.currentExerciseTotalSets,
              total > 0 else {
            return 0
        }
        return min(max(Double(completed) / Double(total), 0), 1)
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

private struct WatchNavigationTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(subtitle)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .watchCard(borderColor: color.opacity(0.14))
    }
}

private struct WatchProgressRow: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            ProgressView(value: min(max(progress, 0), 1))
                .progressViewStyle(LinearTintProgressStyle(color: color))

            Text(detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.86)
        }
        .watchCard(borderColor: color.opacity(0.14))
    }
}

private struct WatchMiniRing: View {
    let value: Double
    let label: String
    let caption: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(value, 1))))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(caption)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 54, height: 54)
    }
}

struct GlassProgressCircle: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 4.5)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(progress, 1.0))))
                .stroke(color, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .frame(width: 44, height: 44)
    }
}

private struct WatchTimePill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WatchSetRow: View {
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "scalemass")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct LinearTintProgressStyle: ProgressViewStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, proxy.size.width * CGFloat(configuration.fractionCompleted ?? 0)))
            }
        }
        .frame(height: 5)
    }
}

private struct WatchMetric: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Text(unit.isEmpty ? title : "\(title) · \(unit)")
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
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}
