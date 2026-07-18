import Charts
import MuscleMap
import SwiftUI

private struct ProgressDashboardRenderInput: @unchecked Sendable {
  let key: ProgressDashboardRenderModel.Key
  let sessions: [WorkoutSession]
  let cardioLogs: [CardioLog]
  let healthMetrics: [DailyHealthMetric]
  let todayHealthMetric: DailyHealthMetric?
  let bodyMetrics: [BodyMetric]
  let exercises: [Exercise]
  let goals: [Goal]
  let activePlan: WorkoutPlan
}

private actor ProgressDashboardRenderWorker {
  static let shared = ProgressDashboardRenderWorker()

  func build(_ input: ProgressDashboardRenderInput) throws -> ProgressDashboardRenderModel {
    try Task.checkCancellation()
    let model = ProgressDashboardRenderModel.build(
      key: input.key,
      sessions: input.sessions,
      cardioLogs: input.cardioLogs,
      healthMetrics: input.healthMetrics,
      todayHealthMetric: input.todayHealthMetric,
      bodyMetrics: input.bodyMetrics,
      exercises: input.exercises,
      goals: input.goals,
      activePlan: input.activePlan
    )
    try Task.checkCancellation()
    return model
  }
}

// MARK: - Layout customization

/// The optional, reorderable/hideable cards on Progress, including the overview
/// bundle (`.overview`, first by default — training load + rings hero + today's
/// metric grid), fully reorderable/hideable like every other card.
private enum ProgressDashboardSection: String, CustomizableSection {
    case overview, trends, todayFocus, cardioEvolution, strengthEvolution, coreEvolution, explore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: localizedString("load")
        case .trends: localizedString("trends")
        case .todayFocus: localizedString("today")
        case .cardioEvolution: localizedString("evolucion_cardio")
        case .strengthEvolution: localizedString("evolucion_fuerza")
        case .coreEvolution: localizedString("evolucion_core")
        case .explore: localizedString("explore")
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "bolt.fill"
        case .trends: "chart.line.uptrend.xyaxis"
        case .todayFocus: "sun.max.fill"
        case .cardioEvolution: "figure.run"
        case .strengthEvolution: "figure.strengthtraining.traditional"
        case .coreEvolution: "figure.core.training"
        case .explore: "square.grid.2x2.fill"
        }
    }
}

