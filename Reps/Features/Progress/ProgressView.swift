import Charts
import MuscleMap
import SwiftUI

struct ProgressDashboardView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedRange: ProgressRange = .week
  @State private var selectedSection: ProgressSection = .muscles
  @State private var activeDestination: ProgressDestination?

  var onSelectTab: ((AppTab) -> Void)? = nil

  var body: some View {
    NavigationStack {
      StickyHeaderScaffold(
        title: "progress_2",
        subtitle: "performance",
        topContentPadding: 128,
        accessory: {
            NavigationLink {
              CalendarView()
            } label: {
              StreakBadge(days: store.streakDays)
            }
            .buttonStyle(.plain)
        }
      ) {

          ProgressHeroCard(
            metrics: heroMetrics,
            onTapStreak: { onSelectTab?(.calendar) },
            onTapVolume: { withAnimation(.snappy(duration: 0.2)) { selectedSection = .muscles } },
            onTapSessions: { withAnimation(.snappy(duration: 0.2)) { selectedSection = .general } }
          )
            .stickyHeaderTitle(localizedString("this_week"))

          Picker("range", selection: $selectedRange) {
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
                  HapticService.notification(.warning)
                  store.presentPaywall(source: .progressLoad, feature: .advancedAnalytics)
                } else {
                  HapticService.selection()
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
          .stickyHeaderTitle(localizedString("metric_2"))

          // The next-best-action plan lives on the Today tab; Progress stays a
          // pure analytics surface to avoid duplicating it across both tabs.

          if selectedSection == .general {
            HStack(spacing: 14) {
              Button {
                if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                  activeDestination = .exerciseAnalytics
                }
              } label: {
                AnalyticsShortcutCard(
                  title: "exercises_3", subtitle: localizedFormat("with_history_count_format", exercisesWithHistory.count),
                  systemImage: "chart.line.uptrend.xyaxis")
              }
              .buttonStyle(.plain)

              Button {
                if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                  activeDestination = .workoutHistory
                }
              } label: {
                AnalyticsShortcutCard(
                  title: "history_label", subtitle: localizedFormat("sessions_subtitle_format", filteredSessions.count),
                  systemImage: "list.clipboard")
              }
              .buttonStyle(.plain)
            }
            .stickyHeaderTitle(localizedString("overview"))

            HStack(spacing: 14) {
              MetricCard(
                title: "workouts_label", value: "\(filteredSessions.count)",
                subtitle: selectedRange.subtitle, systemImage: "dumbbell",
                badgeColor: PulseTheme.primary)
              MetricCard(
                title: "volume_label",
                value: "\(Int(FitnessMetrics.totalVolumeKg(for: filteredSessions)))",
                subtitle: "kg_total", systemImage: "bag", badgeColor: PulseTheme.primaryBright)
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
                    Text("calculadora_1rm")
                      .font(.headline)
                    Text("estimate_your_maximum_strength_and_load_zones")
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
                    Text("plate_calculator")
                      .font(.headline)
                    Text("knows_which_discs_to_load_on_each_side_of_the_bar")
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

          if selectedSection == .cardio {
            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("cardio_2")
                    .font(.headline)
                  Spacer()
                  Text(localizedFormat("records_count_format", filteredCardioLogs.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if filteredCardioLogs.isEmpty {
                  PulseEmptyState(
                    title: "no_cardio_logged",
                    message: "register_sessions_from_profile_message",
                    systemImage: "figure.run"
                  )
                } else {
                  HStack(spacing: 14) {
                    MetricInline(
                      title: "time_label",
                      value: "\(filteredCardioLogs.reduce(0) { $0 + $1.durationMinutes }) min")
                    MetricInline(
                      title: "distance_label", value: String(format: "%.1f km", filteredCardioDistance))
                    MetricInline(title: "avg_rpe", value: averageCardioRPEText)
                  }

                  Chart(filteredCardioLogs.sorted { $0.date < $1.date }) { log in
                    BarMark(
                      x: .value(localizedString("date_label"), log.date, unit: selectedRange.chartUnit),
                      y: .value(localizedString("minutes_label"), log.durationMinutes)
                    )
                    .foregroundStyle(PulseTheme.primaryBright)
                  }
                  .frame(height: 140)
                  .allowsHitTesting(false)

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
            .stickyHeaderTitle(localizedString("cardio_label"))

            HRZoneDurationCard(
              logs: filteredCardioLogs,
              dateOfBirth: store.userProfile.dateOfBirth
            )

            CardioAnalyticsCard(
              logs: filteredCardioLogs,
              dateOfBirth: store.userProfile.dateOfBirth
            )
          }

          if selectedSection == .load {
            CompetitiveSummaryCard(summary: competitiveSummary)
              .stickyHeaderTitle(localizedString("load"))

            HStack(spacing: 14) {
              MetricCard(
                title: "load_metric", value: "\(Int(workload.acuteLoad))", subtitle: "7_days",
                systemImage: "waveform.path.ecg", badgeColor: PulseTheme.primary)
              MetricCard(
                title: "effective_sets", value: "\(effectiveSetCount)",
                subtitle: "\(Int(effectiveVolume)) kg", systemImage: "checkmark.seal",
                badgeColor: PulseTheme.primaryBright)
            }

            HStack(spacing: 14) {
              MetricCard(
                title: "ACWR", value: String(format: "%.2f", workload.acwr),
                subtitle: "acute_chronic", systemImage: "gauge.with.needle",
                badgeColor: PulseTheme.accent)
              MetricCard(
                title: "fatigue_score", value: "\(Int(workload.fatigueScore))", subtitle: "0-100",
                systemImage: "battery.50", badgeColor: PulseTheme.warning)
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("intensity_distribution")
                  .font(.headline)

                if intensityDistribution.allSatisfy({ $0.count == 0 }) {
                  PulseEmptyState(
                    title: "no_rpe_logged",
                    message: "activate_rpe_message",
                    systemImage: "dial.high"
                  )
                } else {
                  Chart(intensityDistribution) { bucket in
                    BarMark(
                      x: .value(localizedString("range_label"), bucket.label),
                      y: .value(localizedString("sets_label"), bucket.count)
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
                  Text("target_vs_actual")
                    .font(.headline)
                  Spacer()
                  Text(localizedFormat("sets_fraction_format", competitiveSummary.actualWeeklySets, competitiveSummary.targetWeeklySets))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if competitiveSummary.muscleTargets.isEmpty {
                  PulseEmptyState(
                    title: "no_active_plan",
                    message: "activate_plan_to_compare_message",
                    systemImage: "target"
                  )
                } else {
                  Chart(competitiveSummary.muscleTargets) { point in
                    BarMark(
                      x: .value(localizedString("muscle_label"), point.muscleGroup),
                      y: .value(localizedString("sets_label"), point.sets)
                    )
                    .foregroundStyle(by: .value(localizedString("type_label"), point.kind))
                    .position(by: .value(localizedString("type_label"), point.kind))
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
                    Text("stalled_exercises")
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
                Text("what_to_run")
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
                title: "steps_metric", value: "\(Int(latestHealth.steps))", subtitle: "last_day",
                systemImage: "figure.walk", badgeColor: PulseTheme.primary)
              MetricCard(
                title: "active_kcal", value: "\(Int(latestHealth.activeEnergyKcal))",
                subtitle: "last_day", systemImage: "flame", badgeColor: PulseTheme.accent)
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("health_trends").font(.headline)
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
                    Label("personal_records", systemImage: "trophy")
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
                  Text("progress_per_exercise")
                    .font(.headline)
                  Spacer()
                  Text("\(exercisesWithHistory.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if exercisesWithHistory.isEmpty {
                  PulseEmptyState(
                    title: "no_exercise_history",
                    message: "record_sets_during_workout_message",
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
            .stickyHeaderTitle(localizedString("exercises_3"))

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Text("training_log")
                    .font(.headline)
                  Spacer()
                  Text("\(filteredSessions.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }

                if filteredSessions.isEmpty {
                  PulseEmptyState(
                    title: "no_workouts_logged",
                    message: "start_and_finish_workout_message",
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
                  Text("constancia").font(.headline)
                  Spacer()
                  Text(localizedFormat("sessions_count_format", consistencyTotal))
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
                  Text("estimated_maximum")
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
              .stickyHeaderTitle(localizedString("body_2"))
          }

          if selectedSection == .muscles {
            if store.workoutSessions.isEmpty && store.activePlan.days.isEmpty {
              PulseCard {
                PulseEmptyState(
                  title: "no_muscle_data",
                  message: "create_plan_or_finish_workout_message",
                  systemImage: "figure.strengthtraining.traditional"
                )
              }
            } else {
	              MuscleMapProgressView(
	                sessions: store.workoutSessions,
	                plannedWorkout: store.todaysWorkout,
	                startDate: selectedRange.startDate,
	                gender: store.userProfile.muscleMapGender,
	                catalog: store.exercises
	              )
              .stickyHeaderTitle(localizedString("muscle_map"))
            }
          }

          if selectedSection == .general {
            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                Text("insights_accionables").font(.headline)
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
                Label("resumen_diario", systemImage: "doc.text.magnifyingglass")
                  .font(.headline)
                Text(store.dailySummary)
                  .foregroundStyle(PulseTheme.secondaryText)
              }
            }
          }
      }
      .toolbar(.hidden, for: .navigationBar)
    }
  }

  private var filteredSessions: [WorkoutSession] {
    store.workoutSessions.filter { $0.date >= selectedRange.startDate }
  }

  /// At-a-glance snapshot of the current week (independent of the analytical
  /// range selector below) compared with the previous week.
  private var heroMetrics: ProgressHeroMetrics {
    let calendar = Calendar.current
    let now = Date()
    let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
    let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
    let thisWeek = store.workoutSessions.filter { $0.date >= thisWeekStart }
    let lastWeek = store.workoutSessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
    return ProgressHeroMetrics(
      streak: store.streakDays,
      adherence: store.weeklyCompletion,
      sessionsThisWeek: thisWeek.count,
      sessionsLastWeek: lastWeek.count,
      volumeThisWeek: FitnessMetrics.totalVolumeKg(for: thisWeek),
      volumeLastWeek: FitnessMetrics.totalVolumeKg(for: lastWeek)
    )
  }

  private var filteredCardioLogs: [CardioLog] {
    store.combinedCardioLogs.filter { $0.date >= selectedRange.startDate }
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
      parts.append(localizedFormat("steps_count_format", Int(steps)))
    }
    if let heartRate = log.averageHeartRate {
      parts.append("\(Int(heartRate)) lpm")
    }
    return parts.isEmpty ? localizedString("no_sensors") : parts.joined(separator: " · ")
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
          Text("body_and_wellness").font(.headline)
          Spacer()
          Text(store.hasBodyMetrics ? "\(String(format: "%.1f", store.displayedWeight.value)) \(store.displayedWeight.unit)" : localizedString("pendiente"))
            .font(.headline)
            .foregroundStyle(store.hasBodyMetrics ? .primary : PulseTheme.secondaryText)
        }

        if store.bodyMetrics.isEmpty {
          PulseEmptyState(
            title: "no_body_metrics",
            message: "add_weight_height_or_wellness_from_profile_to_see_trends",
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
                title: "sleep_metric",
                value: latest.sleepHours.map { String(format: "%.1f h", $0) } ?? "-")
              MetricInline(title: "fatigue_rating", value: latest.fatigue.map { "\($0)/5" } ?? "-")
              MetricInline(title: "stress_metric", value: latest.stress.map { "\($0)/5" } ?? "-")
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
    HapticService.selection()
    guard let destination = store.executeCompetitiveAction(action) else {
      return
    }
    onSelectTab?(destination)
  }
}

private extension CardioLog.ActivityType {
  var displayName: LocalizedStringKey {
    switch self {
    case .treadmill: "treadmill_label"
    case .elliptical: "elliptical_label"
    case .stationaryBike: "stationary_bike_label"
    case .outdoorRun: "outdoor_run_label"
    case .walking: "walking_label"
    case .rowing: "rowing_label"
    case .hiit: "hiit_label"
    case .other: "other_label"
    }
  }
}

private struct ExerciseProgressRow: View {
  let exercise: Exercise
  @Environment(AppStore.self) private var store

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
      Text(localizedKey(title))
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
      Text(localizedKey(title))
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

private struct ProgressActionPlanCard: View {
  let steps: [RetentionEngine.ActivationStep]
  let weeklyCompletion: Double
  let battery: FitnessMetrics.TrainingBatteryStatus
  let completionRate: Double
  let onAction: (RetentionEngine.ActivationAction?) -> Void

  private var pendingStep: RetentionEngine.ActivationStep? {
    steps.first { !$0.isCompleted } ?? steps.first
  }

  private var completedSteps: Int {
    steps.filter(\.isCompleted).count
  }

  private var planProgress: Double {
    guard !steps.isEmpty else { return 0 }
    return Double(completedSteps) / Double(steps.count)
  }

  private var visibleStepCount: Int {
    min(steps.count, 2)
  }

  private var batteryColor: Color {
    switch battery.state {
    case .charged:
      return PulseTheme.recovery
    case .steady:
      return PulseTheme.primary
    case .low:
      return PulseTheme.warning
    case .critical:
      return PulseTheme.destructive
    }
  }

  var body: some View {
    PulseCard(contentPadding: 18) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .center, spacing: 16) {
          ProgressPlanRing(
            progress: max(planProgress, min(max(weeklyCompletion, 0), 1) * 0.85),
            color: batteryColor,
            centerValue: "\(Int(max(weeklyCompletion, 0) * 100))%"
          )
          .frame(width: 92, height: 92)

          VStack(alignment: .leading, spacing: 9) {
            Label(localizedString("progress_direction"), systemImage: "sparkles")
              .font(.caption.weight(.black))
              .textCase(.uppercase)
              .foregroundStyle(PulseTheme.primary)

            Text(pendingStep?.title ?? (localizedString("keep_the_week_stable")))
              .font(.title3.weight(.bold))
              .lineLimit(2)
              .minimumScaleFactor(0.82)

            Text(pendingStep?.message ?? battery.suggestion)
              .font(.subheadline)
              .foregroundStyle(PulseTheme.secondaryText)
              .lineLimit(3)
              .minimumScaleFactor(0.82)
          }

          Spacer(minLength: 0)
        }

        HStack(spacing: 8) {
          ProgressSignalPill(
            title: "adherence",
            value: "\(Int(completionRate * 100))%",
            color: completionRate >= 0.75 ? PulseTheme.recovery : PulseTheme.warning
          )
          ProgressSignalPill(
            title: "battery",
            value: "\(battery.level)%",
            color: batteryColor
          )
          ProgressSignalPill(
            title: "steps_3",
            value: "\(completedSteps)/\(max(steps.count, 1))",
            color: PulseTheme.primary
          )
        }

        VStack(spacing: 0) {
          ForEach(Array(steps.prefix(visibleStepCount).enumerated()), id: \.element.id) { index, step in
            ProgressActionStepRow(step: step) {
              onAction(step.action)
            }

            if index < visibleStepCount - 1 {
              Divider()
                .padding(.leading, 52)
            }
          }
        }

        if let pendingStep, !pendingStep.isCompleted, pendingStep.action != nil {
          Button {
            onAction(pendingStep.action)
          } label: {
            Label(pendingStep.actionTitle, systemImage: "arrow.forward.circle.fill")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 46)
              .background(PulseTheme.accent)
              .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct ProgressPlanRing: View {
  let progress: Double
  let color: Color
  let centerValue: String

  var body: some View {
    ZStack {
      Circle()
        .stroke(PulseTheme.grouped, lineWidth: 12)
      Circle()
        .trim(from: 0, to: min(max(progress, 0), 1))
        .stroke(
          AngularGradient(colors: [color, PulseTheme.accent, color], center: .center),
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        Text(centerValue)
          .font(.system(size: 20, weight: .black, design: .rounded))
        Text("plan_2")
          .font(.system(size: 9, weight: .black, design: .rounded))
          .foregroundStyle(PulseTheme.secondaryText)
      }
    }
    .accessibilityLabel(localizedFormat("weekly_progress_format", centerValue))
  }
}

private struct ProgressSignalPill: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(localizedKey(title))
        .font(.caption2.weight(.bold))
        .foregroundStyle(PulseTheme.secondaryText)
      Text(value)
        .font(.caption.weight(.black).monospacedDigit())
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(color.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
  }
}

private struct ProgressActionStepRow: View {
  let step: RetentionEngine.ActivationStep
  let onAction: () -> Void

  private var iconColor: Color {
    step.isCompleted ? PulseTheme.recovery : PulseTheme.primary
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
          .fill(iconColor.opacity(step.isCompleted ? 0.18 : 0.12))
        Image(systemName: step.isCompleted ? "checkmark.seal.fill" : step.systemImage)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(iconColor)
      }
      .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(step.title)
            .font(.subheadline.weight(.bold))
            .lineLimit(2)
            .minimumScaleFactor(0.86)

          if step.isCompleted {
            Text(localizedString("done"))
              .font(.caption2.weight(.bold))
              .foregroundStyle(PulseTheme.recovery)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(PulseTheme.recovery.opacity(0.12))
              .clipShape(Capsule())
          }
        }

        Text(step.message)
          .font(.caption)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)

        if !step.isCompleted, step.action != nil {
          Button(action: onAction) {
            Text(step.actionTitle)
              .font(.caption.weight(.bold))
              .foregroundStyle(PulseTheme.primary)
          }
          .buttonStyle(.plain)
          .padding(.top, 2)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 9)
  }
}

private struct CompetitiveSummaryCard: View {
  let summary: AnalyticsEngine.CompetitiveSummary

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("competitive_diagnostics")
              .font(.headline)
            Text("adherence_volume_and_stall_signals_against_the_active_plan")
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
            title: "plan",
            value: "\(summary.completedWorkouts)/\(max(summary.plannedWorkouts, 1))")
          MetricInline(
            title: "volume_label",
            value: "\(summary.actualWeeklySets)/\(summary.targetWeeklySets)")
          MetricInline(
            title: "alerts_label",
            value: "\(summary.undertrainedMuscles.count + summary.overtrainedMuscles.count + summary.stalledExercises.count)")
        }

        if !summary.undertrainedMuscles.isEmpty || !summary.overtrainedMuscles.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(summary.undertrainedMuscles.prefix(2)) { point in
              CompetitiveMuscleGapRow(
                point: point,
                title: localizedFormat("muscle_gap_under_format", point.muscleGroup, point.sets),
                color: PulseTheme.warning
              )
            }
            ForEach(summary.overtrainedMuscles.prefix(2)) { point in
              CompetitiveMuscleGapRow(
                point: point,
                title: localizedFormat("muscle_gap_over_format", point.muscleGroup, point.sets),
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
        Text(localizedFormat("stall_summary_format", stall.loggedSessions, Int(stall.previousBestEstimatedOneRepMaxKg), Int(stall.latestEstimatedOneRepMaxKg)))
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
      return localizedString("schedule_focus")
    case .scheduleDeloadExercise:
      return localizedString("schedule_deload")
    case .reviewPlan:
      return localizedString("review_plan")
    case .scheduleRecovery:
      return localizedString("schedule_recovery")
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
              title: "no_exercise_history",
              message: "finish_workout_to_see_progress_message",
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
    .navigationTitle("exercises_3")
    .navigationBarTitleDisplayMode(.inline)
    .mainTabBarHidden()
  }
}

struct ProgressHeroMetrics {
  let streak: Int
  let adherence: Double          // 0...1 weekly plan completion
  let sessionsThisWeek: Int
  let sessionsLastWeek: Int
  let volumeThisWeek: Double      // kg
  let volumeLastWeek: Double

  /// Percentage change vs last week, or nil when there is no baseline.
  var volumeDelta: Double? {
    guard volumeLastWeek > 0 else { return nil }
    return (volumeThisWeek - volumeLastWeek) / volumeLastWeek * 100
  }

  var sessionsDelta: Int { sessionsThisWeek - sessionsLastWeek }
}

/// Graphical, at-a-glance summary of the current week: an adherence ring plus
/// streak, volume and session tiles with week-over-week trend.
struct ProgressHeroCard: View {
  let metrics: ProgressHeroMetrics
  var onTapStreak: (() -> Void)? = nil
  var onTapVolume: (() -> Void)? = nil
  var onTapSessions: (() -> Void)? = nil

  var body: some View {
    PulseCard {
      HStack(spacing: 0) {
        HeroTile(
          systemImage: "flame.fill",
          tint: PulseTheme.accent,
          value: "\(metrics.streak)",
          title: localizedString("streak"),
          trend: nil,
          onTap: onTapStreak
        )
        HeroTileDivider()
        HeroTile(
          systemImage: "scalemass.fill",
          tint: PulseTheme.primaryBright,
          value: volumeText,
          title: localizedString("volume_label"),
          trend: metrics.volumeDelta.map { HeroTrend(percent: $0) },
          onTap: onTapVolume
        )
        HeroTileDivider()
        HeroTile(
          systemImage: "dumbbell.fill",
          tint: PulseTheme.primary,
          value: "\(metrics.sessionsThisWeek)",
          title: localizedString("sessions"),
          trend: metrics.sessionsLastWeek > 0 ? HeroTrend(countDelta: metrics.sessionsDelta) : nil,
          onTap: onTapSessions
        )
      }
    }
  }

  private var volumeText: String {
    let v = metrics.volumeThisWeek
    if v >= 1000 {
      return String(format: "%.1ft", v / 1000)
    }
    return "\(Int(v.rounded())) kg"
  }
}

private struct HeroTileDivider: View {
  var body: some View {
    Rectangle()
      .fill(PulseTheme.separator)
      .frame(width: 1, height: 44)
  }
}

struct HeroTrend {
  let isUp: Bool
  let label: String

  init(percent: Double) {
    isUp = percent >= 0
    label = String(format: "%@%.0f%%", percent >= 0 ? "+" : "", percent)
  }

  init(countDelta: Int) {
    isUp = countDelta >= 0
    label = "\(countDelta >= 0 ? "+" : "")\(countDelta)"
  }
}

private struct HeroTile: View {
  let systemImage: String
  let tint: Color
  let value: String
  let title: String
  let trend: HeroTrend?
  var onTap: (() -> Void)? = nil

  var body: some View {
    if let onTap {
      Button {
        HapticService.selection()
        onTap()
      } label: { content }
      .buttonStyle(.plain)
    } else {
      content
    }
  }

  private var content: some View {
    VStack(spacing: 5) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(tint)

      Text(value)
        .font(.system(size: 19, weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      Text(title)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(1)

      if let trend {
        HStack(spacing: 2) {
          Image(systemName: trend.isUp ? "arrow.up.right" : "arrow.down.right")
            .font(.system(size: 8, weight: .black))
          Text(trend.label)
            .font(.system(size: 10, weight: .black, design: .rounded).monospacedDigit())
        }
        .foregroundStyle(trend.isUp ? PulseTheme.primaryBright : PulseTheme.destructive)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background((trend.isUp ? PulseTheme.primaryBright : PulseTheme.destructive).opacity(0.14), in: Capsule())
      } else {
        // Keep tiles vertically aligned when one has no trend badge.
        Color.clear.frame(height: 16)
      }
    }
    .frame(maxWidth: .infinity)
  }
}

private enum ProgressSection: String, CaseIterable, Identifiable {
  case general
  case exercises
  case muscles
  case cardio
  case body
  case load

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .general: "general_label"
    case .exercises: "exercises_3"
    case .muscles: "muscles_label"
    case .cardio: "cardio"
    case .body: "body_2"
    case .load: "load"
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
    case .week: "week_label"
    case .month: "month_label"
    case .year: "year_label"
    }
  }

  var subtitle: LocalizedStringKey {
    switch self {
    case .week: "this_week"
    case .month: "this_month"
    case .year: "this_year"
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
          Text(localizedFormat("weekly_sets_of_12_format", point.completedSets))
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
    point.completedSets >= 4 ? localizedString("growth_zone") : localizedFormat("sets_remaining_format", max(4 - point.completedSets, 0))
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
        Text(localizedString("streak"))
          .font(.system(size: 10, weight: .black, design: .rounded))
          .foregroundStyle(PulseTheme.secondaryText)
          .tracking(1.4)

        Text(
          "\(formattedDays) \(days == 1 ? (localizedString("day")) : (localizedString("days")))"
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

// MARK: - Cardio analytics (pace/distance, pace·HR, efficiency factor)

private struct CardioAnalyticsPoint: Identifiable {
  let id: UUID
  let date: Date
  let distanceKm: Double
  let paceSecPerKm: Double
  let avgHR: Double?
  let ef: Double?
}

private struct CardioAnalyticsCard: View {
  let logs: [CardioLog]
  let dateOfBirth: Date?

  enum Metric: String, CaseIterable, Identifiable {
    case paceDistance
    case paceHR
    case ef
    var id: String { rawValue }
    var title: String {
      switch self {
      case .paceDistance: return localizedString("pace_dist_label")
      case .paceHR: return localizedString("pace_hr_label")
      case .ef: return "EF"
      }
    }
  }

  enum DistanceBucket: String, CaseIterable, Identifiable {
    case all, sub1, r1to5, r5to10, r10to20, r20to40, r40plus
    var id: String { rawValue }
    var title: String {
      switch self {
      case .all: return localizedString("all_label")
      case .sub1: return "<1km"
      case .r1to5: return "1-5km"
      case .r5to10: return "5-10km"
      case .r10to20: return "10-20km"
      case .r20to40: return "20-40km"
      case .r40plus: return "40+km"
      }
    }
    func contains(_ km: Double) -> Bool {
      switch self {
      case .all: return true
      case .sub1: return km < 1
      case .r1to5: return km >= 1 && km < 5
      case .r5to10: return km >= 5 && km < 10
      case .r10to20: return km >= 10 && km < 20
      case .r20to40: return km >= 20 && km < 40
      case .r40plus: return km >= 40
      }
    }
  }

  @State private var metric: Metric = .paceDistance
  @State private var bucket: DistanceBucket = .all

  private var estimatedMaxHR: Double {
    guard let dob = dateOfBirth,
          let years = Calendar.current.dateComponents([.year], from: dob, to: .now).year,
          years > 0 else { return 190 }
    return Double(max(120, 220 - years))
  }

  private var points: [CardioAnalyticsPoint] {
    logs.compactMap { log -> CardioAnalyticsPoint? in
      guard let km = log.distanceKm, km > 0, log.durationMinutes > 0 else { return nil }
      guard bucket.contains(km) else { return nil }
      let minutes = Double(log.durationMinutes)
      let pace = minutes * 60.0 / km
      let ef = log.averageHeartRate.flatMap { hr -> Double? in
        hr > 0 ? (km * 1000.0 / minutes) / hr : nil
      }
      return CardioAnalyticsPoint(
        id: log.id, date: log.date, distanceKm: km,
        paceSecPerKm: pace, avgHR: log.averageHeartRate, ef: ef)
    }
  }

  private func zoneColor(_ hr: Double?) -> Color {
    guard let hr else { return PulseTheme.secondaryText }
    switch hr / estimatedMaxHR {
    case ..<0.6: return Color(red: 0.0, green: 0.48, blue: 1.0)
    case ..<0.7: return Color(red: 0.20, green: 0.80, blue: 0.35)
    case ..<0.8: return Color.yellow
    case ..<0.9: return Color.orange
    default: return Color.red
    }
  }

  private static func paceLabel(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "--" }
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("run_analysis")
          .font(.headline)

        Picker("metrics", selection: $metric) {
          ForEach(Metric.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(DistanceBucket.allCases) { option in
              let selected = bucket == option
              Button {
                bucket = option
              } label: {
                Text(option.title)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(selected ? .white : PulseTheme.secondaryText)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(selected ? PulseTheme.primary : PulseTheme.grouped)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }

        if points.isEmpty {
          PulseEmptyState(
            title: "no_enough_data",
            message: "record_runs_with_distance_message",
            systemImage: "chart.dots.scatter"
          )
        } else {
          chart
            .frame(height: 200)
            .allowsHitTesting(false)

          if metric != .ef {
            HStack(spacing: 12) {
              ForEach(Array(zip(["Z1", "Z2", "Z3", "Z4", "Z5"],
                                [0.55, 0.65, 0.75, 0.85, 0.95])), id: \.0) { name, frac in
                HStack(spacing: 4) {
                  Circle().fill(zoneColor(frac * estimatedMaxHR)).frame(width: 8, height: 8)
                  Text(name).font(.caption2).foregroundStyle(PulseTheme.secondaryText)
                }
              }
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var chart: some View {
    switch metric {
    case .paceDistance:
      Chart(points) { point in
        PointMark(
          x: .value(localizedString("distance_label"), point.distanceKm),
          y: .value(localizedString("pace_label"), point.paceSecPerKm)
        )
        .foregroundStyle(zoneColor(point.avgHR))
      }
      .chartYAxis { axisPaceMarks }
      .chartXAxisLabel("km")
    case .paceHR:
      Chart(points.filter { $0.avgHR != nil }) { point in
        PointMark(
          x: .value(localizedString("avg_hr_label"), point.avgHR ?? 0),
          y: .value(localizedString("pace_label"), point.paceSecPerKm)
        )
        .foregroundStyle(zoneColor(point.avgHR))
      }
      .chartYAxis { axisPaceMarks }
      .chartXAxisLabel("ppm")
    case .ef:
      Chart(points.filter { $0.ef != nil }.sorted { $0.date < $1.date }) { point in
        LineMark(
          x: .value(localizedString("date_label"), point.date),
          y: .value("EF", point.ef ?? 0)
        )
        .foregroundStyle(PulseTheme.primaryBright)
        PointMark(
          x: .value(localizedString("date_label"), point.date),
          y: .value("EF", point.ef ?? 0)
        )
        .foregroundStyle(PulseTheme.accent)
      }
      .chartYAxisLabel("m/min · ppm")
    }
  }

  private var axisPaceMarks: some AxisContent {
    AxisMarks { value in
      AxisGridLine()
      AxisValueLabel {
        if let seconds = value.as(Double.self) {
          Text(Self.paceLabel(seconds))
        }
      }
    }
  }
}

// MARK: - HR zone duration (time-in-zone aggregated by each session's average HR)

private struct HRZoneDurationCard: View {
  let logs: [CardioLog]
  let dateOfBirth: Date?

  private struct Zone: Identifiable {
    let id: Int
    let name: String
    let color: Color
  }

  private var zones: [Zone] {
    [
      Zone(id: 0, name: localizedString("zone_1_label"), color: Color(red: 0.0, green: 0.48, blue: 1.0)),
      Zone(id: 1, name: localizedString("zone_2_label"), color: Color(red: 0.20, green: 0.80, blue: 0.35)),
      Zone(id: 2, name: localizedString("zone_3_label"), color: .yellow),
      Zone(id: 3, name: localizedString("zone_4_label"), color: .orange),
      Zone(id: 4, name: localizedString("zone_5_label"), color: .red)
    ]
  }

  private var estimatedMaxHR: Double {
    guard let dob = dateOfBirth,
          let years = Calendar.current.dateComponents([.year], from: dob, to: .now).year,
          years > 0 else { return 190 }
    return Double(max(120, 220 - years))
  }

  private func zoneIndex(_ hr: Double) -> Int {
    switch hr / estimatedMaxHR {
    case ..<0.6: return 0
    case ..<0.7: return 1
    case ..<0.8: return 2
    case ..<0.9: return 3
    default: return 4
    }
  }

  private var minutesByZone: [Int] {
    var mins = [0, 0, 0, 0, 0]
    for log in logs {
      guard let hr = log.averageHeartRate, hr > 0 else { continue }
      mins[zoneIndex(hr)] += log.durationMinutes
    }
    return mins
  }

  var body: some View {
    let mins = minutesByZone
    let total = mins.reduce(0, +)
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("time_in_hr_zones")
          .font(.headline)

        if total == 0 {
          PulseEmptyState(
            title: "no_hr_data",
            message: "log_cardio_with_hr_message",
            systemImage: "heart"
          )
        } else {
          GeometryReader { geo in
            HStack(spacing: 2) {
              ForEach(zones) { zone in
                let frac = Double(mins[zone.id]) / Double(total)
                Rectangle()
                  .fill(zone.color)
                  .frame(width: max(geo.size.width * frac, frac > 0 ? 3 : 0))
              }
            }
            .clipShape(Capsule())
          }
          .frame(height: 14)

          ForEach(zones) { zone in
            HStack(spacing: 10) {
              Circle().fill(zone.color).frame(width: 10, height: 10)
              Text(zone.name).font(.subheadline)
              Spacer()
              Text("\(mins[zone.id]) min")
                .font(.subheadline.weight(.semibold).monospacedDigit())
              Text("(\(Int((Double(mins[zone.id]) / Double(total) * 100).rounded()))%)")
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(width: 46, alignment: .trailing)
            }
          }

          Text("estimated_from_each_session_average_hr")
            .font(.caption2)
            .foregroundStyle(PulseTheme.secondaryText)
        }
      }
    }
  }
}
