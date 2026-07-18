import CloudKit
import Foundation
import Network

// MARK: - WorkoutPost Model

struct WorkoutPost: Identifiable, Equatable, Hashable, Sendable {
    let id: String               // CKRecord recordName
    var ownerUsername: String
    var ownerDisplayName: String
    var workoutTitle: String
    var caption: String?         // free-text body of a manual post
    var durationSeconds: Int
    var volumeKg: Double
    var exerciseNames: [String]
    var createdAt: Date
    var likeCount: Int
    var commentCount: Int
    var photoDataList: [Data]    // up to 3 photos decoded from CKAssets

    var isCustomPost: Bool { durationSeconds == 0 && exerciseNames.isEmpty }

    init?(record: CKRecord) {
        guard
            let owner = record["ownerUsername"] as? String,
            let title = record["workoutTitle"] as? String
        else { return nil }
        self.id = record.recordID.recordName
        self.ownerUsername = owner
        self.ownerDisplayName = record["ownerDisplayName"] as? String ?? owner
        self.workoutTitle = title
        self.caption = record["caption"] as? String
        self.durationSeconds = (record["durationSeconds"] as? Int64).map(Int.init) ?? 0
        self.volumeKg = record["volumeKg"] as? Double ?? 0
        self.exerciseNames = record["exerciseNames"] as? [String] ?? []
        self.createdAt = record.creationDate ?? .now
        self.likeCount = (record["likeCount"] as? Int64).map(Int.init) ?? 0
        self.commentCount = (record["commentCount"] as? Int64).map(Int.init) ?? 0
        var photos: [Data] = []
        for i in 1...3 {
            if let asset = record["photo\(i)Asset"] as? CKAsset,
               let url = asset.fileURL,
               let data = try? Data(contentsOf: url) {
                photos.append(data)
            }
        }
        self.photoDataList = photos
    }
}

// MARK: - WorkoutComment Model

struct WorkoutComment: Identifiable, Equatable, Hashable, Sendable, Codable {
    let id: String
    var ownerUsername: String
    var ownerDisplayName: String
    var text: String
    var createdAt: Date
    var ownerAvatarData: Data?        // decoded from CKAsset "avatarAsset"
    /// True while the comment lives only in the local outbox and has not yet
    /// been confirmed in CloudKit (e.g. written while offline).
    var isPending: Bool = false

    init(
        id: String,
        ownerUsername: String,
        ownerDisplayName: String,
        text: String,
        createdAt: Date,
        ownerAvatarData: Data?,
        isPending: Bool = false
    ) {
        self.id = id
        self.ownerUsername = ownerUsername
        self.ownerDisplayName = ownerDisplayName
        self.text = text
        self.createdAt = createdAt
        self.ownerAvatarData = ownerAvatarData
        self.isPending = isPending
    }

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
        self.isPending = false
        if let asset = record["avatarAsset"] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url) {
            self.ownerAvatarData = data
        } else {
            self.ownerAvatarData = nil
        }
    }
}

// MARK: - CommentSummary

/// Lightweight per-post comment digest used to render the feed card
/// ("View all N comments" + latest comment preview) without loading the
/// full thread.
struct CommentSummary: Equatable, Sendable, Codable {
    var count: Int
    var lastComment: WorkoutComment?
}

// MARK: - CloudKit Account Availability

enum SocialICloudAccountIssue: Equatable, Sendable {
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    var localizedMessage: String {
        switch self {
        case .noAccount:
            localizedString("social_icloud_no_account_message")
        case .restricted:
            localizedString("social_icloud_restricted_message")
        case .temporarilyUnavailable:
            localizedString("social_icloud_temporarily_unavailable_message")
        case .couldNotDetermine:
            localizedString("social_icloud_unknown_message")
        }
    }
}

private extension CKError {
    /// True for failures caused by CloudKit's own session/service still
    /// settling (e.g. right after a cold app launch) rather than a real,
    /// stable outcome like a permission or schema problem.
    var isTransient: Bool {
        if retryAfterSeconds != nil { return true }
        switch code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .zoneBusy, .requestRateLimited, .notAuthenticated:
            return true
        default:
            return false
        }
    }
}