struct ProgressDashboardView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedRange: ProgressRange = .week
  @State private var selectedSection: ProgressSection = .muscles
  @State private var activeDestination: ProgressDestination?
  @State private var sectionDetail: ProgressSection?
  @State private var metricDetail: SummaryMetricRoute?
  @State private var showNotifications = false
  @State private var showEditLayout = false
  @State private var goalToEdit: Goal?
  @State private var renderModel = ProgressDashboardRenderModel.empty

  var onSelectTab: ((AppTab) -> Void)? = nil

  var body: some View {
    NavigationStack {
      StickyHeaderScaffold(
        title: "summary",
        subtitle: currentDateSubtitle,
        accessory: {
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
      ) {

          ForEach(resolvedProgressSections.visible) { section in
            progressSectionView(for: section)
          }

          SecondaryButton("edit_layout", systemImage: "slider.horizontal.3") {
            HapticService.selection()
            showEditLayout = true
          }

      }
      .sheet(item: $goalToEdit) { goal in
        GoalEditorView(existingGoal: goal)
      }
      .sheet(isPresented: $showEditLayout) {
        let resolved = resolvedProgressSections
        SectionLayoutEditorSheet(
          title: localizedString("edit_layout"),
          visible: resolved.visible,
          hidden: resolved.hiddenAvailable
        ) { order, hiddenIDs in
          store.userProfile.progressSectionOrder = order
          store.userProfile.progressHiddenSectionIDs = hiddenIDs
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(isPresented: $showNotifications) {
        NotificationsView()
      }
      .navigationDestination(item: $activeDestination) { destination in
        switch destination {
        case .exerciseAnalytics:
          ExerciseAnalyticsListView(exercises: exercisesWithHistory, summaries: renderModel.exerciseProgressSummaries)
        case .workoutHistory:
          WorkoutHistoryView(sessions: filteredSessions.sorted { $0.date > $1.date })
        case .personalRecords:
          PersonalRecordsView()
        }
      }
      .navigationDestination(item: $sectionDetail) { section in
        sectionDetailScreen(for: section)
      }
      .navigationDestination(item: $metricDetail) { metric in
        metricDetailScreen(for: metric)
      }
      .navigationDestination(for: SummaryMetricRoute.self) { route in
        metricDetailScreen(for: route)
      }
      .task(id: renderModelKey) {
        await rebuildRenderModel(for: renderModelKey)
      }
    }
  }

  // MARK: - Layout customization

  private enum WorkoutCategory {
      case strength, cardio, core
  }

  private var latestWorkoutCategory: WorkoutCategory {
      guard let last = store.workoutSessions.sorted(by: { $0.date > $1.date }).first else {
          return .strength
      }
      if last.isRouteSession {
          return .cardio
      }
      let exercises = last.exerciseLogs?.map { $0.exercise.name.lowercased() } ?? []
      let coreCount = exercises.filter { name in
          name.contains("core") || name.contains("abs") || name.contains("abdom") || name.contains("plank")
      }.count
      if coreCount > 0 && coreCount >= exercises.count / 2 {
          return .core
      }
      return .strength
  }

  private var resolvedProgressSections: (visible: [ProgressDashboardSection], hiddenAvailable: [ProgressDashboardSection]) {
    let resolved = SectionLayoutResolver.resolve(
      storedOrder: store.userProfile.progressSectionOrder,
      storedHidden: store.userProfile.progressHiddenSectionIDs
    ) { (section: ProgressDashboardSection) -> Bool in
      switch section {
      case .overview, .todayFocus, .explore, .cardioEvolution, .strengthEvolution, .coreEvolution: return true
      case .trends: return !trendMetrics.isEmpty
      }
    }

    // Sort visible evolution sections based on latestWorkoutCategory:
    var visible = resolved.visible
    let category = latestWorkoutCategory
    let evoOrder: [ProgressDashboardSection] = {
        switch category {
        case .cardio: return [.cardioEvolution, .strengthEvolution, .coreEvolution]
        case .core: return [.coreEvolution, .strengthEvolution, .cardioEvolution]
        case .strength: return [.strengthEvolution, .cardioEvolution, .coreEvolution]
        }
    }()

    let evoSections: Set<ProgressDashboardSection> = [.cardioEvolution, .strengthEvolution, .coreEvolution]
    let presentEvos = visible.filter { evoSections.contains($0) }
    if !presentEvos.isEmpty {
        let sortedEvos = presentEvos.sorted { a, b in
            let indexA = evoOrder.firstIndex(of: a) ?? 99
            let indexB = evoOrder.firstIndex(of: b) ?? 99
            return indexA < indexB
        }
        var sortedIdx = 0
        for i in 0..<visible.count {
            if evoSections.contains(visible[i]) {
                visible[i] = sortedEvos[sortedIdx]
                sortedIdx += 1
            }
        }
    }

    return (visible: visible, hiddenAvailable: resolved.hiddenAvailable)
  }

  @ViewBuilder
  private var overviewSection: some View {
    TrainingLoadOverviewCard(
      battery: store.trainingBattery,
      workload: workload,
      onTap: { openSection(.load) }
    )

    // ── HOY: Anillos + métricas clave, inspirado en Fitness ───────────────
    SummaryRingsHeroCard(
      moveProgress: ringVolumeProgress,
      exerciseProgress: ringSessionsProgress,
      standProgress: ringConsistencyProgress,
      moveLabel: localizedString("volume_label").uppercased(),
      moveValue: "\(Int(heroMetrics.volumeThisWeek))",
      moveGoal: "kg",
      exerciseLabel: localizedString("sessions").uppercased(),
      exerciseValue: sessionsGoalDisplay,
      exerciseGoal: sessionsGoalSubtitle,
      exerciseCaption: sessionsGoalCaption,
      standLabel: localizedString("consistency").uppercased(),
      standValue: "\(weekActiveDays)/7",
      standGoal: localizedString("days").lowercased(),
      weeklyDays: heroMetrics.weekActivityDays,
      weekStart: heroMetrics.weekStart,
      dailyPoints: bodyFusionChartPoints,
      onTapMove: { handleMetricTap(.volume, range: .week) },
      onTapExercise: { handleMetricTap(.sessions) },
      onTapStand: { onSelectTab?(.calendar) }
    )

    LazyVGrid(columns: summaryGridColumns, spacing: 12) {
      Button { handleMetricTap(.steps, range: .today) } label: {
        TodayBarChartCard(
          icon: TrackedMetric.steps.systemImage,
          color: TrackedMetric.steps.tint,
          title: "steps_metric",
          value: stepsToday > 0 ? "\(stepsToday)" : "—",
          unit: localizedString("steps_2"),
          chartData: stepsWeekData,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)

      Button { handleMetricTap(.distance, range: .today) } label: {
        TodayBarChartCard(
          icon: TrackedMetric.distance.systemImage,
          color: TrackedMetric.distance.tint,
          title: "distance_label",
          value: distanceTodayKm > 0 ? String(format: "%.2f", distanceTodayKm) : "—",
          unit: "KM",
          chartData: distanceWeekData,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)

      Button { handleMetricTap(.activeEnergy, range: .today) } label: {
        TodayBarChartCard(
          icon: TrackedMetric.activeEnergy.systemImage,
          color: TrackedMetric.activeEnergy.tint,
          title: "active_kcal",
          value: activeEnergyToday > 0 ? "\(Int(activeEnergyToday))" : "—",
          unit: "KCAL",
          chartData: activeEnergyWeekData,
          showsChevron: true
        )
      }
      .buttonStyle(.plain)

      TodayMetricCard(
        icon: TrackedMetric.sessions.systemImage,
        color: TrackedMetric.sessions.tint,
        title: "sessions",
        value: "\(heroMetrics.sessionsThisWeek)",
        detail: "\(weekTotalMinutes) min \(localizedString("week_label").lowercased())"
      )
    }
  }

  @ViewBuilder
  private func progressSectionView(for section: ProgressDashboardSection) -> some View {
    switch section {
    case .overview:
      overviewSection
        .stickyHeaderTitle(section.title)
    case .trends:
      // ── TENDENCIAS (90 días vs 365, estilo Apple Fitness) ─
      TrendHighlightsCard(
        metrics: trendMetrics,
        sessionsThisWeek: heroMetrics.sessionsThisWeek,
        sessionsGoal: weeklySessionGoal,
        volumeThisWeek: Int(heroMetrics.volumeThisWeek),
        weekDays: heroMetrics.weekActivityDays
      )
      .stickyHeaderTitle(section.title)

      TrendsGridView(metrics: trendMetrics) { metric in
        handleTrendTap(metric)
      }
    case .todayFocus:
      DailySummaryFocusCard(
        readinessLevel: store.trainingBattery.level,
        todaySessions: todaySessions,
        dateOfBirth: store.userProfile.dateOfBirth,
        sessionsToday: todaySessionsCount,
        activeEnergyToday: Int(activeEnergyToday),
        stepsToday: stepsToday,
        exerciseMinutesWeek: weekHealthExerciseMinutes,
        hasHealthData: !weekHealthMetrics.isEmpty,
        hasManualData: heroMetrics.sessionsThisWeek > 0,
        onMetricTap: { handleMetricTap($0, range: .today) }
      )
      .stickyHeaderTitle(section.title)
    case .cardioEvolution:
      cardioEvolutionView
        .stickyHeaderTitle(section.title)
    case .strengthEvolution:
      strengthEvolutionView
        .stickyHeaderTitle(section.title)
    case .coreEvolution:
      coreEvolutionView
        .stickyHeaderTitle(section.title)
    case .explore:
      // ── EXPLORAR: pantallas de análisis detallado ────────
      VStack(spacing: 10) {
        ForEach(ProgressSection.allCases) { section in
          Button { openSection(section) } label: {
            ProgressSectionTile(
              section: section,
              isSelected: false,
              value: sectionValue(for: section),
              isLocked: section == .load && !store.hasFeatureAccess(.advancedAnalytics),
              showsChevron: true
            )
          }
          .buttonStyle(.plain)
        }
      }
      .stickyHeaderTitle(section.title)
    }
  }

  // MARK: - Section detail (pushed analytics screens)

  @ViewBuilder
  private func sectionDetailScreen(for section: ProgressSection) -> some View {
    StickyHeaderScaffold(
      title: section.titleKey,
      subtitle: "metric_2",
      backAction: { sectionDetail = nil },
      accessory: { EmptyView() }
    ) {
      Picker("range", selection: $selectedRange) {
        ForEach(ProgressRange.allCases) { range in
          Text(range.title).tag(range)
        }
      }
      .pickerStyle(.segmented)

      sectionDetailBody(for: section)
    }
    .toolbar(.hidden, for: .navigationBar)
    .onAppear { if selectedSection != section { selectedSection = section } }
  }

  private func sectionDetailBody(for selectedSection: ProgressSection) -> some View {
    VStack(alignment: .leading, spacing: 18) {
          if selectedSection == .general {
            ProgressExecutiveCard(
              sessions: filteredSessions.count,
              volumeKg: Int(FitnessMetrics.totalVolumeKg(for: filteredSessions)),
              bestEstimatedOneRepMaxKg: Int(store.bestEstimatedOneRepMaxKg),
              rangeTitle: selectedRange.subtitle,
              primaryInsight: insightCards.first,
              onOpenExercises: {
                if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                  activeDestination = .exerciseAnalytics
                }
              },
              onOpenHistory: {
                if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                  activeDestination = .workoutHistory
                }
              },
              onOpenPRs: {
                if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
                  activeDestination = .personalRecords
                }
              }
            )
            .stickyHeaderTitle(localizedString("overview"))

            HStack(spacing: 12) {
              NavigationLink {
                OneRepMaxCalculatorView()
              } label: {
                ProgressToolTile(
                  title: "calculadora_1rm",
                  subtitle: "estimate_your_maximum_strength_and_load_zones",
                  systemImage: "calculator.fill",
                  color: PulseTheme.accent
                )
              }
              .buttonStyle(.plain)

              NavigationLink {
                PlateCalculatorView()
              } label: {
                ProgressToolTile(
                  title: "plate_calculator",
                  subtitle: "knows_which_discs_to_load_on_each_side_of_the_bar",
                  systemImage: "circle.grid.3x3.fill",
                  color: PulseTheme.ringStand
                )
              }
              .buttonStyle(.plain)
            }

            NavigationLink {
              StrengthComparisonView()
            } label: {
              HStack(spacing: 14) {
                ZStack {
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 38, height: 38)
                  Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.headline.weight(.black))
                    .foregroundStyle(PulseTheme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                  Text(localizedKey("compare_strength"))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.primary)
                  Text(localizedKey("you_vs_your_past_self"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(PulseTheme.secondaryText.opacity(0.5))
              }
              .padding(14)
              .frame(maxWidth: .infinity)
              .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                  .stroke(PulseTheme.separator, lineWidth: 1)
              )
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
                    .foregroundStyle(PulseTheme.ringStand)
                  }
                  .frame(height: 140)
                  .allowsHitTesting(false)

                  VStack(spacing: 10) {
                    ForEach(walkingAndRunningLogs.prefix(6)) { log in
                      HStack(spacing: 12) {
                        Image(systemName: log.activityType == .walking ? "figure.walk" : "figure.run")
                          .foregroundStyle(PulseTheme.accent)
                          .frame(width: 34, height: 34)
                          .background(PulseTheme.accent.opacity(0.12))
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
                systemImage: "waveform.path.ecg", badgeColor: PulseTheme.accent, domain: .recovery)
              MetricCard(
                title: "effective_sets", value: "\(effectiveSetCount)",
                subtitle: "\(Int(effectiveVolume)) kg", systemImage: "checkmark.seal",
                badgeColor: PulseTheme.ringStand, domain: .strength)
            }

            HStack(spacing: 14) {
              MetricCard(
                title: "ACWR", value: String(format: "%.2f", workload.acwr),
                subtitle: "acute_chronic", systemImage: "gauge.with.needle",
                badgeColor: PulseTheme.accent, domain: .recovery)
              MetricCard(
                title: "fatigue_score", value: "\(Int(workload.fatigueScore))", subtitle: "0-100",
                systemImage: "bolt.slash", badgeColor: PulseTheme.warning, domain: .recovery)
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
                    .foregroundStyle(PulseTheme.accent)
                  }
                  .frame(height: 150)
                  .allowsHitTesting(false)
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
                  .allowsHitTesting(false)
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
                systemImage: "figure.walk", badgeColor: PulseTheme.accent, domain: .activity)
              MetricCard(
                title: "active_kcal", value: "\(Int(latestHealth.activeEnergyKcal))",
                subtitle: "last_day", systemImage: "flame", badgeColor: PulseTheme.accent, domain: .nutrition)
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                CardTitle("health_trends")
                Chart(store.health.latestDailyMetrics) { metric in
                  LineMark(x: .value(localizedString("date"), metric.date), y: .value(localizedString("steps"), metric.steps))
                    .foregroundStyle(PulseTheme.accent)
                  LineMark(
                    x: .value(localizedString("date"), metric.date),
                    y: .value(localizedString("active_kcal"), metric.activeEnergyKcal)
                  )
                  .foregroundStyle(PulseTheme.accent)
                }
                .frame(height: 160)
                .allowsHitTesting(false)
              }
            }
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
                      ExerciseProgressRow(exercise: exercise, summary: renderModel.exerciseProgressSummaries[exercise.id])
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
                  CardTitle("constancia")
                  Spacer()
                  Text(localizedFormat("sessions_count_format", consistencyTotal))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
                Chart(consistencyData) { point in
                  BarMark(
                    x: .value(localizedString("date"), point.date, unit: selectedRange.chartUnit),
                    y: .value(localizedString("workouts"), point.count)
                  )
                  .foregroundStyle(PulseTheme.accent)
                  if point.count > 0 {
                    PointMark(
                      x: .value(localizedString("date"), point.date, unit: selectedRange.chartUnit),
                      y: .value(localizedString("workouts"), point.count)
                    )
                    .foregroundStyle(PulseTheme.accent)
                  }
                }
                .frame(height: 160)
                .allowsHitTesting(false)
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
              }
            }
            goalsProgressSection
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
              if !muscleVolumePoints.isEmpty {
                PulseCard {
                  VStack(alignment: .leading, spacing: 14) {
                    CardTitle("volume_by_muscle_group")
                    MetricDonutChart(
                      slices: muscleVolumeDonutSlices,
                      centerValue: formattedTotalMuscleVolume,
                      centerLabel: "total_volume",
                      legendValueFormatter: { String(format: "%.0f kg", $0) }
                    )
                  }
                }
                .stickyHeaderTitle(localizedString("volume_by_muscle_group"))
              }

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
                CardTitle("insights_accionables")
                ForEach(Array(insightCards.enumerated()), id: \.element.id) { index, insight in
                  InsightRow(insight: insight)
                  if index < insightCards.count - 1 {
                    Divider()
                  }
                }
              }
            }

            if !store.monetization.hasProAccess {
              ProInsightsTeaserCard {
                store.presentPaywall(source: .proInsights, feature: nil, trigger: .featureGate)
              }
            }

          }
    }
  }

  // MARK: - Rings & metric navigation

  private var weekActiveDays: Int {
    heroMetrics.weekActivityDays.filter { $0 }.count
  }

  private var todaySessionsCount: Int {
    todaySessions.count
  }

  private var todaySessions: [WorkoutSession] {
    let today = Calendar.current.startOfDay(for: .now)
    return store.workoutSessions.filter { Calendar.current.startOfDay(for: $0.date) == today }
  }

  private var weeklySessionGoal: Int {
    max(store.activePlan.daysPerWeek, 1)
  }

  private var sessionsGoalDisplay: String {
    if store.activePlan.daysPerWeek > 0 {
      return "\(heroMetrics.sessionsThisWeek)/\(store.activePlan.daysPerWeek)"
    }
    return "\(heroMetrics.sessionsThisWeek)"
  }

  private var sessionsGoalSubtitle: String {
    if store.activePlan.daysPerWeek > 0 {
      return localizedString("week_label").lowercased()
    }
    return localizedString("sessions_2").lowercased()
  }

  private var sessionsGoalCaption: String {
    if store.activePlan.daysPerWeek > 0 {
      return localizedString("weekly_target")
    }
    return localizedString("this_week").lowercased()
  }

  /// Weekly volume vs. last week (ring laps when you beat it).
  private var ringVolumeProgress: Double {
    guard heroMetrics.volumeLastWeek > 0 else {
      return heroMetrics.volumeThisWeek > 0 ? 1 : 0
    }
    return min(heroMetrics.volumeThisWeek / heroMetrics.volumeLastWeek, 2.0)
  }

  private var ringSessionsProgress: Double {
    min(Double(heroMetrics.sessionsThisWeek) / Double(weeklySessionGoal), 2.0)
  }

  private var ringConsistencyProgress: Double {
    Double(weekActiveDays) / 7.0
  }

  private func handleMetricTap(_ metric: SummaryMetric, range: MetricDetailRange? = nil) {
    switch metric {
    case .sessions:
      openSection(.general)
    case .streak:
      onSelectTab?(.calendar)
    case .oneRepMax:
      if store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics) {
        activeDestination = .personalRecords
      }
    case .volume, .steps, .distance, .activeEnergy:
      HapticService.selection()
      metricDetail = SummaryMetricRoute(metric: metric, range: range ?? MetricDetailRange(progressRange: selectedRange))
    }
  }

  private func handleTrendTap(_ trend: TrendMetric) {
    guard let metric = trend.metric else { return }
    handleMetricTap(metric, range: MetricDetailRange(progressRange: selectedRange))
  }

  private func openSection(_ section: ProgressSection) {
    if section == .load, !store.hasFeatureAccess(.advancedAnalytics) {
      HapticService.notification(.warning)
      store.presentPaywall(source: .progressLoad, feature: .advancedAnalytics)
      return
    }
    HapticService.selection()
    selectedSection = section
    sectionDetail = section
  }

  // MARK: - Metric detail screens (Apple-Fitness-style drill-down)

  @ViewBuilder
  private func metricDetailScreen(for route: SummaryMetricRoute) -> some View {
    switch route.metric {
    case .steps:
      StepsView(initialRange: route.range)
    case .volume:
      ProgressMetricDetailView(
        title: localizedString("volume_label"),
        accent: TrackedMetric.volume.tint,
        unit: "KG",
        points: dailyVolumeSeries,
        initialRange: route.range,
        explanation: localizedString("metric_volume_explanation")
      )
    case .distance:
      ProgressMetricDetailView(
        title: localizedString("distance_label"),
        accent: TrackedMetric.distance.tint,
        unit: "KM",
        points: dailyDistanceSeries,
        initialRange: route.range,
        explanation: localizedString("metric_distance_explanation"),
        format: { String(format: "%.1f", $0) }
      )
    case .activeEnergy:
      ProgressMetricDetailView(
        title: localizedString("active_kcal"),
        accent: TrackedMetric.activeEnergy.tint,
        unit: "KCAL",
        points: dailyActiveEnergySeries,
        initialRange: route.range,
        explanation: localizedString("metric_active_energy_explanation")
      )
    case .sessions, .streak, .oneRepMax:
      EmptyView()
    }
  }

  private var last365Start: Date {
    let cal = Calendar.current
    return cal.date(byAdding: .day, value: -364, to: cal.startOfDay(for: .now)) ?? .now
  }

  private var dailyVolumeSeries: [MetricDetailPoint] {
    renderModel.dailyVolumeSeries
  }

  private var dailyDistanceSeries: [MetricDetailPoint] {
    renderModel.dailyDistanceSeries
  }

  private var dailyActiveEnergySeries: [MetricDetailPoint] {
    renderModel.dailyActiveEnergySeries
  }

  private var filteredSessions: [WorkoutSession] {
    renderModel.filteredSessions
  }

  /// At-a-glance snapshot of the current week (independent of the analytical
  /// range selector below) compared with the previous week.
  private var heroMetrics: ProgressHeroMetrics {
    renderModel.heroMetrics
  }

  private var currentDateSubtitle: String {
    let f = DateFormatter()
    f.locale = Locale(identifier: store.userProfile.preferredLanguage)
    f.dateFormat = "EEEE, d MMM"
    return f.string(from: Date()).capitalized(with: f.locale)
  }

  private var renderModelKey: ProgressDashboardRenderModel.Key {
    ProgressDashboardRenderModel.Key(
      range: selectedRange,
      sessionCount: store.workoutSessions.count,
      latestSessionDate: store.workoutSessions.map(\.date).max(),
      cardioCount: store.combinedCardioLogs.count,
      latestCardioDate: store.combinedCardioLogs.map(\.date).max(),
      healthCount: store.health.latestDailyMetrics.count,
      latestHealthDate: store.health.latestDailyMetrics.map(\.date).max(),
      bodyMetricCount: store.bodyMetrics.count,
      latestBodyMetricDate: store.bodyMetrics.map(\.date).max(),
      exerciseCount: store.exercises.count,
      goalCount: store.goals.count,
      activePlanID: store.activePlan.id,
      streakDays: store.streakDays,
      weeklyCompletion: store.weeklyCompletion,
      bestEstimatedOneRepMaxKg: store.bestEstimatedOneRepMaxKg
    )
  }

  private func rebuildRenderModel(for key: ProgressDashboardRenderModel.Key) async {
    // Capture immutable value snapshots on MainActor, then let the worker do
    // the collection-heavy analytics without starving SwiftUI's render loop.
    let input = ProgressDashboardRenderInput(
      key: key,
      sessions: store.workoutSessions,
      cardioLogs: store.combinedCardioLogs,
      healthMetrics: store.health.latestDailyMetrics,
      todayHealthMetric: store.todayHealthMetric,
      bodyMetrics: store.bodyMetrics,
      exercises: store.exercises,
      goals: store.goals,
      activePlan: store.activePlan
    )

    do {
      let model = try await ProgressDashboardRenderWorker.shared.build(input)
      try Task.checkCancellation()
      guard model.key == renderModelKey else { return }
      renderModel = model
    } catch is CancellationError {
      // SwiftUI cancels the previous task when the selected range or source
      // signature changes. Never let an obsolete result replace newer data.
    } catch {
      TelemetryService.shared.record(error, context: "progress.render_model")
    }
  }

  private var weekTotalMinutes: Int {
    renderModel.weekTotalMinutes
  }

  private var weekSessions: [WorkoutSession] {
    renderModel.weekSessions
  }

  private var weekHealthMetrics: [DailyHealthMetric] {
    renderModel.weekHealthMetrics
  }

  private var weekHealthSteps: Int {
    Int(weekHealthMetrics.map(\.steps).reduce(0, +))
  }

  private var weekHealthKcal: Int {
    Int(weekHealthMetrics.map(\.activeEnergyKcal).reduce(0, +))
  }

  private var weekHealthExerciseMinutes: Int {
    Int(weekHealthMetrics.compactMap(\.exerciseMinutes).reduce(0, +))
  }

  private var weekCardioDistanceKm: Double {
    renderModel.weekCardioDistanceKm
  }

  private var weekCompletedSets: Int {
    weekSessions.reduce(0) { $0 + FitnessMetrics.completedSets(in: $1).count }
  }

  private var weekAverageHeartRate: Double? {
    renderModel.weekAverageHeartRate
  }

  private var summaryGridColumns: [GridItem] {
    [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
  }

  private var stepsToday: Int {
    Int(store.todayHealthMetric?.steps ?? 0)
  }

  private var stepsWeekData: [TodayChartPoint] {
    renderModel.stepsWeekData
  }

  private var distanceTodayKm: Double {
    renderModel.distanceTodayKm
  }

  private var activeEnergyToday: Double {
    store.todayHealthMetric?.activeEnergyKcal ?? 0
  }

  private var activeEnergyWeekData: [TodayChartPoint] {
    renderModel.activeEnergyWeekData
  }

  private var distanceWeekData: [TodayChartPoint] {
    renderModel.distanceWeekData
  }

  private var monthSessions: Int {
    renderModel.monthSessions
  }

  private var monthVolumeKg: Int {
    renderModel.monthVolumeKg
  }

  private var yearSessions: Int {
    renderModel.yearSessions
  }

  private var yearVolumeKg: Int {
    renderModel.yearVolumeKg
  }

  private var weeklyConsistencyData: [ConsistencyPoint] {
    renderModel.weeklyConsistencyData
  }

  private var trendMetrics: [TrendMetric] {
    renderModel.trendMetrics
  }

  private var filteredCardioLogs: [CardioLog] {
    renderModel.filteredCardioLogs
  }

  private var workload: AnalyticsEngine.WorkloadSummary {
    renderModel.workload
  }

  private var competitiveSummary: AnalyticsEngine.CompetitiveSummary {
    renderModel.competitiveSummary
  }

  private var effectiveSetCount: Int {
    renderModel.effectiveSetCount
  }

  private var effectiveVolume: Double {
    renderModel.effectiveVolume
  }

  private var filteredCardioDistance: Double {
    renderModel.filteredCardioDistance
  }

  private var walkingAndRunningLogs: [CardioLog] {
    renderModel.walkingAndRunningLogs
  }

  private var intensityDistribution: [AnalyticsEngine.IntensityBucket] {
    renderModel.intensityDistribution
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
      parts.append("\(Int(heartRate)) \(localizedString("lpm"))")
    }
    return parts.isEmpty ? localizedString("no_sensors") : parts.joined(separator: " · ")
  }

  private var consistencyTotal: Int {
    consistencyData.reduce(0) { $0 + $1.count }
  }

  private var muscleVolumePoints: [FitnessMetrics.MuscleVolumePoint] {
    renderModel.muscleVolumePoints
  }

  private static let donutPalette: [Color] = [
    PulseTheme.accent, PulseTheme.ringStand, PulseTheme.ringExercise, PulseTheme.ringMove,
    PulseTheme.growth, PulseTheme.warning, .purple, PulseTheme.fitOrange,
  ]

  private var muscleVolumeDonutSlices: [DonutSlice] {
    muscleVolumePoints.prefix(donutPalette.count).enumerated().map { index, point in
      DonutSlice(label: point.muscleGroup, value: point.totalVolumeKg, color: donutPalette[index])
    }
  }

  private var donutPalette: [Color] { Self.donutPalette }

  private var formattedTotalMuscleVolume: String {
    let total = muscleVolumePoints.reduce(0) { $0 + $1.totalVolumeKg }
    if total >= 1000 {
      return String(format: "%.1fk kg", total / 1000)
    }
    return String(format: "%.0f kg", total)
  }

  @ViewBuilder
  private var goalsProgressSection: some View {
    if store.goals.isEmpty {
      PulseCard {
        PulseEmptyState(
          title: "goal_progress_empty_title",
          message: "goal_progress_empty_sub",
          systemImage: "target"
        )
      }
    } else {
      VStack(spacing: 8) {
        HStack {
          Text("goals_title")
            .font(.headline)
          Spacer()
          Text(localizedFormat("goal_summary_active_fmt", store.goals.filter { !$0.isAchieved }.count))
            .font(.subheadline)
            .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.horizontal, 4)
        ForEach(store.goals.prefix(3)) { goal in
          GoalCard(goal: goal) {
            goalToEdit = goal
          }
        }
        if store.goals.count > 3 {
          Text(localizedFormat("goal_more_fmt", store.goals.count - 3))
            .font(.caption)
            .foregroundStyle(PulseTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
        }
      }
    }
  }

  private var insightCards: [FitnessMetrics.TrainingInsight] {
    renderModel.insightCards
  }

  private var exercisesWithHistory: [Exercise] {
    renderModel.exercisesWithHistory
  }

  private func sectionValue(for section: ProgressSection) -> String {
    switch section {
    case .general:
      return "\(filteredSessions.count)"
    case .exercises:
      return "\(exercisesWithHistory.count)"
    case .muscles:
      return "\(competitiveSummary.actualWeeklySets)/\(max(competitiveSummary.targetWeeklySets, 1))"
    case .cardio:
      return "\(filteredCardioLogs.count)"
    case .body:
      return store.hasBodyMetrics ? "\(String(format: "%.0f", store.displayedWeight.value))" : "-"
    case .load:
      return "\(Int(workload.fatigueScore))"
    }
  }

  @ViewBuilder
  private var bodyProgressCard: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          CardTitle("body_and_wellness")
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
            LineMark(x: .value(localizedString("date"), metric.date), y: .value(localizedString("weight"), metric.weightKg))
              .foregroundStyle(PulseTheme.accent)
            PointMark(x: .value(localizedString("date"), metric.date), y: .value(localizedString("weight"), metric.weightKg))
              .foregroundStyle(PulseTheme.accent)
          }
          .frame(height: 150)
          .allowsHitTesting(false)

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

        Divider().opacity(0.12)

        BodyHealthFusionPanel(
          steps: weekHealthSteps,
          activeKcal: weekHealthKcal,
          exerciseMinutes: weekHealthExerciseMinutes,
          sessions: heroMetrics.sessionsThisWeek,
          volumeKg: Int(heroMetrics.volumeThisWeek),
          hrv: store.todayHealthMetric?.heartRateVariabilityMS,
          restingHeartRate: store.todayHealthMetric?.restingHeartRate,
          fatigueScore: workload.fatigueScore,
          dataPoints: bodyFusionChartPoints
        )
      }
    }
  }

  private var bodyFusionChartPoints: [BodyFusionPoint] {
    renderModel.bodyFusionChartPoints
  }

  private var consistencyData: [ConsistencyPoint] {
    renderModel.consistencyData
  }

  private var cardioSessions: [WorkoutSession] {
      store.workoutSessions.filter { $0.isRouteSession }
  }

  private var strengthSessions: [WorkoutSession] {
      store.workoutSessions.filter { !$0.isRouteSession && !isCoreSession($0) }
  }

  private var coreSessions: [WorkoutSession] {
      store.workoutSessions.filter { !$0.isRouteSession && isCoreSession($0) }
  }

  private func isCoreSession(_ session: WorkoutSession) -> Bool {
      let title = session.workoutTitle.lowercased()
      if title.contains("core") || title.contains("abs") || title.contains("abdom") {
          return true
      }
      let exercises = session.exerciseLogs?.map { $0.exercise.name.lowercased() } ?? []
      let coreCount = exercises.filter { name in
          name.contains("core") || name.contains("abs") || name.contains("abdom") || name.contains("plank")
      }.count
      return coreCount > 0 && coreCount >= exercises.count / 2
  }

  private func averageHeartRate(for sessions: [WorkoutSession]) -> Double? {
      let hrs = sessions.compactMap(\.averageHeartRate)
      guard !hrs.isEmpty else { return nil }
      return hrs.reduce(0.0, +) / Double(hrs.count)
  }

  private func averageRPE(for sessions: [WorkoutSession]) -> Double? {
      let rpes = sessions.compactMap(\.sessionRPE)
      guard !rpes.isEmpty else { return nil }
      return rpes.reduce(0.0, +) / Double(rpes.count)
  }

  /// One point per calendar day, so several sessions on the same date never
  /// draw as vertical zigzags, and days whose sessions carry no value (e.g. a
  /// walk without distance yet) don't drag the line down to a false 0.
  private func evolutionDailyPoints(
      for sessions: [WorkoutSession],
      value: (WorkoutSession) -> Double
  ) -> [EvolutionDayPoint] {
      let calendar = Calendar.current
      let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
      let points = byDay
          .map { day, items in EvolutionDayPoint(date: day, value: items.reduce(0) { $0 + value($1) }) }
          .filter { $0.value > 0 }
          .sorted { $0.date < $1.date }
      return Array(points.suffix(7))
  }

  /// Sessions inside the same window the chart draws, so the headline metrics
  /// describe what the user sees instead of an unbounded all-time total.
  private func evolutionWindowSessions(
      _ sessions: [WorkoutSession],
      chartedDays: [EvolutionDayPoint]
  ) -> [WorkoutSession] {
      guard let start = chartedDays.first?.date else {
          let calendar = Calendar.current
          let fallbackStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
          return sessions.filter { $0.date >= fallbackStart }
      }
      return sessions.filter { $0.date >= start }
  }

  @ViewBuilder
  private var cardioEvolutionView: some View {
      let sessions = cardioSessions.sorted { $0.date < $1.date }
      let chartedDays = evolutionDailyPoints(for: sessions) { $0.distanceKm ?? 0 }
      let windowSessions = evolutionWindowSessions(sessions, chartedDays: chartedDays)
      let totalDistance = windowSessions.compactMap(\.distanceKm).reduce(0.0, +)
      let totalMinutes = windowSessions.reduce(0) { $0 + $1.durationMinutes }

      PulseCard {
          VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 8) {
                  Image(systemName: "figure.run")
                      .font(.title3)
                      .foregroundStyle(Color.blue)
                  
                  VStack(alignment: .leading, spacing: 2) {
                      Text(localizedString("evolucion_cardio"))
                          .font(.system(size: 14, weight: .bold, design: .rounded))
                          .foregroundStyle(PulseTheme.textPrimary)
                      Text(localizedString("trends_and_distance"))
                          .font(.system(size: 10, weight: .bold))
                          .foregroundStyle(PulseTheme.secondaryText)
                  }
                  Spacer()
                  
                  if latestWorkoutCategory == .cardio {
                      Text(localizedString("last_workout_cardio"))
                          .font(.system(size: 9, weight: .black))
                          .foregroundStyle(Color.blue)
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(Color.blue.opacity(0.12), in: Capsule())
                  }
              }
              
              if sessions.isEmpty {
                  PulseEmptyState(
                      title: LocalizedStringKey(localizedString("no_cardio_sessions")),
                      message: LocalizedStringKey(localizedString("start_cardio_to_see_trends")),
                      systemImage: "figure.walk"
                  )
              } else {
                  HStack(spacing: 12) {
                      MetricInline(title: "distance_label", value: String(format: "%.1f km", totalDistance))
                      MetricInline(title: "duration_2", value: "\(totalMinutes) min")
                      if let avgHR = averageHeartRate(for: windowSessions) {
                          MetricInline(title: "avg_hr_2", value: "\(Int(avgHR)) \(localizedString("lpm").uppercased())")
                      }
                  }
                  .padding(.vertical, 4)

                  if !chartedDays.isEmpty {
                      Chart(chartedDays) { day in
                          AreaMark(
                              x: .value(localizedString("date_2"), day.date, unit: .day),
                              y: .value(localizedString("distance_label"), day.value)
                          )
                          .foregroundStyle(
                              LinearGradient(
                                  colors: [Color.blue.opacity(0.24), Color.blue.opacity(0)],
                                  startPoint: .top,
                                  endPoint: .bottom
                              )
                          )

                          LineMark(
                              x: .value(localizedString("date_2"), day.date, unit: .day),
                              y: .value(localizedString("distance_label"), day.value)
                          )
                          .foregroundStyle(Color.blue)
                          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                          PointMark(
                              x: .value(localizedString("date_2"), day.date, unit: .day),
                              y: .value(localizedString("distance_label"), day.value)
                          )
                          .foregroundStyle(Color.blue)
                      }
                      .frame(height: 100)
                      .chartXAxis {
                          AxisMarks(values: .automatic) { _ in
                              AxisGridLine().foregroundStyle(PulseTheme.separator)
                              AxisTick().foregroundStyle(PulseTheme.separator)
                              AxisValueLabel(format: .dateTime.day().month(), centered: true)
                                  .foregroundStyle(PulseTheme.secondaryText)
                                  .font(.system(size: 8, weight: .bold))
                          }
                      }
                      .chartYAxis {
                          AxisMarks(position: .leading) { _ in
                              AxisGridLine().foregroundStyle(PulseTheme.separator)
                              AxisValueLabel()
                                  .foregroundStyle(PulseTheme.secondaryText)
                                  .font(.system(size: 8, weight: .bold))
                          }
                      }
                      .allowsHitTesting(false)
                  }
              }
          }
      }
  }

  @ViewBuilder
  private var strengthEvolutionView: some View {
      let sessions = strengthSessions.sorted { $0.date < $1.date }
      let chartedDays = evolutionDailyPoints(for: sessions) { FitnessMetrics.totalVolumeKg(for: [$0]) }
      let windowSessions = evolutionWindowSessions(sessions, chartedDays: chartedDays)
      let totalVolume = windowSessions.reduce(0.0) { $0 + FitnessMetrics.totalVolumeKg(for: [$1]) }
      let totalSets = windowSessions.reduce(0) { $0 + $1.sets.count }

      PulseCard {
          VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 8) {
                  Image(systemName: "figure.strengthtraining.traditional")
                      .font(.title3)
                      .foregroundStyle(Color.orange)
                  
                  VStack(alignment: .leading, spacing: 2) {
                      Text(localizedString("evolucion_fuerza"))
                          .font(.system(size: 14, weight: .bold, design: .rounded))
                          .foregroundStyle(PulseTheme.textPrimary)
                      Text(localizedString("volume_and_intensity"))
                          .font(.system(size: 10, weight: .bold))
                          .foregroundStyle(PulseTheme.secondaryText)
                  }
                  Spacer()
                  
                  if latestWorkoutCategory == .strength {
                      Text(localizedString("last_workout_strength"))
                          .font(.system(size: 9, weight: .black))
                          .foregroundStyle(Color.orange)
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(Color.orange.opacity(0.12), in: Capsule())
                  }
              }
              
              if sessions.isEmpty {
                  PulseEmptyState(
                      title: LocalizedStringKey(localizedString("no_strength_sessions")),
                      message: LocalizedStringKey(localizedString("start_strength_to_see_trends")),
                      systemImage: "figure.strengthtraining.traditional"
                  )
              } else {
                  HStack(spacing: 12) {
                      MetricInline(title: "total_volume", value: "\(Int(totalVolume)) kg")
                      MetricInline(title: "completed_sets", value: "\(totalSets) \(localizedString("series"))")
                      if store.bestEstimatedOneRepMaxKg > 0 {
                          MetricInline(title: "best_1rm_estimated", value: "\(Int(store.bestEstimatedOneRepMaxKg)) kg")
                      }
                  }
                  .padding(.vertical, 4)

                  if !chartedDays.isEmpty {
                      Chart(chartedDays) { day in
                          BarMark(
                              x: .value(localizedString("date_2"), day.date, unit: .day),
                              y: .value(localizedString("volume_label"), day.value)
                          )
                          .foregroundStyle(
                              LinearGradient(
                                  colors: [Color.orange, Color.orange.opacity(0.6)],
                                  startPoint: .top,
                                  endPoint: .bottom
                              )
                          )
                          .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                      }
                      .frame(height: 100)
                      .chartXAxis {
                          AxisMarks(values: .automatic) { _ in
                              AxisGridLine().foregroundStyle(PulseTheme.separator)
                              AxisValueLabel(format: .dateTime.day().month(), centered: true)
                                  .foregroundStyle(PulseTheme.secondaryText)
                                  .font(.system(size: 8, weight: .bold))
                          }
                      }
                      .chartYAxis {
                          AxisMarks(position: .leading) { _ in
                              AxisGridLine().foregroundStyle(PulseTheme.separator)
                              AxisValueLabel()
                                  .foregroundStyle(PulseTheme.secondaryText)
                                  .font(.system(size: 8, weight: .bold))
                          }
                      }
                      .allowsHitTesting(false)
                  }
              }
          }
      }
  }

  @ViewBuilder
  private var coreEvolutionView: some View {
      let sessions = coreSessions.sorted { $0.date < $1.date }
      let chartedDays = evolutionDailyPoints(for: sessions) { Double($0.durationMinutes) }
      let windowSessions = evolutionWindowSessions(sessions, chartedDays: chartedDays)
      let totalSessions = windowSessions.count
      let totalMinutes = windowSessions.reduce(0) { $0 + $1.durationMinutes }

      PulseCard {
          VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 8) {
                  Image(systemName: "figure.core.training")
                      .font(.title3)
                      .foregroundStyle(Color.purple)
                  
                  VStack(alignment: .leading, spacing: 2) {
                      Text(localizedString("evolucion_core"))
                          .font(.system(size: 14, weight: .bold, design: .rounded))
                          .foregroundStyle(PulseTheme.textPrimary)
                      Text(localizedString("stability_and_consistency"))
                          .font(.system(size: 10, weight: .bold))
                          .foregroundStyle(PulseTheme.secondaryText)
                  }
                  Spacer()
                  
                  if latestWorkoutCategory == .core {
                      Text(localizedString("last_workout_core"))
                          .font(.system(size: 9, weight: .black))
                          .foregroundStyle(Color.purple)
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(Color.purple.opacity(0.12), in: Capsule())
                  }
              }
              
              if sessions.isEmpty {
                  PulseEmptyState(
                      title: LocalizedStringKey(localizedString("no_core_sessions")),
                      message: LocalizedStringKey(localizedString("start_core_to_see_trends")),
                      systemImage: "figure.core.training"
                  )
              } else {
                  HStack(spacing: 12) {
                      MetricInline(title: "sessions", value: "\(totalSessions)")
                      MetricInline(title: "duration_2", value: "\(totalMinutes) min")
                      if let avgRPE = averageRPE(for: windowSessions) {
                          MetricInline(title: "avg_rpe", value: String(format: "%.1f", avgRPE))
                      }
                  }
                  .padding(.vertical, 4)

                  if !chartedDays.isEmpty {
                      Chart(chartedDays) { day in
                          LineMark(
                              x: .value(localizedString("date_2"), day.date, unit: .day),
                              y: .value(localizedString("duration_label"), day.value)
                          )
                          .foregroundStyle(Color.purple)
                          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                          PointMark(
                              x: .value(localizedString("date_2"), day.date, unit: .day),
                              y: .value(localizedString("duration_label"), day.value)
                          )
                          .foregroundStyle(Color.purple)
                      }
                      .frame(height: 100)
                      .chartXAxis {
                          AxisMarks(values: .automatic) { _ in
                              AxisGridLine().foregroundStyle(PulseTheme.separator)
                              AxisValueLabel(format: .dateTime.day().month(), centered: true)
                                  .foregroundStyle(PulseTheme.secondaryText)
                                  .font(.system(size: 8, weight: .bold))
                          }
                      }
                      .chartYAxis {
                          AxisMarks(position: .leading) { _ in
                              AxisGridLine().foregroundStyle(PulseTheme.separator)
                              AxisValueLabel()
                                  .foregroundStyle(PulseTheme.secondaryText)
                                  .font(.system(size: 8, weight: .bold))
                          }
                      }
                      .allowsHitTesting(false)
                  }
              }
          }
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

