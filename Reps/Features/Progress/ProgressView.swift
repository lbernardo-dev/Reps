import Charts
import MuscleMap
import SwiftUI

struct ProgressDashboardView: View {
  @EnvironmentObject private var store: AppStore
  @State private var selectedRange: ProgressRange = .week
  @State private var selectedSection: ProgressSection = .muscles
  @State private var activeDestination: ProgressDestination?

  var onSelectTab: ((AppTab) -> Void)? = nil

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          let isSpanish = store.userProfile.preferredLanguage.hasPrefix("es")
          HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
              Text(isSpanish ? "RENDIMIENTO" : "PERFORMANCE")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(2.0)
                .foregroundStyle(PulseTheme.primary)
                .padding(.bottom, 1)

              Text(isSpanish ? "Progreso" : "Progress")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .lineLimit(1)

              Text(
                selectedSection == .muscles
                  ? (isSpanish
                    ? "Series por músculo en los últimos 7 días"
                    : "Sets per muscle in the last 7 days") : selectedRange.subtitle
              )
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(PulseTheme.secondaryText)
              .lineLimit(2)
              .minimumScaleFactor(0.82)
            }

            Spacer()

            NavigationLink {
              CalendarView()
            } label: {
              StreakBadge(days: store.streakDays, isSpanish: isSpanish)
            }
            .buttonStyle(.plain)
          }

          Picker("Rango", selection: $selectedRange) {
            ForEach(ProgressRange.allCases) { range in
              Text(range.title).tag(range)
            }
          }
          .pickerStyle(.segmented)

          LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(ProgressSection.allCases) { section in
              Button {
                if section == .load,
                   !store.hasFeatureAccess(.advancedAnalytics) {
                  store.presentPaywall(source: .progressLoad, feature: .advancedAnalytics)
                } else {
                  withAnimation(.snappy(duration: 0.2)) {
                    selectedSection = section
                  }
                }
              } label: {
                PulseChip(title: section.title, isSelected: selectedSection == section)
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.plain)
            }
          }

          if selectedSection == .general {
            HStack(spacing: 14) {
              Button {
                if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                  activeDestination = .exerciseAnalytics
                }
              } label: {
                AnalyticsShortcutCard(
                  title: "Ejercicios", subtitle: "\(exercisesWithHistory.count) con historial",
                  systemImage: "chart.line.uptrend.xyaxis")
              }
              .buttonStyle(.plain)

              Button {
                if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                  activeDestination = .workoutHistory
                }
              } label: {
                AnalyticsShortcutCard(
                  title: "Historial", subtitle: "\(filteredSessions.count) sesiones",
                  systemImage: "list.clipboard")
              }
              .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
              MetricCard(
                title: "Entrenos", value: "\(filteredSessions.count)",
                subtitle: selectedRange.subtitle, systemImage: "dumbbell",
                badgeColor: PulseTheme.primary)
              MetricCard(
                title: "Volumen",
                value: "\(Int(FitnessMetrics.totalVolumeKg(for: filteredSessions)))",
                subtitle: "kg total", systemImage: "bag", badgeColor: PulseTheme.primaryBright)
            }

            NavigationLink {
              OneRepMaxCalculatorView()
            } label: {
              PulseCard {
                HStack(spacing: 14) {
                  Image(systemName: "calculator.fill")
                    .font(.headline)
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(
                      RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                  VStack(alignment: .leading, spacing: 3) {
                    Text("Calculadora 1RM")
                      .font(.headline)
                    Text("Estima tu fuerza máxima y zonas de carga")
                      .font(.subheadline)
                      .foregroundStyle(PulseTheme.secondaryText)
                  }
                  Spacer()
                  Image(systemName: "chevron.right")
                    .foregroundStyle(PulseTheme.secondaryText)
                }
              }
            }
            .buttonStyle(.plain)

            NavigationLink {
              PlateCalculatorView()
            } label: {
              PulseCard {
                HStack(spacing: 14) {
                  Image(systemName: "circle.grid.3x3.fill")
                    .font(.headline)
                    .foregroundStyle(PulseTheme.primaryBright)
                    .frame(width: 42, height: 42)
                    .background(PulseTheme.primaryBright.opacity(0.12))
                    .clipShape(
                      RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                  VStack(alignment: .leading, spacing: 3) {
                    Text("Calculadora de Discos")
                      .font(.headline)
                    Text("Sabe qué discos cargar en cada lado de la barra")
                      .font(.subheadline)
                      .foregroundStyle(PulseTheme.secondaryText)
                  }
                  Spacer()
                  Image(systemName: "chevron.right")
                    .foregroundStyle(PulseTheme.secondaryText)
                }
              }
            }
            .buttonStyle(.plain)
          }

          if selectedSection == .load {
            CompetitiveSummaryCard(summary: competitiveSummary)

            HStack(spacing: 14) {
              MetricCard(
                title: "Carga", value: "\(Int(workload.acuteLoad))", subtitle: "7 días",
                systemImage: "waveform.path.ecg", badgeColor: PulseTheme.primary)
              MetricCard(
                title: "Series efectivas", value: "\(effectiveSetCount)",
                subtitle: "\(Int(effectiveVolume)) kg", systemImage: "checkmark.seal",
                badgeColor: PulseTheme.primaryBright)
            }

            HStack(spacing: 14) {
              MetricCard(
                title: "ACWR", value: String(format: "%.2f", workload.acwr),
                subtitle: "agudo/crónico", systemImage: "gauge.with.needle",
                badgeColor: PulseTheme.accent)
              MetricCard(
                title: "Fatiga", value: "\(Int(workload.fatigueScore))", subtitle: "0-100",
                systemImage: "battery.50", badgeColor: PulseTheme.warning)
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("Cardio")
                    .font(.headline)
                  Spacer()
                  Text("\(filteredCardioLogs.count) registros")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if filteredCardioLogs.isEmpty {
                  PulseEmptyState(
                    title: "Sin cardio registrado",
                    message:
                      "Registra sesiones desde Perfil para ver duración, distancia e intensidad.",
                    systemImage: "figure.run"
                  )
                } else {
                  HStack(spacing: 14) {
                    MetricInline(
                      title: "Tiempo",
                      value: "\(filteredCardioLogs.reduce(0) { $0 + $1.durationMinutes }) min")
                    MetricInline(
                      title: "Distancia", value: String(format: "%.1f km", filteredCardioDistance))
                    MetricInline(title: "RPE medio", value: averageCardioRPEText)
                  }

                  Chart(filteredCardioLogs.sorted { $0.date < $1.date }) { log in
                    BarMark(
                      x: .value("Fecha", log.date, unit: selectedRange.chartUnit),
                      y: .value("Minutos", log.durationMinutes)
                    )
                    .foregroundStyle(PulseTheme.primaryBright)
                  }
                  .frame(height: 140)

                  VStack(spacing: 10) {
                    ForEach(walkingAndRunningLogs.prefix(6)) { log in
                      HStack(spacing: 12) {
                        Image(systemName: log.activityType == .walking ? "figure.walk" : "figure.run")
                          .foregroundStyle(PulseTheme.primary)
                          .frame(width: 34, height: 34)
                          .background(PulseTheme.primary.opacity(0.12))
                          .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                          Text(log.activityType.displayName)
                            .font(.subheadline.weight(.bold))
                          Text(log.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                          Text("\(log.durationMinutes) min")
                            .font(.subheadline.weight(.bold))
                          Text(cardioDetailText(for: log))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                        }
                      }
                      .padding(10)
                      .background(PulseTheme.grouped)
                      .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                  }
                }
              }
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("Distribución de intensidad")
                  .font(.headline)

                if intensityDistribution.allSatisfy({ $0.count == 0 }) {
                  PulseEmptyState(
                    title: "Sin RPE registrado",
                    message:
                      "Activa RPE en Preferencias Pro y registra series para ver si entrenas demasiado suave o demasiado cerca del fallo.",
                    systemImage: "dial.high"
                  )
                } else {
                  Chart(intensityDistribution) { bucket in
                    BarMark(
                      x: .value("Rango", bucket.label),
                      y: .value("Series", bucket.count)
                    )
                    .foregroundStyle(PulseTheme.primary)
                  }
                  .frame(height: 150)
                }
              }
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("Objetivo vs real")
                    .font(.headline)
                  Spacer()
                  Text("\(competitiveSummary.actualWeeklySets)/\(competitiveSummary.targetWeeklySets) series")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if competitiveSummary.muscleTargets.isEmpty {
                  PulseEmptyState(
                    title: "Sin plan activo",
                    message: "Activa un plan para comparar el volumen real contra el objetivo semanal.",
                    systemImage: "target"
                  )
                } else {
                  Chart(competitiveSummary.muscleTargets) { point in
                    BarMark(
                      x: .value("Músculo", point.muscleGroup),
                      y: .value("Series", point.sets)
                    )
                    .foregroundStyle(by: .value("Tipo", point.kind))
                    .position(by: .value("Tipo", point.kind))
                  }
                  .frame(height: 190)
                  .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                  }
                }
              }
            }

            if !competitiveSummary.stalledExercises.isEmpty {
              PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                  HStack {
                    Text("Ejercicios estancados")
                      .font(.headline)
                    Spacer()
                    Text("\(competitiveSummary.stalledExercises.count)")
                      .font(.subheadline.weight(.semibold))
                      .foregroundStyle(PulseTheme.secondaryText)
                  }

                  ForEach(competitiveSummary.stalledExercises) { stall in
                    StalledExerciseRow(stall: stall)
                    if stall.id != competitiveSummary.stalledExercises.last?.id {
                      Divider()
                    }
                  }
                }
              }
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("Qué ejecutar")
                  .font(.headline)
                ForEach(competitiveSummary.recommendations) { recommendation in
                  CompetitiveRecommendationRow(recommendation: recommendation) {
                    perform(recommendation.action)
                  }
                  if recommendation.id != competitiveSummary.recommendations.last?.id {
                    Divider()
                  }
                }
              }
            }
          }

          if selectedSection == .body, let latestHealth = store.health.latestDailyMetrics.last {
            HStack(spacing: 14) {
              MetricCard(
                title: "Pasos", value: "\(Int(latestHealth.steps))", subtitle: "último día",
                systemImage: "figure.walk", badgeColor: PulseTheme.primary)
              MetricCard(
                title: "Kcal activas", value: "\(Int(latestHealth.activeEnergyKcal))",
                subtitle: "último día", systemImage: "flame", badgeColor: PulseTheme.accent)
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("Tendencias de Salud").font(.headline)
                Chart(store.health.latestDailyMetrics) { metric in
                  LineMark(x: .value("Date", metric.date), y: .value("Steps", metric.steps))
                    .foregroundStyle(PulseTheme.primary)
                  LineMark(
                    x: .value("Date", metric.date),
                    y: .value("Active kcal", metric.activeEnergyKcal)
                  )
                  .foregroundStyle(PulseTheme.accent)
                }
                .frame(height: 160)
              }
            }
          }

          if selectedSection == .general {
            Button {
              if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                activeDestination = .personalRecords
              }
            } label: {
              PulseCard {
                HStack {
                  VStack(alignment: .leading, spacing: 22) {
                    Label("Récords personales", systemImage: "trophy")
                    Text(
                      "\(Int(FitnessMetrics.personalRecordWeightKg(for: store.workoutSessions) ?? 0))"
                    )
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.primary)
                  }
                  Spacer()
                  Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(PulseTheme.accent)
                    .accessibilityHidden(true)
                }
              }
            }
            .buttonStyle(.plain)
          }

          if selectedSection == .exercises {
            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("Progreso por ejercicio")
                    .font(.headline)
                  Spacer()
                  Text("\(exercisesWithHistory.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if exercisesWithHistory.isEmpty {
                  PulseEmptyState(
                    title: "Sin historial de ejercicios",
                    message:
                      "Registra series durante un entreno para desbloquear gráficas por ejercicio.",
                    systemImage: "chart.line.uptrend.xyaxis"
                  )
                } else {
                  ForEach(exercisesWithHistory.prefix(6)) { exercise in
                    NavigationLink {
                      ExerciseProgressView(exercise: exercise)
                    } label: {
                      ExerciseProgressRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)

                    if exercise.id != exercisesWithHistory.prefix(6).last?.id {
                      Divider()
                    }
                  }
                }
              }
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("Registro de entrenos")
                    .font(.headline)
                  Spacer()
                  Text("\(filteredSessions.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if filteredSessions.isEmpty {
                  PulseEmptyState(
                    title: "Sin entrenos registrados",
                    message: "Empieza y finaliza un entreno para construir el historial.",
                    systemImage: "list.clipboard"
                  )
                } else {
                  ForEach(filteredSessions.sorted { $0.date > $1.date }.prefix(8)) { session in
                    NavigationLink {
                      WorkoutSessionDetailView(session: session)
                    } label: {
                      WorkoutLogRow(session: session)
                    }
                    .buttonStyle(.plain)

                    if session.id
                      != filteredSessions.sorted(by: { $0.date > $1.date }).prefix(8).last?.id
                    {
                      Divider()
                    }
                  }
                }
              }
            }
          }

          if selectedSection == .general {
            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("Constancia").font(.headline)
                  Spacer()
                  Text("\(consistencyTotal) sesiones")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
                Chart(consistencyData) { point in
                  BarMark(
                    x: .value("Date", point.date, unit: selectedRange.chartUnit),
                    y: .value("Workouts", point.count)
                  )
                  .foregroundStyle(PulseTheme.primary)
                  if point.count > 0 {
                    PointMark(
                      x: .value("Date", point.date, unit: selectedRange.chartUnit),
                      y: .value("Workouts", point.count)
                    )
                    .foregroundStyle(PulseTheme.accent)
                  }
                }
                .frame(height: 160)
                .chartYAxis {
                  AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                }
              }
            }
          }

          if selectedSection == .exercises {
            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("Máximo estimado")
                    .font(.headline)
                  Spacer()
                  Text("\(store.bestEstimatedOneRepMaxKg, specifier: "%.0f") kg")
                    .font(.headline)
                }
                Chart(store.goals) { goal in
                  BarMark(x: .value("Goal", goal.title), y: .value("Current", goal.current))
                    .foregroundStyle(PulseTheme.primary)
                  RuleMark(y: .value("Target", goal.target))
                    .foregroundStyle(PulseTheme.accent)
                }
                .frame(height: 160)
              }
            }
          }

          if selectedSection == .body {
            bodyProgressCard
          }

          if selectedSection == .muscles {
            if store.workoutSessions.isEmpty && store.activePlan.days.isEmpty {
              PulseCard {
                PulseEmptyState(
                  title: "Sin datos musculares",
                  message: "Crea un plan o finaliza un entreno para ver volumen y distribución por músculo.",
                  systemImage: "figure.strengthtraining.traditional"
                )
              }
            } else {
              MuscleMapProgressView(
                sessions: store.workoutSessions,
                plannedWorkout: store.todaysWorkout,
                startDate: selectedRange.startDate,
                gender: store.userProfile.muscleMapGender
              )
            }
          }

          if selectedSection == .general {
            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("Insights accionables").font(.headline)
                ForEach(Array(insightCards.enumerated()), id: \.element.id) { index, insight in
                  InsightRow(insight: insight)
                  if index < insightCards.count - 1 {
                    Divider()
                  }
                }
              }
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 10) {
                Label("Resumen diario", systemImage: "doc.text.magnifyingglass")
                  .font(.headline)
                Text(store.dailySummary)
                  .foregroundStyle(PulseTheme.secondaryText)
              }
            }
          }
        }
        .padding(20)
        .padding(.bottom, 112)
      }
      .screenBackground()
      .navigationBarHidden(true)
    }
  }

  private var filteredSessions: [WorkoutSession] {
    store.workoutSessions.filter { $0.date >= selectedRange.startDate }
  }

  private var filteredCardioLogs: [CardioLog] {
    store.cardioLogs.filter { $0.date >= selectedRange.startDate }
  }

  private var workload: AnalyticsEngine.WorkloadSummary {
    AnalyticsEngine.workloadSummary(sessions: store.workoutSessions, bodyMetrics: store.bodyMetrics)
  }

  private var competitiveSummary: AnalyticsEngine.CompetitiveSummary {
    AnalyticsEngine.competitiveSummary(
      sessions: store.workoutSessions,
      activePlan: store.activePlan,
      exercises: store.exercises,
      since: selectedRange.startDate
    )
  }

  private var effectiveSetCount: Int {
    filteredSessions.reduce(0) { $0 + AnalyticsEngine.effectiveSets(in: $1).count }
  }

  private var effectiveVolume: Double {
    AnalyticsEngine.effectiveVolumeKg(for: filteredSessions)
  }

  private var filteredCardioDistance: Double {
    filteredCardioLogs.compactMap(\.distanceKm).reduce(0, +)
  }

  private var walkingAndRunningLogs: [CardioLog] {
    filteredCardioLogs
      .filter { $0.activityType == .walking || $0.activityType == .outdoorRun }
      .sorted { $0.date > $1.date }
  }

  private var intensityDistribution: [AnalyticsEngine.IntensityBucket] {
    AnalyticsEngine.intensityDistribution(for: filteredSessions)
  }

  private var averageCardioRPEText: String {
    let values = filteredCardioLogs.compactMap(\.rpe)
    guard !values.isEmpty else { return "-" }
    return String(format: "%.1f", values.reduce(0, +) / Double(values.count))
  }

  private func cardioDetailText(for log: CardioLog) -> String {
    var parts: [String] = []
    if let distanceKm = log.distanceKm {
      parts.append(String(format: "%.2f km", distanceKm))
    }
    if let steps = log.steps {
      parts.append("\(Int(steps)) pasos")
    }
    if let heartRate = log.averageHeartRate {
      parts.append("\(Int(heartRate)) lpm")
    }
    return parts.isEmpty ? "Sin sensores" : parts.joined(separator: " · ")
  }

  private var consistencyTotal: Int {
    consistencyData.reduce(0) { $0 + $1.count }
  }

  private var muscleVolumePoints: [FitnessMetrics.MuscleVolumePoint] {
    FitnessMetrics.muscleVolumePoints(for: store.workoutSessions, since: selectedRange.startDate)
  }

  private var insightCards: [FitnessMetrics.TrainingInsight] {
    FitnessMetrics.insightCards(
      for: store.workoutSessions, goals: store.goals, since: selectedRange.startDate)
  }

  private var exercisesWithHistory: [Exercise] {
    store.exercises.filter { exercise in
      !FitnessMetrics.progressPoints(for: exercise, in: store.workoutSessions).isEmpty
    }
  }

  @ViewBuilder
  private var bodyProgressCard: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("Cuerpo y bienestar").font(.headline)
          Spacer()
          Text(store.hasBodyMetrics ? "\(store.displayedWeight.value, specifier: "%.1f") \(store.displayedWeight.unit)" : "pendiente")
            .font(.headline)
            .foregroundStyle(store.hasBodyMetrics ? .primary : PulseTheme.secondaryText)
        }

        if store.bodyMetrics.isEmpty {
          PulseEmptyState(
            title: "Sin métricas corporales",
            message: "Añade peso, altura o bienestar desde Perfil para ver tendencias.",
            systemImage: "scalemass"
          )
        } else {
          Chart(store.bodyMetrics) { metric in
            LineMark(x: .value("Date", metric.date), y: .value("Weight", metric.weightKg))
              .foregroundStyle(PulseTheme.primary)
            PointMark(x: .value("Date", metric.date), y: .value("Weight", metric.weightKg))
              .foregroundStyle(PulseTheme.primary)
          }
          .frame(height: 150)

          HStack {
            Label(
              "\(store.displayedHeight.value, specifier: "%.0f") \(store.displayedHeight.unit)",
              systemImage: "ruler")
            Spacer()
            Text(store.bodyMetrics.last?.source.rawValue ?? "Manual")
          }
          .foregroundStyle(PulseTheme.secondaryText)

          if let latest = store.bodyMetrics.last {
            HStack(spacing: 14) {
              MetricInline(
                title: "Sueño",
                value: latest.sleepHours.map { String(format: "%.1f h", $0) } ?? "-")
              MetricInline(title: "Fatiga", value: latest.fatigue.map { "\($0)/5" } ?? "-")
              MetricInline(title: "Estrés", value: latest.stress.map { "\($0)/5" } ?? "-")
            }
          }
        }
      }
      .navigationDestination(item: $activeDestination) { destination in
        switch destination {
        case .exerciseAnalytics:
          ExerciseAnalyticsListView(exercises: exercisesWithHistory)
        case .workoutHistory:
          WorkoutHistoryView(sessions: filteredSessions.sorted { $0.date > $1.date })
        case .personalRecords:
          PersonalRecordsView()
        }
      }
    }
  }

  private var consistencyData: [ConsistencyPoint] {
    let calendar = Calendar.current
    let start = selectedRange.startDate
    let grouped = Dictionary(grouping: filteredSessions) { session in
      calendar.startOfDay(for: session.date)
    }

    return (0..<selectedRange.days).compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
        return nil
      }
      return ConsistencyPoint(
        date: date, count: grouped[calendar.startOfDay(for: date)]?.count ?? 0)
    }
  }

  private func perform(_ action: AnalyticsEngine.CompetitiveAction) {
    guard let destination = store.executeCompetitiveAction(action) else {
      return
    }
    onSelectTab?(destination)
  }
}

