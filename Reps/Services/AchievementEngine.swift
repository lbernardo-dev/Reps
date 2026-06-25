import Foundation

// MARK: - Achievement Engine (AppStore extension)
// Detects when achievements are newly unlocked and queues them for overlay presentation.

extension AppStore {

    // MARK: - Dequeue

    /// Called by AchievementUnlockOverlay after the card is dismissed.
    func dequeueAchievementUnlock() {
        guard !pendingAchievementUnlocks.isEmpty else { return }
        pendingAchievementUnlocks.removeFirst()
    }

    // MARK: - Hydration achievements

    func evaluateHydrationAchievements(isFirstEverLog: Bool, logHour: Int) {
        if isFirstEverLog {
            queueIfNew(
                key: "achievement_first_sip_title",
                title: localizedString("achievement_first_sip_title"),
                desc: localizedString("achievement_first_sip_desc"),
                icon: "drop.fill",
                colorName: "blue",
                xp: 10
            )
        }

        let isMorningWindow = (7...9).contains(logHour)
        if isMorningWindow {
            queueIfNew(
                key: "achievement_morning_hydrator_title",
                title: localizedString("achievement_morning_hydrator_title"),
                desc: localizedString("achievement_morning_hydrator_desc"),
                icon: "sunrise.fill",
                colorName: "orange",
                xp: 5
            )
        }

        evaluateHydrationGoalAchievements()
    }

    // MARK: - Full achievement evaluation (call after workout finish / session import)

    func evaluateExistingAchievementUnlocks() {
        evaluateWorkoutAchievements()
        evaluateHydrationGoalAchievements()
    }

    func evaluateWorkoutAchievements() {
        let sessions     = workoutSessions
        let cardioLogs   = combinedCardioLogs
        let streak       = streakDays
        let totalVol     = totalVolumeKg
        let sessionCount = sessions.count
        let cardioCount  = cardioLogs.count
        let maxPR        = FitnessMetrics.personalRecordWeightKg(for: sessions) ?? 0.0
        let prCount      = sessions
            .flatMap { $0.exerciseLogs ?? [] }
            .flatMap { $0.sets }
            .filter { $0.isPersonalRecord && $0.completed }
            .count
        let muscleGroups = Set(sessions.flatMap { $0.exerciseLogs ?? [] }.map { $0.exercise.muscleGroup })
        let photoCount   = progressPhotos.count
        let hasLongCardio = cardioLogs.contains { $0.durationMinutes >= 45 }

        let checks: [(key: String, desc: String, icon: String, colorName: String, xp: Int, unlocked: Bool)] = [
            ("achievement_first_step_title",
             localizedString("achievement_first_step_desc"),
             "figure.walk", "orange", 10,
             sessionCount >= 1),

            ("achievement_iron_consistency_title",
             localizedString("achievement_iron_consistency_desc"),
             "flame.fill", "accent", 15,
             streak >= 3),

            ("achievement_habit_builder_title",
             localizedString("achievement_habit_builder_desc"),
             "flame.circle.fill", "orange", 25,
             streak >= 7),

            ("achievement_unstoppable_title",
             localizedString("achievement_unstoppable_desc"),
             "bolt.circle.fill", "yellow", 50,
             streak >= 21),

            ("achievement_getting_started_title",
             localizedString("achievement_getting_started_desc"),
             "dumbbell.fill", "primaryBright", 15,
             sessionCount >= 3),

            ("achievement_dedicated_title",
             localizedString("achievement_dedicated_desc"),
             "medal.fill", "orange", 30,
             sessionCount >= 10),

            ("achievement_veteran_title",
             localizedString("achievement_veteran_desc"),
             "shield.fill", "primaryBright", 100,
             sessionCount >= 50),

            ("achievement_titan_lifter_title",
             localizedString("achievement_titan_lifter_desc"),
             "scalemass.fill", "primaryBright", 40,
             totalVol >= 5000.0 || maxPR >= 80.0),

            ("achievement_iron_giant_title",
             localizedString("achievement_iron_giant_desc"),
             "bolt.fill", "yellow", 150,
             totalVol >= 50_000.0),

            ("achievement_record_breaker_title",
             localizedString("achievement_record_breaker_desc"),
             "trophy", "accent", 25,
             prCount >= 1),

            ("achievement_pr_machine_title",
             localizedString("achievement_pr_machine_desc"),
             "trophy.fill", "yellow", 75,
             prCount >= 10),

            ("achievement_endurance_hero_title",
             localizedString("achievement_endurance_hero_desc"),
             "figure.run", "primaryBright", 20,
             hasLongCardio || cardioCount >= 3),

            ("achievement_cardio_devotee_title",
             localizedString("achievement_cardio_devotee_desc"),
             "heart.circle.fill", "red", 40,
             cardioCount >= 10),

            ("achievement_full_body_title",
             localizedString("achievement_full_body_desc"),
             "figure.mixed.cardio", "primaryBright", 30,
             muscleGroups.count >= 5),

            ("achievement_evidence_keeper_title",
             localizedString("achievement_evidence_keeper_desc"),
             "camera.fill", "purple", 15,
             photoCount >= 3),
        ]

        for c in checks where c.unlocked {
            queueIfNew(key: c.key, title: localizedString(c.key), desc: c.desc,
                       icon: c.icon, colorName: c.colorName, xp: c.xp)
        }
    }

    func evaluateHydrationGoalAchievements() {
        let goalLiters = max(userProfile.dailyWaterGoalLiters, 0.1)
        let goalDays = health.latestDailyMetrics.filter { $0.waterLiters >= goalLiters }.count
        if goalDays >= 3 {
            queueIfNew(
                key: "achievement_hydration_hero_title",
                title: localizedString("achievement_hydration_hero_title"),
                desc: localizedString("achievement_hydration_hero_desc"),
                icon: "drop.circle.fill",
                colorName: "primaryBright",
                xp: 25
            )
        }
    }

    // MARK: - Private helper

    private func queueIfNew(key: String, title: String, desc: String,
                            icon: String, colorName: String, xp: Int) {
        guard !seenAchievementKeys.contains(key) else { return }
        guard !pendingAchievementUnlocks.contains(where: { $0.id == key }) else { return }
        seenAchievementKeys.insert(key)
        UserDefaults.standard.set(Array(seenAchievementKeys), forKey: seenAchievementsKey)
        pendingAchievementUnlocks.append(
            AchievementUnlockBanner(id: key, title: title, description: desc,
                                    systemImage: icon, colorName: colorName, xpReward: xp)
        )
    }
}