private struct EvolutionDayPoint: Identifiable {
  let date: Date
  let value: Double

  var id: Date { date }
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

struct ProgressDashboardRenderModel: @unchecked Sendable {
  struct ExerciseProgressSummary {
    let loggedDaysCount: Int
    let totalVolumeKg: Double
  }

  struct Key: Equatable {
    let range: ProgressRange
    let sessionCount: Int
    let latestSessionDate: Date?
    let cardioCount: Int
    let latestCardioDate: Date?
    let healthCount: Int
    let latestHealthDate: Date?
    let bodyMetricCount: Int
    let latestBodyMetricDate: Date?
    let exerciseCount: Int
    let goalCount: Int
    let activePlanID: UUID
    let streakDays: Int
    let weeklyCompletion: Double
    let bestEstimatedOneRepMaxKg: Double
  }

  let key: Key?
  let heroMetrics: ProgressHeroMetrics
  let dailyVolumeSeries: [MetricDetailPoint]
  let dailyDistanceSeries: [MetricDetailPoint]
  let dailyActiveEnergySeries: [MetricDetailPoint]
  let filteredSessions: [WorkoutSession]
  let weekSessions: [WorkoutSession]
  let weekHealthMetrics: [DailyHealthMetric]
  let weekTotalMinutes: Int
  let stepsWeekData: [TodayChartPoint]
  let distanceWeekData: [TodayChartPoint]
  let activeEnergyWeekData: [TodayChartPoint]
  let weeklyConsistencyData: [ConsistencyPoint]
  let trendMetrics: [TrendMetric]
  let filteredCardioLogs: [CardioLog]
  let workload: AnalyticsEngine.WorkloadSummary
  let competitiveSummary: AnalyticsEngine.CompetitiveSummary
  let effectiveSetCount: Int
  let effectiveVolume: Double
  let filteredCardioDistance: Double
  let walkingAndRunningLogs: [CardioLog]
  let intensityDistribution: [AnalyticsEngine.IntensityBucket]
  let muscleVolumePoints: [FitnessMetrics.MuscleVolumePoint]
  let insightCards: [FitnessMetrics.TrainingInsight]
  let exercisesWithHistory: [Exercise]
  let exerciseProgressSummaries: [UUID: ExerciseProgressSummary]
  let bodyFusionChartPoints: [BodyFusionPoint]
  let consistencyData: [ConsistencyPoint]
  // Supplementary stats computed once per rebuild
  let monthSessions: Int
  let monthVolumeKg: Int
  let yearSessions: Int
  let yearVolumeKg: Int
  let weekCardioDistanceKm: Double
  let weekAverageHeartRate: Double?
  let distanceTodayKm: Double