private extension CardioLog.ActivityType {
  var displayName: LocalizedStringKey {
    switch self {
    case .treadmill: "Cinta"
    case .elliptical: "Elíptica"
    case .stationaryBike: "Bici"
    case .outdoorRun: "Carrera"
    case .walking: "Caminata"
    case .rowing: "Remo"
    case .hiit: "HIIT"
    case .other: "Otro"
    }
  }
}

private struct ExerciseProgressRow: View {
  let exercise: Exercise
  @EnvironmentObject private var store: AppStore

  private var points: [FitnessMetrics.ExerciseProgressPoint] {
    FitnessMetrics.progressPoints(for: exercise, in: store.workoutSessions)
  }

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.headline)
        .foregroundStyle(PulseTheme.primary)
        .frame(width: 42, height: 42)
        .background(PulseTheme.primary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        Text(exercise.name)
          .font(.headline)
        Text(
          "\(points.count) logged days · \(Int(points.map(\.totalVolumeKg).reduce(0, +))) kg volume"
        )
        .font(.subheadline)
        .foregroundStyle(PulseTheme.secondaryText)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(PulseTheme.secondaryText)
    }
    .padding(.vertical, 8)
  }
}

private struct MetricInline: View {
  let title: LocalizedStringKey
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(PulseTheme.secondaryText)
      Text(value)
        .font(.headline.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PulseTheme.grouped)
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
  }
}

