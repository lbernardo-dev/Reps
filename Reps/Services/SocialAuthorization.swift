import Foundation

/// Local authorization policy for the social moderation surface.
///
/// The superadmin is identified only by the immutable CloudKit owner record
/// name. Usernames are display data and must never grant administrative access.
enum SocialAuthorization {
    static let superAdminOwnerRecordName = "61631E27-8C99-4353-A9E2-307B923AF46E"

    static func normalizedOwnerRecordName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isSuperAdmin(ownerRecordName: String?) -> Bool {
        guard let ownerRecordName, !ownerRecordName.isEmpty else { return false }
        return normalizedOwnerRecordName(ownerRecordName) == normalizedOwnerRecordName(superAdminOwnerRecordName)
    }

    static func canModerate(ownerRecordName: String?, moderatorOwnerRecordNames: Set<String>) -> Bool {
        guard let ownerRecordName, !ownerRecordName.isEmpty else { return false }
        if isSuperAdmin(ownerRecordName: ownerRecordName) { return true }
        let normalized = normalizedOwnerRecordName(ownerRecordName)
        return moderatorOwnerRecordNames.contains { normalizedOwnerRecordName($0) == normalized }
    }
}