  static let empty = ProgressDashboardRenderModel(
    key: nil,
    heroMetrics: ProgressHeroMetrics(
      streak: 0,
      adherence: 0,
      sessionsThisWeek: 0,
      sessionsLastWeek: 0,
      volumeThisWeek: 0,
      volumeLastWeek: 0,
      weekStart: Calendar.current.startOfDay(for: .now),
      weekActivityDays: Array(repeating: false, count: 7)
    ),
    dailyVolumeSeries: [],
    dailyDistanceSeries: [],
    dailyActiveEnergySeries: [],
    filteredSessions: [],
    weekSessions: [],
    weekHealthMetrics: [],
    weekTotalMinutes: 0,
    stepsWeekData: [],
    distanceWeekData: [],
    activeEnergyWeekData: [],
    weeklyConsistencyData: [],
    trendMetrics: [],
    filteredCardioLogs: [],
    workload: AnalyticsEngine.WorkloadSummary(acuteLoad: 0, chronicLoad: 0, acwr: 0, fatigueScore: 0),
    competitiveSummary: AnalyticsEngine.CompetitiveSummary(
      completedWorkouts: 0,
      plannedWorkouts: 0,
      completionRate: 0,
      targetWeeklySets: 0,
      actualWeeklySets: 0,
      muscleTargets: [],
      undertrainedMuscles: [],
      overtrainedMuscles: [],
      stalledExercises: [],
      recommendations: []
    ),
    effectiveSetCount: 0,
    effectiveVolume: 0,
    filteredCardioDistance: 0,
    walkingAndRunningLogs: [],
    intensityDistribution: AnalyticsEngine.intensityDistribution(for: []),
    muscleVolumePoints: [],
    insightCards: [],
    exercisesWithHistory: [],
    exerciseProgressSummaries: [:],
    bodyFusionChartPoints: [],
    consistencyData: [],
    monthSessions: 0,
    monthVolumeKg: 0,
    yearSessions: 0,
    yearVolumeKg: 0,
    weekCardioDistanceKm: 0,
    weekAverageHeartRate: nil,
    distanceTodayKm: 0
  )