private struct AnalyticsShortcutCard: View {
  let title: LocalizedStringKey
  let subtitle: String
  let systemImage: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: systemImage)
        .font(.headline)
        .foregroundStyle(PulseTheme.primary)
        .frame(width: 42, height: 42)
        .background(PulseTheme.primary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
      Text(title)
        .font(.headline)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(PulseTheme.secondaryText)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
    .background(PulseTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)
  }
}

private struct CompetitiveSummaryCard: View {
  let summary: AnalyticsEngine.CompetitiveSummary

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Diagnóstico competitivo")
              .font(.headline)
            Text("Adherencia, volumen y señales de estancamiento contra el plan activo.")
              .font(.subheadline)
              .foregroundStyle(PulseTheme.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Text("\(Int(summary.completionRate * 100))%")
            .font(.title2.monospacedDigit().weight(.bold))
            .foregroundStyle(summary.completionRate >= 0.75 ? PulseTheme.recovery : PulseTheme.warning)
        }

        ProgressView(value: summary.completionRate)
          .tint(summary.completionRate >= 0.75 ? PulseTheme.recovery : PulseTheme.warning)

        HStack(spacing: 10) {
          MetricInline(
            title: "Plan",
            value: "\(summary.completedWorkouts)/\(max(summary.plannedWorkouts, 1))")
          MetricInline(
            title: "Volumen",
            value: "\(summary.actualWeeklySets)/\(summary.targetWeeklySets)")
          MetricInline(
            title: "Alertas",
            value: "\(summary.undertrainedMuscles.count + summary.overtrainedMuscles.count + summary.stalledExercises.count)")
        }