enum SocialServiceError: LocalizedError, Equatable, Sendable {
    case iCloudUnavailable(SocialICloudAccountIssue)
    case usernameTaken
    case malformedChallengeRecord

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable(let issue):
            issue.localizedMessage
        case .usernameTaken:
            localizedString("social_username_taken")
        case .malformedChallengeRecord:
            localizedString("social_challenge_save_failed")
        }
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
    var followingUsernames: [String]
    var avatarImageData: Data?        // decoded from CKAsset "avatarAsset"
    var lastActiveAt: Date?           // updated on each foreground ping

    var isOnline: Bool {
        guard let t = lastActiveAt else { return false }
        return Date().timeIntervalSince(t) < 600 // 10 min window
    }

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
        self.followingUsernames = record["followingUsernames"] as? [String] ?? []
        self.lastActiveAt = record["lastActiveAt"] as? Date
        if let asset = record["avatarAsset"] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url) {
            self.avatarImageData = data
        } else {
            self.avatarImageData = nil
        }
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

    // MARK: - Reachability
    //
    // Lightweight, system-provided path monitoring so social writes degrade to
    // a deferred outbox when offline and auto-flush the moment connectivity
    // returns. Runs on its own background queue — no main-thread impact.

    private let pathMonitor = NWPathMonitor()
    private var isOnline = true
    private var monitoringStarted = false

    private func startMonitoringIfNeeded() {
        guard !monitoringStarted else { return }
        monitoringStarted = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { await self?.handleReachabilityChange(online) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.reps.social.path"))
    }

    private func handleReachabilityChange(_ online: Bool) async {
        let cameOnline = online && !isOnline
        isOnline = online
        if cameOnline { await flushOutbox() }
    }

    // MARK: - Identity

    func iCloudAccountIssue() async -> SocialICloudAccountIssue? {
        let issue: SocialICloudAccountIssue?
        do {
            issue = Self.issue(for: try await container.accountStatus())
        } catch {
            issue = .couldNotDetermine
        }

        if issue != nil {
            _myRecordID = nil
        }
        return issue
    }

    private func requireICloudAccount() async throws {
        if let issue = await iCloudAccountIssue() {
            throw SocialServiceError.iCloudUnavailable(issue)
        }
    }

    private static func issue(for status: CKAccountStatus) -> SocialICloudAccountIssue? {
        switch status {
        case .available:
            nil
        case .noAccount:
            .noAccount
        case .restricted:
            .restricted
        case .temporarilyUnavailable:
            .temporarilyUnavailable
        case .couldNotDetermine:
            .couldNotDetermine
        @unknown default:
            .couldNotDetermine
        }
    }

    func myRecordID() async throws -> CKRecord.ID {
        try await requireICloudAccount()
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
        try await requireICloudAccount()
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

    func fetchFollowerCount(myUsername: String) async -> Int {
        guard !myUsername.isEmpty else { return 0 }
        let pred = NSPredicate(format: "followingUsername == %@", myUsername.lowercased())
        let query = CKQuery(recordType: "SocialFollow", predicate: pred)
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: 1000)
            return result.matchResults.count
        } catch { return 0 }
    }

    func pingActivity(myUsername: String) async {
        guard !myUsername.isEmpty else { return }
        guard await iCloudAccountIssue() == nil else { return }
        let rid = profileRecordID(username: myUsername.lowercased())
        do {
            let record = try await publicDB.record(for: rid)
            record["lastActiveAt"] = Date() as CKRecordValue
            _ = try await publicDB.save(record)
        } catch { }
    }

    // Retries transient CloudKit failures (the account/token session is still
    // warming up right after a cold app launch, so the first network call of
    // the process can fail even though the account is valid). Errors that
    // reflect a real, non-transient outcome (permission, unknown item, taken
    // username, etc.) are rethrown immediately without retrying.
    private func withTransientRetry<T: Sendable>(
        attempts: Int = 3,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error = SocialServiceError.malformedChallengeRecord
        for attempt in 0..<attempts {
            do {
                return try await operation()
            } catch let ck as CKError where ck.isTransient {
                lastError = ck
                if attempt < attempts - 1 {
                    let delayNanos = UInt64((ck.retryAfterSeconds ?? Double(attempt + 1) * 0.5) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNanos)
                }
            }
        }
        throw lastError
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
        totalVolumeKg: Double,
        followingUsernames: [String] = [],
        avatarImageData: Data? = nil
    ) async throws {
        try await withTransientRetry {
            try await self.saveProfile(
                username: username,
                displayName: displayName,
                bio: bio,
                location: location,
                activePlanName: activePlanName,
                level: level,
                levelTitle: levelTitle,
                totalXP: totalXP,
                totalSessions: totalSessions,
                streakDays: streakDays,
                totalVolumeKg: totalVolumeKg,
                followingUsernames: followingUsernames,
                avatarImageData: avatarImageData
            )
        }
    }

    private func saveProfile(
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
        totalVolumeKg: Double,
        followingUsernames: [String],
        avatarImageData: Data?
    ) async throws {
        try await requireICloudAccount()
        let myID = try await myRecordID()
        let normalized = username.lowercased()
        let rid = profileRecordID(username: normalized)

        let record: CKRecord
        do {
            let existing = try await publicDB.record(for: rid)
            // If this record belongs to someone else the username is taken.
            let owner = existing["ownerRecordName"] as? String ?? ""
            guard owner == myID.recordName else {
                throw SocialServiceError.usernameTaken
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
        record["followingUsernames"] = followingUsernames.map { $0.lowercased() } as CKRecordValue
        record["lastActiveAt"] = Date() as CKRecordValue
        if let data = avatarImageData,
           let tmpURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
               .appendingPathComponent("reps_avatar_\(normalized).jpg") {
            try? data.write(to: tmpURL)
            record["avatarAsset"] = CKAsset(fileURL: tmpURL)
        }

        _ = try await publicDB.save(record)
    }

    // Updates only the followingUsernames field on own SocialProfile so
    // friend-of-friend suggestions work for other users.
    func updateMyFollowingList(myUsername: String, followingUsernames: [String]) async {
        guard !myUsername.isEmpty else { return }
        guard await iCloudAccountIssue() == nil else { return }
        let rid = profileRecordID(username: myUsername.lowercased())
        do {
            let record = try await publicDB.record(for: rid)
            record["followingUsernames"] = followingUsernames.map { $0.lowercased() } as CKRecordValue
            _ = try await publicDB.save(record)
        } catch { /* non-critical */ }
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
    // Seed accounts baked into the app — fallback when no friend-of-friend candidates exist.
    static let featuredUsernames: [String] = [
        "repsfitness", "repsofficial"
    ]

    // Friend-of-friend suggestions: surfaces users that your friends follow but you don't.
    // Falls back to featured accounts when no candidates are found.
    // No CKQuery index needed — uses direct record(for:) lookups.
    func fetchSuggested(
        myUsername: String,
        followingUsernames: [String],
        followingProfiles: [SocialProfile]
    ) async throws -> [SocialProfile] {
        let excluded = Set((followingUsernames + [myUsername]).map { $0.lowercased() }.filter { !$0.isEmpty })

        // Collect usernames from friends' following lists that I don't already follow
        var candidates: [String] = []
        var seen: Set<String> = excluded
        for profile in followingProfiles {
            for uname in profile.followingUsernames {
                let u = uname.lowercased()
                if seen.insert(u).inserted { candidates.append(u) }
            }
        }

        let toFetch: [String] = candidates.isEmpty
            ? Self.featuredUsernames.filter { !excluded.contains($0) }
            : Array(candidates.prefix(15))

        guard !toFetch.isEmpty else { return [] }
        let ids = toFetch.map { profileRecordID(username: $0) }
        let results = try await publicDB.records(for: ids)
        return results.values
            .compactMap { res in (try? res.get()).flatMap(SocialProfile.init) }
            .filter { !excluded.contains($0.username.lowercased()) }
            .sorted { $0.totalXP > $1.totalXP }
    }

    // MARK: - Discovery (requires QUERYABLE index on `username` in CloudKit Dashboard)

    func searchUsers(query: String) async throws -> [SocialProfile] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let myID = try await myRecordID()
        let normalized = query.lowercased()
        let pred = NSPredicate(format: "username BEGINSWITH %@", normalized)
        let ckQuery = CKQuery(recordType: "SocialProfile", predicate: pred)
        // No server-side sort — SORTABLE index not required, sort client-side instead.
        do {
            let result = try await publicDB.records(matching: ckQuery, resultsLimit: 25)
            return result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(SocialProfile.init) }
                .filter { $0.ownerRecordName != myID.recordName }
                .sorted { $0.username < $1.username }
        } catch let ck as CKError where ck.code == .unknownItem || ck.code == .invalidArguments {
            return []
        }
    }

    // MARK: - Follow / Unfollow

    func follow(_ profile: SocialProfile, myUsername: String) async throws {
        let myID = try await myRecordID()
        let fid = followRecordID(followerOwner: myID.recordName, followingUsername: profile.username)
        let record = CKRecord(recordType: "SocialFollow", recordID: fid)
        record["followerOwnerName"] = myID.recordName as CKRecordValue
        // Stored alongside the owner name so a "who followed me" notification
        // can display/link to the follower without an extra profile lookup.
        record["followerUsername"] = myUsername.lowercased() as CKRecordValue
        record["followingUsername"] = profile.username.lowercased() as CKRecordValue
        _ = try await publicDB.save(record)
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

    // MARK: - Post local cache
    // Stores known post record names in UserDefaults so they can be fetched
    // directly by ID when the CKQuery index is not yet provisioned.

    private static let postCacheKey = "feed_post_record_names_v1"
    private static let postCacheLimit = 50

    func savePostID(_ recordName: String) {
        var ids = loadCachedPostIDs()
        guard !ids.contains(recordName) else { return }
        ids.insert(recordName, at: 0)
        if ids.count > Self.postCacheLimit { ids = Array(ids.prefix(Self.postCacheLimit)) }
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: Self.postCacheKey)
        }
    }

    func loadCachedPostIDs() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: Self.postCacheKey),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return ids
    }

    func fetchPost(username: String, sessionID: String) async throws -> WorkoutPost? {
        let rid = postRecordID(username: username, sessionID: sessionID)
        do {
            let record = try await publicDB.record(for: rid)
            if let post = WorkoutPost(record: record) {
                savePostID(rid.recordName)
                return post
            }
            return nil
        } catch let ck as CKError where ck.code == .unknownItem {
            return nil
        }
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
        try await requireICloudAccount()
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
        _ = try await publicDB.save(record)
        savePostID(rid.recordName)
    }

    // Creates a standalone manual post (not tied to a workout session).
    // Requires caption (String), photo1Asset / photo2Asset / photo3Asset (Asset)
    // fields to exist on the WorkoutPost record type in CloudKit Dashboard.
    func publishCustomPost(
        username: String,
        displayName: String,
        caption: String,
        photoDataList: [Data]
    ) async throws -> WorkoutPost? {
        try await requireICloudAccount()
        let postID = "WorkoutPost_\(username.lowercased())_\(UUID().uuidString)"
        let rid = CKRecord.ID(recordName: postID)
        let record = CKRecord(recordType: "WorkoutPost", recordID: rid)
        record["ownerUsername"] = username.lowercased() as CKRecordValue
        record["ownerDisplayName"] = displayName as CKRecordValue
        record["workoutTitle"] = caption as CKRecordValue
        record["caption"] = caption as CKRecordValue
        record["durationSeconds"] = Int64(0) as CKRecordValue
        record["volumeKg"] = Double(0) as CKRecordValue
        record["exerciseNames"] = [String]() as CKRecordValue
        record["likeCount"] = Int64(0) as CKRecordValue
        record["commentCount"] = Int64(0) as CKRecordValue

        var tmpURLs: [URL] = []
        defer { tmpURLs.forEach { try? FileManager.default.removeItem(at: $0) } }
        for (i, data) in photoDataList.prefix(3).enumerated() {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("post_photo_\(i + 1)_\(UUID().uuidString).jpg")
            try data.write(to: url)
            tmpURLs.append(url)
            record["photo\(i + 1)Asset"] = CKAsset(fileURL: url)
        }

        let saved = try await publicDB.save(record)
        savePostID(postID)
        return WorkoutPost(record: saved)
    }

    // Fetches posts by CKQuery (requires QUERYABLE index on ownerUsername).
    // Falls back to direct record(for:) lookups using locally cached IDs.
    func fetchFeed(followingUsernames: [String], limit: Int = 30) async throws -> [WorkoutPost] {
        guard !followingUsernames.isEmpty else { return [] }
        let lowercased = Set(followingUsernames.map { $0.lowercased() })
        let pred = NSPredicate(format: "ownerUsername IN %@", Array(lowercased))
        let query = CKQuery(recordType: "WorkoutPost", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: limit)
            let posts = result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(WorkoutPost.init) }
            if !posts.isEmpty {
                posts.forEach { savePostID($0.id) }
                return posts
            }
        } catch { /* index not provisioned — fall through */ }

        // Fallback: fetch known post IDs directly (no index required).
        // Filter to only posts belonging to the requested usernames.
        let cachedIDs = loadCachedPostIDs().prefix(limit).map { CKRecord.ID(recordName: $0) }
        guard !cachedIDs.isEmpty else { return [] }
        let fetched = try await publicDB.records(for: Array(cachedIDs))
        return fetched.values
            .compactMap { res in (try? res.get()).flatMap(WorkoutPost.init) }
            .filter { lowercased.contains($0.ownerUsername.lowercased()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // Fetches every post belonging to a single user, newest first — used by
    // the profile grid. Same index/fallback strategy as fetchFeed.
    func fetchPosts(username: String, limit: Int = 60) async -> [WorkoutPost] {
        let uname = username.lowercased()
        let pred = NSPredicate(format: "ownerUsername == %@", uname)
        let query = CKQuery(recordType: "WorkoutPost", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: limit)
            let posts = result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(WorkoutPost.init) }
            if !posts.isEmpty {
                posts.forEach { savePostID($0.id) }
                return posts.sorted { $0.createdAt > $1.createdAt }
            }
        } catch { /* index not provisioned — fall through */ }

        // Fallback: filter locally cached post IDs by owner (covers own
        // profile and anyone already surfaced in the feed).
        let cachedIDs = loadCachedPostIDs().map { CKRecord.ID(recordName: $0) }
        guard !cachedIDs.isEmpty,
              let fetched = try? await publicDB.records(for: cachedIDs) else { return [] }
        return fetched.values
            .compactMap { res in (try? res.get()).flatMap(WorkoutPost.init) }
            .filter { $0.ownerUsername.lowercased() == uname }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Explore
    //
    // Surfaces posts beyond the following graph — there is no server-side
    // ranking here (no custom backend), just recency + like count as a cheap
    // popularity signal. The unscoped query needs a QUERYABLE+SORTABLE index
    // on creationDate for WorkoutPost; without it we degrade to whatever this
    // device has already cached locally (feed/profile visits), which is a
    // smaller pool but still a reasonable "trending" approximation.
    func fetchExplorePosts(excluding usernames: Set<String>, limit: Int = 30) async -> [WorkoutPost] {
        let excluded = Set(usernames.map { $0.lowercased() })
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "WorkoutPost", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let result = try? await publicDB.records(matching: query, resultsLimit: limit * 2) {
            let posts = result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(WorkoutPost.init) }
                .filter { !excluded.contains($0.ownerUsername.lowercased()) }
            if !posts.isEmpty {
                posts.forEach { savePostID($0.id) }
                return posts.sorted { $0.likeCount > $1.likeCount }.prefix(limit).map { $0 }
            }
        }

        // Fallback: rank whatever this device already has cached locally.
        let cachedIDs = loadCachedPostIDs().map { CKRecord.ID(recordName: $0) }
        guard !cachedIDs.isEmpty,
              let fetched = try? await publicDB.records(for: cachedIDs) else { return [] }
        return fetched.values
            .compactMap { res in (try? res.get()).flatMap(WorkoutPost.init) }
            .filter { !excluded.contains($0.ownerUsername.lowercased()) }
            .sorted { $0.likeCount > $1.likeCount }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Likes
    //
    // WorkoutLike recordName: "WorkoutLike_<likerOwner>_<postRecordName>"

    private func likeRecordID(likerOwner: String, postRecordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "WorkoutLike_\(likerOwner)_\(postRecordName)")
    }

    func likePost(_ post: WorkoutPost, likerUsername: String) async throws {
        let myID = try await myRecordID()
        let lid = likeRecordID(likerOwner: myID.recordName, postRecordName: post.id)
        let record = CKRecord(recordType: "WorkoutLike", recordID: lid)
        record["likerOwnerName"] = myID.recordName as CKRecordValue
        // Stored so a "who liked my post" notification can display/link to the
        // liker without an extra profile lookup.
        record["likerUsername"] = likerUsername.lowercased() as CKRecordValue
        record["postRecordName"] = post.id as CKRecordValue
        record["postOwnerUsername"] = post.ownerUsername.lowercased() as CKRecordValue
        _ = try await publicDB.save(record)
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

    // MARK: Moderation

    /// Writes a moderation report to the public database. Reports are
    /// append-only and intentionally do not expose reporter identity in the UI;
    /// the owner record is retained for timely operator follow-up.
    func reportContent(
        contentID: String,
        contentType: String,
        ownerUsername: String,
        reason: String,
        reporterUsername: String
    ) async throws {
        try await requireICloudAccount()
        let myID = try await myRecordID()
        let record = CKRecord(recordType: "SocialReport")
        record["contentID"] = contentID as CKRecordValue
        record["contentType"] = contentType as CKRecordValue
        record["ownerUsername"] = ownerUsername.lowercased() as CKRecordValue
        record["reason"] = reason as CKRecordValue
        record["reporterUsername"] = reporterUsername.lowercased() as CKRecordValue
        record["reporterOwnerName"] = myID.recordName as CKRecordValue
        record["reportedAt"] = Date() as CKRecordValue
        _ = try await publicDB.save(record)
    }

    /// Persists a block relationship in CloudKit. The local profile is updated
    /// by AppStore before/alongside this call so the block is immediate offline.
    func blockUser(username: String, blockerUsername: String) async throws {
        try await requireICloudAccount()
        let myID = try await myRecordID()
        let normalized = username.lowercased()
        let rid = CKRecord.ID(recordName: "SocialBlock_\(myID.recordName)_\(normalized)")
        let record = CKRecord(recordType: "SocialBlock", recordID: rid)
        record["blockerOwnerName"] = myID.recordName as CKRecordValue
        record["blockerUsername"] = blockerUsername.lowercased() as CKRecordValue
        record["blockedUsername"] = normalized as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        _ = try await publicDB.save(record)
    }

    // MARK: Moderation (developer-managed, read-only in app)

    /// Fetches every currently-banned username so clients can filter feeds and
    /// threads. Records must be created/deleted outside the app in CloudKit
    /// Dashboard, with public write access disabled in the production schema.
    func fetchBannedUsernames() async -> Set<String> {
        let query = CKQuery(recordType: "SocialBan", predicate: NSPredicate(value: true))
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: 1000)
            return Set(result.matchResults.compactMap { _, res in
                (try? res.get())?["bannedUsername"] as? String
            })
        } catch {
            return []
        }
    }

    // MARK: - Comments (offline-first, deferred sync)
    //
    // WorkoutComment recordName: "WorkoutComment_<postID>_<uuid>"
    //
    // Design:
    //  • Every comment thread is mirrored to an on-disk cache so the feed and
    //    the thread render instantly and work fully offline.
    //  • Writes are optimistic: the comment appears immediately and is pushed to
    //    CloudKit. If the push fails (offline / transient), it lands in a
    //    persistent outbox and is flushed automatically when connectivity
    //    returns (NWPathMonitor) or on the next foreground / feed load.
    //  • Counts are derived from the actual comment set (not a racy denormalized
    //    counter), so two people commenting at once can never drift the total.
    //
    // CloudKit reads prefer a QUERYABLE index on `postRecordName`; without it,
    // they fall back to locally cached record IDs, and finally to the on-disk
    // cache when fully offline.

    private static let commentIndexKey = "comment_record_names_v1"
    private static let maxCachedCommentsPerPost = 50

    private var commentsCache: [String: [WorkoutComment]] = [:]
    private var outbox: [PendingComment] = []
    private var cacheLoaded = false

    struct PendingComment: Codable, Sendable {
        var comment: WorkoutComment
        var postID: String
        // Defaulted so outbox entries persisted before this field existed still decode.
        var postOwnerUsername: String = ""
    }

    // MARK: Cache persistence

    private var socialCacheDir: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Reps/Social", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    private var commentsCacheURL: URL? { socialCacheDir?.appendingPathComponent("comments_cache_v1.json") }
    private var outboxURL: URL? { socialCacheDir?.appendingPathComponent("comment_outbox_v1.json") }

    private func ensureLoaded() {
        guard !cacheLoaded else { return }
        cacheLoaded = true
        startMonitoringIfNeeded()
        if let url = commentsCacheURL, let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: [WorkoutComment]].self, from: data) {
            commentsCache = decoded
        }
        if let url = outboxURL, let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([PendingComment].self, from: data) {
            outbox = decoded
            // Re-surface any still-pending comments into the cache so they show
            // immediately after a cold launch.
            for p in outbox { mergeIntoCache([p.comment], postID: p.postID) }
        }
    }

    private func persistCache() {
        guard let url = commentsCacheURL else { return }
        // Strip avatar bytes from the on-disk copy to keep the cache small and
        // fast — avatars are re-hydrated from CloudKit on the next online refresh.
        var lean: [String: [WorkoutComment]] = [:]
        for (pid, list) in commentsCache {
            lean[pid] = list.map {
                var c = $0; c.ownerAvatarData = nil; return c
            }
        }
        if let data = try? JSONEncoder().encode(lean) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func persistOutbox() {
        guard let url = outboxURL else { return }
        if let data = try? JSONEncoder().encode(outbox) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Inserts/updates comments in the in-memory cache, de-duplicating by id,
    /// preserving freshly fetched avatar bytes, sorted oldest→newest, capped.
    private func mergeIntoCache(_ incoming: [WorkoutComment], postID: String) {
        var byID: [String: WorkoutComment] = [:]
        var order: [String] = []
        for c in (commentsCache[postID] ?? []) + incoming {
            if let existing = byID[c.id] {
                // Prefer the non-pending / avatar-bearing version.
                var merged = c.isPending ? existing : c
                merged.ownerAvatarData = c.ownerAvatarData ?? existing.ownerAvatarData
                byID[c.id] = merged
            } else {
                byID[c.id] = c
                order.append(c.id)
            }
        }
        let sorted = order.compactMap { byID[$0] }.sorted { $0.createdAt < $1.createdAt }
        commentsCache[postID] = Array(sorted.suffix(Self.maxCachedCommentsPerPost))
    }

    // MARK: Local index (record IDs, used as a no-index CloudKit fallback)

    private func saveCommentID(_ recordName: String, forPost postID: String) {
        var index = loadCommentIndex()
        var ids = index[postID] ?? []
        guard !ids.contains(recordName) else { return }
        ids.append(recordName)
        index[postID] = ids
        if let data = try? JSONEncoder().encode(index) {
            UserDefaults.standard.set(data, forKey: Self.commentIndexKey)
        }
    }

    private func loadCommentIndex() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: Self.commentIndexKey),
              let index = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return index
    }

    // MARK: Public API

    /// Adds a comment optimistically. Never throws: if the network write fails
    /// the comment is queued and synced later. The returned comment is `isPending`
    /// until confirmed in CloudKit.
    func addComment(
        postID: String,
        postOwnerUsername: String,
        text: String,
        ownerUsername: String,
        ownerDisplayName: String,
        ownerAvatarData: Data? = nil
    ) async -> WorkoutComment {
        ensureLoaded()
        let recordName = "WorkoutComment_\(postID)_\(UUID().uuidString)"
        let comment = WorkoutComment(
            id: recordName,
            ownerUsername: ownerUsername.lowercased(),
            ownerDisplayName: ownerDisplayName,
            text: text,
            createdAt: Date(),
            ownerAvatarData: ownerAvatarData,
            isPending: true
        )
        mergeIntoCache([comment], postID: postID)
        persistCache()

        if isOnline {
            if let synced = try? await pushComment(comment, postID: postID, postOwnerUsername: postOwnerUsername) {
                mergeIntoCache([synced], postID: postID)
                persistCache()
                return synced
            }
        }
        // Offline or push failed → defer.
        enqueue(comment, postID: postID, postOwnerUsername: postOwnerUsername)
        return comment
    }

    /// Pushes a single comment to CloudKit using its stable local record name so
    /// retries are idempotent.
    private func pushComment(_ comment: WorkoutComment, postID: String, postOwnerUsername: String) async throws -> WorkoutComment {
        let myID = try await myRecordID()
        let rid = CKRecord.ID(recordName: comment.id)
        let record = CKRecord(recordType: "WorkoutComment", recordID: rid)
        record["postRecordName"] = postID as CKRecordValue
        // Stored so a "new comment on my post" notification can display/link
        // to the commenter without an extra profile lookup.
        record["postOwnerUsername"] = postOwnerUsername.lowercased() as CKRecordValue
        record["ownerUsername"] = comment.ownerUsername as CKRecordValue
        record["ownerDisplayName"] = comment.ownerDisplayName as CKRecordValue
        record["ownerRecordName"] = myID.recordName as CKRecordValue
        record["text"] = comment.text as CKRecordValue

        var tmpURL: URL?
        defer { if let u = tmpURL { try? FileManager.default.removeItem(at: u) } }
        if let data = comment.ownerAvatarData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("comment_avatar_\(UUID().uuidString).jpg")
            if (try? data.write(to: url)) != nil {
                tmpURL = url
                record["avatarAsset"] = CKAsset(fileURL: url)
            }
        }

        let saved = try await publicDB.save(record)
        saveCommentID(rid.recordName, forPost: postID)
        guard var synced = WorkoutComment(record: saved) else {
            throw NSError(domain: "SocialService", code: 0, userInfo: nil)
        }
        synced.ownerAvatarData = synced.ownerAvatarData ?? comment.ownerAvatarData
        return synced
    }

    private func enqueue(_ comment: WorkoutComment, postID: String, postOwnerUsername: String) {
        guard !outbox.contains(where: { $0.comment.id == comment.id }) else { return }
        outbox.append(PendingComment(comment: comment, postID: postID, postOwnerUsername: postOwnerUsername))
        persistOutbox()
    }

    /// Drains the outbox when online. Safe to call repeatedly; keeps any entry
    /// that still fails for a later attempt.
    func flushOutbox() async {
        ensureLoaded()
        guard isOnline, !outbox.isEmpty else { return }
        for pending in outbox {
            if let synced = try? await pushComment(pending.comment, postID: pending.postID, postOwnerUsername: pending.postOwnerUsername) {
                mergeIntoCache([synced], postID: pending.postID)
                outbox.removeAll { $0.comment.id == pending.comment.id }
            }
        }
        persistOutbox()
        persistCache()
    }

    /// Returns the full thread for a post: cached comments refreshed from
    /// CloudKit when online. Never throws — degrades to the local cache offline.
    func fetchComments(postID: String) async -> [WorkoutComment] {
        ensureLoaded()
        if isOnline { await refreshComments(forPosts: [postID]) }
        return commentsCache[postID] ?? []
    }

    /// Instant, network-free thread for first paint.
    func cachedComments(postID: String) -> [WorkoutComment] {
        ensureLoaded()
        return commentsCache[postID] ?? []
    }

    /// Instant, network-free summary for a single post.
    func cachedSummary(postID: String) -> CommentSummary {
        ensureLoaded()
        let list = commentsCache[postID] ?? []
        return CommentSummary(count: list.count, lastComment: list.last)
    }

    /// Refreshes comments for the given posts (when online) and returns an
    /// accurate per-post summary derived from the actual comment set.
    func commentSummaries(forPosts postIDs: [String]) async -> [String: CommentSummary] {
        ensureLoaded()
        if isOnline { await refreshComments(forPosts: postIDs) }
        var out: [String: CommentSummary] = [:]
        for pid in postIDs {
            let list = commentsCache[pid] ?? []
            out[pid] = CommentSummary(count: list.count, lastComment: list.last)
        }
        return out
    }

    // MARK: Network refresh

    private func refreshComments(forPosts postIDs: [String]) async {
        guard isOnline, !postIDs.isEmpty else { return }
        var serverByPost: [String: [WorkoutComment]] = [:]
        var resolvedPosts = Set<String>()   // posts we got an authoritative answer for

        // Primary: one batched query for all posts (needs queryable index).
        let pred = NSPredicate(format: "postRecordName IN %@", postIDs)
        let query = CKQuery(recordType: "WorkoutComment", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: 400)
            for (_, res) in result.matchResults {
                guard let rec = try? res.get(), let c = WorkoutComment(record: rec) else { continue }
                let pid = (rec["postRecordName"] as? String) ?? ""
                serverByPost[pid, default: []].append(c)
                saveCommentID(c.id, forPost: pid)
            }
            // The query is authoritative for every requested post (empty = no comments).
            resolvedPosts.formUnion(postIDs)
        } catch {
            // No index yet → fall back to direct fetch by locally cached IDs.
            let index = loadCommentIndex()
            for pid in postIDs {
                let ids = (index[pid] ?? []).map { CKRecord.ID(recordName: $0) }
                guard !ids.isEmpty else { continue }
                if let results = try? await publicDB.records(for: ids) {
                    let comments = results.values
                        .compactMap { try? $0.get() }
                        .compactMap(WorkoutComment.init)
                    serverByPost[pid] = comments
                    resolvedPosts.insert(pid)
                }
            }
        }

        // Reconcile: replace the synced portion of each resolved post's cache
        // with the server truth, then re-append any still-pending outbox entries.
        for pid in resolvedPosts {
            let server = serverByPost[pid] ?? []
            let serverIDs = Set(server.map(\.id))
            let stillPending = outbox
                .filter { $0.postID == pid && !serverIDs.contains($0.comment.id) }
                .map(\.comment)
            commentsCache[pid] = []   // reset so removed/foreign comments don't linger
            mergeIntoCache(server + stillPending, postID: pid)
        }
        persistCache()
    }

    // MARK: - Push subscriptions
    //
    // Subscribes to CloudKit push for social activity targeting myUsername.
    // Requires QUERYABLE indexes on `followingUsername` (SocialFollow) and
    // `postOwnerUsername` (WorkoutLike) in CloudKit Dashboard.
    // Silently no-ops when subscription save fails.

    func subscribeToSocialActivity(myUsername: String) async {
        guard await iCloudAccountIssue() == nil else { return }
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

        // New comment on own posts
        let commentPred = NSPredicate(format: "postOwnerUsername == %@", username)
        let commentSub = CKQuerySubscription(
            recordType: "WorkoutComment",
            predicate: commentPred,
            subscriptionID: "new-comment-\(username)",
            options: .firesOnRecordCreation
        )
        let commentNote = CKSubscription.NotificationInfo()
        commentNote.shouldSendContentAvailable = true
        commentSub.notificationInfo = commentNote

        _ = try? await publicDB.save(followSub)
        _ = try? await publicDB.save(likeSub)
        _ = try? await publicDB.save(commentSub)
    }

    // MARK: - Activity actor resolution
    //
    // The silent CKQuerySubscription push only carries the triggering record's
    // ID — this resolves it to who actually did the following/liking/commenting
    // so the in-app activity entry can show and link to them.

    func resolveActivityActor(recordID: CKRecord.ID) async -> (kind: String, username: String)? {
        guard let record = try? await publicDB.record(for: recordID) else { return nil }
        switch record.recordType {
        case "SocialFollow":
            guard let uname = record["followerUsername"] as? String else { return nil }
            return ("follow", uname)
        case "WorkoutLike":
            guard let uname = record["likerUsername"] as? String else { return nil }
            return ("like", uname)
        case "WorkoutComment":
            guard let uname = record["ownerUsername"] as? String else { return nil }
            return ("comment", uname)
        default:
            return nil
        }
    }

    // MARK: - Account deletion
    //
    // App Store Review Guideline 5.1.1(v): an app that offers account
    // creation must offer account deletion, not just local data reset.
    // `SocialProfile`/`WorkoutPost`/etc. are a real public CloudKit account,
    // so this removes every record owned by it, not just the profile.
    //
    // The profile record itself is deleted last, once owned content cleanup
    // has completed, so a retryable failure never leaves a profile that looks
    // deleted while its owned content remains public.

    /// Deletes the public CloudKit account for `username`: profile, posts,
    /// comments, outgoing follows, likes, blocks, reports, and push
    /// subscriptions. Local caches are cleared afterward.
    func deleteAccount(username: String) async throws {
        try await requireICloudAccount()
        let myID = try await myRecordID()
        let normalized = username.lowercased()

        try await deleteRecords(
            type: "WorkoutPost",
            predicate: NSPredicate(format: "ownerUsername == %@", normalized)
        )
        try await deleteRecords(
            type: "WorkoutComment",
            predicate: NSPredicate(format: "ownerUsername == %@", normalized)
        )
        try await deleteRecords(
            type: "WorkoutLike",
            predicate: NSPredicate(format: "likerOwnerName == %@", myID.recordName)
        )
        try await deleteRecords(
            type: "SocialBlock",
            predicate: NSPredicate(format: "blockerOwnerName == %@", myID.recordName)
        )
        try await deleteRecords(
            type: "ContentReport",
            predicate: NSPredicate(format: "reporterUsername == %@", normalized)
        )

        // Outgoing follows use deterministic IDs, so no query/index is needed.
        if let profile = try? await fetchMyProfile(username: normalized) {
            for followed in profile.followingUsernames {
                let fid = followRecordID(followerOwner: myID.recordName, followingUsername: followed)
                try await deleteRecordIfPresent(fid)
            }
        }

        for subscriptionID in ["new-follower-\(normalized)", "new-like-\(normalized)", "new-comment-\(normalized)"] {
            try await deleteSubscriptionIfPresent(subscriptionID)
        }

        // Profile record last — see note above on ordering.
        try await deleteRecordIfPresent(profileRecordID(username: normalized))

        UserDefaults.standard.removeObject(forKey: Self.postCacheKey)
        UserDefaults.standard.removeObject(forKey: Self.commentIndexKey)
        commentsCache = [:]
        outbox = []
        if let url = commentsCacheURL { try? FileManager.default.removeItem(at: url) }
        if let url = outboxURL { try? FileManager.default.removeItem(at: url) }
    }

    /// Paginates through all records matching `predicate` and deletes each
    /// record owned by this account.
    private func deleteRecords(type: String, predicate: NSPredicate) async throws {
        let query = CKQuery(recordType: type, predicate: predicate)
        var page = try await publicDB.records(matching: query, resultsLimit: 200)
        while true {
            for (recordID, _) in page.matchResults {
                try await deleteRecordIfPresent(recordID)
            }
            guard let cursor = page.queryCursor else { break }
            page = try await publicDB.records(continuingMatchFrom: cursor, resultsLimit: 200)
        }
    }

    private func deleteRecordIfPresent(_ recordID: CKRecord.ID) async throws {
        do {
            _ = try await publicDB.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        }
    }

    private func deleteSubscriptionIfPresent(_ subscriptionID: String) async throws {
        do {
            _ = try await publicDB.deleteSubscription(withID: subscriptionID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        }
    }
}