  static func build(
    key: Key,
    sessions: [WorkoutSession],
    cardioLogs: [CardioLog],
    healthMetrics: [DailyHealthMetric],
    todayHealthMetric: DailyHealthMetric?,
    bodyMetrics: [BodyMetric],
    exercises: [Exercise],
    goals: [Goal],
    activePlan: WorkoutPlan
  ) -> ProgressDashboardRenderModel {
    let interval = PerformanceSignpost.begin(
      "progress.renderModel",
      "sessions=\(sessions.count) cardio=\(cardioLogs.count) health=\(healthMetrics.count) range=\(key.range.rawValue)"
    )
    defer {
      PerformanceSignpost.end("progress.renderModel", interval)
    }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let rangeStart = key.range.startDate
    let last365Start = calendar.date(byAdding: .day, value: -364, to: today) ?? today
    let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart

    let filteredSessions = sessions.filter { $0.date >= rangeStart }
    let filteredCardioLogs = cardioLogs.filter { $0.date >= rangeStart }
    let weekSessions = sessions.filter { $0.date >= thisWeekStart }
    let lastWeekSessions = sessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
    let weekHealthMetrics = healthMetrics.filter { $0.date >= thisWeekStart }
    let healthByDay = Dictionary(grouping: healthMetrics) { calendar.startOfDay(for: $0.date) }
    let cardioByDay = Dictionary(grouping: cardioLogs) { calendar.startOfDay(for: $0.date) }
    let sessionsByDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }

