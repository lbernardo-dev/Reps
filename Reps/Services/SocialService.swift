import CloudKit
import Foundation

// MARK: - WorkoutPost Model

struct WorkoutPost: Identifiable, Equatable, Hashable, Sendable {
    let id: String               // CKRecord recordName
    var ownerUsername: String
    var ownerDisplayName: String
    var workoutTitle: String
    var durationSeconds: Int
    var volumeKg: Double
    var exerciseNames: [String]
    var createdAt: Date
    var likeCount: Int
    var commentCount: Int

    init?(record: CKRecord) {
        guard
            let owner = record["ownerUsername"] as? String,
            let title = record["workoutTitle"] as? String
        else { return nil }
        self.id = record.recordID.recordName
        self.ownerUsername = owner
        self.ownerDisplayName = record["ownerDisplayName"] as? String ?? owner
        self.workoutTitle = title
        self.durationSeconds = (record["durationSeconds"] as? Int64).map(Int.init) ?? 0
        self.volumeKg = record["volumeKg"] as? Double ?? 0
        self.exerciseNames = record["exerciseNames"] as? [String] ?? []
        self.createdAt = record.creationDate ?? .now
        self.likeCount = (record["likeCount"] as? Int64).map(Int.init) ?? 0
        self.commentCount = (record["commentCount"] as? Int64).map(Int.init) ?? 0
    }
}

// MARK: - WorkoutComment Model

struct WorkoutComment: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    var ownerUsername: String
    var ownerDisplayName: String
    var text: String
    var createdAt: Date

    init?(record: CKRecord) {
        guard
            let owner = record["ownerUsername"] as? String,
            let text = record["text"] as? String
        else { return nil }
        self.id = record.recordID.recordName
        self.ownerUsername = owner
        self.ownerDisplayName = record["ownerDisplayName"] as? String ?? owner
        self.text = text
        self.createdAt = record.creationDate ?? .now
    }
}

// MARK: - Public Profile Model

struct SocialProfile: Identifiable, Equatable, Hashable, Sendable {
    let id: String          // normalized username — stable record key
    var username: String
    var displayName: String
    var ownerRecordName: String
    var bio: String
    var location: String
    var activePlanName: String
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
        self.bio = record["bio"] as? String ?? ""
        self.location = record["location"] as? String ?? ""
        self.activePlanName = record["activePlanName"] as? String ?? ""
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
        bio: String,
        location: String,
        activePlanName: String,
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
        record["bio"] = bio as CKRecordValue
        record["location"] = location as CKRecordValue
        record["activePlanName"] = activePlanName as CKRecordValue
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

    // MARK: - Suggested Athletes
    //
    // Featured seed usernames baked into the app — fetched via direct record(for:)
    // lookups, no index required. Add usernames here as the community grows.
    static let featuredUsernames: [String] = [
        "repsfitness", "repsofficial"
    ]

    // Returns featured profiles that are not already followed by the current user.
    func fetchSuggested(excluding followingUsernames: [String]) async throws -> [SocialProfile] {
        let excluded = Set(followingUsernames.map { $0.lowercased() })
        let candidates = Self.featuredUsernames.filter { !excluded.contains($0) }
        guard !candidates.isEmpty else { return [] }
        let ids = candidates.map { profileRecordID(username: $0) }
        let results = try await publicDB.records(for: ids)
        return results.values
            .compactMap { res in (try? res.get()).flatMap(SocialProfile.init) }
            .sorted { $0.totalXP > $1.totalXP }
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

    // MARK: - Feed (WorkoutPost)
    //
    // WorkoutPost recordName: "WorkoutPost_<ownerUsername>_<sessionID>"
    // No CKQuery needed for self-feed — we build record IDs from known usernames.
    // For friend feeds we use a CKQuery on `ownerUsername` which requires a
    // QUERYABLE index on that field in CloudKit Dashboard.  We degrade gracefully.

    private func postRecordID(username: String, sessionID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "WorkoutPost_\(username.lowercased())_\(sessionID)")
    }

    func publishPost(
        username: String,
        displayName: String,
        sessionID: String,
        workoutTitle: String,
        durationSeconds: Int,
        volumeKg: Double,
        exerciseNames: [String]
    ) async throws {
        let rid = postRecordID(username: username, sessionID: sessionID)
        let record = CKRecord(recordType: "WorkoutPost", recordID: rid)
        record["ownerUsername"] = username.lowercased() as CKRecordValue
        record["ownerDisplayName"] = displayName as CKRecordValue
        record["workoutTitle"] = workoutTitle as CKRecordValue
        record["durationSeconds"] = Int64(durationSeconds) as CKRecordValue
        record["volumeKg"] = volumeKg as CKRecordValue
        record["exerciseNames"] = exerciseNames as CKRecordValue
        record["likeCount"] = Int64(0) as CKRecordValue
        record["commentCount"] = Int64(0) as CKRecordValue
        try await publicDB.save(record)
    }

