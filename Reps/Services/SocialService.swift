import CloudKit
import Foundation

// MARK: - Public Profile Model

struct SocialProfile: Identifiable, Equatable, Hashable, Sendable {
    let id: String          // iCloud user record name — stable unique identity
    var username: String
    var displayName: String
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
        self.id = owner
        self.username = username
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

// CloudKit public DB schema — record types (auto-created on first write in dev;
// must be promoted in CloudKit Dashboard before production release):
//   SocialProfile: username(q), displayName, ownerRecordName(q), level,
//                  levelTitle, totalXP, totalSessions, streakDays, totalVolumeKg
//   SocialFollow:  followerRecordName(q), followingRecordName(q), followingUsername
// Indexes: username (QUERY on SocialProfile), followerRecordName & followingRecordName (QUERY on SocialFollow)
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

    private func profileRecordID(for ownerName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "Profile_\(ownerName)")
    }

    private func followRecordID(follower: String, following: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "Follow_\(follower)_\(following)")
    }

    // MARK: - Profile

    func checkAvailability(username: String) async throws -> Bool {
        let normalized = username.lowercased()
        let pred = NSPredicate(format: "username == %@", normalized)
        let query = CKQuery(recordType: "SocialProfile", predicate: pred)
        let result = try await publicDB.records(matching: query, resultsLimit: 1)
        return result.matchResults.isEmpty
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
        let profileID = profileRecordID(for: myID.recordName)

        let record: CKRecord
        do {
            record = try await publicDB.record(for: profileID)
        } catch let ck as CKError where ck.code == .unknownItem {
            record = CKRecord(recordType: "SocialProfile", recordID: profileID)
            record["ownerRecordName"] = myID.recordName as CKRecordValue
        }

        record["username"] = username.lowercased() as CKRecordValue
        record["displayName"] = displayName as CKRecordValue
        record["level"] = Int64(level) as CKRecordValue
        record["levelTitle"] = levelTitle as CKRecordValue
        record["totalXP"] = Int64(totalXP) as CKRecordValue
        record["totalSessions"] = Int64(totalSessions) as CKRecordValue
        record["streakDays"] = Int64(streakDays) as CKRecordValue
        record["totalVolumeKg"] = totalVolumeKg as CKRecordValue

        try await publicDB.save(record)
    }

    func fetchMyProfile() async throws -> SocialProfile? {
        let myID = try await myRecordID()
        let profileID = profileRecordID(for: myID.recordName)
        do {
            let record = try await publicDB.record(for: profileID)
            return SocialProfile(record: record)
        } catch let ck as CKError where ck.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Discovery

    func searchUsers(query: String) async throws -> [SocialProfile] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let myID = try await myRecordID()
        let normalized = query.lowercased()
        let pred = NSPredicate(format: "username BEGINSWITH %@", normalized)
        let ckQuery = CKQuery(recordType: "SocialProfile", predicate: pred)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]
        let result = try await publicDB.records(matching: ckQuery, resultsLimit: 25)
        return result.matchResults
            .compactMap { _, res in (try? res.get()).flatMap(SocialProfile.init) }
            .filter { $0.id != myID.recordName }
    }

    // MARK: - Follow / Unfollow

    func follow(_ profile: SocialProfile) async throws {
        let myID = try await myRecordID()
        let fid = followRecordID(follower: myID.recordName, following: profile.id)
        let record = CKRecord(recordType: "SocialFollow", recordID: fid)
        record["followerRecordName"] = myID.recordName as CKRecordValue
        record["followingRecordName"] = profile.id as CKRecordValue
        record["followingUsername"] = profile.username as CKRecordValue
        try await publicDB.save(record)
    }

    func unfollow(_ profile: SocialProfile) async throws {
        let myID = try await myRecordID()
        let fid = followRecordID(follower: myID.recordName, following: profile.id)
        try await publicDB.deleteRecord(withID: fid)
    }

    func isFollowing(_ profile: SocialProfile) async throws -> Bool {
        let myID = try await myRecordID()
        let fid = followRecordID(follower: myID.recordName, following: profile.id)
        do {
            _ = try await publicDB.record(for: fid)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Social graph

    func fetchFollowing() async throws -> [SocialProfile] {
        let myID = try await myRecordID()
        let pred = NSPredicate(format: "followerRecordName == %@", myID.recordName)
        let followQuery = CKQuery(recordType: "SocialFollow", predicate: pred)
        let follows = try await publicDB.records(matching: followQuery, resultsLimit: 200)

        let followingIDs = follows.matchResults.compactMap { _, res in
            (try? res.get())?["followingRecordName"] as? String
        }
        guard !followingIDs.isEmpty else { return [] }

        let profileIDs = followingIDs.map { profileRecordID(for: $0) }
        let profileResults = try await publicDB.records(for: profileIDs)
        return profileResults.values
            .compactMap { res in (try? res.get()).flatMap(SocialProfile.init) }
            .sorted { $0.totalXP > $1.totalXP }
    }

    func fetchFollowerCount() async throws -> Int {
        let myID = try await myRecordID()
        let pred = NSPredicate(format: "followingRecordName == %@", myID.recordName)
        let query = CKQuery(recordType: "SocialFollow", predicate: pred)
        let result = try await publicDB.records(matching: query, resultsLimit: 200)
        return result.matchResults.count
    }
}