    let weekActivityDays: [Bool] = (0..<7).map { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: thisWeekStart) else { return false }
      return !(sessionsByDay[calendar.startOfDay(for: date)] ?? []).isEmpty
    }

    let heroMetrics = ProgressHeroMetrics(
      streak: key.streakDays,
      adherence: key.weeklyCompletion,
      sessionsThisWeek: weekSessions.count,
      sessionsLastWeek: lastWeekSessions.count,
      volumeThisWeek: FitnessMetrics.totalVolumeKg(for: weekSessions),
      volumeLastWeek: FitnessMetrics.totalVolumeKg(for: lastWeekSessions),
      totalSessions: sessions.count,
      totalVolumeKg: FitnessMetrics.totalVolumeKg(for: sessions),
      weekStart: thisWeekStart,
      weekActivityDays: weekActivityDays
    )

    let dailyVolumeSeries = Dictionary(grouping: sessions.filter { $0.date >= last365Start }) {
      calendar.startOfDay(for: $0.date)
    }
    .map { day, sessions in
      MetricDetailPoint(date: day, value: FitnessMetrics.totalVolumeKg(for: sessions))
    }
    .sorted { $0.date < $1.date }

    let dailyDistanceSeries = Dictionary(grouping: cardioLogs.filter { $0.date >= last365Start }) {
      calendar.startOfDay(for: $0.date)
    }
    .compactMap { day, logs -> MetricDetailPoint? in
      let km = logs.compactMap(\.distanceKm).reduce(0, +)
      return km > 0 ? MetricDetailPoint(date: day, value: km) : nil
    }
    .sorted { $0.date < $1.date }

