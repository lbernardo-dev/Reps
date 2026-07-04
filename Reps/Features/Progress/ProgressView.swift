import Charts
import MuscleMap
import SwiftUI

struct ProgressDashboardView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedRange: ProgressRange = .week
  @State private var selectedSection: ProgressSection = .muscles
  @State private var activeDestination: ProgressDestination?
  @State private var sectionDetail: ProgressSection?
  @State private var metricDetail: SummaryMetric?
  @State private var showNotifications = false

  var onSelectTab: ((AppTab) -> Void)? = nil

  var body: some View {
    NavigationStack {
      StickyHeaderScaffold(
        title: "summary",
        subtitle: currentDateSubtitle,
        topContentPadding: 108,
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
                            .fill(.red)
                            .frame(width: 9, height: 9)
                            .offset(x: -1, y: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("notifications")
        }
      ) {

          DailySummaryFocusCard(
            summary: store.dailySummary,
            readinessLevel: store.trainingBattery.level,
            sessionsToday: todaySessionsCount,
            activeEnergyToday: Int(activeEnergyToday),
            stepsToday: stepsToday,
            exerciseMinutesWeek: weekHealthExerciseMinutes,
            hasHealthData: !weekHealthMetrics.isEmpty,
            hasManualData: heroMetrics.sessionsThisWeek > 0,
            onOpenWorkout: { onSelectTab?(.today) },
            onOpenCalendar: { onSelectTab?(.calendar) }
          )
          .stickyHeaderTitle(localizedString("today"))

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
            onTapMove: { handleMetricTap(.volume) },
            onTapExercise: { handleMetricTap(.sessions) },
            onTapStand: { onSelectTab?(.calendar) }
          )

          LazyVGrid(columns: summaryGridColumns, spacing: 12) {
            Button { handleMetricTap(.steps) } label: {
              TodayBarChartCard(
                icon: "figure.walk",
                color: Color(red: 0.68, green: 0.50, blue: 1.00),
                title: "steps_metric",
                value: stepsToday > 0 ? "\(stepsToday)" : "—",
                unit: "PASOS",
                chartData: stepsWeekData,
                showsChevron: true
              )
            }
            .buttonStyle(.plain)

            Button { handleMetricTap(.distance) } label: {
              TodayBarChartCard(
                icon: "figure.run",
                color: PulseTheme.ringStand,
                title: "distance_label",
                value: distanceTodayKm > 0 ? String(format: "%.2f", distanceTodayKm) : "—",
                unit: "KM",
                chartData: distanceWeekData,
                showsChevron: true
              )
            }
            .buttonStyle(.plain)

            Button { handleMetricTap(.activeEnergy) } label: {
              TodayBarChartCard(
                icon: "flame.fill",
                color: PulseTheme.ringMove,
                title: "active_kcal",
                value: activeEnergyToday > 0 ? "\(Int(activeEnergyToday))" : "—",
                unit: "KCAL",
                chartData: activeEnergyWeekData,
                showsChevron: true
              )
            }
            .buttonStyle(.plain)

            TodayMetricCard(
              icon: "timer",
              color: PulseTheme.ringExercise,
              title: "sessions",
              value: "\(heroMetrics.sessionsThisWeek)",
              detail: "\(weekTotalMinutes) min \(localizedString("week_label").lowercased())"
            )
          }

          // ── TENDENCIAS (90 días vs 365, estilo Apple Fitness) ─
          if !trendMetrics.isEmpty {
            TrendHighlightsCard(
              metrics: trendMetrics,
              sessionsThisWeek: heroMetrics.sessionsThisWeek,
              sessionsGoal: weeklySessionGoal,
              volumeThisWeek: Int(heroMetrics.volumeThisWeek),
              weekDays: heroMetrics.weekActivityDays
            )
            .stickyHeaderTitle(localizedString("trends"))

            TrendsGridView(metrics: trendMetrics) { metric in
              handleTrendTap(metric)
            }
          }

          TrainingLoadOverviewCard(
            battery: store.trainingBattery,
            workload: workload,
            onTap: { openSection(.load) }
          )

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
          .stickyHeaderTitle(localizedString("explore"))

      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(isPresented: $showNotifications) {
        NotificationsView()
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
      .navigationDestination(item: $sectionDetail) { section in
        sectionDetailScreen(for: section)
      }
      .navigationDestination(item: $metricDetail) { metric in
        metricDetailScreen(for: metric)
      }
    }
  }

  // MARK: - Section detail (pushed analytics screens)

  @ViewBuilder
  private func sectionDetailScreen(for section: ProgressSection) -> some View {
    StickyHeaderScaffold(
      title: section.titleKey,
      subtitle: "metric_2",
      topContentPadding: 96,
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
                systemImage: "battery.50", badgeColor: PulseTheme.warning, domain: .recovery)
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
                      centerLabel: "total_2",
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
    let today = Calendar.current.startOfDay(for: .now)
    return store.workoutSessions.filter { Calendar.current.startOfDay(for: $0.date) == today }.count
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
    return "sesiones"
  }

  private var sessionsGoalCaption: String {
    if store.activePlan.daysPerWeek > 0 {
      return "objetivo semanal"
    }
    return "esta semana"
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

  private func handleMetricTap(_ metric: SummaryMetric) {
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
      metricDetail = metric
    }
  }

  private func handleTrendTap(_ trend: TrendMetric) {
    guard let metric = trend.metric else { return }
    handleMetricTap(metric)
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
  private func metricDetailScreen(for metric: SummaryMetric) -> some View {
    switch metric {
    case .steps:
      StepsView()
    case .volume:
      ProgressMetricDetailView(
        title: localizedString("volume_label"),
        accent: PulseTheme.ringMove,
        unit: "KG",
        points: dailyVolumeSeries,
        explanation: localizedString("metric_volume_explanation")
      )
    case .distance:
      ProgressMetricDetailView(
        title: localizedString("distance_label"),
        accent: PulseTheme.ringStand,
        unit: "KM",
        points: dailyDistanceSeries,
        explanation: localizedString("metric_distance_explanation"),
        format: { String(format: "%.1f", $0) }
      )
    case .activeEnergy:
      ProgressMetricDetailView(
        title: localizedString("active_kcal"),
        accent: PulseTheme.ringMove,
        unit: "KCAL",
        points: dailyActiveEnergySeries,
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
    let cal = Calendar.current
    let grouped = Dictionary(grouping: store.workoutSessions.filter { $0.date >= last365Start }) {
      cal.startOfDay(for: $0.date)
    }
    return grouped.map { day, sessions in
      MetricDetailPoint(date: day, value: FitnessMetrics.totalVolumeKg(for: sessions))
    }.sorted { $0.date < $1.date }
  }

  private var dailyDistanceSeries: [MetricDetailPoint] {
    let cal = Calendar.current
    let grouped = Dictionary(grouping: store.combinedCardioLogs.filter { $0.date >= last365Start }) {
      cal.startOfDay(for: $0.date)
    }
    return grouped.compactMap { day, logs -> MetricDetailPoint? in
      let km = logs.compactMap(\.distanceKm).reduce(0, +)
      return km > 0 ? MetricDetailPoint(date: day, value: km) : nil
    }.sorted { $0.date < $1.date }
  }

  private var dailyActiveEnergySeries: [MetricDetailPoint] {
    store.health.latestDailyMetrics
      .filter { $0.date >= last365Start && $0.activeEnergyKcal > 0 }
      .map { MetricDetailPoint(date: $0.date, value: $0.activeEnergyKcal) }
      .sorted { $0.date < $1.date }
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
    let weekActivityDays: [Bool] = (0..<7).map { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: thisWeekStart) else { return false }
      let dayStart = calendar.startOfDay(for: date)
      return thisWeek.contains { calendar.startOfDay(for: $0.date) == dayStart }
    }
    return ProgressHeroMetrics(
      streak: store.streakDays,
      adherence: store.weeklyCompletion,
      sessionsThisWeek: thisWeek.count,
      sessionsLastWeek: lastWeek.count,
      volumeThisWeek: FitnessMetrics.totalVolumeKg(for: thisWeek),
      volumeLastWeek: FitnessMetrics.totalVolumeKg(for: lastWeek),
      totalSessions: store.workoutSessions.count,
      totalVolumeKg: FitnessMetrics.totalVolumeKg(for: store.workoutSessions),
      weekStart: thisWeekStart,
      weekActivityDays: weekActivityDays
    )
  }

  private var currentDateSubtitle: String {
    let f = DateFormatter()
    f.locale = Locale(identifier: store.userProfile.preferredLanguage)
    f.dateFormat = "EEEE, d MMM"
    return f.string(from: Date()).capitalized(with: f.locale)
  }

  private var weekTotalMinutes: Int {
    store.workoutSessions.filter { $0.date >= heroMetrics.weekStart }.reduce(0) { $0 + $1.durationMinutes }
  }

  private var weekSessions: [WorkoutSession] {
    store.workoutSessions.filter { $0.date >= heroMetrics.weekStart }
  }

  private var weekHealthMetrics: [DailyHealthMetric] {
    store.health.latestDailyMetrics.filter { $0.date >= heroMetrics.weekStart }
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
    store.combinedCardioLogs
      .filter { $0.date >= heroMetrics.weekStart }
      .compactMap(\.distanceKm)
      .reduce(0, +)
  }

  private var weekCompletedSets: Int {
    weekSessions.reduce(0) { $0 + FitnessMetrics.completedSets(in: $1).count }
  }

  private var weekAverageHeartRate: Double? {
    let values = store.combinedCardioLogs
      .filter { $0.date >= heroMetrics.weekStart }
      .compactMap(\.averageHeartRate)
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
  }

  private var summaryGridColumns: [GridItem] {
    [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
  }

  private var stepsToday: Int {
    store.health.latestDailyMetrics.last.map { Int($0.steps) } ?? 0
  }

  private var stepsWeekData: [TodayChartPoint] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    let symbols = cal.veryShortWeekdaySymbols
    return store.health.latestDailyMetrics.suffix(7).map { metric in
      let weekday = cal.component(.weekday, from: metric.date)
      return TodayChartPoint(
        label: symbols[weekday - 1].uppercased(),
        value: metric.steps,
        isToday: cal.startOfDay(for: metric.date) == today
      )
    }
  }

  private var distanceTodayKm: Double {
    let today = Calendar.current.startOfDay(for: .now)
    return store.combinedCardioLogs
      .filter { Calendar.current.startOfDay(for: $0.date) == today }
      .compactMap(\.distanceKm)
      .reduce(0, +)
  }

  private var activeEnergyToday: Double {
    store.todayHealthMetric?.activeEnergyKcal ?? store.health.latestDailyMetrics.last?.activeEnergyKcal ?? 0
  }

  private var activeEnergyWeekData: [TodayChartPoint] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    let symbols = cal.veryShortWeekdaySymbols
    return store.health.latestDailyMetrics.suffix(7).map { metric in
      let weekday = cal.component(.weekday, from: metric.date)
      return TodayChartPoint(
        label: symbols[weekday - 1].uppercased(),
        value: metric.activeEnergyKcal,
        isToday: cal.startOfDay(for: metric.date) == today
      )
    }
  }

  private var distanceWeekData: [TodayChartPoint] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    let symbols = cal.veryShortWeekdaySymbols
    return (0..<7).compactMap { offset -> TodayChartPoint? in
      guard let date = cal.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
      let km = store.combinedCardioLogs
        .filter { cal.startOfDay(for: $0.date) == date }
        .compactMap(\.distanceKm)
        .reduce(0, +)
      let weekday = cal.component(.weekday, from: date)
      return TodayChartPoint(label: symbols[weekday - 1].uppercased(), value: km, isToday: date == today)
    }
  }

  private var monthSessions: Int {
    let start = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: .now)) ?? .now
    return store.workoutSessions.filter { $0.date >= start }.count
  }

  private var monthVolumeKg: Int {
    let start = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: .now)) ?? .now
    return Int(FitnessMetrics.totalVolumeKg(for: store.workoutSessions.filter { $0.date >= start }))
  }

  private var yearSessions: Int {
    let start = Calendar.current.date(byAdding: .day, value: -364, to: Calendar.current.startOfDay(for: .now)) ?? .now
    return store.workoutSessions.filter { $0.date >= start }.count
  }

  private var yearVolumeKg: Int {
    let start = Calendar.current.date(byAdding: .day, value: -364, to: Calendar.current.startOfDay(for: .now)) ?? .now
    return Int(FitnessMetrics.totalVolumeKg(for: store.workoutSessions.filter { $0.date >= start }))
  }

  private var weeklyConsistencyData: [ConsistencyPoint] {
    let cal = Calendar.current
    let weekStart = heroMetrics.weekStart
    return (0..<7).compactMap { offset in
      guard let date = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
      let dayStart = cal.startOfDay(for: date)
      let count = store.workoutSessions.filter { cal.startOfDay(for: $0.date) == dayStart }.count
      return ConsistencyPoint(date: date, count: count)
    }
  }

  private var trendMetrics: [TrendMetric] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    guard let recent30Start = cal.date(byAdding: .day, value: -29, to: today),
          let prev30Start = cal.date(byAdding: .day, value: -59, to: today) else { return [] }

    let recent = store.workoutSessions.filter { $0.date >= recent30Start }
    let prev = store.workoutSessions.filter { $0.date >= prev30Start && $0.date < recent30Start }

    let recentWeeklyVol = FitnessMetrics.totalVolumeKg(for: recent) / 4.0
    let prevWeeklyVol = prev.isEmpty ? 0.0 : FitnessMetrics.totalVolumeKg(for: prev) / 4.0
    let recentWeeklySess = Double(recent.count) / 4.0
    let prevWeeklySess = prev.isEmpty ? 0.0 : Double(prev.count) / 4.0

    var metrics: [TrendMetric] = []

    let volDir: TrendMetric.Direction = recentWeeklyVol > prevWeeklyVol + 1 ? .up
      : (recentWeeklyVol < prevWeeklyVol - 1 ? .down : .neutral)
    metrics.append(TrendMetric(
      title: localizedString("volume_label"),
      value: recentWeeklyVol > 0 ? "\(Int(recentWeeklyVol))" : "—",
      unit: "KG/SEM",
      direction: volDir,
      color: PulseTheme.ringMove,
      metric: .volume
    ))

    let sessDir: TrendMetric.Direction = recentWeeklySess > prevWeeklySess + 0.1 ? .up
      : (recentWeeklySess < prevWeeklySess - 0.1 ? .down : .neutral)
    metrics.append(TrendMetric(
      title: localizedString("sessions"),
      value: recentWeeklySess > 0 ? String(format: "%.1f", recentWeeklySess) : "—",
      unit: "SES/SEM",
      direction: sessDir,
      color: PulseTheme.ringExercise,
      metric: .sessions
    ))

    let recentStepsSample = store.health.latestDailyMetrics.suffix(14).map(\.steps)
    let prevStepsSample = store.health.latestDailyMetrics.dropLast(14).suffix(14).map(\.steps)
    if !recentStepsSample.isEmpty {
      let avgRecent = recentStepsSample.reduce(0, +) / Double(recentStepsSample.count)
      let avgPrev = prevStepsSample.isEmpty ? 0.0 : prevStepsSample.reduce(0, +) / Double(prevStepsSample.count)
      if avgRecent > 0 {
        let stepsDir: TrendMetric.Direction = avgRecent > avgPrev + 100 ? .up : (avgRecent < avgPrev - 100 ? .down : .neutral)
        metrics.append(TrendMetric(
          title: localizedString("steps_metric"),
          value: "\(Int(avgRecent))",
          unit: "PASOS/DÍA",
          direction: stepsDir,
          color: PulseTheme.accent,
          metric: .steps
        ))
      }
    }

    metrics.append(TrendMetric(
      title: localizedString("streak"),
      value: "\(store.streakDays)",
      unit: localizedString("days").uppercased(),
      direction: store.streakDays > 7 ? .up : (store.streakDays == 0 ? .down : .neutral),
      color: .orange,
      metric: .streak
    ))

    if store.bestEstimatedOneRepMaxKg > 0 {
      metrics.append(TrendMetric(
        title: "1RM Est.",
        value: "\(Int(store.bestEstimatedOneRepMaxKg))",
        unit: "KG",
        direction: .up,
        color: PulseTheme.accent,
        metric: .oneRepMax
      ))
    }

    let recentKcal = store.health.latestDailyMetrics.suffix(7).map(\.activeEnergyKcal)
    let prevKcal = store.health.latestDailyMetrics.dropLast(7).suffix(7).map(\.activeEnergyKcal)
    if !recentKcal.isEmpty {
      let avgRecent = recentKcal.reduce(0, +) / Double(recentKcal.count)
      let avgPrev = prevKcal.isEmpty ? 0.0 : prevKcal.reduce(0, +) / Double(prevKcal.count)
      if avgRecent > 0 {
        let kcalDir: TrendMetric.Direction = avgRecent > avgPrev + 10 ? .up : (avgRecent < avgPrev - 10 ? .down : .neutral)
        metrics.append(TrendMetric(
          title: localizedString("active_kcal"),
          value: "\(Int(avgRecent))",
          unit: "KCAL/DÍA",
          direction: kcalDir,
          color: PulseTheme.ringMove,
          metric: .activeEnergy
        ))
      }
    }

    return metrics
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
          GoalCard(goal: goal) {}
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
    FitnessMetrics.insightCards(
      for: store.workoutSessions, goals: store.goals, since: selectedRange.startDate)
  }

  private var exercisesWithHistory: [Exercise] {
    store.exercises.filter { exercise in
      !FitnessMetrics.progressPoints(for: exercise, in: store.workoutSessions).isEmpty
    }
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
    let calendar = Calendar.current
    let healthByDay = Dictionary(grouping: weekHealthMetrics) { calendar.startOfDay(for: $0.date) }
    let sessionsByDay = Dictionary(grouping: weekSessions) { calendar.startOfDay(for: $0.date) }
    return (0..<7).compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: heroMetrics.weekStart) else { return nil }
      let day = calendar.startOfDay(for: date)
      let health = healthByDay[day]?.first
      let sessions = sessionsByDay[day] ?? []
      return BodyFusionPoint(
        date: day,
        activity: health?.activeEnergyKcal ?? 0,
        volume: FitnessMetrics.totalVolumeKg(for: sessions)
      )
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
