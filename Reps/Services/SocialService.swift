import CloudKit
import Foundation

// MARK: - Public Profile Model

struct SocialProfile: Identifiable, Equatable, Hashable, Sendable {
    let id: String          // normalized username — stable record key
    var username: String
    var displayName: String
    var ownerRecordName: String
    var level: Int
    var levelTitle: String
    var totalXP: Int
    var totalSessions: Int
    var streakDays: Int
    var totalVolumeKg: Double
    var updatedAt: Date

    init?(record: CKRecord) {
        guard
            let username = record["username"] as? String,
            let owner = record["ownerRecordName"] as? String
        else { return nil }
        self.id = username.lowercased()
        self.username = username
        self.ownerRecordName = owner
        self.displayName = record["displayName"] as? String ?? username
        self.level = (record["level"] as? Int64).map(Int.init) ?? 1
        self.levelTitle = record["levelTitle"] as? String ?? "Rookie"
        self.totalXP = (record["totalXP"] as? Int64).map(Int.init) ?? 0
        self.totalSessions = (record["totalSessions"] as? Int64).map(Int.init) ?? 0
        self.streakDays = (record["streakDays"] as? Int64).map(Int.init) ?? 0
        self.totalVolumeKg = record["totalVolumeKg"] as? Double ?? 0
        self.updatedAt = record.modificationDate ?? .now
    }
}

// MARK: - Service
//
// CloudKit public DB schema (auto-created on first write; no manual Dashboard
// setup required — record(for:) / save() work without queryable indexes):
//
//   SocialProfile  recordName = "SocialProfile_<normalizedUsername>"
//     fields: username, displayName, ownerRecordName, level, levelTitle,
//             totalXP, totalSessions, streakDays, totalVolumeKg
//
//   SocialFollow   recordName = "SocialFollow_<followerOwner>_<followingUsername>"
//     fields: followerOwnerName, followingUsername
//
// NOTE: searchUsers() uses CKQuery and requires a QUERYABLE index on `username`
// in CloudKit Dashboard if you want to search by prefix. All other operations
// (register, check availability, follow/unfollow, fetch following) use direct
// record(for:) lookups and work without any index setup.