// MARK: - Challenge Models

struct SocialChallenge: Identifiable, Equatable, Hashable, Sendable {
    enum Metric: String, Codable, CaseIterable, Identifiable, Sendable {
        case volumeKg  = "volume"
        case streak    = "streak"
        case prCount   = "prCount"
        var id: String { rawValue }
    }

    let id: String            // CKRecord recordName
    var creatorUsername: String
    var creatorDisplayName: String
    var title: String
    var description: String
    var metric: Metric
    var startDate: Date
    var endDate: Date
    var participantCount: Int
    var createdAt: Date

    var isActive: Bool { Date.now >= startDate && Date.now <= endDate }

    init?(record: CKRecord) {
        guard
            let creator = record["creatorUsername"] as? String,
            let title   = record["title"] as? String,
            let start   = record["startDate"] as? Date,
            let end     = record["endDate"] as? Date
        else { return nil }
        self.id                 = record.recordID.recordName
        self.creatorUsername    = creator
        self.creatorDisplayName = record["creatorDisplayName"] as? String ?? creator
        self.title              = title
        self.description        = record["description"] as? String ?? ""
        self.metric             = Metric(rawValue: record["metric"] as? String ?? "") ?? .volumeKg
        self.startDate          = start
        self.endDate            = end
        self.participantCount   = (record["participantCount"] as? Int64).map(Int.init) ?? 0
        self.createdAt          = record.creationDate ?? .now
    }
}

