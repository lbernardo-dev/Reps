import Foundation
import UIKit

enum DemoPremiumSeedData {
    static let healthMessage = "Demo premium sincronizada con datos realistas de 12 meses."

    static func snapshot(now: Date = .now, calendar: Calendar = .current) -> AppSnapshot {
        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        var generator = SeededGenerator(seed: 0x5EED_2026_0709)

        var activePlan = SeedData.upperLower4DayPlan
        activePlan.name = "Upper Lower 4-Day - Alex"
        activePlan.currentWeek = 7
        activePlan.totalWeeks = 8
        activePlan.completion = 0.82
        activePlan.currentDayIndex = 2
        activePlan.playlists = [
            PlanPlaylist(
                provider: .appleMusic,
                title: "Heavy sets / clean reps",
                urlString: "https://music.apple.com/es/playlist/heavy-sets-clean-reps/pl.u-demo",
                notes: "Usada en los dias de fuerza."
            )
        ]

        var profile = UserProfile()
        profile.displayName = "Alex Romero"
        profile.alias = "Alex"
        profile.email = "alex.romero@example.com"
        profile.sex = .male
        profile.dateOfBirth = calendar.date(from: DateComponents(year: 1991, month: 4, day: 18))
        profile.avatarImageData = makeProfileImageData(initials: "AR")
        profile.preferredLanguage = "es"
        profile.units = .metric
        profile.distanceUnit = .kilometers
        profile.trainingLocation = .both
        profile.mainGoal = .bodyRecomposition
        profile.experience = .advanced
        profile.weeklyTrainingDays = 5
        profile.preferredSessionLengthMinutes = 55
        profile.availableEquipment = [
            "Barbell", "Bench", "Cable", "Cardio Machine", "Dumbbells",
            "Kettlebell", "Machine", "Pullup Bar", "Rack", "Resistance Band"
        ]
        profile.showRPE = true
        profile.showRIR = true
        profile.showSetType = true
        profile.showTempo = true
        profile.weightIncrementKg = 2.5
        profile.autoProgressionEnabled = true
        profile.remindersEnabled = true
        profile.confirmBeforeEndingWorkout = true
        profile.onboardingCompleted = true
        profile.themeMode = .dark
        profile.targetEventName = "Media maraton de Madrid"
        profile.targetEventDate = calendar.date(byAdding: .day, value: 74, to: today)
        profile.widgetAccentColorName = "green"
        profile.sleepTargetHours = 7.5
        profile.dailyCalorieGoalKcal = 2_550
        profile.calorieGoalType = .recomposition
        profile.dailyWaterGoalLiters = 3.0
        profile.dailyStepsGoal = 10_000
        profile.socialEnabled = true
        profile.socialUsername = "alex.reps"
        profile.socialBio = "Fuerza, carrera suave y constancia. Madrid."
        profile.socialLocation = "Madrid"
        profile.socialFollowingUsernames = ["marta.moves", "dani.strength", "club.retiro"]

        let monetization = MonetizationState(
            entitlement: .pro,
            status: .active,
            billingCycle: .yearly,
            provider: .local,
            trialStartDate: nil,
            trialEndDate: nil,
            renewsAt: calendar.date(byAdding: .month, value: 9, to: today),
            lastPaywallPresentationDate: calendar.date(byAdding: .month, value: -11, to: today),
            lastPaywallDismissDate: calendar.date(byAdding: .month, value: -11, to: today),
            lastPaywallSource: .onboarding,
            paywallPresentationCount: 1,
            lastEntitlementSyncDate: now
        )

        let strengthSessions = makeStrengthSessions(
            from: startDate,
            through: today,
            plan: activePlan,
            calendar: calendar,
            generator: &generator
        )
        let routeSessions = makeRouteSessions(
            from: startDate,
            through: today,
            calendar: calendar,
            generator: &generator
        )
        let workoutSessions = (strengthSessions + routeSessions).sorted { $0.date < $1.date }

        let cardioLogs = makeCardioLogs(
            from: startDate,
            through: today,
            calendar: calendar,
            generator: &generator
        )
        let bodyMetrics = makeBodyMetrics(
            from: startDate,
            through: today,
            calendar: calendar,
            generator: &generator
        )
        let health = makeHealthState(
            from: startDate,
            through: today,
            calendar: calendar,
            generator: &generator,
            workoutSessions: workoutSessions,
            cardioLogs: cardioLogs
        )
        let progressPhotos = makeProgressPhotos(
            from: startDate,
            through: today,
            calendar: calendar,
            bodyMetrics: bodyMetrics
        )
        let gymPasses = makeGymPasses(
            from: startDate,
            through: today,
            calendar: calendar
        )
        let gymVisits = makeGymVisits(
            sessions: workoutSessions,
            gymName: "Distrito Strength Club"
        )
        let scheduledWorkouts = makeSchedule(
            from: startDate,
            through: today,
            plan: activePlan,
            sessions: strengthSessions,
            calendar: calendar
        )
        let goals = makeGoals(
            today: today,
            calendar: calendar,
            sessions: workoutSessions,
            bodyMetrics: bodyMetrics
        )
        let savedShareCards = workoutSessions.suffix(4).map { session in
            SavedShareCard(
                date: session.date,
                workoutTitle: session.workoutTitle,
                imageData: makeCardImageData(title: session.workoutTitle, subtitle: "\(session.durationMinutes) min")
            )
        }

        return AppSnapshot(
            userProfile: profile,
            monetization: monetization,
            activePlan: activePlan,
            plans: [activePlan] + SeedData.defaultPlans.filter { $0.id != activePlan.id },
            workoutTemplates: SeedData.workoutTemplates,
            exercises: SeedData.exercises,
            scheduledWorkouts: scheduledWorkouts,
            workoutSessions: workoutSessions,
            cardioLogs: cardioLogs,
            bodyMetrics: bodyMetrics,
            progressPhotos: progressPhotos,
            gymPasses: gymPasses,
            gymVisits: gymVisits,
            goals: goals,
            health: health,
            savedShareCards: savedShareCards
        )
    }

