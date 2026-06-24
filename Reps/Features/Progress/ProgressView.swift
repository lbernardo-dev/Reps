import Charts
import MuscleMap
import SwiftUI

struct ProgressDashboardView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedRange: ProgressRange = .week
  @State private var selectedSection: ProgressSection = .muscles
  @State private var activeDestination: ProgressDestination?
  @State private var showNotifications = false
  @State private var showSocialHub = false
  @State private var showProfile = false

  var onSelectTab: ((AppTab) -> Void)? = nil

  var body: some View {
    NavigationStack {
      StickyHeaderScaffold(
        title: "progress_2",
        subtitle: "performance",
        topContentPadding: 128,
        accessory: {
            HStack(spacing: 6) {
                Button {
                    HapticService.selection()
                    showNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
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

                if store.userProfile.socialEnabled {
                    Button {
                        HapticService.selection()
                        showSocialHub = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(PulseTheme.primary)
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                            if store.unreadFeedCount > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 9, height: 9)
                                    .offset(x: -1, y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("social_hub")
                }

                HeaderAvatarButton(
                    imageData: store.userProfile.avatarImageData,
                    accessibilityLabel: "profile"
                ) {
                    showProfile = true
                }
            }
        }
      ) {

          ProgressHeroCard(
            metrics: heroMetrics,
            onTapStreak: { onSelectTab?(.calendar) },
            onTapVolume: { withAnimation(.snappy(duration: 0.2)) { selectedSection = .muscles } },
            onTapSessions: { withAnimation(.snappy(duration: 0.2)) { selectedSection = .general } }
          )
            .stickyHeaderTitle(localizedString("this_week"))

          if !store.workoutSessions.isEmpty {
            ProgressWeekContextCard(
              sessionsThisWeek: heroMetrics.sessionsThisWeek,
              volumeThisWeek: heroMetrics.volumeThisWeek,
              sessionsLastWeek: heroMetrics.sessionsLastWeek,
              volumeLastWeek: heroMetrics.volumeLastWeek,
              streak: heroMetrics.streak
            )
          }

          ProgressCoachStrip(
            step: nextBestSteps.first(where: { !$0.isCompleted }) ?? nextBestSteps.first,
            weeklyCompletion: store.weeklyCompletion,
            battery: store.trainingBattery,
            onAction: perform
          )
          .stickyHeaderTitle(localizedString("progress_direction"))

          Picker("range", selection: $selectedRange) {
            ForEach(ProgressRange.allCases) { range in
              Text(range.title).tag(range)
            }
          }
          .pickerStyle(.segmented)

          LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
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
                ProgressSectionTile(
                  section: section,
                  isSelected: selectedSection == section,
                  value: sectionValue(for: section),
                  isLocked: section == .load && !store.hasFeatureAccess(.advancedAnalytics)
                )
              }
              .buttonStyle(.plain)
            }
          }
          .stickyHeaderTitle(localizedString("metric_2"))

          // The next-best-action plan lives on the Today tab; Progress stays a
          // pure analytics surface to avoid duplicating it across both tabs.

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
                  color: PulseTheme.primaryBright
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
                    .fill(PulseTheme.primary.opacity(0.12))
                    .frame(width: 38, height: 38)
                  Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.headline.weight(.black))
                    .foregroundStyle(PulseTheme.primary)
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
                systemImage: "figure.walk", badgeColor: PulseTheme.primary)
              MetricCard(
                title: "active_kcal", value: "\(Int(latestHealth.activeEnergyKcal))",
                subtitle: "last_day", systemImage: "flame", badgeColor: PulseTheme.accent)
            }

            PulseCard {
              VStack(alignment: .leading, spacing: 14) {
                CardTitle("health_trends")
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
      .navigationDestination(isPresented: $showNotifications) {
        NotificationsView()
      }
      .navigationDestination(isPresented: $showSocialHub) {
        SocialHubView()
      }
      .navigationDestination(isPresented: $showProfile) {
        ProfileView()
      }
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

  private var nextBestSteps: [RetentionEngine.ActivationStep] {
    RetentionEngine.nextBestSteps(
      sessions: store.workoutSessions,
      activePlan: store.activePlan,
      scheduledWorkouts: store.scheduledWorkouts,
      remindersEnabled: store.userProfile.remindersEnabled,
      competitiveSummary: competitiveSummary
    )
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
            LineMark(x: .value("Date", metric.date), y: .value("Weight", metric.weightKg))
              .foregroundStyle(PulseTheme.primary)
            PointMark(x: .value("Date", metric.date), y: .value("Weight", metric.weightKg))
              .foregroundStyle(PulseTheme.primary)
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

  private func perform(_ action: RetentionEngine.ActivationAction?) {
    HapticService.selection()
    guard let action else {
      onSelectTab?(.today)
      return
    }

    switch action {
    case .startWorkout:
      onSelectTab?(.today)
    case .createPlan:
      onSelectTab?(.plans)
    case .scheduleWorkout:
      onSelectTab?(.calendar)
    case .competitive(let competitiveAction):
      perform(competitiveAction)
    case .openProgress:
      withAnimation(.snappy(duration: 0.2)) {
        selectedSection = .general
      }
    }
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

private struct ProgressExecutiveCard: View {
  let sessions: Int
  let volumeKg: Int
  let bestEstimatedOneRepMaxKg: Int
  let rangeTitle: LocalizedStringKey
  let primaryInsight: FitnessMetrics.TrainingInsight?
  let onOpenExercises: () -> Void
  let onOpenHistory: () -> Void
  let onOpenPRs: () -> Void

  private var headline: String {
    if sessions == 0 {
      return localizedString("start_and_finish_workout_message")
    }
    if let primaryInsight {
      return primaryInsight.title
    }
    return localizedString("performance")
  }

  private var message: String {
    if let primaryInsight {
      return primaryInsight.message
    }
    return localizedString("complete_a_session_with_sets_and_reps_to_unlock_practical_signals")
  }

  var body: some View {
	    PulseCard(contentPadding: 15) {
	      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
	          Image(systemName: primaryInsight?.systemImage ?? "chart.bar.fill")
	            .font(.title3.weight(.black))
	            .foregroundStyle(.white)
	            .frame(width: 48, height: 48)
	            .background(PulseTheme.fitActionGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
	            .overlay(
	              RoundedRectangle(cornerRadius: 14, style: .continuous)
	                .stroke(.white.opacity(0.18), lineWidth: 1)
	            )

          VStack(alignment: .leading, spacing: 5) {
            Text(localizedKey(rangeTitle))
              .font(.caption.weight(.black))
              .textCase(.uppercase)
              .foregroundStyle(PulseTheme.primary)
            Text(headline)
              .font(.title3.weight(.black))
              .lineLimit(2)
              .minimumScaleFactor(0.76)
            Text(message)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(PulseTheme.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        HStack(spacing: 8) {
          ProgressExecutiveMetric(value: "\(sessions)", label: "sessions", systemImage: "dumbbell.fill", color: PulseTheme.primary)
          ProgressExecutiveMetric(value: "\(volumeKg)", label: "kg_total", systemImage: "scalemass.fill", color: PulseTheme.primaryBright)
          ProgressExecutiveMetric(value: "\(bestEstimatedOneRepMaxKg)kg", label: "estimated_maximum", systemImage: "trophy.fill", color: PulseTheme.accent)
        }

	        HStack(spacing: 8) {
	          Button(action: onOpenExercises) {
	            Label("exercises_3", systemImage: "chart.line.uptrend.xyaxis")
	              .font(.caption.weight(.black))
	              .frame(maxWidth: .infinity)
	              .frame(height: 40)
	              .foregroundStyle(.black)
	              .background(PulseTheme.primaryBright, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
	          }
          .buttonStyle(.plain)

	          Button(action: onOpenHistory) {
	            Label("history_label", systemImage: "list.clipboard")
	              .font(.caption.weight(.black))
	              .frame(maxWidth: .infinity)
	              .frame(height: 40)
	              .foregroundStyle(.white.opacity(0.82))
	              .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
	              .overlay(
	                RoundedRectangle(cornerRadius: 12, style: .continuous)
	                  .stroke(Color.white.opacity(0.07), lineWidth: 1)
	              )
	          }
          .buttonStyle(.plain)

	          Button(action: onOpenPRs) {
	            Image(systemName: "trophy.fill")
	              .font(.headline.weight(.black))
	              .frame(width: 40, height: 40)
	              .foregroundStyle(.white)
	              .background(PulseTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(localizedString("personal_records"))
        }
      }
    }
  }
}

private struct ProgressExecutiveMetric: View {
  let value: String
  let label: LocalizedStringKey
  let systemImage: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Image(systemName: systemImage)
        .font(.caption.weight(.black))
        .foregroundStyle(color)
      Text(value)
        .font(.headline.weight(.black).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(localizedKey(label))
        .font(.caption2.weight(.bold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}

private struct ProgressToolTile: View {
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey
  let systemImage: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Image(systemName: systemImage)
        .font(.headline.weight(.black))
        .foregroundStyle(color)
        .frame(width: 38, height: 38)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      Text(localizedKey(title))
        .font(.subheadline.weight(.black))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(localizedKey(subtitle))
        .font(.caption.weight(.semibold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(2)
        .minimumScaleFactor(0.76)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
    .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
        .stroke(PulseTheme.separator, lineWidth: 1)
    )
  }
}

private struct ProgressCoachStrip: View {
  let step: RetentionEngine.ActivationStep?
  let weeklyCompletion: Double
  let battery: FitnessMetrics.TrainingBatteryStatus
  let onAction: (RetentionEngine.ActivationAction?) -> Void

  private var color: Color {
    if weeklyCompletion < 0.75 { return PulseTheme.warning }
    switch battery.state {
    case .charged, .steady: return PulseTheme.primary
    case .low: return PulseTheme.warning
    case .critical: return PulseTheme.destructive
    }
  }

  var body: some View {
    PulseCard(contentPadding: 14) {
      HStack(spacing: 12) {
        Image(systemName: step?.systemImage ?? "sparkles")
          .font(.headline.weight(.black))
          .foregroundStyle(color)
          .frame(width: 42, height: 42)
          .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          Text(step?.title ?? localizedString("progress_direction"))
            .font(.subheadline.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
          Text(step?.message ?? battery.suggestion)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PulseTheme.secondaryText)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
        }

        Spacer(minLength: 0)

        Button {
          onAction(step?.action)
        } label: {
          Text(step?.actionTitle ?? localizedString("open"))
            .font(.caption.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct ProgressSectionTile: View {
  let section: ProgressSection
  let isSelected: Bool
	  let value: String
	  let isLocked: Bool

	  private var tileFill: Color {
	    isSelected ? section.tint : Color.white.opacity(0.028)
	  }

	  private var tileStroke: Color {
	    isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.075)
	  }
	
	  var body: some View {
	    HStack(spacing: 10) {
      Image(systemName: isLocked ? "lock.fill" : section.systemImage)
        .font(.headline.weight(.black))
        .foregroundStyle(isSelected ? .white : section.tint)
        .frame(width: 42, height: 42)
        .background((isSelected ? Color.white.opacity(0.16) : section.tint.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(localizedKey(section.title))
          .font(.subheadline.weight(.black))
          .foregroundStyle(isSelected ? .white : .primary)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        Text(value)
          .font(.caption.weight(.black).monospacedDigit())
          .foregroundStyle(isSelected ? .white.opacity(0.82) : PulseTheme.secondaryText)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
	    }
	    .padding(12)
	    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
	    .background(tileBackground)
	    .overlay(
	      RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
	        .stroke(tileStroke, lineWidth: 1)
	    )
	    .shadow(color: isSelected ? section.tint.opacity(0.12) : Color.black.opacity(0.10), radius: isSelected ? 10 : 6, x: 0, y: 4)
	    .accessibilityElement(children: .combine)
	  }

	  private var tileBackground: some View {
	    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
	      .fill(tileFill)
	      .overlay(
	        LinearGradient(
	          colors: [
	            Color.white.opacity(isSelected ? 0.16 : 0.045),
	            section.tint.opacity(isSelected ? 0.10 : 0.018),
	            Color.black.opacity(0.08)
	          ],
	          startPoint: .topLeading,
	          endPoint: .bottomTrailing
	        )
	      )
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

  private var visibleSteps: [RetentionEngine.ActivationStep] {
    guard let pendingStep else {
      return Array(steps.prefix(2))
    }

    var result = [pendingStep]
    if let supportStep = steps.first(where: { $0.id != pendingStep.id && $0.isCompleted }) {
      result.append(supportStep)
    }
    return result
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
            .frame(width: 82, height: 82)

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
          ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { index, step in
            ProgressActionStepRow(step: step) {
              onAction(step.action)
            }

            if index < visibleSteps.count - 1 {
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
      Image(systemName: point.kind == localizedString("muscle_target_kind_missing") ? "arrow.down.circle.fill" : "exclamationmark.triangle.fill")
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
    ScrollView(.vertical, showsIndicators: false) {
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
      .padding(.horizontal, PulseTheme.screenHorizontalPadding)
      .padding(.vertical, 20)
      .padding(.bottom, 112)
    }
    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    .screenBackground()
    .navigationTitle("exercises_3")
    .navigationBarTitleDisplayMode(.inline)
    .mainTabBarHidden()
  }
}

struct ProgressHeroMetrics {
  let streak: Int
  let adherence: Double
  let sessionsThisWeek: Int
  let sessionsLastWeek: Int
  let volumeThisWeek: Double
  let volumeLastWeek: Double
  var totalSessions: Int = 0
  var totalVolumeKg: Double = 0
  var weekStart: Date = .now
  var weekActivityDays: [Bool] = Array(repeating: false, count: 7)

  var volumeDelta: Double? {
    guard volumeLastWeek > 0 else { return nil }
    return (volumeThisWeek - volumeLastWeek) / volumeLastWeek * 100
  }

  var sessionsDelta: Int { sessionsThisWeek - sessionsLastWeek }
}

/// Graphical, at-a-glance summary of the current week: an adherence ring plus
/// streak, volume and session tiles with week-over-week trend, plus all-time totals row.
struct ProgressHeroCard: View {
  let metrics: ProgressHeroMetrics
  var onTapStreak: (() -> Void)? = nil
  var onTapVolume: (() -> Void)? = nil
  var onTapSessions: (() -> Void)? = nil

  var body: some View {
    PulseCard(contentPadding: 0) {
      VStack(spacing: 0) {
        // ── Header ──────────────────────────────────────
        HStack(alignment: .center, spacing: 8) {
          Label(localizedString("this_week"), systemImage: "calendar")
            .font(.caption.weight(.black))
            .textCase(.uppercase)
            .foregroundStyle(PulseTheme.primary)
          Spacer()
          if let dir = weekDirection {
            HStack(spacing: 3) {
              Image(systemName: dir.icon)
                .font(.system(size: 9, weight: .black))
              Text(dir.label)
                .font(.caption2.weight(.black))
            }
            .foregroundStyle(dir.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(dir.color.opacity(0.14), in: Capsule())
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)

        // ── Three metric mini-cards ──────────────────────
        HStack(spacing: 10) {
          HeroTile(
            systemImage: "flame.fill",
            tint: PulseTheme.accent,
            value: "\(metrics.streak)",
            title: localizedString("streak"),
            subtitle: localizedString("days"),
            trend: nil,
            onTap: onTapStreak
          )
          HeroTile(
            systemImage: "scalemass.fill",
            tint: PulseTheme.primaryBright,
            value: volumeText,
            title: localizedString("volume_label"),
            subtitle: nil,
            trend: metrics.volumeDelta.map { HeroTrend(percent: $0) },
            onTap: onTapVolume
          )
          HeroTile(
            systemImage: "dumbbell.fill",
            tint: PulseTheme.primary,
            value: "\(metrics.sessionsThisWeek)",
            title: localizedString("sessions"),
            subtitle: nil,
            trend: metrics.sessionsLastWeek > 0 ? HeroTrend(countDelta: metrics.sessionsDelta) : nil,
            onTap: onTapSessions
          )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)

        // ── 7-day activity strip ─────────────────────────
        WeekActivityStrip(weekStart: metrics.weekStart, activeDays: metrics.weekActivityDays)

        // ── Divider ─────────────────────────────────────
        Divider().padding(.horizontal, 16)

        // ── All-time totals ──────────────────────────────
        HStack(spacing: 0) {
          TotalStatPill(
            label: localizedString("total_sessions"),
            value: "\(metrics.totalSessions)"
          )
          Rectangle()
            .fill(PulseTheme.separator)
            .frame(width: 1, height: 24)
          TotalStatPill(
            label: localizedString("volume_label"),
            value: totalVolumeAllTimeText
          )
          Rectangle()
            .fill(PulseTheme.separator)
            .frame(width: 1, height: 24)
          TotalStatPill(
            label: localizedString("adherence"),
            value: "\(Int(metrics.adherence * 100))%"
          )
        }
        .padding(.vertical, 12)
      }
    }
  }

  private var weekDirection: (icon: String, label: String, color: Color)? {
    let sessionDelta = metrics.sessionsDelta
    let volDelta = metrics.volumeDelta ?? 0
    if sessionDelta > 0 || volDelta > 5 {
      return ("arrow.up.right", "+\(sessionDelta) sessions", PulseTheme.primaryBright)
    } else if sessionDelta < 0 || volDelta < -5 {
      return ("arrow.down.right", "\(sessionDelta) sessions", PulseTheme.destructive)
    }
    return nil
  }

  private var volumeText: String {
    let v = metrics.volumeThisWeek
    if v >= 1000 { return String(format: "%.1ft", v / 1000) }
    return "\(Int(v.rounded())) kg"
  }

  private var totalVolumeAllTimeText: String {
    let v = metrics.totalVolumeKg
    if v >= 1000 { return String(format: "%.1ft", v / 1000) }
    return "\(Int(v.rounded())) kg"
  }
}

private struct TotalStatPill: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 3) {
      Text(value)
        .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
        .foregroundStyle(.primary)
      Text(label)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
    .frame(maxWidth: .infinity)
  }
}
private struct WeekActivityStrip: View {
  let weekStart: Date
  let activeDays: [Bool]

  private struct DayInfo: Identifiable {
    let id: Int
    let label: String
    let active: Bool
    let isToday: Bool
  }

  private var dayInfos: [DayInfo] {
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: .now)
    return (0..<7).compactMap { offset -> DayInfo? in
      guard let date = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
      let weekday = cal.component(.weekday, from: date)
      return DayInfo(
        id: offset,
        label: cal.veryShortWeekdaySymbols[weekday - 1].uppercased(),
        active: offset < activeDays.count && activeDays[offset],
        isToday: cal.startOfDay(for: date) == todayStart
      )
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(dayInfos) { day in
        VStack(spacing: 5) {
          ZStack {
            Circle()
              .fill(day.active ? PulseTheme.primary : Color.clear)
              .frame(width: 28, height: 28)
            Circle()
              .strokeBorder(
                day.active
                  ? Color.clear
                  : (day.isToday ? PulseTheme.primary.opacity(0.65) : Color.white.opacity(0.13)),
                lineWidth: 1.5
              )
              .frame(width: 28, height: 28)
            if day.active {
              Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
            }
          }
          Text(day.label)
            .font(.system(size: 10, weight: day.isToday ? .black : .medium))
            .foregroundStyle(
              day.active
                ? .primary
                : (day.isToday ? PulseTheme.primary : PulseTheme.secondaryText)
            )
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}


private struct ProgressWeekContextCard: View {
  let sessionsThisWeek: Int
  let volumeThisWeek: Double
  let sessionsLastWeek: Int
  let volumeLastWeek: Double
  let streak: Int

  private var volumeDelta: Double {
    guard volumeLastWeek > 0 else { return 0 }
    return ((volumeThisWeek - volumeLastWeek) / volumeLastWeek) * 100
  }

  private var sessionsDelta: Int { sessionsThisWeek - sessionsLastWeek }

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 12) {
        Label(localizedString("progress_direction"), systemImage: "chart.line.uptrend.xyaxis")
          .font(.caption.weight(.black))
          .foregroundStyle(PulseTheme.primary)
          .textCase(.uppercase)

        HStack(spacing: 16) {
          contextStat(
            icon: "dumbbell.fill",
            value: sessionsDelta >= 0 ? "+\(sessionsDelta)" : "\(sessionsDelta)",
            label: localizedString("vs_last_week"),
            isPositive: sessionsDelta >= 0
          )
          contextStat(
            icon: "scalemass.fill",
            value: String(format: "%+.0f%%", volumeDelta),
            label: localizedString("volume_label"),
            isPositive: volumeDelta >= 0
          )
          contextStat(
            icon: "flame.fill",
            value: "\(streak)d",
            label: localizedString("streak"),
            isPositive: streak > 0
          )
        }
      }
    }
  }

  private func contextStat(icon: String, value: String, label: String, isPositive: Bool) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(isPositive ? PulseTheme.primaryBright : PulseTheme.destructive)
        .frame(width: 32, height: 32)
        .background((isPositive ? PulseTheme.primaryBright : PulseTheme.destructive).opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(value)
          .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
          .foregroundStyle(isPositive ? PulseTheme.primaryBright : PulseTheme.destructive)
        Text(label)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(PulseTheme.secondaryText)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity)
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
  var subtitle: String? = nil
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
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: systemImage)
        .font(.system(size: 14, weight: .black))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

      Text(value)
        .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.55)

      if let subtitle {
        Text("\(title) \(subtitle)")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(PulseTheme.secondaryText)
          .lineLimit(1)
      } else {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(PulseTheme.secondaryText)
          .lineLimit(1)
      }

      if let trend {
        HStack(spacing: 3) {
          Image(systemName: trend.isUp ? "arrow.up.right" : "arrow.down.right")
            .font(.system(size: 8, weight: .black))
          Text(trend.label)
            .font(.system(size: 10, weight: .black, design: .rounded).monospacedDigit())
        }
        .foregroundStyle(trend.isUp ? PulseTheme.primaryBright : PulseTheme.destructive)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
          (trend.isUp ? PulseTheme.primaryBright : PulseTheme.destructive).opacity(0.15),
          in: Capsule()
        )
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.white.opacity(0.045))
        .overlay(
          LinearGradient(
            colors: [tint.opacity(0.10), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(tint.opacity(0.20), lineWidth: 1)
    )
    .shadow(color: tint.opacity(0.10), radius: 8, x: 0, y: 4)
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

  var systemImage: String {
    switch self {
    case .general: "chart.bar.fill"
    case .exercises: "chart.line.uptrend.xyaxis"
    case .muscles: "figure.strengthtraining.traditional"
    case .cardio: "figure.run"
    case .body: "scalemass"
    case .load: "waveform.path.ecg"
    }
  }

  var tint: Color {
    switch self {
    case .general: PulseTheme.primary
    case .exercises: PulseTheme.primaryBright
    case .muscles: PulseTheme.accent
    case .cardio: PulseTheme.recovery
    case .body: PulseTheme.warning
    case .load: PulseTheme.destructive
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