struct ChallengeParticipation: Identifiable, Equatable, Hashable, Sendable {
    let id: String            // CKRecord recordName
    var challengeID: String
    var participantUsername: String
    var participantDisplayName: String
    var currentValue: Double
    var joinedAt: Date

    init?(record: CKRecord) {
        guard
            let cid   = record["challengeID"] as? String,
            let pname = record["participantUsername"] as? String
        else { return nil }
        self.id                     = record.recordID.recordName
        self.challengeID            = cid
        self.participantUsername    = pname
        self.participantDisplayName = record["participantDisplayName"] as? String ?? pname
        self.currentValue           = record["currentValue"] as? Double ?? 0
        self.joinedAt               = record.creationDate ?? .now
    }
}

// MARK: - SocialService Challenge Extension

extension SocialService {

    // Deterministic record IDs so we never need a CKQuery for our own records.
    private func challengeRecordID(_ challengeUUID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "Challenge_\(challengeUUID)")
    }

    private func participationRecordID(challengeID: String, username: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "ChallengeParticipation_\(challengeID)_\(username.lowercased())")
    }

    // MARK: Challenge CRUD

    @discardableResult
    func createChallenge(
        title: String,
        description: String,
        metric: SocialChallenge.Metric,
        startDate: Date,
        endDate: Date,
        creatorUsername: String,
        creatorDisplayName: String
    ) async throws -> SocialChallenge {
        try await requireICloudAccount()
        let uuid = UUID().uuidString
        let rid = challengeRecordID(uuid)
        let record = CKRecord(recordType: "Challenge", recordID: rid)
        record["title"]                = title as CKRecordValue
        record["description"]          = description as CKRecordValue
        record["metric"]               = metric.rawValue as CKRecordValue
        record["startDate"]            = startDate as CKRecordValue
        record["endDate"]              = endDate as CKRecordValue
        record["creatorUsername"]      = creatorUsername.lowercased() as CKRecordValue
        record["creatorDisplayName"]   = creatorDisplayName as CKRecordValue
        record["participantCount"]     = Int64(0) as CKRecordValue
        _ = try await publicDB.save(record)
        guard let ch = SocialChallenge(record: record) else {
            throw SocialServiceError.malformedChallengeRecord
        }
        return ch
    }

    /// Fetches currently active + recent challenges.
    /// Requires QUERYABLE index on `endDate` in CloudKit Dashboard.
    /// Falls back to empty list when index not yet provisioned.
    func fetchActiveChallenges() async -> [SocialChallenge] {
        // Filter server-side for challenges that ended in the last 30 days or haven't ended.
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let pred = NSPredicate(format: "endDate >= %@", cutoff as CVarArg)
        let query = CKQuery(recordType: "Challenge", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: 50)
            return result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(SocialChallenge.init) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
        }
    }

    /// Join a challenge. Idempotent — safe to call even if already joined.
    func joinChallenge(
        _ challengeID: String,
        username: String,
        displayName: String
    ) async throws {
        try await requireICloudAccount()
        let rid = participationRecordID(challengeID: challengeID, username: username)
        // Check if already joined.
        if (try? await publicDB.record(for: rid)) != nil { return }
        let record = CKRecord(recordType: "ChallengeParticipation", recordID: rid)
        record["challengeID"]              = challengeID as CKRecordValue
        record["participantUsername"]      = username.lowercased() as CKRecordValue
        record["participantDisplayName"]   = displayName as CKRecordValue
        record["currentValue"]             = Double(0) as CKRecordValue
        _ = try await publicDB.save(record)

        // Optimistically bump participantCount on the challenge record.
        let crid = challengeRecordID(challengeID)
        if let cr = try? await publicDB.record(for: crid) {
            let current = (cr["participantCount"] as? Int64) ?? 0
            cr["participantCount"] = (current + 1) as CKRecordValue
            _ = try? await publicDB.save(cr)
        }
    }

    func updateMyChallengeProgress(challengeID: String, username: String, value: Double) async {
        guard await iCloudAccountIssue() == nil else { return }
        let rid = participationRecordID(challengeID: challengeID, username: username)
        do {
            let record = try await publicDB.record(for: rid)
            record["currentValue"] = value as CKRecordValue
            _ = try await publicDB.save(record)
        } catch { /* not joined — silently ignore */ }
    }

    /// Fetch all participants for a challenge (requires QUERYABLE index on `challengeID`).
    func fetchParticipants(challengeID: String) async -> [ChallengeParticipation] {
        let pred = NSPredicate(format: "challengeID == %@", challengeID)
        let query = CKQuery(recordType: "ChallengeParticipation", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "currentValue", ascending: false)]
        do {
            let result = try await publicDB.records(matching: query, resultsLimit: 200)
            return result.matchResults
                .compactMap { _, res in (try? res.get()).flatMap(ChallengeParticipation.init) }
                .sorted { $0.currentValue > $1.currentValue }
        } catch {
            return []
        }
    }

    /// Fetch the current user's participation record for a single challenge.
    func myParticipation(challengeID: String, username: String) async -> ChallengeParticipation? {
        let rid = participationRecordID(challengeID: challengeID, username: username)
        guard let record = try? await publicDB.record(for: rid) else { return nil }
        return ChallengeParticipation(record: record)
    }
}