    let dailyActiveEnergySeries = healthMetrics
      .filter { $0.date >= last365Start && $0.activeEnergyKcal > 0 }
      .map { MetricDetailPoint(date: $0.date, value: $0.activeEnergyKcal) }
      .sorted { $0.date < $1.date }

    let symbols = calendar.veryShortWeekdaySymbols
    let healthWeekSeries: ((DailyHealthMetric?) -> Double) -> [TodayChartPoint] = { value in
      (0..<7).compactMap { offset -> TodayChartPoint? in
        guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
        let metric = healthByDay[date]?.last
        let weekday = calendar.component(.weekday, from: date)
        return TodayChartPoint(label: symbols[weekday - 1].uppercased(), value: value(metric), isToday: date == today)
      }
    }
    let stepsWeekData = healthWeekSeries { $0?.steps ?? 0 }
    let activeEnergyWeekData = healthWeekSeries { $0?.activeEnergyKcal ?? 0 }
    let distanceWeekData = (0..<7).compactMap { offset -> TodayChartPoint? in
      guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
      let day = calendar.startOfDay(for: date)
      let km = (cardioByDay[day] ?? []).compactMap(\.distanceKm).reduce(0, +)
      let weekday = calendar.component(.weekday, from: date)
      return TodayChartPoint(label: symbols[weekday - 1].uppercased(), value: km, isToday: day == today)
    }

    let weeklyConsistencyData = (0..<7).compactMap { offset -> ConsistencyPoint? in
      guard let date = calendar.date(byAdding: .day, value: offset, to: thisWeekStart) else { return nil }
      let day = calendar.startOfDay(for: date)
      return ConsistencyPoint(date: date, count: sessionsByDay[day]?.count ?? 0)
    }

    let trendMetrics = buildTrendMetrics(
      sessions: sessions,
      healthMetrics: healthMetrics,
      streakDays: key.streakDays,
      bestEstimatedOneRepMaxKg: key.bestEstimatedOneRepMaxKg,
      today: today,
      calendar: calendar
    )

    let completedExerciseLogs = sessions.flatMap(FitnessMetrics.completedExerciseLogs(in:))
    let loggedExerciseIDs = Set(completedExerciseLogs.map(\.exercise.id))
    let loggedExerciseNames = Set(completedExerciseLogs.map(\.exercise.name))
    let exercisesWithHistory = exercises.filter { exercise in
      loggedExerciseIDs.contains(exercise.id) || loggedExerciseNames.contains(exercise.name)
    }
    // Precomputed once here (background actor) instead of `ExerciseProgressRow`
    // calling `FitnessMetrics.progressPoints` against the full session history
    // directly from `body` for every row shown on screen.
    let exerciseProgressSummaries = Dictionary(uniqueKeysWithValues: exercisesWithHistory.map { exercise in
      let points = FitnessMetrics.progressPoints(for: exercise, in: sessions)
      let summary = ProgressDashboardRenderModel.ExerciseProgressSummary(
        loggedDaysCount: points.count,
        totalVolumeKg: points.map(\.totalVolumeKg).reduce(0, +)
      )
      return (exercise.id, summary)
    })

    let workload = AnalyticsEngine.workloadSummary(sessions: sessions, bodyMetrics: bodyMetrics)
    let competitiveSummary = AnalyticsEngine.competitiveSummary(
      sessions: sessions,
      activePlan: activePlan,
      exercises: exercisesWithHistory,
      since: rangeStart
    )
    let effectiveSetCount = filteredSessions.reduce(0) { $0 + AnalyticsEngine.effectiveSets(in: $1).count }
    let effectiveVolume = AnalyticsEngine.effectiveVolumeKg(for: filteredSessions)
    let filteredCardioDistance = filteredCardioLogs.compactMap(\.distanceKm).reduce(0, +)
    let walkingAndRunningLogs = filteredCardioLogs
      .filter { $0.activityType == .walking || $0.activityType == .outdoorRun }
      .sorted { $0.date > $1.date }
    let intensityDistribution = AnalyticsEngine.intensityDistribution(for: filteredSessions)
    let muscleVolumePoints = FitnessMetrics.muscleVolumePoints(for: sessions, since: rangeStart)
    let insightCards = FitnessMetrics.insightCards(for: sessions, goals: goals, since: rangeStart)
    let weekSessionsByDay = Dictionary(grouping: weekSessions) { calendar.startOfDay(for: $0.date) }
    let weekHealthByDay = Dictionary(grouping: weekHealthMetrics) { calendar.startOfDay(for: $0.date) }
    let bodyFusionChartPoints = (0..<7).compactMap { offset -> BodyFusionPoint? in
      guard let date = calendar.date(byAdding: .day, value: offset, to: thisWeekStart) else { return nil }
      let day = calendar.startOfDay(for: date)
      let health = weekHealthByDay[day]?.first
      return BodyFusionPoint(
        date: day,
        activity: health?.activeEnergyKcal ?? 0,
        volume: FitnessMetrics.totalVolumeKg(for: weekSessionsByDay[day] ?? [])
      )
    }

