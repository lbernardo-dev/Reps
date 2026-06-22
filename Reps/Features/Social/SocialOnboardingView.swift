import SwiftUI

struct SocialOnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var isChecking = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var availabilityStatus: AvailabilityStatus = .idle

    private enum AvailabilityStatus {
        case idle, checking, available, taken, tooShort
    }

    private var canContinue: Bool {
        availabilityStatus == .available && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    usernameSection
                    optionalFieldsSection
                    privacyNote
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 60)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .alert(localizedString("ok"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localizedString("ok")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(PulseTheme.primary)
                    } else {
                        Button(localizedString("activate")) { saveProfile() }
                            .font(.headline)
                            .foregroundStyle(canContinue ? PulseTheme.primary : PulseTheme.secondaryText)
                            .disabled(!canContinue)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PulseTheme.primary.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PulseTheme.primary)
            }

            VStack(spacing: 6) {
                Text(localizedString("connect_with_friends"))
                    .font(.system(size: 24, weight: .black, design: .rounded))

                Text(localizedString("social_onboarding_description"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 12)
    }

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("social_username_label"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Text("@")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PulseTheme.primary)

                TextField(localizedString("social_username_placeholder"), text: $username)
                    .font(.title3.weight(.semibold))
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .onChange(of: username) { _, new in
                        let sanitized = new.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        if sanitized != new { username = sanitized }
                        scheduleAvailabilityCheck()
                    }

                statusIcon
            }
            .padding(14)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )

            statusLabel
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch availabilityStatus {
        case .checking:
            ProgressView().tint(PulseTheme.primary).scaleEffect(0.8)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PulseTheme.primaryBright)
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(PulseTheme.destructive)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch availabilityStatus {
        case .available:
            Label(localizedString("social_username_available"), systemImage: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.primaryBright)
                .padding(.horizontal, 4)
        case .taken:
            Label(localizedString("social_username_taken"), systemImage: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.destructive)
                .padding(.horizontal, 4)
        case .tooShort:
            Text(localizedString("social_username_too_short"))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
        default:
            Text(localizedString("social_username_hint"))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    private var borderColor: Color {
        switch availabilityStatus {
        case .available: return PulseTheme.primaryBright.opacity(0.6)
        case .taken: return PulseTheme.destructive.opacity(0.5)
        default: return PulseTheme.separator
        }
    }

    private var optionalFieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("optional"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "mappin")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(width: 20)
                    AddressSearchField(title: localizedString("social_location_placeholder"), text: $location)
                        .font(.subheadline)
                }
                .padding(14)

                Divider().padding(.leading, 44)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.quote")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(width: 20)
                        .padding(.top, 2)
                    TextField(
                        localizedString("social_bio_placeholder"),
                        text: $bio,
                        axis: .vertical
                    )
                    .font(.subheadline)
                    .lineLimit(2...3)
                    .onChange(of: bio) { _, new in
                        if new.count > 80 { bio = String(new.prefix(80)) }
                    }
                }
                .padding(14)
            }
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if !bio.isEmpty {
                Text("\(bio.count)/80")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PulseTheme.primary)
                .padding(.top, 1)
            Text(localizedString("social_privacy_note"))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }

    // MARK: - Logic

    private func scheduleAvailabilityCheck() {
        let u = username
        guard u.count >= 3, u.count <= 20 else {
            availabilityStatus = u.isEmpty ? .idle : .tooShort
            return
        }
        availabilityStatus = .checking
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard username == u else { return }
            do {
                let available = try await SocialService.shared.checkAvailability(username: u)
                await MainActor.run {
                    guard username == u else { return }
                    availabilityStatus = available ? .available : .taken
                }
            } catch {
                // Network or schema error — optimistically allow the user to proceed.
                await MainActor.run {
                    guard username == u else { return }
                    availabilityStatus = .available
                }
            }
        }
    }

    private func saveProfile() {
        guard canContinue else { return }
        isSaving = true
        let xp = GamificationEngine.totalXP(
            sessions: store.workoutSessions,
            cardioLogs: store.combinedCardioLogs,
            bodyMetrics: store.bodyMetrics,
            progressPhotos: store.progressPhotos,
            streakDays: store.streakDays,
            totalVolumeKg: store.totalVolumeKg
        )
        let lvl = GamificationEngine.playerLevel(for: xp)
        let uname = username
        let dname = store.userProfile.displayName ?? uname
        let bioVal = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let locVal = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let planName = store.activePlan.name
        Task {
            do {
                try await SocialService.shared.createOrUpdateProfile(
                    username: uname,
                    displayName: dname,
                    bio: bioVal,
                    location: locVal,
                    activePlanName: planName,
                    level: lvl.level,
                    levelTitle: lvl.title,
                    totalXP: xp,
                    totalSessions: store.workoutSessions.count,
                    streakDays: store.streakDays,
                    totalVolumeKg: store.totalVolumeKg,
                    followingUsernames: store.userProfile.socialFollowingUsernames,
                    avatarImageData: store.userProfile.avatarImageData
                )
                await MainActor.run {
                    store.userProfile.socialUsername = uname
                    store.userProfile.socialBio = bioVal
                    store.userProfile.socialLocation = locVal
                    store.userProfile.socialEnabled = true
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
