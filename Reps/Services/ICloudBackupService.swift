import Foundation

enum ICloudBackupService {
    /// Automatic mirror is allowed because `save` always projects the snapshot
    /// through `AppSnapshot.iCloudSafe` before encoding.
    static let automaticBackupEnabled = true
    private static let containerIdentifier = "iCloud.com.romerodev.repsfitness"
    private static let backupFileName = "reps-backup.json"
    private static let backupFormatVersion = 1

    private struct BackupEnvelope: Codable {
        let formatVersion: Int
        let snapshot: AppSnapshot
    }

    // Returns nil on unsigned builds or when no iCloud account is available.
    static var containerURL: URL? {
        FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        )?.appendingPathComponent("Documents", isDirectory: true)
    }

    // Writes the current snapshot to iCloud Documents. No-op if container is unavailable.
    // Coordinated via NSFileCoordinator so a concurrent write from another
    // device (or the iCloud sync daemon downloading a remote change) can't
    // corrupt the file mid-write.
    static func save(_ snapshot: AppSnapshot) async {
        await Task.detached(priority: .background) {
            guard let dir = containerURL else { return }
            do {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let envelope = BackupEnvelope(
                    formatVersion: backupFormatVersion,
                    snapshot: snapshot.iCloudSafe
                )
                let data = try encoder.encode(envelope)
                let fileURL = dir.appendingPathComponent(backupFileName)

                var coordinatorError: NSError?
                var writeError: Error?
                let coordinator = NSFileCoordinator(filePresenter: nil)
                coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
                    do {
                        try data.write(to: coordinatedURL, options: .atomic)
                    } catch {
                        writeError = error
                    }
                }
                if let coordinatorError { throw coordinatorError }
                if let writeError { throw writeError }
            } catch {
                // Backup failure is non-critical; ignore silently.
            }
        }.value
    }

    // Loads the latest snapshot from iCloud Documents.
    // Returns nil if container or file is unavailable.
    // Resolves any pending iCloud version conflicts first (see
    // `resolveConflictsIfNeeded`) so a stale local copy never wins over a
    // more recent write made from another device.
    static func load() async -> AppSnapshot? {
        await Task.detached(priority: .background) {
            guard let dir = containerURL else { return nil }
            let fileURL = dir.appendingPathComponent(backupFileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            resolveConflictsIfNeeded(at: fileURL)

            var coordinatorError: NSError?
            var result: AppSnapshot?
            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
                guard let data = try? Data(contentsOf: coordinatedURL) else { return }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                guard let envelope = try? decoder.decode(BackupEnvelope.self, from: data),
                      envelope.formatVersion == backupFormatVersion else { return }
                result = envelope.snapshot
            }
            return result
        }.value
    }

    /// iCloud creates a separate "conflicted copy" file version when two
    /// devices write `reps-backup.json` while the other's edit hasn't been
    /// downloaded yet. Left alone, `load()` only ever sees whichever version
    /// happens to be at the canonical path — silently discarding a possibly
    /// newer backup sitting in an unresolved conflict version instead of
    /// merging or even surfacing it. This picks the most recently modified
    /// version among the current file and its conflicts, promotes it to the
    /// canonical path if it isn't already there, and marks every conflict
    /// version resolved so they stop accumulating on disk.
    private static func resolveConflictsIfNeeded(at fileURL: URL) {
        guard let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL),
              !conflicts.isEmpty,
              let currentVersion = NSFileVersion.currentVersionOfItem(at: fileURL) else { return }

        let newest = ([currentVersion] + conflicts).max {
            ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
        }

        if let newest, newest !== currentVersion {
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: newest.url)
        }

        for conflict in conflicts {
            conflict.isResolved = true
        }
        try? NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
    }

    // Returns the modification date of the backup file, or nil if absent.
    static func lastBackupDate() -> Date? {
        guard let dir = containerURL else { return nil }
        let fileURL = dir.appendingPathComponent(backupFileName)
        return (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
    }

    /// Resolving an ubiquity container can involve an XPC/iCloud round trip.
    /// Keep it away from app construction and the first frame.
    static func lastBackupDateAsync() async -> Date? {
        await Task.detached(priority: .background) {
            lastBackupDate()
        }.value
    }
}
