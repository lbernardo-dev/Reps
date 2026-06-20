import Foundation

enum ICloudBackupService {
    private static let containerIdentifier = "iCloud.com.romerodev.repsfitness"
    private static let backupFileName = "reps-backup.json"

    // Returns nil on unsigned builds or when no iCloud account is available.
    static var containerURL: URL? {
        FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        )?.appendingPathComponent("Documents", isDirectory: true)
    }

    // Writes the current snapshot to iCloud Documents. No-op if container is unavailable.
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
                let data = try encoder.encode(snapshot)
                let fileURL = dir.appendingPathComponent(backupFileName)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Backup failure is non-critical; ignore silently.
            }
        }.value
    }

    // Loads the latest snapshot from iCloud Documents.
    // Returns nil if container or file is unavailable.
    static func load() async -> AppSnapshot? {
        await Task.detached(priority: .background) {
            guard let dir = containerURL else { return nil }
            let fileURL = dir.appendingPathComponent(backupFileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(AppSnapshot.self, from: data)
            } catch {
                return nil
            }
        }.value
    }

    // Returns the modification date of the backup file, or nil if absent.
    static func lastBackupDate() -> Date? {
        guard let dir = containerURL else { return nil }
        let fileURL = dir.appendingPathComponent(backupFileName)
        return (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
    }
}
