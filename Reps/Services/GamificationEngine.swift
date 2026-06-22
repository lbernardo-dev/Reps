import Foundation

struct PlayerLevel {
    let level: Int
    let titleKey: String
    let totalXP: Int
    let xpIntoCurrentLevel: Int
    let xpToNextLevel: Int
    let progress: Double
    let isMaxLevel: Bool

    var title: String {
        localizedString(titleKey)
    }
}

enum GamificationEngine {
    // MARK: - Level table (cumulative XP to reach that level)
    private static let levelTable: [(level: Int, xp: Int, key: String)] = [
        (1,     0,    "player_level_rookie"),
        (2,   150,    "player_level_amateur"),
        (3,   400,    "player_level_trainee"),
        (4,   800,    "player_level_lifter"),
        (5,  1400,    "player_level_athlete"),
        (6,  2200,    "player_level_competitor"),
        (7,  3200,    "player_level_champion"),
        (8,  4500,    "player_level_elite"),
        (9,  6000,    "player_level_legend"),
        (10, 8000,    "player_level_goat"),
    ]

    // MARK: - XP calculation
    static func totalXP(
        sessions: [WorkoutSession],
        cardioLogs: [CardioLog],
        bodyMetrics: [BodyMetric],
        progressPhotos: [ProgressPhoto],
        streakDays: Int,
        totalVolumeKg: Double
    ) -> Int {
        var xp = 0

        // +50 per strength/free session
        xp += sessions.count * 50

        // +25 per cardio log
        xp += cardioLogs.count * 25

        // +10 per body metric (cap at 100 to avoid trivial farming)
        xp += min(bodyMetrics.count * 10, 100)

        // +10 per progress photo (cap at 100)
        xp += min(progressPhotos.count * 10, 100)

        // +75 per flagged PR set
        let prCount = sessions
            .flatMap { $0.exerciseLogs ?? [] }
            .flatMap { $0.sets }
            .filter { $0.isPersonalRecord && $0.completed }
            .count
        xp += prCount * 75

        // Volume milestones: +200 each
        for milestone in [1_000.0, 5_000.0, 10_000.0, 25_000.0, 50_000.0, 100_000.0] {
            if totalVolumeKg >= milestone { xp += 200 }
        }

        // Streak milestones: +100 each (7, 14, 21, 30, 60, 90)
        for milestone in [7, 14, 21, 30, 60, 90] {
            if streakDays >= milestone { xp += 100 }
        }

        return xp
    }

    // MARK: - Level resolution
    static func playerLevel(for xp: Int) -> PlayerLevel {
        let maxIdx = levelTable.count - 1
        var currentIdx = 0
        for (idx, entry) in levelTable.enumerated() where xp >= entry.xp {
            currentIdx = idx
        }

        let isMax = currentIdx == maxIdx
        let current = levelTable[currentIdx]
        let nextXP = isMax ? current.xp : levelTable[currentIdx + 1].xp
        let span = max(nextXP - current.xp, 1)
        let into = xp - current.xp
        let progress = isMax ? 1.0 : min(Double(into) / Double(span), 1.0)

        return PlayerLevel(
            level: current.level,
            titleKey: current.key,
            totalXP: xp,
            xpIntoCurrentLevel: into,
            xpToNextLevel: isMax ? 0 : span - into,
            progress: progress,
            isMaxLevel: isMax
        )
    }
}
