import SwiftUI

struct EditSocialProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var bio = ""
    @State private var location = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    fieldsSection
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
            .screenBackground()
            .navigationTitle(localizedString("social_edit_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(PulseTheme.primary)
                    } else {
                        Button(localizedString("save")) { save() }
                            .font(.headline)
                            .foregroundStyle(PulseTheme.primary)
                    }
                }
            }
            .alert(localizedString("ok"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localizedString("ok")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            bio = store.userProfile.socialBio
            location = store.userProfile.socialLocation
        }
    }

    private var avatarSection: some View {
        let uname = store.userProfile.socialUsername ?? "?"
        return HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(PulseTheme.primary.opacity(0.12))
                    .frame(width: 80, height: 80)
                if let data = store.userProfile.avatarImageData,
                   let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable().scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Text(String(uname.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(PulseTheme.primary)
                }
            }
            Spacer()
        }
    }

    private var fieldsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedString("location_2"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    TextField(localizedString("social_location_placeholder"), text: $location)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                }
            }
            .padding(14)

            Divider().padding(.leading, 46)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "text.quote")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(width: 20)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedString("social_bio"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    TextField(localizedString("social_bio_placeholder"), text: $bio, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(2...4)
                        .onChange(of: bio) { _, new in
                            if new.count > 80 { bio = String(new.prefix(80)) }
                        }
                    if !bio.isEmpty {
                        Text("\(bio.count)/80")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
            .padding(14)
        }
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    }

    private func save() {
        isSaving = true
        let bioVal = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let locVal = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uname = store.userProfile.socialUsername else { dismiss(); return }

        let xp = GamificationEngine.totalXP(
            sessions: store.workoutSessions,
            cardioLogs: store.combinedCardioLogs,
            bodyMetrics: store.bodyMetrics,
            progressPhotos: store.progressPhotos,
            streakDays: store.streakDays,
            totalVolumeKg: store.totalVolumeKg
        )
        let lvl = GamificationEngine.playerLevel(for: xp)
        let dname = store.userProfile.displayName ?? uname
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
                    store.userProfile.socialBio = bioVal
                    store.userProfile.socialLocation = locVal
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
