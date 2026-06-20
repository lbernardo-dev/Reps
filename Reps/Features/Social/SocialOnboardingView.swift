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

    private var isES: Bool { RepsLocalization.language.hasPrefix("es") }
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
            .alert(isES ? "Error" : "Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isES ? "Cancelar" : "Cancel") { dismiss() }
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(PulseTheme.primary)
                    } else {
                        Button(isES ? "Activar" : "Enable") { saveProfile() }
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
                Text(isES ? "Conecta con amigos" : "Connect with friends")
                    .font(.system(size: 24, weight: .black, design: .rounded))

                Text(isES
                    ? "Elige un nombre de usuario para aparecer en la comunidad Reps y comparar tu progreso con amigos."
                    : "Pick a username to appear in the Reps community and compare your progress with friends.")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 12)
    }

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isES ? "Nombre de usuario" : "Username")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Text("@")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PulseTheme.primary)

                TextField(
                    isES ? "tunombre" : "yourname",
                    text: $username
                )
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
            Label(isES ? "Disponible" : "Available", systemImage: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.primaryBright)
                .padding(.horizontal, 4)
        case .taken:
            Label(isES ? "Nombre ya en uso" : "Username already taken", systemImage: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.destructive)
                .padding(.horizontal, 4)
        case .tooShort:
            Text(isES ? "Mínimo 3 caracteres (letras, números, _)" : "Min 3 chars (letters, numbers, _)")
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
        default:
            Text(isES ? "Solo letras, números y _ (3–20 caracteres)" : "Letters, numbers and _ only (3–20 chars)")
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
            Text(isES ? "Opcional" : "Optional")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "mappin")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(width: 20)
                    TextField(isES ? "Ciudad, país" : "City, country", text: $location)
                        .font(.subheadline)
                        .autocorrectionDisabled()
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
                        isES ? "Cuéntanos algo sobre ti…" : "Tell us something about you…",
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
            Text(isES
                ? "Solo se comparten: nivel, XP, sesiones totales, volumen total y racha. Tus entrenamientos siguen siendo privados."
                : "Only shared: level, XP, total sessions, total volume and streak. Your workouts remain private.")
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
                // The save will surface a real error if CloudKit rejects it.
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
                    totalVolumeKg: store.totalVolumeKg
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
