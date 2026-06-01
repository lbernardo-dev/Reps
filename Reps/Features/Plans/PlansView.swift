import SwiftUI

struct PlansView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showCreatePlan = false
    @State private var showExerciseLibrary = false
    @State private var planToEdit: WorkoutPlan?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Plan")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Crea y ajusta tu rutina")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                        let isSpanish = store.userProfile.preferredLanguage.hasPrefix("es")
                        Button {
                            HapticService.selection()
                            showProfile = true
                        } label: {
                            let avatarData = store.userProfile.avatarImageData
                            if let avatarData, let image = UIImage(data: avatarData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 38, height: 38)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(color: .black.opacity(0.20), radius: 4)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(PulseTheme.primary.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(PulseTheme.primary)
                                }
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(color: .black.opacity(0.20), radius: 4)
                            }
                        }
                        .padding(.top, 4)
                        .buttonStyle(.plain)
                        .accessibilityLabel(isSpanish ? "Perfil" : "Profile")
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Bibliotecas")
                                .font(.headline)
                            Text("Busca ejercicios reales o reutiliza rutinas completas.")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)

                            HStack(spacing: 12) {
                                Button {
                                    showExerciseLibrary = true
                                } label: {
                                    LibraryShortcut(
                                        title: "Ejercicios",
                                        subtitle: "\(store.exercises.count) disponibles",
                                        systemImage: "magnifyingglass"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    WorkoutLibraryView()
                                } label: {
                                    LibraryShortcut(
                                        title: "Rutinas",
                                        subtitle: "\(store.workoutTemplates.count) plantillas",
                                        systemImage: "list.clipboard"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SectionHeader(title: "PLAN ACTIVO")

                    PulseCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                PulseChip(title: "En progreso", isSelected: true)
                                Spacer()
                                Menu {
                                    Button("Editar plan") {
                                        planToEdit = store.activePlan
                                    }
                                    Button("Desactivar plan") {
                                        store.deactivatePlan(store.activePlan)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Acciones del plan")
                            }

                            Text(store.activePlan.name)
                                .font(.system(size: 30, weight: .bold, design: .rounded))

                            HStack(spacing: 16) {
                                Label(locationTitle(store.activePlan.location), systemImage: "dumbbell.fill")
                                Divider().frame(height: 18)
                                Label("\(store.activePlan.daysPerWeek) dias/semana", systemImage: "calendar")
                            }
                            .foregroundStyle(PulseTheme.secondaryText)

                            ProgressView(value: store.activePlan.completion)
                                .tint(PulseTheme.primary)

                            HStack {
                                Text("Semana \(store.activePlan.currentWeek) de \(store.activePlan.totalWeeks)")
                                Spacer()
                                Text("\(Int(store.activePlan.completion * 100))% completado")
                            }
                            .foregroundStyle(PulseTheme.secondaryText)

                            if let targetEventName = store.activePlan.targetEventName,
                               let targetEventDate = store.activePlan.targetEventDate {
                                Divider()
                                PlanTargetEventSummary(
                                    eventName: targetEventName,
                                    eventDate: targetEventDate
                                )
                            }
                        }
                    }

                    PlanMusicCard(plan: store.activePlan) {
                        planToEdit = store.activePlan
                    }

                    SectionHeader(title: "DIAS DE ENTRENAMIENTO")

                    PulseCard {
                        VStack(spacing: 0) {
                            ForEach(store.activePlan.days) { day in
                                NavigationLink {
                                    WorkoutDetailView(workout: day)
                                } label: {
                                    PlanDayRow(day: day)
                                }
                                .buttonStyle(.plain)

                                if day.id != store.activePlan.days.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    SectionHeader(title: "TUS PLANES")

                    PulseCard {
                        VStack(spacing: 0) {
                            let inactivePlans = store.plans.filter { $0.id != store.activePlan.id }
                            if inactivePlans.isEmpty {
                                PulseEmptyState(
                                    title: "No hay planes guardados",
                                    message: "Crea un plan nuevo o edita el activo cuando cambie tu rutina.",
                                    systemImage: "square.stack.3d.up"
                                )
                            }
                            ForEach(inactivePlans) { plan in
                                Button {
                                    store.activatePlan(plan)
                                } label: {
                                    PlanRow(plan: plan)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Activar") {
                                        store.activatePlan(plan)
                                    }
                                    Button("Editar plan") {
                                        planToEdit = plan
                                    }
                                    Button("Eliminar", role: .destructive) {
                                        store.deletePlan(plan)
                                    }
                                }

                                if plan.id != inactivePlans.last?.id {
                                    Divider().padding(.leading, 72)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 112)
            }
            .screenBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(item: $planToEdit) { plan in
                EditPlanView(plan: plan)
            }
            .sheet(isPresented: $showExerciseLibrary) {
                ExerciseLibraryView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    private func locationTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: "Gimnasio"
        case .home: "Casa"
        case .both: "Casa y gimnasio"
        }
    }
}

private struct LibraryShortcut: View {
    let title: LocalizedStringKey
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 38, height: 38)
                .background(PulseTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PlanTargetEventSummary: View {
    let eventName: String
    let eventDate: Date

    private var eventState: (days: Int, weeks: Int) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.startOfDay(for: eventDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (days, max(0, days / 7))
    }

    private var statusText: String {
        let state = eventState
        if state.days > 0 {
            return "Faltan \(state.days) dias (\(state.weeks) sem)"
        }
        if state.days == 0 {
            return "Hoy"
        }
        return "Completado"
    }

    private var adviceText: String {
        let state = eventState
        if state.days <= 0 {
            return "Evento alcanzado. Revisa resultados y prepara el siguiente bloque con el estado actual."
        }
        if state.weeks < 6 {
            return "Plazo corto: prioriza consistencia e intensidad controlada. Considera extender el plan 4 semanas despues del evento."
        }
        if state.weeks <= 12 {
            return "Plazo optimo: estas dentro de una ventana ideal para completar un bloque progresivo."
        }
        return "Plazo largo: completa un bloque de fuerza/hipertrofia de 8-12 semanas y reserva un bloque final de mantenimiento o definicion."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(PulseTheme.primary)
                Text("Objetivo: \(eventName)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(PulseTheme.primaryBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PulseTheme.primaryBright.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(adviceText)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PlanRow: View {
    let plan: WorkoutPlan

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: plan.location == .home ? "house.fill" : "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 52, height: 52)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name).font(.title3.weight(.bold))
                Text("\(plan.daysPerWeek) dias/semana").foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "ellipsis")
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

private struct PlanDayRow: View {
    let day: WorkoutDay

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "list.clipboard")
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 42, height: 42)
                .background(PulseTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(day.title)
                    .font(.headline)
                Text("\(day.exercises.count) ejercicios · \(day.durationMinutes) min")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.vertical, 10)
    }
}

private struct PlanMusicCard: View {
    let plan: WorkoutPlan
    let onEdit: () -> Void
    @Environment(\.openURL) private var openURL
    @StateObject private var musicPlayer = WorkoutAppleMusicPlayer.shared

    private var primaryPlaylist: PlanPlaylist? {
        plan.playlists.first
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Música del plan", systemImage: "music.note.list")
                        .font(.headline)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: plan.playlists.isEmpty ? "plus.circle.fill" : "slider.horizontal.3")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                    }
                    .accessibilityLabel(plan.playlists.isEmpty ? "Añadir playlist" : "Editar playlists")
                }

                if let primaryPlaylist {
                    HStack(spacing: 12) {
                        PlaylistProviderBadge(provider: primaryPlaylist.provider)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(primaryPlaylist.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(statusTitle(for: primaryPlaylist))
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            playPlaylist(primaryPlaylist)
                        } label: {
                            Image(systemName: playButtonIcon(for: primaryPlaylist))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(primaryPlaylist.provider == .appleMusic ? Color.pink : PulseTheme.accent)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(primaryPlaylist.provider == .appleMusic ? "Reproducir en Reps" : "Abrir playlist")
                    }

                    if plan.playlists.count > 1 {
                        Text("+\(plan.playlists.count - 1) playlists alternativas para otros estados de ánimo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                } else {
                    Text("Añade una playlist de Spotify o Apple Music para arrancarla desde el entrenamiento.")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                    Button(action: onEdit) {
                        Label("Conectar playlist", systemImage: "link.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private func statusTitle(for playlist: PlanPlaylist) -> String {
        playlist.provider == .appleMusic ? musicPlayer.statusText(for: playlist) : providerTitle(playlist.provider)
    }

    private func playButtonIcon(for playlist: PlanPlaylist) -> String {
        playlist.provider == .appleMusic && musicPlayer.isPlaying(playlist) ? "pause.fill" : "play.fill"
    }

    private func playPlaylist(_ playlist: PlanPlaylist) {
        if playlist.provider == .appleMusic {
            Task {
                await musicPlayer.playOrPause(playlist)
            }
            return
        }

        guard let url = URL(string: playlist.urlString) else {
            return
        }
        openURL(url)
    }
}

private struct PlaylistProviderBadge: View {
    let provider: PlanPlaylist.Provider

    var body: some View {
        Image(systemName: provider == .spotify ? "dot.radiowaves.left.and.right" : "music.note")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(provider == .spotify ? Color.green : Color.pink)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PlanPlaylistEditor: View {
    @Binding var playlists: [PlanPlaylist]
    @Binding var showMusicConnector: Bool
    @State private var provider: PlanPlaylist.Provider = .spotify
    @State private var title = ""
    @State private var urlString = ""
    @State private var notes = ""
    
    @State private var showManualForm = false

    var body: some View {
        Section("Música") {
            if playlists.isEmpty {
                Text("Guarda playlists de Spotify o Apple Music para abrirlas durante el entrenamiento.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playlists) { playlist in
                    HStack(spacing: 12) {
                        PlaylistProviderBadge(provider: playlist.provider)
                            .frame(width: 38, height: 38)
                        VStack(alignment: .leading) {
                            Text(playlist.title)
                                .font(.headline)
                            Text(providerTitle(playlist.provider))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            playlists.removeAll { $0.id == playlist.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            Button {
                showMusicConnector = true
            } label: {
                Label("Conectar desde Biblioteca", systemImage: "music.note.list")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [Color.pink, Color.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            DisclosureGroup(isExpanded: $showManualForm) {
                VStack(spacing: 12) {
                    Picker("Servicio", selection: $provider) {
                        ForEach(PlanPlaylist.Provider.allCases) { provider in
                            Text(providerTitle(provider)).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    TextField("Nombre de la playlist", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField(provider == .spotify ? "https://open.spotify.com/playlist/..." : "https://music.apple.com/...", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Nota opcional: fuerza, cardio, focus...", text: $notes)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        addPlaylist()
                    } label: {
                        Label("Añadir playlist manual", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .foregroundStyle(.white)
                            .background(canAdd ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canAdd)
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            } label: {
                Text("Añadir manualmente por URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func addPlaylist() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        playlists.append(
            PlanPlaylist(
                provider: provider,
                title: trimmedTitle,
                urlString: trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        )
        title = ""
        urlString = ""
        notes = ""
    }
}

private func providerTitle(_ provider: PlanPlaylist.Provider) -> String {
    switch provider {
    case .appleMusic: "Apple Music"
    case .spotify: "Spotify"
    }
}

private struct PlanExerciseBookmarkTarget: Identifiable {
    let dayIndex: Int
    let exerciseIndex: Int
    var id: String { "\(dayIndex)-\(exerciseIndex)" }
}

private struct PlanExerciseBookmarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bookmarks: [ExerciseMediaBookmark]

    @State private var title = ""
    @State private var source: ExerciseMediaBookmark.Source = .youtube
    @State private var urlString = ""
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var durationMinutes = 0
    @State private var durationSeconds = 0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Marcadores del ejercicio") {
                    if bookmarks.isEmpty {
                        Text("Guarda referencias de técnica con minuto exacto para este ejercicio dentro del plan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(bookmarks) { bookmark in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(bookmark.title, systemImage: bookmarkIcon(bookmark.source))
                                    .font(.headline)
                                Spacer()
                                Button(role: .destructive) {
                                    bookmarks.removeAll { $0.id == bookmark.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            Text(bookmark.urlString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack(spacing: 12) {
                                if let timestamp = bookmark.timestampSeconds {
                                    Text("Marcador \(timestamp / 60):\(String(format: "%02d", timestamp % 60))")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.primary)
                                }
                                if let duration = bookmark.playbackDurationSeconds {
                                    Text("Duración \(duration / 60)m \(duration % 60)s")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                }

                Section("Añadir") {
                    TextField("Título", text: $title)
                    Picker("Fuente", selection: $source) {
                        ForEach(ExerciseMediaBookmark.Source.allCases) { source in
                            Text(bookmarkSourceTitle(source)).tag(source)
                        }
                    }
                    TextField("URL", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Text("Punto de inicio en video")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper("Min \(minutes)", value: $minutes, in: 0...240)
                    Stepper("Seg \(seconds)", value: $seconds, in: 0...59)
                    
                    Text("Duración de reproducción")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper("Min Duración \(durationMinutes)", value: $durationMinutes, in: 0...60)
                    Stepper("Seg Duración \(durationSeconds)", value: $durationSeconds, in: 0...59)
                    
                    TextField("Nota", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        add()
                    } label: {
                        Label("Añadir marcador", systemImage: "bookmark.fill")
                    }
                    .disabled(!canAdd)
                }
            }
            .navigationTitle("Marcadores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func add() {
        let totalDuration = durationMinutes * 60 + durationSeconds
        bookmarks.append(
            ExerciseMediaBookmark(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
                timestampSeconds: minutes == 0 && seconds == 0 ? nil : minutes * 60 + seconds,
                playbackDurationSeconds: totalDuration > 0 ? totalDuration : nil,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            )
        )
        title = ""
        urlString = ""
        minutes = 0
        seconds = 0
        durationMinutes = 0
        durationSeconds = 0
        note = ""
    }
}

private func bookmarkSourceTitle(_ source: ExerciseMediaBookmark.Source) -> String {
    switch source {
    case .youtube: "YouTube"
    case .youtubeShorts: "YouTube Shorts"
    case .tiktok: "TikTok"
    case .instagram: "Instagram"
    case .other: "Otro"
    }
}

private func bookmarkIcon(_ source: ExerciseMediaBookmark.Source) -> String {
    switch source {
    case .youtube, .youtubeShorts: "play.rectangle.fill"
    case .tiktok: "music.note.tv"
    case .instagram: "camera.fill"
    case .other: "link"
    }
}

private enum PlanWizardStep: Int, CaseIterable, Identifiable {
    case basics
    case schedule
    case sessions
    case musicReview

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .basics: "Base del plan"
        case .schedule: "Distribución"
        case .sessions: "Sesiones"
        case .musicReview: "Música y revisión"
        }
    }

    var subtitle: String {
        switch self {
        case .basics: "Define objetivo, entorno y duración del bloque."
        case .schedule: "Elige si el plan rota por ciclo o se fija a días concretos."
        case .sessions: "Construye cada día con tipo, ejercicios y descansos."
        case .musicReview: "Añade playlists y confirma la estructura."
        }
    }
}

private enum PlanScheduleMode: String, CaseIterable, Identifiable {
    case cycle
    case weekdays

    var id: String { rawValue }
    var title: String { self == .cycle ? "Ciclo" : "Días" }
    var description: String {
        self == .cycle
        ? "Las sesiones avanzan en orden: Día A, Día B, Día C, sin depender de lunes o martes."
        : "Las sesiones se asignan a días fijos de la semana para planificar calendario."
    }
}

private struct PlanExercisePickerTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var step: PlanWizardStep = .basics
    @State private var planName = ""
    @State private var location: UserProfile.TrainingLocation = .gym
    @State private var daysPerWeek = 4
    @State private var totalWeeks = 8
    @State private var activateImmediately = true
    @State private var scheduleMode: PlanScheduleMode = .cycle
    @State private var selectedWeekdays: Set<Int> = [1, 3, 5, 6]
    @State private var days: [WorkoutDay] = [
        WorkoutDay(title: "Día A", subtitle: "Fuerza", durationMinutes: 45, exercises: []),
        WorkoutDay(title: "Día B", subtitle: "Fuerza", durationMinutes: 45, exercises: [])
    ]
    @State private var playlists: [PlanPlaylist] = []
    @State private var pickerTargetDay: Int?
    @State private var showMusicConnector = false
    @State private var hasTargetEvent = false
    @State private var targetEventName = ""
    @State private var targetEventDate = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                wizardHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case .basics:
                            basicsStep
                        case .schedule:
                            scheduleStep
                        case .sessions:
                            sessionsStep
                        case .musicReview:
                            musicReviewStep
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
                .screenBackground()
            }
            .navigationTitle("Crear plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button { previousStep() } label: {
                        Label("Atrás", systemImage: "chevron.left")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .disabled(step == .basics)
                    .opacity(step == .basics ? 0.45 : 1)

                    Button { nextOrSave() } label: {
                        Label(step == .musicReview ? "Guardar" : "Siguiente", systemImage: step == .musicReview ? "checkmark" : "chevron.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.white)
                            .background(canContinue ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .disabled(!canContinue)
                }
                .padding(20)
                .background(.ultraThinMaterial)
            }
            .sheet(item: pickerBinding) { target in
                PlanExercisePickerSheet(exercises: store.exercises) { exercise in
                    addExercise(exercise, to: target.index)
                    pickerTargetDay = nil
                }
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(PlanWizardStep.allCases) { wizardStep in
                    Capsule()
                        .fill(wizardStep.rawValue <= step.rawValue ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.18))
                        .frame(height: 6)
                }
            }
            Text(step.title).font(.title2.bold())
            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(PulseTheme.background)
    }

    private var basicsStep: some View {
        VStack(spacing: 16) {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Identidad del plan").font(.headline)
                    TextField("Nombre del plan", text: $planName)
                        .textFieldStyle(.roundedBorder)
                    Picker("Entorno", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Activar al guardar", isOn: $activateImmediately)
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $hasTargetEvent) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(PulseTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("¿Tienes un evento objetivo?")
                                    .font(.headline)
                                Text("Adaptar duración según fecha límite.")
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }

                    if hasTargetEvent {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nombre del evento")
                                .font(.caption.bold())
                                .foregroundStyle(PulseTheme.secondaryText)
                            TextField("Ej. Boda, Vacaciones, Maratón", text: $targetEventName)
                                .textFieldStyle(.roundedBorder)

                            DatePicker(
                                "Fecha del evento",
                                selection: $targetEventDate,
                                in: Date.now...,
                                displayedComponents: .date
                            )
                            .font(.subheadline.weight(.semibold))

                            if let advice = targetEventAdvice {
                                Text(advice.text)
                                    .font(.caption)
                                    .foregroundStyle(advice.color)
                                    .padding(10)
                                    .background(advice.color.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .padding(.top, 4)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }

            HStack(spacing: 12) {
                WizardMetricStepper(title: "Días/sem", value: $daysPerWeek, range: 1...7)
                WizardMetricStepper(title: "Semanas", value: $totalWeeks, range: 1...24)
            }
        }
        .onChange(of: targetEventDate) { _, _ in
            updateWeeksFromEventDate()
        }
        .onChange(of: hasTargetEvent) { _, active in
            if active {
                updateWeeksFromEventDate()
            } else {
                totalWeeks = 8
            }
        }
        .onChange(of: targetEventName) { _, newName in
            if !newName.isEmpty && planName.isEmpty {
                planName = "Plan para \(newName)"
            }
        }
    }

    private var scheduleStep: some View {
        VStack(spacing: 16) {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Distribución").font(.headline)
                    Picker("Modo", selection: $scheduleMode) {
                        ForEach(PlanScheduleMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(scheduleMode.description)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            if scheduleMode == .weekdays {
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Días fijos").font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                Button { toggleWeekday(day) } label: {
                                    Text(weekdayTitle(day))
                                        .font(.caption.bold())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .foregroundStyle(selectedWeekdays.contains(day) ? .white : PulseTheme.primary)
                                        .background(selectedWeekdays.contains(day) ? PulseTheme.primary : PulseTheme.primary.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sessionsStep: some View {
        VStack(spacing: 16) {
            ForEach(days.indices, id: \.self) { index in
                SessionBuilderCard(day: $days[index], index: index) {
                    pickerTargetDay = index
                }
            }
            Button { addDay() } label: {
                Label("Añadir sesión", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(PulseTheme.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                            .stroke(PulseTheme.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
            }
        }
    }

    private var musicReviewStep: some View {
        VStack(spacing: 16) {
            PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)
            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resumen").font(.headline)
                    PlanPreviewDay(title: planName.isEmpty ? "Plan sin nombre" : planName, workout: "\(days.count) sesiones · \(daysPerWeek) días/semana", exercises: days.reduce(0) { $0 + $1.exercises.count })
                    ForEach(days) { day in
                        HStack {
                            Label(day.title, systemImage: sessionTypeIcon(day.sessionType))
                            Spacer()
                            Text("\(day.exercises.count) ejercicios")
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case .basics:
            !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .schedule:
            scheduleMode == .cycle || !selectedWeekdays.isEmpty
        case .sessions:
            !days.isEmpty && days.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .musicReview:
            true
        }
    }

    private var pickerBinding: Binding<PlanExercisePickerTarget?> {
        Binding(
            get: { pickerTargetDay.map(PlanExercisePickerTarget.init(index:)) },
            set: { pickerTargetDay = $0?.index }
        )
    }

    private func nextOrSave() {
        if step == .musicReview {
            save()
        } else {
            step = PlanWizardStep(rawValue: step.rawValue + 1) ?? .musicReview
        }
    }

    private func previousStep() {
        step = PlanWizardStep(rawValue: max(step.rawValue - 1, 0)) ?? .basics
    }

    private func addDay() {
        let letter = Character(UnicodeScalar(65 + min(days.count, 25))!)
        days.append(WorkoutDay(title: "Día \(letter)", subtitle: "Fuerza", durationMinutes: 45, exercises: []))
    }

    private func addExercise(_ exercise: Exercise, to dayIndex: Int) {
        guard days.indices.contains(dayIndex) else { return }
        days[dayIndex].exercises.append(
            WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-", restSeconds: 90)
        )
        if days[dayIndex].sessionType == .cardioRun || days[dayIndex].sessionType == .cardioWalk {
            days[dayIndex].sessionType = .mixedRoute
        }
    }

    private func save() {
        let preparedDays = days.enumerated().map { offset, day in
            var copy = day
            if copy.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.title = "Sesión \(offset + 1)"
            }
            if copy.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.subtitle = sessionTypeTitle(copy.sessionType)
            }
            return copy
        }
        let plan = WorkoutPlan(
            name: planName.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location,
            daysPerWeek: daysPerWeek,
            currentWeek: 1,
            totalWeeks: totalWeeks,
            completion: 0,
            days: preparedDays,
            playlists: playlists,
            targetEventName: hasTargetEvent ? (targetEventName.isEmpty ? "Evento" : targetEventName) : nil,
            targetEventDate: hasTargetEvent ? targetEventDate : nil
        )
        store.addPlan(plan, activate: activateImmediately)
        dismiss()
    }

    private func toggleWeekday(_ day: Int) {
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
    }

    private func weekdayTitle(_ day: Int) -> String {
        ["L", "M", "X", "J", "V", "S", "D"][max(0, min(day - 1, 6))]
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: "Gimnasio"
        case .home: "Casa"
        case .both: "Casa y gimnasio"
        }
    }

    private struct EventAdvice {
        let text: String
        let color: Color
        let weeks: Int
    }

    private var targetEventAdvice: EventAdvice? {
        guard hasTargetEvent else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: targetEventDate).day ?? 0
        let weeks = max(1, days / 7)
        
        if weeks < 6 {
            return EventAdvice(
                text: "Faltan \(weeks) semanas. Duración corta: te sugerimos maximizar el rendimiento actual de inmediato. El plan se ha ajustado a \(weeks) semanas.",
                color: PulseTheme.warning,
                weeks: weeks
            )
        } else if weeks <= 12 {
            return EventAdvice(
                text: "Faltan \(weeks) semanas. ¡Duración óptima para progresar! El plan se ha ajustado a \(weeks) semanas.",
                color: PulseTheme.primaryBright,
                weeks: weeks
            )
        } else {
            return EventAdvice(
                text: "Faltan \(weeks) semanas. Duración larga: te sugerimos realizar un bloque de 8 a 12 semanas y luego un plan de mantenimiento/definición secundario de \(weeks - 8) semanas.",
                color: PulseTheme.primary,
                weeks: weeks
            )
        }
    }

    private func updateWeeksFromEventDate() {
        guard hasTargetEvent else { return }
        let days = Calendar.current.dateComponents([.day], from: .now, to: targetEventDate).day ?? 0
        if days > 0 {
            totalWeeks = max(3, min(24, days / 7))
        }
    }
}


struct EditPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let plan: WorkoutPlan

    @State private var name: String
    @State private var location: UserProfile.TrainingLocation
    @State private var daysPerWeek: Int
    @State private var totalWeeks: Int
    @State private var currentWeek: Int
    @State private var days: [WorkoutDay]
    @State private var playlists: [PlanPlaylist]
    @State private var bookmarkTarget: PlanExerciseBookmarkTarget?
    @State private var showMusicConnector = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _name = State(initialValue: plan.name)
        _location = State(initialValue: plan.location)
        _daysPerWeek = State(initialValue: plan.daysPerWeek)
        _totalWeeks = State(initialValue: plan.totalWeeks)
        _currentWeek = State(initialValue: plan.currentWeek)
        _days = State(initialValue: plan.days)
        _playlists = State(initialValue: plan.playlists)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informacion basica") {
                    TextField("Nombre del plan", text: $name)
                    Picker("Entorno de entrenamiento", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                }

                Section("Calendario") {
                    Stepper("\(daysPerWeek) dias por semana", value: $daysPerWeek, in: 1...7)
                    Stepper("Semana \(currentWeek) de \(totalWeeks)", value: $currentWeek, in: 1...max(totalWeeks, 1))
                    Stepper("\(totalWeeks) semanas", value: $totalWeeks, in: max(currentWeek, 1)...24)
                }

                PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)

                ForEach(days.indices, id: \.self) { dayIndex in
                    Section("Entrenamiento \(dayIndex + 1)") {
                        TextField("Titulo", text: Binding(
                            get: { days[dayIndex].title },
                            set: { days[dayIndex].title = $0 }
                        ))
                        TextField("Subtitulo", text: Binding(
                            get: { days[dayIndex].subtitle },
                            set: { days[dayIndex].subtitle = $0 }
                        ))
                        Stepper("\(days[dayIndex].durationMinutes) min", value: Binding(
                            get: { days[dayIndex].durationMinutes },
                            set: { days[dayIndex].durationMinutes = $0 }
                        ), in: 10...180, step: 5)
                        Stepper("Descanso entre ejercicios: \(days[dayIndex].restBetweenExercisesSeconds) s", value: Binding(
                            get: { days[dayIndex].restBetweenExercisesSeconds },
                            set: { days[dayIndex].restBetweenExercisesSeconds = $0 }
                        ), in: 0...600, step: 15)

                        ForEach(days[dayIndex].exercises.indices, id: \.self) { exerciseIndex in
                            VStack(alignment: .leading, spacing: 12) {
                                // Row 1 — Name & Trash Button
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(days[dayIndex].exercises[exerciseIndex].exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Text("\(days[dayIndex].exercises[exerciseIndex].exercise.muscleGroup) · \(days[dayIndex].exercises[exerciseIndex].exercise.equipment)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        days[dayIndex].exercises.remove(at: exerciseIndex)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.red.opacity(0.8))
                                            .frame(width: 32, height: 32)
                                            .background(Color.red.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 8) {
                                    // Bookmarks Badge Button
                                    Button {
                                        bookmarkTarget = PlanExerciseBookmarkTarget(dayIndex: dayIndex, exerciseIndex: exerciseIndex)
                                    } label: {
                                        Label("\(days[dayIndex].exercises[exerciseIndex].mediaBookmarks.count) marcadores", systemImage: "bookmark.fill")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(PulseTheme.primary.opacity(0.12))
                                            .foregroundStyle(PulseTheme.primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }

                                Divider()

                                // Metrics grid
                                HStack(spacing: 8) {
                                    CompactStepper(
                                        title: "Series",
                                        value: Binding(
                                            get: { days[dayIndex].exercises[exerciseIndex].targetSets },
                                            set: { days[dayIndex].exercises[exerciseIndex].targetSets = $0 }
                                        ),
                                        range: 1...10,
                                        suffix: "",
                                        step: 1
                                    )

                                    CompactStepper(
                                        title: "Descanso",
                                        value: Binding(
                                            get: { days[dayIndex].exercises[exerciseIndex].restSeconds },
                                            set: { days[dayIndex].exercises[exerciseIndex].restSeconds = $0 }
                                        ),
                                        range: 0...600,
                                        suffix: "s",
                                        step: 15
                                    )

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Reps")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                        TextField("8-12", text: Binding(
                                            get: { days[dayIndex].exercises[exerciseIndex].repRange },
                                            set: { days[dayIndex].exercises[exerciseIndex].repRange = $0 }
                                        ))
                                        .font(.headline.weight(.bold).monospacedDigit())
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(PulseTheme.grouped)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                            .padding(14)
                            .background(PulseTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .listRowInsets(EditPlanLayout.cardRowInsets)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        VStack(spacing: 0) {
                            Menu {
                                ForEach(store.exercises) { exercise in
                                    Button(exercise.name) {
                                        days[dayIndex].exercises.append(WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-", restSeconds: 90))
                                    }
                                }
                            } label: {
                                PlanEditorActionRow(title: "Anadir ejercicio", systemImage: "plus", color: PulseTheme.primary)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, EditPlanLayout.actionDividerLeading)

                            Button(role: .destructive) {
                                days.remove(at: dayIndex)
                            } label: {
                                PlanEditorActionRow(title: "Eliminar dia", systemImage: "trash", color: .red)
                            }
                            .buttonStyle(.plain)
                            .disabled(days.count == 1)
                        }
                        .padding(.horizontal, EditPlanLayout.cardPadding)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .listRowInsets(EditPlanLayout.cardRowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                Section {
                    Button {
                        days.append(WorkoutDay(title: "Entrenamiento \(days.count + 1)", subtitle: "Fuerza", durationMinutes: 45, exercises: []))
                    } label: {
                        Label("Anadir dia", systemImage: "plus")
                    }

                    Menu {
                        ForEach(store.workoutTemplates) { workout in
                            Button(workout.title) {
                                days.append(workout)
                            }
                        }
                    } label: {
                        Label("Anadir rutina existente", systemImage: "list.clipboard")
                    }
                }
            }
            .navigationTitle("Editar plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: $bookmarkTarget) { target in
                PlanExerciseBookmarkEditor(bookmarks: Binding(
                    get: {
                        guard days.indices.contains(target.dayIndex),
                              days[target.dayIndex].exercises.indices.contains(target.exerciseIndex) else {
                            return []
                        }
                        return days[target.dayIndex].exercises[target.exerciseIndex].mediaBookmarks
                    },
                    set: { newValue in
                        guard days.indices.contains(target.dayIndex),
                              days[target.dayIndex].exercises.indices.contains(target.exerciseIndex) else {
                            return
                        }
                        days[target.dayIndex].exercises[target.exerciseIndex].mediaBookmarks = newValue
                    }
                ))
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private func save() {
        var updated = plan
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.location = location
        updated.daysPerWeek = daysPerWeek
        updated.currentWeek = min(currentWeek, totalWeeks)
        updated.totalWeeks = totalWeeks
        updated.days = days.isEmpty ? plan.days : days
        updated.playlists = playlists
        store.updatePlan(updated)
        dismiss()
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: "Gimnasio"
        case .home: "Casa"
        case .both: "Casa y gimnasio"
        }
    }
}

private enum EditPlanLayout {
    static let cardPadding: CGFloat = 14
    static let cardRowInsets = EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
    static let actionDividerLeading: CGFloat = 56
}

private struct PlanEditorActionRow: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.title2.weight(.medium))
                .frame(width: 38, height: 52)

            Text(title)
                .font(.headline.weight(.regular))

            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct LegacyCreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var planName = ""
    @State private var location: UserProfile.TrainingLocation = .gym
    @State private var daysPerWeek = 4
    @State private var totalWeeks = 8
    @State private var activateImmediately = true
    @State private var workoutTitle = "Full body"
    @State private var selectedExerciseIDs = Set<Exercise.ID>()
    @State private var playlists: [PlanPlaylist] = []
    @State private var showMusicConnector = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Informacion basica") {
                    TextField("Nombre del plan", text: $planName)
                    Picker("Entorno de entrenamiento", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                }

                Section("Calendario") {
                    Stepper("\(daysPerWeek) dias por semana", value: $daysPerWeek, in: 1...7)
                    Stepper("\(totalWeeks) semanas", value: $totalWeeks, in: 1...16)
                    Toggle("Activar al guardar", isOn: $activateImmediately)
                }

                PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)

                Section("Entrenamiento") {
                    TextField("Titulo del entrenamiento", text: $workoutTitle)
                    ForEach(store.exercises) { exercise in
                        Button {
                            toggle(exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedExerciseIDs.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedExerciseIDs.contains(exercise.id) ? PulseTheme.primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Vista previa") {
                    PlanPreviewDay(title: "Entrenamiento A", workout: workoutTitle.isEmpty ? "Full body" : workoutTitle, exercises: selectedExerciseIDs.count)
                    Text("Reps creara \(daysPerWeek) dias editables a partir de esta plantilla.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Crear plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        if selectedExerciseIDs.contains(exercise.id) {
            selectedExerciseIDs.remove(exercise.id)
        } else {
            selectedExerciseIDs.insert(exercise.id)
        }
    }

    private func save() {
        let trimmedName = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedExercises = store.exercises.filter { selectedExerciseIDs.contains($0.id) }
        let workoutExercises = (selectedExercises.isEmpty ? Array(store.exercises.prefix(4)) : selectedExercises).map {
            WorkoutExercise(exercise: $0, targetSets: 3, repRange: defaultRepRange(for: $0), previous: "-")
        }
        let baseTitle = workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Full body" : workoutTitle
        let days = (1...daysPerWeek).map { index in
            WorkoutDay(
                title: daysPerWeek == 1 ? baseTitle : "\(baseTitle) \(index)",
                subtitle: location == .home ? "Entrenamiento en casa" : "Fuerza",
                durationMinutes: max(35, workoutExercises.count * 10),
                exercises: workoutExercises
            )
        }
        let plan = WorkoutPlan(
            name: trimmedName,
            location: location,
            daysPerWeek: daysPerWeek,
            currentWeek: 1,
            totalWeeks: totalWeeks,
            completion: 0,
            days: days,
            playlists: playlists
        )
        store.addPlan(plan, activate: activateImmediately)
        dismiss()
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: "Gimnasio"
        case .home: "Casa"
        case .both: "Casa y gimnasio"
        }
    }
}

private struct WizardMetricStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                HStack {
                    Text("\(value)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.primary)
                    Spacer()
                    Stepper(title, value: $value, in: range)
                        .labelsHidden()
                }
            }
        }
    }
}

private struct SessionBuilderCard: View {
    @Binding var day: WorkoutDay
    let index: Int
    let onAddExercise: () -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Sesión \(index + 1)", systemImage: sessionTypeIcon(day.sessionType))
                        .font(.headline)
                    Spacer()
                    Text("\(day.exercises.count) ejercicios")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                TextField("Título", text: $day.title)
                    .textFieldStyle(.roundedBorder)
                TextField("Subtítulo", text: $day.subtitle)
                    .textFieldStyle(.roundedBorder)

                Picker("Tipo", selection: $day.sessionType) {
                    ForEach(WorkoutDay.SessionType.allCases) { type in
                        Text(sessionTypeTitle(type)).tag(type)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 12) {
                    CompactStepper(title: "Duración", value: $day.durationMinutes, range: 10...240, suffix: "min", step: 5)
                    CompactStepper(title: "Entre ejercicios", value: $day.restBetweenExercisesSeconds, range: 0...600, suffix: "s", step: 15)
                }

                if day.sessionType == .cardioRun || day.sessionType == .cardioWalk || day.sessionType == .mixedRoute {
                    Label("Esta sesión mostrará GPS, ruta y mapa durante el entrenamiento.", systemImage: "map.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(day.exercises.indices, id: \.self) { exerciseIndex in
                    EditableWorkoutExerciseRow(item: $day.exercises[exerciseIndex]) {
                        day.exercises.remove(at: exerciseIndex)
                    }
                }

                Button(action: onAddExercise) {
                    Label("Añadir desde catálogo visual", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }
}

private struct CompactStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            
            HStack(spacing: 2) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 40)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Text("\(value)\(suffix)")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                
                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 40)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct EditableWorkoutExerciseRow: View {
    @Binding var item: WorkoutExercise
    let onDelete: () -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1 — identity + delete
            HStack(spacing: 12) {
                ExerciseMediaThumbnail(exercise: item.exercise, gender: store.userProfile.muscleMapGender)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.exercise.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(item.exercise.muscleGroup) · \(item.exercise.equipment)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eliminar \(item.exercise.name)")
            }

            // Row 2 — metric controls (Series | Descanso | Reps)
            HStack(spacing: 8) {
                // Series
                ExerciseMetricTile(
                    label: "Series",
                    value: "\(item.targetSets)",
                    onDecrement: { item.targetSets = max(1, item.targetSets - 1) },
                    onIncrement: { item.targetSets = min(10, item.targetSets + 1) }
                )

                // Descanso
                ExerciseMetricTile(
                    label: "Descanso",
                    value: "\(item.restSeconds)s",
                    onDecrement: { item.restSeconds = max(0, item.restSeconds - 15) },
                    onIncrement: { item.restSeconds = min(600, item.restSeconds + 15) }
                )

                // Rep range (text input tile)
                VStack(spacing: 4) {
                    Text("Reps")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)

                    TextField("8-12", text: $item.repRange)
                        .font(.headline.weight(.bold).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(PulseTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .keyboardType(.default)
                        .accessibilityLabel("Rango de repeticiones")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ExerciseMetricTile: View {
    let label: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)

            HStack(spacing: 4) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 44)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reducir \(label)")

                Text(value)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(PulseTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 44)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aumentar \(label)")
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct PlanExercisePickerSheet: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var searchText = ""
    @State private var selectedMuscle = "Todos"
    @State private var selectedEquipment = "Todos"

    private var muscles: [String] {
        ["Todos"] + Array(Set(exercises.map(\.muscleGroup))).sorted()
    }

    private var equipment: [String] {
        ["Todos"] + Array(Set(exercises.map(\.equipment))).sorted()
    }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = query.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.muscleGroup.localizedCaseInsensitiveContains(query)
                || exercise.equipment.localizedCaseInsensitiveContains(query)
            let matchesMuscle = selectedMuscle == "Todos" || exercise.muscleGroup == selectedMuscle
            let matchesEquipment = selectedEquipment == "Todos" || exercise.equipment == selectedEquipment
            return matchesQuery && matchesMuscle && matchesEquipment
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Buscar por nombre, músculo o equipo", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("Músculo", selection: $selectedMuscle) {
                                ForEach(muscles, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            Picker("Equipo", selection: $selectedEquipment) {
                                ForEach(equipment, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 20)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filtered) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender)
                                        .frame(height: 118)
                                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                    Text(exercise.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .background(PulseTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .screenBackground()
            .navigationTitle("Elegir ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

private func sessionTypeTitle(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: "Fuerza"
    case .cardioRun: "Carrera"
    case .cardioWalk: "Caminata"
    case .mixedRoute: "Mixta + ruta"
    case .mobility: "Movilidad"
    case .free: "Libre"
    }
}

private func sessionTypeIcon(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: "dumbbell.fill"
    case .cardioRun: "figure.run"
    case .cardioWalk: "figure.walk"
    case .mixedRoute: "map.fill"
    case .mobility: "figure.flexibility"
    case .free: "sparkles"
    }
}

private struct PlanPreviewDay: View {
    let title: String
    let workout: String
    let exercises: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(workout).foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Text("\(exercises) ejercicios")
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }
}