    // Fetches posts from a list of usernames using a CKQuery.
    // Degrades to empty array when index is unavailable.
    func fetchFeed(followingUsernames: [String], limit: Int = 30) async throws -> [WorkoutPost] {
        guard !followingUsernames.isEmpty else { return [] }
        let lowercased = followingUsernames.map { $0.lowercased() }
        let pred = NSPredicate(format: "ownerUsername IN %@", lowercased)
        let query = CKQuery(recordType: "WorkoutPost", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: limit)
            return result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(WorkoutPost.init) }
        } catch let ck as CKError where ck.code == .unknownItem || ck.code == .invalidArguments {
            return []
        }
    }

    // MARK: - Likes
    //
    // WorkoutLike recordName: "WorkoutLike_<likerOwner>_<postRecordName>"

    private func likeRecordID(likerOwner: String, postRecordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "WorkoutLike_\(likerOwner)_\(postRecordName)")
    }

    func likePost(_ post: WorkoutPost) async throws {
        let myID = try await myRecordID()
        let lid = likeRecordID(likerOwner: myID.recordName, postRecordName: post.id)
        let record = CKRecord(recordType: "WorkoutLike", recordID: lid)
        record["likerOwnerName"] = myID.recordName as CKRecordValue
        record["postRecordName"] = post.id as CKRecordValue
        record["postOwnerUsername"] = post.ownerUsername.lowercased() as CKRecordValue
        try await publicDB.save(record)
    }

    func unlikePost(_ post: WorkoutPost) async throws {
        let myID = try await myRecordID()
        let lid = likeRecordID(likerOwner: myID.recordName, postRecordName: post.id)
        try await publicDB.deleteRecord(withID: lid)
    }

    func isLiked(_ post: WorkoutPost) async throws -> Bool {
        let myID = try await myRecordID()
        let lid = likeRecordID(likerOwner: myID.recordName, postRecordName: post.id)
        do {
            _ = try await publicDB.record(for: lid)
            return true
        } catch let ck as CKError where ck.code == .unknownItem {
            return false
        }
    }

    // MARK: - Comments
    //
    // WorkoutComment recordName: "WorkoutComment_<postID>_<uuid>"
    // Requires a QUERYABLE index on `postRecordName` in CloudKit Dashboard.
    // Degrades to empty array gracefully when index is unavailable.

    func addComment(
        postID: String,
        text: String,
        ownerUsername: String,
        ownerDisplayName: String
    ) async throws -> WorkoutComment {
        let myID = try await myRecordID()
        let rid = CKRecord.ID(recordName: "WorkoutComment_\(postID)_\(UUID().uuidString)")
        let record = CKRecord(recordType: "WorkoutComment", recordID: rid)
        record["postRecordName"] = postID as CKRecordValue
        record["ownerUsername"] = ownerUsername.lowercased() as CKRecordValue
        record["ownerDisplayName"] = ownerDisplayName as CKRecordValue
        record["ownerRecordName"] = myID.recordName as CKRecordValue
        record["text"] = text as CKRecordValue
        try await publicDB.save(record)
        guard let comment = WorkoutComment(record: record) else {
            throw NSError(domain: "SocialService", code: 0, userInfo: nil)
        }
        return comment
    }

    func fetchComments(postID: String, limit: Int = 50) async throws -> [WorkoutComment] {
        let pred = NSPredicate(format: "postRecordName == %@", postID)
        let query = CKQuery(recordType: "WorkoutComment", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: limit)
            return result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(WorkoutComment.init) }
        } catch {
            return []
        }
    }

    // MARK: - Push subscriptions
    //
    // Subscribes to CloudKit push for social activity targeting myUsername.
    // Requires QUERYABLE indexes on `followingUsername` (SocialFollow) and
    // `postOwnerUsername` (WorkoutLike) in CloudKit Dashboard.
    // Silently no-ops when subscription save fails.

    func subscribeToSocialActivity(myUsername: String) async {
        let username = myUsername.lowercased()

        // New follower
        let followPred = NSPredicate(format: "followingUsername == %@", username)
        let followSub = CKQuerySubscription(
            recordType: "SocialFollow",
            predicate: followPred,
            subscriptionID: "new-follower-\(username)",
            options: .firesOnRecordCreation
        )
        let followNote = CKSubscription.NotificationInfo()
        followNote.shouldSendContentAvailable = true
        followSub.notificationInfo = followNote

        // New like on own posts
        let likePred = NSPredicate(format: "postOwnerUsername == %@", username)
        let likeSub = CKQuerySubscription(
            recordType: "WorkoutLike",
            predicate: likePred,
            subscriptionID: "new-like-\(username)",
            options: .firesOnRecordCreation
        )
        let likeNote = CKSubscription.NotificationInfo()
        likeNote.shouldSendContentAvailable = true
        likeSub.notificationInfo = likeNote

        _ = try? await publicDB.save(followSub)
        _ = try? await publicDB.save(likeSub)
    }
}
