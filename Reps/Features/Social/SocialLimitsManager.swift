//
//  SocialLimitsManager.swift
//  Reps
//

import Foundation

@MainActor
final class SocialLimitsManager {
    static let shared = SocialLimitsManager()
    private init() {}

    private let defaults = UserDefaults.standard
    private let lastPostDateKey = "social_free_last_post_date"
    private let inviteDatesKey = "social_free_invite_dates"

    // MARK: - Posts (Max 1 post per 24 hours for Free)

    func canPostToday(hasProAccess: Bool) -> Bool {
        if hasProAccess { return true }
        guard let lastPost = defaults.object(forKey: lastPostDateKey) as? Date else { return true }
        return Date().timeIntervalSince(lastPost) >= 86400
    }

    func remainingPostsToday(hasProAccess: Bool) -> Int {
        if hasProAccess { return 999 }
        return canPostToday(hasProAccess: false) ? 1 : 0
    }

    func timeUntilPostReset() -> String {
        guard let lastPost = defaults.object(forKey: lastPostDateKey) as? Date else { return "0h 0m" }
        let elapsed = Date().timeIntervalSince(lastPost)
        let remaining = max(0, 86400 - elapsed)
        if remaining <= 0 { return "0h 0m" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    func recordPostSent() {
        defaults.set(Date(), forKey: lastPostDateKey)
    }

    // MARK: - Connections & Invites (Max 3 per 24 hours for Free)

    private var storedInviteDates: [Date] {
        get {
            guard let raw = defaults.array(forKey: inviteDatesKey) as? [Date] else { return [] }
            let now = Date()
            return raw.filter { now.timeIntervalSince($0) < 86400 }
        }
        set {
            defaults.set(newValue, forKey: inviteDatesKey)
        }
    }

    func canSendInviteToday(hasProAccess: Bool) -> Bool {
        if hasProAccess { return true }
        return storedInviteDates.count < 3
    }

    func remainingInvitesToday(hasProAccess: Bool) -> Int {
        if hasProAccess { return 999 }
        return max(0, 3 - storedInviteDates.count)
    }

    func timeUntilInviteReset() -> String {
        let dates = storedInviteDates
        guard let oldest = dates.min() else { return "0h 0m" }
        let elapsed = Date().timeIntervalSince(oldest)
        let remaining = max(0, 86400 - elapsed)
        if remaining <= 0 { return "0h 0m" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    func recordInviteSent() {
        var dates = storedInviteDates
        dates.append(Date())
        storedInviteDates = dates
    }

    // MARK: - Challenges

    func canJoinChallenge(currentActiveCount: Int, hasProAccess: Bool) -> Bool {
        if hasProAccess { return true }
        return currentActiveCount < 1
    }

    func canCreateChallenge(hasProAccess: Bool) -> Bool {
        return hasProAccess
    }

    // MARK: - XP Boost (10% Bonus for Premium)

    static func applyXPBoost(baseXP: Int, isPremium: Bool) -> Int {
        if isPremium {
            return Int(Double(baseXP) * 1.10)
        }
        return baseXP
    }
}