        if !summary.undertrainedMuscles.isEmpty || !summary.overtrainedMuscles.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(summary.undertrainedMuscles.prefix(2)) { point in
              CompetitiveMuscleGapRow(
                point: point,
                title: "\(point.muscleGroup): faltan \(point.sets) series",
                color: PulseTheme.warning
              )
            }
            ForEach(summary.overtrainedMuscles.prefix(2)) { point in
              CompetitiveMuscleGapRow(
                point: point,
                title: "\(point.muscleGroup): exceso de \(point.sets) series",
                color: PulseTheme.destructive
              )
            }
          }
        }
      }
    }
  }
}

private struct CompetitiveMuscleGapRow: View {
  let point: AnalyticsEngine.MuscleTargetPoint
  let title: String
  let color: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: point.kind == "Faltan" ? "arrow.down.circle.fill" : "exclamationmark.triangle.fill")
        .font(.subheadline)
        .foregroundStyle(color)
        .frame(width: 28, height: 28)
        .background(color.opacity(0.12))
        .clipShape(Circle())
      Text(title)
        .font(.subheadline.weight(.semibold))
      Spacer()
    }
  }
}

private struct StalledExerciseRow: View {
  let stall: AnalyticsEngine.ExerciseStall

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "pause.circle.fill")
        .font(.headline)
        .foregroundStyle(PulseTheme.warning)
        .frame(width: 38, height: 38)
        .background(PulseTheme.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(stall.exercise.name)
          .font(.headline)
        Text("\(stall.loggedSessions) sesiones · mejor previo \(Int(stall.previousBestEstimatedOneRepMaxKg)) kg · actual \(Int(stall.latestEstimatedOneRepMaxKg)) kg")
          .font(.subheadline)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()
    }
    .padding(.vertical, 4)
  }
}