    private static func makeStrengthSessions(
        from startDate: Date,
        through today: Date,
        plan: WorkoutPlan,
        calendar: Calendar,
        generator: inout SeededGenerator
    ) -> [WorkoutSession] {
        let trainingWeekdays: Set<Int> = [2, 3, 5, 7]
        var sessions: [WorkoutSession] = []
        let totalDays = max(calendar.dateComponents([.day], from: startDate, to: today).day ?? 365, 1)

        for dayOffset in 0...totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            guard trainingWeekdays.contains(weekday) else { continue }

            let weekIndex = dayOffset / 7
            let travelWeek = weekIndex == 15 || weekIndex == 31
            let deloadWeek = weekIndex % 9 == 8
            if travelWeek && weekday != 5 { continue }
            if generator.nextDouble() < (deloadWeek ? 0.18 : 0.08) { continue }

            let dayIndex = sessions.count % max(plan.days.count, 1)
            let workoutDay = plan.days[dayIndex]
            let progression = 1.0 + (Double(dayOffset) / Double(totalDays)) * 0.16
            let fatigueScale = deloadWeek ? 0.82 : (travelWeek ? 0.74 : 1.0)
            let startedAt = calendar.date(bySettingHour: weekday == 7 ? 10 : 18, minute: weekday == 7 ? 20 : 35, second: 0, of: date) ?? date
            let duration = max(38, workoutDay.durationMinutes + generator.nextInt(in: -6...8))
            let exerciseLogs = workoutDay.exercises.prefix(travelWeek ? 4 : 6).enumerated().map { index, item in
                makeExerciseLog(
                    item: item,
                    exerciseIndex: index,
                    progression: progression * fatigueScale,
                    deload: deloadWeek,
                    generator: &generator
                )
            }
            let sets = exerciseLogs.flatMap(\.sets)
            let volume = sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
            let context: WorkoutSession.ContextTag = deloadWeek ? .deload : (travelWeek ? .travel : .normal)
            let session = WorkoutSession(
                workoutTitle: workoutDay.title,
                date: startedAt,
                startedAt: startedAt,
                endedAt: calendar.date(byAdding: .minute, value: duration, to: startedAt),
                origin: .routine,
                location: travelWeek ? .other : .gym,
                contextTag: context,
                durationMinutes: duration,
                sets: sets,
                notes: deloadWeek ? "Semana de descarga: tecnica limpia, sin apurar." : sessionNote(for: workoutDay.title, volume: volume),
                exerciseLogs: exerciseLogs,
                sessionRPE: deloadWeek ? 6.0 : Double(generator.nextInt(in: 7...9)),
                energyBefore: generator.nextInt(in: 3...5),
                energyAfter: generator.nextInt(in: 3...5),
                estimatedCalories: Double(duration * generator.nextInt(in: 7...10)),
                heartRateBefore: Double(generator.nextInt(in: 61...76)),
                heartRateAfter: Double(generator.nextInt(in: 92...118)),
                averageHeartRate: Double(generator.nextInt(in: 108...136)),
                maxHeartRate: Double(generator.nextInt(in: 142...168))
            )
            sessions.append(session)
        }