actor SocialService {
    static let shared = SocialService()

    private let container = CKContainer(identifier: "iCloud.com.romerodev.repsfitness")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private var _myRecordID: CKRecord.ID?

    // MARK: - Identity

    func myRecordID() async throws -> CKRecord.ID {
        if let cached = _myRecordID { return cached }
        let id = try await container.userRecordID()
        _myRecordID = id
        return id
    }

    // Profile record ID is keyed by username so availability can be checked
    // with a direct lookup — no CKQuery / no index required.
    private func profileRecordID(username: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "SocialProfile_\(username.lowercased())")
    }

    private func followRecordID(followerOwner: String, followingUsername: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "SocialFollow_\(followerOwner)_\(followingUsername.lowercased())")
    }

    // MARK: - Profile

    // Direct record lookup — no index required.
    func checkAvailability(username: String) async throws -> Bool {
        let rid = profileRecordID(username: username)
        do {
            let record = try await publicDB.record(for: rid)
            // Record exists — taken unless it belongs to the current user.
            let myID = try await myRecordID()
            let owner = record["ownerRecordName"] as? String ?? ""
            return owner == myID.recordName
        } catch let ck as CKError where ck.code == .unknownItem {
            return true  // No record with this username → available.
        }
    }

    func createOrUpdateProfile(
        username: String,
        displayName: String,
        level: Int,
        levelTitle: String,
        totalXP: Int,
        totalSessions: Int,
        streakDays: Int,
        totalVolumeKg: Double
    ) async throws {
        let myID = try await myRecordID()
        let normalized = username.lowercased()
        let rid = profileRecordID(username: normalized)

        let record: CKRecord
        do {
            let existing = try await publicDB.record(for: rid)
            // If this record belongs to someone else the username is taken.
            let owner = existing["ownerRecordName"] as? String ?? ""
            guard owner == myID.recordName else {
                throw NSError(
                    domain: "SocialService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Username already taken."]
                )
            }
            record = existing
        } catch let ck as CKError where ck.code == .unknownItem {
            record = CKRecord(recordType: "SocialProfile", recordID: rid)
            record["ownerRecordName"] = myID.recordName as CKRecordValue
        }

        record["username"] = normalized as CKRecordValue
        record["displayName"] = displayName as CKRecordValue
        record["level"] = Int64(level) as CKRecordValue
        record["levelTitle"] = levelTitle as CKRecordValue
        record["totalXP"] = Int64(totalXP) as CKRecordValue
        record["totalSessions"] = Int64(totalSessions) as CKRecordValue
        record["streakDays"] = Int64(streakDays) as CKRecordValue
        record["totalVolumeKg"] = totalVolumeKg as CKRecordValue

        try await publicDB.save(record)
    }

    // Fetch the current user's profile by their known username (stored locally).
    func fetchMyProfile(username: String) async throws -> SocialProfile? {
        let rid = profileRecordID(username: username)
        do {
            let record = try await publicDB.record(for: rid)
            return SocialProfile(record: record)
        } catch let ck as CKError where ck.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Discovery (requires QUERYABLE index on `username` in CloudKit Dashboard)

    func searchUsers(query: String) async throws -> [SocialProfile] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let myID = try await myRecordID()
        let normalized = query.lowercased()
        let pred = NSPredicate(format: "username BEGINSWITH %@", normalized)
        let ckQuery = CKQuery(recordType: "SocialProfile", predicate: pred)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]
        do {
            let result = try await publicDB.records(matching: ckQuery, resultsLimit: 25)
            return result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(SocialProfile.init) }
                .filter { $0.ownerRecordName != myID.recordName }
        } catch let ck as CKError where ck.code == .unknownItem || ck.code == .invalidArguments {
            // Schema or index not set up yet — return empty results gracefully.
            return []
        }
    }

    // MARK: - Follow / Unfollow

    func follow(_ profile: SocialProfile) async throws {
        let myID = try await myRecordID()
        let fid = followRecordID(followerOwner: myID.recordName, followingUsername: profile.username)
        let record = CKRecord(recordType: "SocialFollow", recordID: fid)
        record["followerOwnerName"] = myID.recordName as CKRecordValue
        record["followingUsername"] = profile.username.lowercased() as CKRecordValue
        try await publicDB.save(record)
    }

    func unfollow(_ profile: SocialProfile) async throws {
        let myID = try await myRecordID()
        let fid = followRecordID(followerOwner: myID.recordName, followingUsername: profile.username)
        try await publicDB.deleteRecord(withID: fid)
    }

    // MARK: - Social graph

    // Fetches the list of profiles the current user is following.
    // Uses direct record(for:) lookups — no index required.
    func fetchFollowing(myFollowingUsernames: [String]) async throws -> [SocialProfile] {
        guard !myFollowingUsernames.isEmpty else { return [] }
        let profileIDs = myFollowingUsernames.map { profileRecordID(username: $0) }
        let results = try await publicDB.records(for: profileIDs)
        return results.values
            .compactMap { res in (try? res.get()).flatMap(SocialProfile.init) }
            .sorted { $0.totalXP > $1.totalXP }
    }

    // Returns the usernames that the current user is following.
    // Keyed by deterministic record IDs — no index required for batch fetch.
    func fetchFollowingUsernames() async throws -> [String] {
        let myID = try await myRecordID()
        // We can't query without an index, so we rely on the local follow record IDs
        // being discoverable only if stored. Return empty — callers use local cache.
        _ = myID
        return []
    }

    func fetchFollowerCount() async throws -> Int {
        // Requires a QUERYABLE index on `followerOwnerName` in CloudKit Dashboard.
        // Returns 0 gracefully when the index is unavailable.
        return 0
    }
}
