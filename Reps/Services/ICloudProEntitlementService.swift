import CloudKit
import CryptoKit
import Foundation

struct ICloudProEntitlementSnapshot: Equatable {
    let identifier: String
    let identifierHash: String
    let source: ICloudProEntitlementSource
    let allowedHashesConfigured: Bool
    let isAllowed: Bool
}

enum ICloudProEntitlementSource: String, Equatable {
    case cloudKitRecord
    case ubiquityIdentityToken
}

enum ICloudProEntitlementError: LocalizedError {
    case noICloudAccount
    case missingUserRecord
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .noICloudAccount:
            return "No hay una cuenta iCloud disponible en este dispositivo."
        case .missingUserRecord:
            return "CloudKit no devolvió un identificador para la cuenta iCloud actual."
        case .missingIdentityToken:
            return "iCloud no devolvió un token de identidad en este dispositivo."
        }
    }
}

final class ICloudProEntitlementService: @unchecked Sendable {
    static let shared = ICloudProEntitlementService()

    private enum Constants {
        static let infoPlistKey = "RepsProICloudRecordIDHashes"
        static let environmentKey = "REPS_PRO_ICLOUD_RECORD_ID_HASHES"
    }

    private let containerFactory: () -> CKContainer
    // Constructing a CKContainer (even with an explicit identifier, and even
    // for .default()) crashes immediately on unsigned/simulator runs that
    // lack a real iCloud provisioning profile. Defer creation until a code
    // path that actually needs it runs, so the simulator early-return in
    // evaluateCurrentAccount() below never touches CloudKit at all.
    private lazy var container: CKContainer = containerFactory()
    private let bundle: Bundle
    private let environment: [String: String]
    private let fileManager: FileManager

    init(
        container containerFactory: @escaping () -> CKContainer = { CKContainer(identifier: "iCloud.com.romerodev.repsfitness") },
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.containerFactory = containerFactory
        self.bundle = bundle
        self.environment = environment
        self.fileManager = fileManager
    }

    func evaluateCurrentAccount() async throws -> ICloudProEntitlementSnapshot {
        #if targetEnvironment(simulator)
        // CloudKit containers are not provisioned for unsigned simulator runs;
        // entitlement evaluation must degrade to the normal StoreKit path.
        throw ICloudProEntitlementError.noICloudAccount
        #else
        do {
            let status = try await accountStatus()
            guard status == .available else {
                throw ICloudProEntitlementError.noICloudAccount
            }

            let recordID = try await currentUserRecordID()
            let recordName = recordID.recordName
            guard !recordName.isEmpty else {
                throw ICloudProEntitlementError.missingUserRecord
            }

            return Self.snapshot(
                identifier: recordName,
                source: .cloudKitRecord,
                bundle: bundle,
                environment: environment
            )
        } catch {
            if let fallback = try ubiquityIdentityTokenSnapshot() {
                return fallback
            }

            throw error
        }
        #endif
    }

    private func ubiquityIdentityTokenSnapshot() throws -> ICloudProEntitlementSnapshot? {
        guard let identityToken = fileManager.ubiquityIdentityToken else {
            return nil
        }

        let tokenData = try NSKeyedArchiver.archivedData(
            withRootObject: identityToken,
            requiringSecureCoding: false
        )
        return Self.snapshot(
            identifier: tokenData.base64EncodedString(),
            source: .ubiquityIdentityToken,
            bundle: bundle,
            environment: environment
        )
    }

    private static func snapshot(
        identifier: String,
        source: ICloudProEntitlementSource,
        bundle: Bundle,
        environment: [String: String]
    ) -> ICloudProEntitlementSnapshot {
        let identifierHash = sha256Hex("\(source.rawValue):\(identifier)")
        let allowedHashes = Self.allowedRecordNameHashes(bundle: bundle, environment: environment)
        return ICloudProEntitlementSnapshot(
            identifier: identifier,
            identifierHash: identifierHash,
            source: source,
            allowedHashesConfigured: !allowedHashes.isEmpty,
            isAllowed: allowedHashes.contains(identifierHash)
        )
    }

    static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func allowedRecordNameHashes(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Set<String> {
        if let environmentHashes = environment[Constants.environmentKey] {
            return Set(
                environmentHashes
                .split(separator: ",")
                .map { normalizedHash(String($0)) }
                .filter { !$0.isEmpty }
            )
        }

        var hashes = Set<String>()

        if let plistHashes = bundle.object(forInfoDictionaryKey: Constants.infoPlistKey) as? [String] {
            hashes.formUnion(plistHashes.map(Self.normalizedHash).filter { !$0.isEmpty })
        }

        return hashes
    }

    private static func normalizedHash(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func currentUserRecordID() async throws -> CKRecord.ID {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchUserRecordID { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let recordID {
                    continuation.resume(returning: recordID)
                } else {
                    continuation.resume(throwing: ICloudProEntitlementError.missingUserRecord)
                }
            }
        }
    }
}