        return sessions
    }

    private static func makeExerciseLog(
        item: WorkoutExercise,
        exerciseIndex: Int,
        progression: Double,
        deload: Bool,
        generator: inout SeededGenerator
    ) -> ExerciseLog {
        let baseWeight = baseWeightKg(for: item.exercise)
        let setCount = max(2, item.targetSets + (deload ? -1 : generator.nextInt(in: -1...1)))
        let sets = (1...setCount).map { setNumber in
            let reps = repsForExercise(item.exercise, setNumber: setNumber, generator: &generator)
            let warmup = setNumber == 1 && baseWeight > 0 && item.targetSets >= 4
            let weight = warmup
                ? roundedWeight(baseWeight * progression * 0.72)
                : roundedWeight(baseWeight * progression * (deload ? 0.86 : 1.0))
            return SetLog(
                setNumber: setNumber,
                weightKg: item.exercise.trackingType == .weightReps ? weight : 0,
                reps: reps,
                completed: generator.nextDouble() > 0.025,
                setType: warmup ? .warmUp : (setNumber == 2 && item.priority == .primary ? .topSet : .work),
                rpe: deload ? 6.5 : Double(generator.nextInt(in: 7...9)) + (generator.nextDouble() > 0.72 ? 0.5 : 0),
                rir: deload ? 3 : generator.nextInt(in: 0...3),
                tempo: exerciseIndex % 3 == 0 ? "3-1-1" : nil,
                previousRestSeconds: item.restSeconds + generator.nextInt(in: -15...25),
                isPersonalRecord: !deload && generator.nextDouble() > 0.985,
                notes: setNumber == setCount && generator.nextDouble() > 0.82 ? "Buena velocidad, mantener carga." : nil
            )
        }

        return ExerciseLog(
            exercise: item.exercise,
            notes: item.cues ?? "",
            sets: sets
        )
    }

    private static func makeRouteSessions(
        from startDate: Date,
        through today: Date,
        calendar: Calendar,
        generator: inout SeededGenerator
    ) -> [WorkoutSession] {
        var sessions: [WorkoutSession] = []
        let totalDays = max(calendar.dateComponents([.day], from: startDate, to: today).day ?? 365, 1)

        for dayOffset in stride(from: 4, through: totalDays, by: 7) {
            guard generator.nextDouble() > 0.12,
                  let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let startedAt = calendar.date(bySettingHour: 8, minute: 15, second: 0, of: date) ?? date
            let distance = 4.8 + Double(dayOffset) / Double(totalDays) * 2.0 + generator.nextDouble()
            let pace = 355 - (Double(dayOffset) / Double(totalDays) * 22) + Double(generator.nextInt(in: -12...18))
            let duration = Int((distance * pace) / 60.0)
            let routePoints = routePoints(
                start: startedAt,
                count: 18,
                baseLatitude: 40.4153,
                baseLongitude: -3.6844,
                distanceKm: distance
            )
            sessions.append(
                WorkoutSession(
                    workoutTitle: "Carrera suave Retiro",
                    date: startedAt,
                    startedAt: startedAt,
                    endedAt: calendar.date(byAdding: .minute, value: duration, to: startedAt),
                    origin: .free,
                    location: .outdoor,
                    contextTag: .normal,
                    durationMinutes: duration,
                    sets: [],
                    notes: "Zona 2, respiracion nasal casi todo el rodaje.",
                    exerciseLogs: [],
                    sessionRPE: 5.5,
                    energyBefore: generator.nextInt(in: 3...5),
                    energyAfter: generator.nextInt(in: 4...5),
                    estimatedCalories: distance * 72,
                    routePoints: routePoints,
                    distanceKm: rounded(distance, places: 2),
                    averagePaceSecondsPerKm: pace,
                    steps: distance * 1_250,
                    activeEnergyKcal: distance * 71,
                    heartRateBefore: Double(generator.nextInt(in: 58...70)),
                    heartRateAfter: Double(generator.nextInt(in: 105...126)),
                    healthKitActivityTypes: ["running"],
                    averageHeartRate: Double(generator.nextInt(in: 132...146)),
                    maxHeartRate: Double(generator.nextInt(in: 158...176))
                )
            )
        }

        return sessions
    }

    private static func makeCardioLogs(
        from startDate: Date,
        through today: Date,
        calendar: Calendar,
        generator: inout SeededGenerator
    ) -> [CardioLog] {
        var logs: [CardioLog] = []
        let totalDays = max(calendar.dateComponents([.day], from: startDate, to: today).day ?? 365, 1)

        for dayOffset in stride(from: 2, through: totalDays, by: 10) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let activity: CardioLog.ActivityType = generator.nextDouble() > 0.55 ? .stationaryBike : .rowing
            let duration = generator.nextInt(in: 18...34)
            let distance = activity == .rowing ? Double(duration) * 0.22 : Double(duration) * 0.48
            logs.append(
                CardioLog(
                    activityType: activity,
                    date: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: date) ?? date,
                    durationMinutes: duration,
                    distanceKm: rounded(distance, places: 2),
                    averageSpeedKmh: rounded(distance / (Double(duration) / 60.0), places: 1),
                    averageHeartRate: Double(generator.nextInt(in: 122...148)),
                    maxHeartRate: Double(generator.nextInt(in: 150...172)),
                    estimatedCalories: Double(duration * generator.nextInt(in: 8...11)),
                    activeEnergyKcal: Double(duration * generator.nextInt(in: 7...10)),
                    heartRateBefore: Double(generator.nextInt(in: 62...76)),
                    heartRateAfter: Double(generator.nextInt(in: 96...118)),
                    rpe: Double(generator.nextInt(in: 5...8)),
                    notes: activity == .rowing ? "Remo tecnico, ritmo constante." : "Bici suave tras pierna."
                )
            )
        }

        return logs
    }

    private static func makeBodyMetrics(
        from startDate: Date,
        through today: Date,
        calendar: Calendar,
        generator: inout SeededGenerator
    ) -> [BodyMetric] {
        var metrics: [BodyMetric] = []
        let totalDays = max(calendar.dateComponents([.day], from: startDate, to: today).day ?? 365, 1)

        for dayOffset in stride(from: 0, through: totalDays, by: 7) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let progress = Double(dayOffset) / Double(totalDays)
            let weight = 84.8 - progress * 5.6 + Double(generator.nextInt(in: -4...4)) * 0.12
            metrics.append(
                BodyMetric(
                    date: calendar.date(bySettingHour: 7, minute: 8, second: 0, of: date) ?? date,
                    weightKg: rounded(weight, places: 1),
                    heightCm: 178,
                    bodyFatPercentage: rounded(20.5 - progress * 4.2 + Double(generator.nextInt(in: -2...2)) * 0.2, places: 1),
                    waistCm: rounded(91.0 - progress * 7.0 + Double(generator.nextInt(in: -3...3)) * 0.2, places: 1),
                    chestCm: rounded(104.0 + progress * 2.4 + Double(generator.nextInt(in: -2...2)) * 0.15, places: 1),
                    armCm: rounded(35.0 + progress * 1.8 + Double(generator.nextInt(in: -2...2)) * 0.1, places: 1),
                    thighCm: rounded(58.5 + progress * 1.5 + Double(generator.nextInt(in: -2...2)) * 0.1, places: 1),
                    hipCm: rounded(100.0 - progress * 2.2, places: 1),
                    calfCm: rounded(38.2 + progress * 0.6, places: 1),
                    neckCm: rounded(39.4 - progress * 0.3, places: 1),
                    sleepHours: rounded(7.1 + Double(generator.nextInt(in: -5...6)) * 0.08, places: 1),
                    sleepQuality: generator.nextInt(in: 3...5),
                    fatigue: generator.nextInt(in: 1...4),
                    stress: generator.nextInt(in: 1...4),
                    waterLiters: rounded(2.4 + generator.nextDouble() * 0.9, places: 1),
                    dietaryEnergyKcal: Double(generator.nextInt(in: 2_350...2_780)),
                    sorenessNotes: dayOffset % 28 == 0 ? "Carga alta de piernas, movilidad por la noche." : nil,
                    source: .manual
                )
            )
        }

        return metrics
    }

    private static func makeHealthState(
        from startDate: Date,
        through today: Date,
        calendar: Calendar,
        generator: inout SeededGenerator,
        workoutSessions: [WorkoutSession],
        cardioLogs: [CardioLog]
    ) -> HealthSyncState {
        let totalDays = max(calendar.dateComponents([.day], from: startDate, to: today).day ?? 365, 1)
        let sessionDays = Set(workoutSessions.map { calendar.startOfDay(for: $0.date) })
        let cardioDays = Set(cardioLogs.map { calendar.startOfDay(for: $0.date) })
        let metrics = (0...totalDays).compactMap { offset -> DailyHealthMetric? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let day = calendar.startOfDay(for: date)
            let trained = sessionDays.contains(day) || cardioDays.contains(day)
            let weekday = calendar.component(.weekday, from: date)
            let weekend = weekday == 1 || weekday == 7
            let stepsBase = trained ? 10_500 : (weekend ? 8_800 : 7_400)
            return DailyHealthMetric(
                date: day,
                steps: Double(stepsBase + generator.nextInt(in: -1_800...2_500)),
                activeEnergyKcal: Double((trained ? 760 : 430) + generator.nextInt(in: -90...140)),
                dietaryEnergyKcal: Double((trained ? 2_640 : 2_430) + generator.nextInt(in: -180...220)),
                waterLiters: rounded(2.3 + generator.nextDouble() * 1.1, places: 1),
                exerciseMinutes: trained ? Double(generator.nextInt(in: 42...78)) : Double(generator.nextInt(in: 12...32)),
                restingHeartRate: Double(61 - min(offset / 90, 3) + generator.nextInt(in: -3...4)),
                heartRateVariabilityMS: Double(48 + min(offset / 55, 6) + generator.nextInt(in: -6...8)),
                sleepHours: rounded(7.0 + generator.nextDouble() * 1.2 - (trained ? 0.1 : 0), places: 1),
                vo2MaxMlKgMin: rounded(42.0 + Double(offset) / Double(totalDays) * 4.8 + generator.nextDouble(), places: 1),
                sleepRemHours: rounded(1.3 + generator.nextDouble() * 0.45, places: 1),
                sleepDeepHours: rounded(1.0 + generator.nextDouble() * 0.5, places: 1),
                sleepCoreHours: rounded(4.2 + generator.nextDouble() * 0.7, places: 1),
                sleepAwakeHours: rounded(generator.nextDouble() * 0.45, places: 1),
                sleepInterruptions: generator.nextInt(in: 0...3)
            )
        }

        return HealthSyncState(
            isAvailable: true,
            isAuthorized: true,
            lastSyncDate: today,
            message: healthMessage,
            latestDailyMetrics: metrics
        )
    }

    private static func makeProgressPhotos(
        from startDate: Date,
        through today: Date,
        calendar: Calendar,
        bodyMetrics: [BodyMetric]
    ) -> [ProgressPhoto] {
        let totalDays = max(calendar.dateComponents([.day], from: startDate, to: today).day ?? 365, 1)
        return stride(from: 0, through: totalDays, by: 61).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let weight = bodyMetrics.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })?.weightKg
            return ProgressPhoto(
                date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date,
                imageData: makeProgressImageData(monthIndex: offset / 30),
                weightKg: weight,
                note: offset == 0 ? "Inicio recomp. Luz natural, misma distancia." : "Misma pose y condiciones para comparar."
            )
        }
    }

    private static func makeGymPasses(
        from startDate: Date,
        through today: Date,
        calendar: Calendar
    ) -> [GymPass] {
        let invoices = (0..<12).compactMap { monthOffset -> GymInvoice? in
            guard let date = calendar.date(byAdding: .month, value: -monthOffset, to: today),
                  let periodEnd = calendar.date(byAdding: .month, value: 1, to: date) else { return nil }
            return GymInvoice(
                date: date,
                amount: 54.90,
                currencyCode: "EUR",
                periodStart: date,
                periodEnd: periodEnd,
                note: "Cuota mensual Distrito Strength Club",
                attachmentData: makeReceiptImageData(monthOffset: monthOffset),
                attachmentIsPDF: false
            )
        }

        return [
            GymPass(
                gymName: "Distrito Strength Club",
                membershipID: "DSC-AR-2048",
                codeValue: "DSC-AR-2048-2026",
                codeType: .qr,
                colorHex: "#9AF02B",
                notes: "Sede Goya. Rack 3 suele estar libre antes de las 19:00.",
                imageData: makeCardImageData(title: "Distrito Strength", subtitle: "Alex Romero"),
                isActive: true,
                startDate: startDate,
                endDate: nil,
                planName: "Full access",
                price: 54.90,
                currencyCode: "EUR",
                billingCycle: .monthly,
                nextRenewalDate: calendar.date(byAdding: .month, value: 1, to: today),
                renewalReminderEnabled: true,
                venueAddress: "Calle de Goya 44, Madrid",
                venuePhone: "+34 910 000 204",
                venueWebsite: "https://example.com/distrito-strength",
                venueHours: "L-V 06:30-23:00, S-D 08:00-20:00",
                invoices: invoices
            )
        ]
    }

    private static func makeGymVisits(sessions: [WorkoutSession], gymName: String) -> [GymVisit] {
        sessions
            .filter { $0.location == .gym }
            .map {
                GymVisit(
                    gymName: gymName,
                    date: $0.date,
                    locationNote: "Sede Goya",
                    workoutTitle: $0.workoutTitle,
                    address: "Calle de Goya 44, Madrid",
                    latitude: 40.4248,
                    longitude: -3.6758,
                    workoutSessionIDs: [$0.id]
                )
            }
    }

    private static func makeSchedule(
        from startDate: Date,
        through today: Date,
        plan: WorkoutPlan,
        sessions: [WorkoutSession],
        calendar: Calendar
    ) -> [ScheduledWorkout] {
        let recentStart = calendar.date(byAdding: .day, value: -28, to: today) ?? startDate
        let completedByDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        var scheduled: [ScheduledWorkout] = []

        for dayOffset in stride(from: 0, through: 42, by: 2) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset - 28, to: today) else { continue }
            let day = calendar.startOfDay(for: date)
            guard date >= recentStart || date >= today else { continue }
            let planDay = plan.days[(dayOffset / 2) % max(plan.days.count, 1)]
            let status: ScheduledWorkout.Status
            if day < today {
                status = completedByDay[day] == nil ? .missed : .completed
            } else {
                status = .scheduled
            }
            scheduled.append(ScheduledWorkout(date: day, workoutDay: planDay, status: status))
        }

        return scheduled
    }

    private static func makeGoals(
        today: Date,
        calendar: Calendar,
        sessions: [WorkoutSession],
        bodyMetrics: [BodyMetric]
    ) -> [Goal] {
        let sortedMetrics = bodyMetrics.sorted { $0.date < $1.date }
        let startingWeight = sortedMetrics.first?.weightKg ?? 84.8
        let latestWeight = sortedMetrics.last?.weightKg ?? 79.2
        let weightLost = max(startingWeight - latestWeight, 0)
        let completedSessions = Double(sessions.count)
        return [
            Goal(
                kind: .strength,
                title: "Press banca 105 kg estimado",
                current: 101,
                target: 105,
                unit: "kg",
                deadline: calendar.date(byAdding: .day, value: 63, to: today),
                reason: "Llegar sin sacrificar tecnica ni hombro."
            ),
            Goal(
                kind: .bodyWeight,
                title: "Bajar 6.8 kg manteniendo fuerza",
                current: rounded(weightLost, places: 1),
                target: 6.8,
                unit: "kg perdidos",
                deadline: calendar.date(byAdding: .day, value: 90, to: today),
                reason: "Mantener rendimiento mientras baja cintura."
            ),
            Goal(
                kind: .consistency,
                title: "180 sesiones registradas",
                current: completedSessions,
                target: 180,
                unit: "sesiones",
                deadline: calendar.date(byAdding: .day, value: 1, to: today),
                reason: "Validar el ano completo de constancia."
            )
        ]
    }

    private static func routePoints(
        start: Date,
        count: Int,
        baseLatitude: Double,
        baseLongitude: Double,
        distanceKm: Double
    ) -> [RoutePoint] {
        (0..<count).map { index in
            let ratio = Double(index) / Double(max(count - 1, 1))
            let angle = ratio * .pi * 2
            return RoutePoint(
                latitude: baseLatitude + cos(angle) * 0.006 + ratio * 0.002,
                longitude: baseLongitude + sin(angle) * 0.009,
                altitude: 650 + sin(angle) * 12,
                horizontalAccuracy: 8,
                timestamp: start.addingTimeInterval(ratio * distanceKm * 360),
                heartRate: 126 + ratio * 28,
                cadenceSpm: 158 + ratio * 8
            )
        }
    }

    private static func baseWeightKg(for exercise: Exercise) -> Double {
        let name = exercise.name.lowercased()
        if name.contains("squat") || name.contains("hack") { return 86 }
        if name.contains("deadlift") { return 92 }
        if name.contains("hip thrust") { return 112 }
        if name.contains("leg press") { return 155 }
        if name.contains("bench") || name.contains("press") { return 64 }
        if name.contains("row") { return 55 }
        if name.contains("pulldown") || name.contains("pull") { return 58 }
        if name.contains("curl") || name.contains("raise") { return 16 }
        if name.contains("triceps") { return 28 }
        return exercise.trackingType == .weightReps ? 32 : 0
    }

    private static func repsForExercise(
        _ exercise: Exercise,
        setNumber: Int,
        generator: inout SeededGenerator
    ) -> Int {
        switch exercise.trackingType {
        case .duration:
            return generator.nextInt(in: 35...65)
        case .repsOnly:
            return generator.nextInt(in: 8...18)
        case .weightReps:
            let name = exercise.name.lowercased()
            if name.contains("squat") || name.contains("deadlift") || name.contains("bench") {
                return setNumber == 1 ? generator.nextInt(in: 5...8) : generator.nextInt(in: 6...10)
            }
            return generator.nextInt(in: 8...14)
        }
    }

    private static func sessionNote(for title: String, volume: Double) -> String {
        if title.localizedCaseInsensitiveContains("Lower") {
            return "Pierna solida. Rodilla estable y buena profundidad."
        }
        if title.localizedCaseInsensitiveContains("Upper") {
            return "Control escapular mejor, ultima serie exigente."
        }
        return "Sesion consistente. Volumen: \(Int(volume)) kg."
    }

    private static func roundedWeight(_ value: Double) -> Double {
        (value / 2.5).rounded() * 2.5
    }

    private static func rounded(_ value: Double, places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (value * factor).rounded() / factor
    }

    private static func makeProfileImageData(initials: String) -> Data? {
        renderImage(size: CGSize(width: 256, height: 256)) { rect in
            UIColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1).setFill()
            UIBezierPath(ovalIn: rect).fill()
            UIColor(red: 0.60, green: 0.94, blue: 0.16, alpha: 1).setFill()
            UIBezierPath(ovalIn: rect.insetBy(dx: 18, dy: 18)).fill()
            drawCentered(initials, in: rect, size: 82, color: .black, weight: .heavy)
        }
    }

    private static func makeProgressImageData(monthIndex: Int) -> Data {
        renderImage(size: CGSize(width: 720, height: 960)) { rect in
            UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1).setFill()
            UIRectFill(rect)
            UIColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 1).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: rect.width, height: rect.height * 0.42))
            UIColor(red: 0.74, green: 0.76, blue: 0.70, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 270, y: 170, width: 180, height: 520), cornerRadius: 88).fill()
            UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1).setFill()
            UIRectFill(CGRect(x: 245, y: 420, width: 230, height: 310))
            UIColor(red: 0.60, green: 0.94, blue: 0.16, alpha: 1).setStroke()
            let line = UIBezierPath()
            line.lineWidth = 8
            line.move(to: CGPoint(x: 90, y: 830))
            line.addLine(to: CGPoint(x: 90 + CGFloat(monthIndex) * 42, y: 830 - CGFloat(monthIndex) * 12))
            line.stroke()
            drawText("PROGRESO M\(monthIndex + 1)", in: CGRect(x: 40, y: 56, width: 640, height: 60), size: 34, color: .white, weight: .bold)
        } ?? Data()
    }

    private static func makeReceiptImageData(monthOffset: Int) -> Data? {
        renderImage(size: CGSize(width: 420, height: 560)) { rect in
            UIColor.white.setFill()
            UIRectFill(rect)
            UIColor.black.setFill()
            drawText("Distrito Strength Club", in: CGRect(x: 30, y: 42, width: 360, height: 40), size: 22, color: .black, weight: .bold)
            drawText("Cuota mensual", in: CGRect(x: 30, y: 105, width: 360, height: 32), size: 18, color: .darkGray, weight: .regular)
            drawText("54,90 EUR", in: CGRect(x: 30, y: 165, width: 360, height: 48), size: 32, color: .black, weight: .heavy)
            drawText("RECIBO #DSC-\(202600 + monthOffset)", in: CGRect(x: 30, y: 245, width: 360, height: 28), size: 16, color: .gray, weight: .medium)
            UIColor(white: 0.88, alpha: 1).setFill()
            for index in 0..<7 {
                UIRectFill(CGRect(x: 30, y: 315 + index * 24, width: 360, height: 2))
            }
        }
    }

    private static func makeCardImageData(title: String, subtitle: String) -> Data {
        renderImage(size: CGSize(width: 640, height: 360)) { rect in
            UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 28).fill()
            UIColor(red: 0.60, green: 0.94, blue: 0.16, alpha: 1).setFill()
            UIRectFill(CGRect(x: 0, y: rect.height - 76, width: rect.width, height: 76))
            drawText(title, in: CGRect(x: 36, y: 46, width: 560, height: 50), size: 32, color: .white, weight: .bold)
            drawText(subtitle, in: CGRect(x: 36, y: 108, width: 560, height: 40), size: 22, color: .lightGray, weight: .semibold)
            drawText("STREAKREP PRO", in: CGRect(x: 36, y: 292, width: 560, height: 36), size: 24, color: .black, weight: .heavy)
        } ?? Data()
    }

    private static func renderImage(size: CGSize, draw: (CGRect) -> Void) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(CGRect(origin: .zero, size: size))
        }.pngData()
    }

    private static func drawCentered(_ text: String, in rect: CGRect, size: CGFloat, color: UIColor, weight: UIFont.Weight) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        let measured = text.size(withAttributes: attributes)
        text.draw(
            in: CGRect(
                x: rect.midX - measured.width / 2,
                y: rect.midY - measured.height / 2,
                width: measured.width,
                height: measured.height
            ),
            withAttributes: attributes
        )
    }

    private static func drawText(_ text: String, in rect: CGRect, size: CGFloat, color: UIColor, weight: UIFont.Weight) {
        text.draw(
            in: rect,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color
            ]
        )
    }
}

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func nextDouble() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(nextDouble() * Double(span))
    }
}
