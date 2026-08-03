//
//  SocialModerationAdminView.swift
//  Reps
//

import SwiftUI

struct SocialModerationAdminView: View {
    @Environment(AppStore.self) private var store

    enum AdminTab: String, CaseIterable, Identifiable {
        case users = "users"
        case reports = "reports"
        var id: String { rawValue }
    }

    enum UserFilter: String, CaseIterable, Identifiable {
        case all = "all"
        case reported = "reported"
        case banned = "banned"
        case moderators = "moderators"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss

    @State private var activeTab: AdminTab = .users
    @State private var userFilter: UserFilter = .all
    @State private var searchText: String = ""

    @State private var usersList: [SocialProfile] = []
    @State private var pendingReports: [SocialReport] = []

    @State private var isLoadingUsers: Bool = false
    @State private var isLoadingReports: Bool = false
    @State private var actionMessage: String? = nil

    // Ban Dialog state
    @State private var profileToBan: SocialProfile? = nil
    @State private var banReasonInput: String = ""
    @State private var showBanDialog: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Moderation Header Bar
            moderationHeader

            // Segmented Picker
            Picker("", selection: $activeTab) {
                Label(String(localized: "social_admin_tab_users"), systemImage: "person.3.fill").tag(AdminTab.users)
                Label(String(localized: "social_admin_tab_reports"), systemImage: "flag.fill").tag(AdminTab.reports)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.vertical, 10)