private struct CompetitiveRecommendationRow: View {
  let recommendation: AnalyticsEngine.CompetitiveRecommendation
  let onExecute: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: recommendation.systemImage)
        .font(.headline)
        .foregroundStyle(PulseTheme.primary)
        .frame(width: 38, height: 38)
        .background(PulseTheme.primary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(recommendation.title)
          .font(.headline)
        Text(recommendation.message)
          .font(.subheadline)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
        if recommendation.action != .none {
          Button(action: onExecute) {
            Label(actionTitle, systemImage: "arrow.forward.circle.fill")
              .font(.caption.weight(.bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 12)
              .frame(height: 32)
              .background(PulseTheme.primary)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .padding(.top, 4)
        }
      }
    }
  }

  private var actionTitle: String {
    switch recommendation.action {
    case .scheduleUndertrainedMuscle:
      return "Programar foco"
    case .scheduleDeloadExercise:
      return "Programar descarga"
    case .reviewPlan:
      return "Revisar plan"
    case .scheduleRecovery:
      return "Programar recuperación"
    case .none:
      return ""
    }
  }
}

struct ExerciseAnalyticsListView: View {
  let exercises: [Exercise]

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        if exercises.isEmpty {
          PulseCard {
            PulseEmptyState(
              title: "Sin historial de ejercicios",
              message:
                "Finaliza un entreno con series registradas para ver progreso por ejercicio.",
              systemImage: "chart.line.uptrend.xyaxis"
            )
          }
        } else {
          ForEach(exercises) { exercise in
            NavigationLink {
              ExerciseProgressView(exercise: exercise)
            } label: {
              PulseCard {
                ExerciseProgressRow(exercise: exercise)
              }
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(20)
      .padding(.bottom, 112)
    }
    .screenBackground()
    .navigationTitle("Ejercicios")
    .navigationBarTitleDisplayMode(.inline)
    .mainTabBarHidden()
  }
}

private enum ProgressSection: String, CaseIterable, Identifiable {
  case general
  case exercises
  case muscles
  case body
  case load

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .general: "General"
    case .exercises: "Ejercicios"
    case .muscles: "Músculos"
    case .body: "Cuerpo"
    case .load: "Carga"
    }
  }
}