    let rangeGroupedSessions = Dictionary(grouping: filteredSessions) { calendar.startOfDay(for: $0.date) }
    let consistencyData = (0..<key.range.days).compactMap { offset -> ConsistencyPoint? in
      guard let date = calendar.date(byAdding: .day, value: offset, to: rangeStart) else { return nil }
      return ConsistencyPoint(date: date, count: rangeGroupedSessions[calendar.startOfDay(for: date)]?.count ?? 0)
    }

    // Supplementary stats
    let monthStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
    let yearStart = calendar.date(byAdding: .day, value: -364, to: today) ?? today
    let monthSessionsList = sessions.filter { $0.date >= monthStart }
    let yearSessionsList = sessions.filter { $0.date >= yearStart }
    let weekCardioLogs = cardioLogs.filter { $0.date >= thisWeekStart }
    let todayCardioLogs = cardioLogs.filter { calendar.startOfDay(for: $0.date) == today }
    let weekHRValues = weekCardioLogs.compactMap(\.averageHeartRate)

    return ProgressDashboardRenderModel(
      key: key,
      heroMetrics: heroMetrics,
      dailyVolumeSeries: dailyVolumeSeries,
      dailyDistanceSeries: dailyDistanceSeries,
      dailyActiveEnergySeries: dailyActiveEnergySeries,
      filteredSessions: filteredSessions,
      weekSessions: weekSessions,
      weekHealthMetrics: weekHealthMetrics,
      weekTotalMinutes: weekSessions.reduce(0) { $0 + $1.durationMinutes },
      stepsWeekData: stepsWeekData,
      distanceWeekData: distanceWeekData,
      activeEnergyWeekData: activeEnergyWeekData,
      weeklyConsistencyData: weeklyConsistencyData,
      trendMetrics: trendMetrics,
      filteredCardioLogs: filteredCardioLogs,
      workload: workload,
      competitiveSummary: competitiveSummary,
      effectiveSetCount: effectiveSetCount,
      effectiveVolume: effectiveVolume,
      filteredCardioDistance: filteredCardioDistance,
      walkingAndRunningLogs: walkingAndRunningLogs,
      intensityDistribution: intensityDistribution,
      muscleVolumePoints: muscleVolumePoints,
      insightCards: insightCards,
      exercisesWithHistory: exercisesWithHistory,
      exerciseProgressSummaries: exerciseProgressSummaries,
      bodyFusionChartPoints: bodyFusionChartPoints,
      consistencyData: consistencyData,
      monthSessions: monthSessionsList.count,
      monthVolumeKg: Int(FitnessMetrics.totalVolumeKg(for: monthSessionsList)),
      yearSessions: yearSessionsList.count,
      yearVolumeKg: Int(FitnessMetrics.totalVolumeKg(for: yearSessionsList)),
      weekCardioDistanceKm: weekCardioLogs.compactMap(\.distanceKm).reduce(0, +),
      weekAverageHeartRate: weekHRValues.isEmpty ? nil : weekHRValues.reduce(0, +) / Double(weekHRValues.count),
      distanceTodayKm: todayCardioLogs.compactMap(\.distanceKm).reduce(0, +)
    )
  }

  private static func buildTrendMetrics(
    sessions: [WorkoutSession],
    healthMetrics: [DailyHealthMetric],
    streakDays: Int,
    bestEstimatedOneRepMaxKg: Double,
    today: Date,
    calendar: Calendar
  ) -> [TrendMetric] {
    guard let recent30Start = calendar.date(byAdding: .day, value: -29, to: today),
          let prev30Start = calendar.date(byAdding: .day, value: -59, to: today) else { return [] }

    let recent = sessions.filter { $0.date >= recent30Start }
    let previous = sessions.filter { $0.date >= prev30Start && $0.date < recent30Start }
    let recentWeeklyVol = FitnessMetrics.totalVolumeKg(for: recent) / 4.0
    let previousWeeklyVol = previous.isEmpty ? 0.0 : FitnessMetrics.totalVolumeKg(for: previous) / 4.0
    let recentWeeklySessions = Double(recent.count) / 4.0
    let previousWeeklySessions = previous.isEmpty ? 0.0 : Double(previous.count) / 4.0

    var metrics: [TrendMetric] = []
    let volumeDirection: TrendMetric.Direction = recentWeeklyVol > previousWeeklyVol + 1 ? .up
      : (recentWeeklyVol < previousWeeklyVol - 1 ? .down : .neutral)
    metrics.append(TrendMetric(
      title: localizedString("volume_label"),
      value: recentWeeklyVol > 0 ? "\(Int(recentWeeklyVol))" : "—",
      unit: localizedString("unit_kg_per_week"),
      direction: volumeDirection,
      color: PulseTheme.ringMove,
      metric: .volume
    ))

    let sessionsDirection: TrendMetric.Direction = recentWeeklySessions > previousWeeklySessions + 0.1 ? .up
      : (recentWeeklySessions < previousWeeklySessions - 0.1 ? .down : .neutral)
    metrics.append(TrendMetric(
      title: localizedString("sessions"),
      value: recentWeeklySessions > 0 ? String(format: "%.1f", recentWeeklySessions) : "—",
      unit: localizedString("unit_sessions_per_week"),
      direction: sessionsDirection,
      color: PulseTheme.ringExercise,
      metric: .sessions
    ))

    let recentStepsSample = healthMetrics.suffix(14).map(\.steps)
    let previousStepsSample = healthMetrics.dropLast(14).suffix(14).map(\.steps)
    if !recentStepsSample.isEmpty {
      let avgRecent = recentStepsSample.reduce(0, +) / Double(recentStepsSample.count)
      let avgPrevious = previousStepsSample.isEmpty ? 0.0 : previousStepsSample.reduce(0, +) / Double(previousStepsSample.count)
      if avgRecent > 0 {
        let direction: TrendMetric.Direction = avgRecent > avgPrevious + 100 ? .up : (avgRecent < avgPrevious - 100 ? .down : .neutral)
        metrics.append(TrendMetric(
          title: localizedString("steps_metric"),
          value: "\(Int(avgRecent))",
          unit: localizedString("unit_steps_per_day"),
          direction: direction,
          color: PulseTheme.accent,
          metric: .steps
        ))
      }
    }

    metrics.append(TrendMetric(
      title: localizedString("streak"),
      value: "\(streakDays)",
      unit: localizedString("days").uppercased(),
      direction: streakDays > 7 ? .up : (streakDays == 0 ? .down : .neutral),
      color: .orange,
      metric: .streak
    ))

    if bestEstimatedOneRepMaxKg > 0 {
      metrics.append(TrendMetric(
        title: "1RM Est.",
        value: "\(Int(bestEstimatedOneRepMaxKg))",
        unit: "KG",
        direction: .up,
        color: PulseTheme.accent,
        metric: .oneRepMax
      ))
    }

    let recentKcal = healthMetrics.suffix(7).map(\.activeEnergyKcal)
    let previousKcal = healthMetrics.dropLast(7).suffix(7).map(\.activeEnergyKcal)
    if !recentKcal.isEmpty {
      let avgRecent = recentKcal.reduce(0, +) / Double(recentKcal.count)
      let avgPrevious = previousKcal.isEmpty ? 0.0 : previousKcal.reduce(0, +) / Double(previousKcal.count)
      if avgRecent > 0 {
        let direction: TrendMetric.Direction = avgRecent > avgPrevious + 10 ? .up : (avgRecent < avgPrevious - 10 ? .down : .neutral)
        metrics.append(TrendMetric(
          title: localizedString("active_kcal"),
          value: "\(Int(avgRecent))",
          unit: localizedString("unit_kcal_per_day"),
          direction: direction,
          color: PulseTheme.ringMove,
          metric: .activeEnergy
        ))
      }
    }

    return metrics
  }
}