            if activeTab == .users {
                usersSection
            } else {
                reportsSection
            }
        }
        .background(PulseTheme.grouped)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadAllData()
        }
        .refreshable {
            await loadAllData()
        }
        .alert(String(localized: "social_moderator_ban_user"), isPresented: $showBanDialog) {
            TextField(String(localized: "social_ban_reason_placeholder"), text: $banReasonInput)
            Button(String(localized: "social_admin_action_ban"), role: .destructive) {
                if let p = profileToBan {
                    executeBan(p, reason: banReasonInput)
                }
            }
            Button(String(localized: "cancel_action"), role: .cancel) {
                profileToBan = nil
                banReasonInput = ""
            }
        } message: {
            if let p = profileToBan {
                Text(String(format: String(localized: "social_ban_confirm_format"), p.username))
            }
        }
    }

    // MARK: - Moderation Header

    private var moderationHeader: some View {
        HStack(spacing: 12) {
            // Shield Icon
            Image(systemName: "shield.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.red)
                .frame(width: 36, height: 36)
                .background(Color.red.opacity(0.14))
                .clipShape(Circle())

            // Title + Subtitle to the right of shield
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "social_admin_panel_title"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(String(localized: "social_admin_panel_subtitle"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Refresh & Red Close Buttons
            HStack(spacing: 10) {
                Button {
                    HapticService.selection()
                    Task { await loadAllData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .frame(width: 36, height: 36)
                        .navigationGlassCircle(.secondary, tint: PulseTheme.accent)
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .navigationGlassCircle(.secondary, tint: .red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(PulseTheme.card)
    }

    // MARK: - Users Section

    @ViewBuilder
    private var usersSection: some View {
        VStack(spacing: 12) {
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(UserFilter.allCases) { filter in
                        Button {
                            userFilter = filter
                            HapticService.selection()
                        } label: {
                            Text(filterTitle(filter))
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(userFilter == filter ? PulseTheme.accent : PulseTheme.card)
                                .foregroundStyle(userFilter == filter ? PulseTheme.onColor(PulseTheme.accent) : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .fixedSize(horizontal: false, vertical: true)

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PulseTheme.secondaryText)
                TextField(String(localized: "social_search_users_placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)

            // Users List
            if isLoadingUsers {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredUsers.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.slash.fill")
                        .font(.largeTitle)
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(String(localized: "social_no_users_found"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredUsers) { profile in
                        adminUserRow(profile)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func adminUserRow(_ profile: SocialProfile) -> some View {
        let isBanned = store.bannedUsernames.contains(profile.username.lowercased()) || store.bannedOwnerIDs.contains(profile.ownerRecordName)
        let isMod = store.moderatorUsernames.contains(profile.username.lowercased()) || store.moderatorOwnerIDs.contains(profile.ownerRecordName)
        let reportsCount = pendingReports.filter { $0.targetUsername.lowercased() == profile.username.lowercased() || $0.targetOwnerRecordName == profile.ownerRecordName }.count

        return HStack(spacing: 12) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                if let data = profile.avatarImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(PulseTheme.accent.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(profile.username.prefix(1).uppercased())
                                .font(.title3.bold())
                                .foregroundStyle(PulseTheme.accent)
                        )
                }

                if profile.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(PulseTheme.card, lineWidth: 1.5))
                }
            }

            // Names & ID
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.displayName.isEmpty ? profile.username : profile.displayName)
                        .font(.body.weight(.semibold))

                    if isMod {
                        Text("🛡️ Mod")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PulseTheme.accent.opacity(0.15))
                            .foregroundStyle(PulseTheme.accent)
                            .clipShape(Capsule())
                    }

                    if isBanned {
                        Text("🚫 Banned")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text("@\(profile.username)")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)

                    if !profile.ownerRecordName.isEmpty {
                        Text("ID: \(profile.ownerRecordName.prefix(8))...")
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.secondaryText.opacity(0.7))
                    }
                }

                if reportsCount > 0 {
                    Text("🚨 \(reportsCount) reportes")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Moderator Menu Actions
            Menu {
                if isBanned {
                    Button(action: { unban(profile) }) {
                        Label(String(localized: "social_admin_action_unban"), systemImage: "lock.open.fill")
                    }
                } else {
                    Button(role: .destructive, action: {
                        profileToBan = profile
                        showBanDialog = true
                    }) {
                        Label(String(localized: "social_admin_action_ban"), systemImage: "person.slash.fill")
                    }
                }

                Divider()

                if store.isCurrentUserSuperAdmin {
                    if isMod {
                        Button(role: .destructive, action: { removeMod(profile) }) {
                            Label(String(localized: "social_admin_action_revoke_mod"), systemImage: "shield.slash")
                        }
                    } else {
                        Button(action: { addMod(profile) }) {
                            Label(String(localized: "social_admin_action_grant_mod"), systemImage: "shield.badge.plus")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private var filteredUsers: [SocialProfile] {
        usersList.filter { profile in
            let matchSearch = searchText.isEmpty ||
                profile.username.localizedCaseInsensitiveContains(searchText) ||
                profile.displayName.localizedCaseInsensitiveContains(searchText) ||
                profile.ownerRecordName.localizedCaseInsensitiveContains(searchText)

            guard matchSearch else { return false }

            let isBanned = store.bannedUsernames.contains(profile.username.lowercased()) || store.bannedOwnerIDs.contains(profile.ownerRecordName)
            let isMod = store.moderatorUsernames.contains(profile.username.lowercased()) || store.moderatorOwnerIDs.contains(profile.ownerRecordName)
            let hasReports = pendingReports.contains { $0.targetUsername.lowercased() == profile.username.lowercased() || $0.targetOwnerRecordName == profile.ownerRecordName }

            switch userFilter {
            case .all: return true
            case .reported: return hasReports
            case .banned: return isBanned
            case .moderators: return isMod
            }
        }
    }

    private func filterTitle(_ filter: UserFilter) -> String {
        switch filter {
        case .all: return String(localized: "social_admin_filter_all")
        case .reported: return String(localized: "social_admin_filter_reported")
        case .banned: return String(localized: "social_admin_filter_banned")
        case .moderators: return String(localized: "social_admin_filter_moderators")
        }
    }

    // MARK: - Reports Section

    @ViewBuilder
    private var reportsSection: some View {
        VStack(spacing: 0) {
            if isLoadingReports {
                Spacer()
                ProgressView()
                Spacer()
            } else if pendingReports.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text(String(localized: "social_admin_no_pending_reports"))
                        .font(.headline)
                    Text(String(localized: "social_admin_no_pending_reports_desc"))
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
            } else {
                List {
                    ForEach(pendingReports) { report in
                        reportRow(report)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func reportRow(_ report: SocialReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    report.targetType.capitalized,
                    systemImage: report.targetType == "user" ? "person.fill" : "doc.text.fill"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(PulseTheme.accent.opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            HStack(spacing: 6) {
                Text(String(localized: "social_report_target"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                Text("@\(report.targetUsername)")
                    .font(.subheadline.bold())
                if !report.targetOwnerRecordName.isEmpty {
                    Text("(ID: \(report.targetOwnerRecordName.prefix(6))...)")
                        .font(.caption2)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            HStack(spacing: 6) {
                Text("Motivo:")
                    .font(.caption.weight(.bold))
                Text(report.reasonCategory.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if !report.reasonNotes.isEmpty {
                Text("\"\(report.reasonNotes)\"")
                    .font(.footnote)
                    .italic()
                    .padding(8)
                    .background(PulseTheme.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 6) {
                Text(String(localized: "social_report_by"))
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.secondaryText)
                Text("@\(report.reporterUsername)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    dismissReportAction(report)
                } label: {
                    Text(String(localized: "social_admin_dismiss"))
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)

                if report.targetType == "post" || report.targetType == "comment" {
                    Button(role: .destructive) {
                        deleteReportedContent(report)
                    } label: {
                        Text(String(localized: "social_admin_delete_content"))
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(role: .destructive) {
                    banUserFromReport(report)
                } label: {
                    Text(String(localized: "social_admin_action_ban"))
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Actions & Data Loading

    private func loadAllData() async {
        isLoadingUsers = true
        isLoadingReports = true

        await store.refreshModerationState()

        // Fetch users
        let found = (try? await SocialService.shared.fetchAllProfilesForModeration()) ?? []
        await MainActor.run {
            self.usersList = found
            self.isLoadingUsers = false
        }

        // Fetch reports
        do {
            let reps = try await SocialService.shared.fetchPendingReports()
            await MainActor.run {
                self.pendingReports = reps
                self.isLoadingReports = false
            }
        } catch {
            await MainActor.run {
                self.pendingReports = []
                self.isLoadingReports = false
            }
        }
    }

    private func executeBan(_ profile: SocialProfile, reason: String) {
        let myUname = store.userProfile.socialUsername ?? "admin"
        Task {
            do {
                try await SocialService.shared.banUser(targetProfile: profile, reason: reason, bannedByUsername: myUname)
                await store.refreshModerationState()
                await loadAllData()
                await MainActor.run { HapticService.notification(.success) }
            } catch {
                await MainActor.run { HapticService.notification(.error) }
            }
        }
    }

    private func unban(_ profile: SocialProfile) {
        Task {
            do {
                try await SocialService.shared.unbanUser(targetOwnerRecordName: profile.ownerRecordName, targetUsername: profile.username)
                await store.refreshModerationState()
                await loadAllData()
                await MainActor.run { HapticService.notification(.success) }
            } catch {
                await MainActor.run { HapticService.notification(.error) }
            }
        }
    }

    private func addMod(_ profile: SocialProfile) {
        let myUname = store.userProfile.socialUsername ?? "admin"
        Task {
            do {
                try await SocialService.shared.addModerator(targetProfile: profile, addedByUsername: myUname)
                await store.refreshModerationState()
                await loadAllData()
                await MainActor.run { HapticService.notification(.success) }
            } catch {
                await MainActor.run { HapticService.notification(.error) }
            }
        }
    }

    private func removeMod(_ profile: SocialProfile) {
        Task {
            do {
                try await SocialService.shared.removeModerator(targetOwnerRecordName: profile.ownerRecordName, targetUsername: profile.username)
                await store.refreshModerationState()
                await loadAllData()
                await MainActor.run { HapticService.notification(.success) }
            } catch {
                await MainActor.run { HapticService.notification(.error) }
            }
        }
    }

    private func dismissReportAction(_ report: SocialReport) {
        Task {
            do {
                try await SocialService.shared.dismissReport(reportID: report.id)
                await loadAllData()
                await MainActor.run { HapticService.notification(.success) }
            } catch {
                await MainActor.run { HapticService.notification(.error) }
            }
        }
    }

    private func deleteReportedContent(_ report: SocialReport) {
        Task {
            do {
                if report.targetType == "post" {
                    try await SocialService.shared.deleteReportedPost(postID: report.targetID)
                }
                try await SocialService.shared.dismissReport(reportID: report.id)
                await loadAllData()
                await MainActor.run { HapticService.notification(.success) }
            } catch {
                await MainActor.run { HapticService.notification(.error) }
            }
        }
    }

    private func banUserFromReport(_ report: SocialReport) {
        let profile = SocialProfile(
            username: report.targetUsername,
            displayName: report.targetUsername,
            ownerRecordName: report.targetOwnerRecordName
        )
        executeBan(profile, reason: "Banned from report: \(report.reasonCategory)")
        dismissReportAction(report)
    }
}