private enum ProgressRange: String, CaseIterable, Identifiable {
  case week
  case month
  case year

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .week: "Semana"
    case .month: "Mes"
    case .year: "Año"
    }
  }

  var subtitle: LocalizedStringKey {
    switch self {
    case .week: "Esta semana"
    case .month: "Este mes"
    case .year: "Este año"
    }
  }

  var days: Int {
    switch self {
    case .week: 7
    case .month: 30
    case .year: 365
    }
  }

  var chartUnit: Calendar.Component {
    switch self {
    case .week, .month: .day
    case .year: .month
    }
  }

  var startDate: Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
  }
}

private enum ProgressDestination: String, Identifiable {
  case exerciseAnalytics
  case workoutHistory
  case personalRecords

  var id: String { rawValue }
}

private struct ConsistencyPoint: Identifiable {
  let id = UUID()
  let date: Date
  let count: Int
}

private struct MuscleRow: View {
  let point: FitnessMetrics.MuscleVolumePoint

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text(point.muscleGroup)
            .font(.title3.weight(.bold))
          Text("\(point.completedSets) de 12 series semanales")
            .font(.headline.monospacedDigit())
            .foregroundStyle(PulseTheme.secondaryText)
        }
        Spacer()
        Text(growthText)
          .font(.headline)
          .foregroundStyle(
            point.completedSets >= 4 ? PulseTheme.primaryBright : PulseTheme.secondaryText)
      }

      HStack(spacing: 14) {
        MuscleGlyph(muscleGroup: point.muscleGroup, intensity: point.targetProgress)
        VolumeSegmentBar(completed: min(point.completedSets, 12))
      }

      HStack {
        Text(point.recommendedRangeText)
        Spacer()
        Text("\(Int(point.totalVolumeKg)) kg")
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(PulseTheme.tertiaryText)
    }
    .padding(18)
    .background(PulseTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
        .stroke(PulseTheme.separator, lineWidth: 1)
    )
  }

  private var growthText: String {
    point.completedSets >= 4 ? "Zona de crecimiento" : "Faltan \(max(4 - point.completedSets, 0))"
  }
}

private struct InsightRow: View {
  let insight: FitnessMetrics.TrainingInsight

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: insight.systemImage)
        .font(.headline)
        .foregroundStyle(PulseTheme.primary)
        .frame(width: 38, height: 38)
        .background(PulseTheme.primary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(insight.title)
          .font(.headline)
        Text(insight.message)
          .font(.subheadline)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct StreakBadge: View {
  let days: Int
  var isSpanish: Bool

  var body: some View {
    HStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(
            days > 0
              ? RadialGradient(
                colors: [Color.orange.opacity(0.35), .clear], center: .center, startRadius: 0,
                endRadius: 30)
              : RadialGradient(
                colors: [.clear, .clear], center: .center, startRadius: 0, endRadius: 30)
          )
          .frame(width: 56, height: 56)

        Circle()
          .strokeBorder(days > 0 ? Color.orange.opacity(0.4) : PulseTheme.separator, lineWidth: 2)
          .frame(width: 44, height: 44)

        if days > 0 {
          Image(systemName: "flame.fill")
            .font(.system(size: 29, weight: .bold))
            .foregroundStyle(
              LinearGradient(
                colors: [.yellow, .orange, .red],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
        } else {
          Image(systemName: "flame.fill")
            .font(.system(size: 29, weight: .bold))
            .foregroundStyle(PulseTheme.secondaryText)
        }
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(isSpanish ? "RACHA" : "STREAK")
          .font(.system(size: 10, weight: .black, design: .rounded))
          .foregroundStyle(PulseTheme.secondaryText)
          .tracking(1.4)

        Text(
          "\(formattedDays) \(days == 1 ? (isSpanish ? "día" : "day") : (isSpanish ? "días" : "days"))"
        )
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(days > 0 ? .white : PulseTheme.secondaryText)
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 8)
    .background(
      days > 0
        ? LinearGradient(
          colors: [PulseTheme.warning.opacity(0.12), PulseTheme.warning.opacity(0.04)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(
          colors: [PulseTheme.grouped.opacity(0.4), PulseTheme.grouped.opacity(0.2)],
          startPoint: .top, endPoint: .bottom)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(
          days > 0
            ? LinearGradient(
              colors: [.yellow.opacity(0.3), .orange.opacity(0.4), .red.opacity(0.3)],
              startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [PulseTheme.separator], startPoint: .top, endPoint: .bottom),
          lineWidth: 1.2
        )
    )
    .shadow(color: days > 0 ? Color.orange.opacity(0.12) : Color.clear, radius: 8, x: 0, y: 3)
  }

  private var formattedDays: String {
    if days >= 1000 {
      let kValue = Double(days) / 1000.0
      if kValue.truncatingRemainder(dividingBy: 1.0) == 0 {
        return String(format: "%.0fK", kValue)
      } else {
        return String(format: "%.1fK", kValue)
      }
    }
    return "\(days)"
  }
}
