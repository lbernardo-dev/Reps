import SwiftUI
import MusicKit

struct MusicIntegrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    
    let onSelect: (PlanPlaylist) -> Void
    
    @State private var selectedProvider: PlanPlaylist.Provider = .appleMusic
    @State private var searchText = ""
    
    // Apple Music local states
    @State private var isAppleMusicAuthorized = false
    @State private var isCheckingAppleMusic = false
    @State private var isLoadingAppleMusicLibrary = false
    @State private var isSearchingCatalog = false
    @State private var appleMusicPlaylists: [Playlist] = []
    @State private var searchedCatalogPlaylists: [Playlist] = []
    @State private var searchTask: Task<Void, Never>? = nil
    
    // Spotify local states
    @AppStorage("isSpotifyConnected") private var isSpotifyConnected = false
    @State private var showSpotifyLogin = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Provider Tab Picker
                providerPicker
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedProvider {
                        case .appleMusic:
                            appleMusicView
                        case .spotify:
                            spotifyView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .screenBackground()
            .navigationTitle("Conectar música")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
            .sheet(isPresented: $showSpotifyLogin) {
                SpotifyLoginModal {
                    isSpotifyConnected = true
                    showSpotifyLogin = false
                }
            }
            .onAppear {
                checkAppleMusicAuthorization()
            }
            .onChange(of: searchText) { _, newValue in
                searchPlaylists(query: newValue)
            }
        }
    }
    
    // MARK: - Views
    
    private var providerPicker: some View {
        HStack(spacing: 4) {
            ForEach(PlanPlaylist.Provider.allCases) { provider in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedProvider = provider
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: provider == .spotify ? "dot.radiowaves.left.and.right" : "music.note")
                            .font(.subheadline.weight(.bold))
                        Text(provider == .spotify ? "Spotify" : "Apple Music")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(selectedProvider == provider ? .white : PulseTheme.secondaryText)
                    .background {
                        if selectedProvider == provider {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(provider == .spotify ? PulseTheme.spotify : PulseTheme.appleMusic)
                                .shadow(color: (provider == .spotify ? PulseTheme.spotify : PulseTheme.appleMusic).opacity(0.35), radius: 6, y: 3)
                        } else {
                            Color.clear
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Apple Music Integration
    
    private var appleMusicView: some View {
        VStack(spacing: 20) {
            if !isAppleMusicAuthorized {
                VStack(spacing: 16) {
                    // Apple Music branding card
                    LinearGradient(
                        colors: [PulseTheme.appleMusic, Color.purple, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.house.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white)
                            Text("Apple Music Integrado")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Sincroniza y busca tus playlists del sistema")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    )
                    .shadow(color: PulseTheme.appleMusic.opacity(0.3), radius: 12, y: 6)
                    
                    Text("Si tienes una suscripción de Apple Music activa en este dispositivo, Reps puede conectarse a tu biblioteca local y cargar tus playlists al instante sin copiar URLs.")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    Button {
                        requestAppleMusicPermission()
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Conectar Apple Music")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(PulseTheme.appleMusic)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Text("O bien, selecciona una de nuestras playlists de entrenamiento recomendadas a continuación.")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.tertiaryText)
                        .padding(.top, 8)
                }
            } else {
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.appleMusic)
                        Text("Apple Music conectado")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(14)
                    .background(PulseTheme.appleMusic.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            
            // Search Input
            VStack(alignment: .leading, spacing: 8) {
                Text(isAppleMusicAuthorized ? "Buscar en tu música o catálogo" : "Buscar playlist...")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                
                TextField("Buscar playlist...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            
            // List Playlists
            VStack(alignment: .leading, spacing: 14) {
                if isAppleMusicAuthorized {
                    // 1. Library Playlists
                    let filteredLibrary = appleMusicPlaylists.filter { playlist in
                        searchText.isEmpty || playlist.name.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    if !filteredLibrary.isEmpty {
                        Text("Tus Playlists (\(filteredLibrary.count))")
                            .font(.headline)
                            .padding(.horizontal, 2)
                        
                        ForEach(filteredLibrary) { playlist in
                            Button {
                                let planPlaylist = PlanPlaylist(
                                    provider: .appleMusic,
                                    title: playlist.name,
                                    urlString: playlist.url?.absoluteString ?? "library://playlist/\(playlist.id.rawValue)",
                                    notes: "Playlist de tu biblioteca"
                                )
                                onSelect(planPlaylist)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    if let artwork = playlist.artwork {
                                        ArtworkImage(artwork, width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        PlaylistArtMock(title: playlist.name, provider: .appleMusic)
                                            .frame(width: 52, height: 52)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("Biblioteca local")
                                            .font(.caption)
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(PulseTheme.appleMusic)
                                }
                                .padding(12)
                                .background(PulseTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    } else if searchText.isEmpty, isLoadingAppleMusicLibrary {
                        RepsLoadingView(
                            messages: [
                                "Cargando tu biblioteca...",
                                "Ordenando playlists...",
                                "Preparando música de entrenamiento..."
                            ],
                            progress: nil,
                            layout: .compact
                        )
                        .padding(.top, 4)
                    }
                }
                
                // 2. Catalog Search Results
                if !searchText.isEmpty {
                    Text("Resultados en Apple Music")
                        .font(.headline)
                        .padding(.horizontal, 2)
                        .padding(.top, 8)
                    
                    if searchedCatalogPlaylists.isEmpty, isSearchingCatalog {
                        RepsLoadingView(
                            messages: [
                                "Buscando en Apple Music...",
                                "Filtrando playlists útiles...",
                                "Preparando resultados..."
                            ],
                            progress: nil,
                            layout: .compact
                        )
                        .padding(.top, 4)
                    } else if searchedCatalogPlaylists.isEmpty {
                        Text("Sin resultados para esta búsqueda.")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(.horizontal, 2)
                    } else {
                        ForEach(searchedCatalogPlaylists) { playlist in
                            Button {
                                let planPlaylist = PlanPlaylist(
                                    provider: .appleMusic,
                                    title: playlist.name,
                                    urlString: playlist.url?.absoluteString ?? "https://music.apple.com/us/playlist/\(playlist.id.rawValue)",
                                    notes: playlist.curatorName ?? "Apple Music"
                                )
                                onSelect(planPlaylist)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    if let artwork = playlist.artwork {
                                        ArtworkImage(artwork, width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        PlaylistArtMock(title: playlist.name, provider: .appleMusic)
                                            .frame(width: 52, height: 52)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if let curator = playlist.curatorName {
                                            Text(curator)
                                                .font(.caption)
                                                .foregroundStyle(PulseTheme.secondaryText)
                                                .lineLimit(1)
                                        } else {
                                            Text("Apple Music")
                                                .font(.caption)
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(PulseTheme.appleMusic)
                                }
                                .padding(12)
                                .background(PulseTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    // Curated recommended playlists (shown only when not searching)
                    Text("Recomendadas para ti")
                        .font(.headline)
                        .padding(.horizontal, 2)
                        .padding(.top, 8)
                    
                    ForEach(curatedAppleMusicPlaylists) { playlist in
                        Button {
                            onSelect(playlist)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                PlaylistArtMock(title: playlist.title, provider: .appleMusic)
                                    .frame(width: 52, height: 52)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if let notes = playlist.notes {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(PulseTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(PulseTheme.appleMusic)
                            }
                            .padding(12)
                            .background(PulseTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Spotify Integration
    
    private var spotifyView: some View {
        VStack(spacing: 20) {
            if !isSpotifyConnected {
                VStack(spacing: 16) {
                    // Spotify branding card
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.8, blue: 0.3), Color(red: 0.05, green: 0.4, blue: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 54))
                                .foregroundStyle(.white)
                            Text("Sincronizar Spotify")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Inicia sesión para cargar tu biblioteca")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    )
                    .shadow(color: PulseTheme.spotify.opacity(0.3), radius: 12, y: 6)
                    
                    Text("Conecta Reps con tu cuenta de Spotify mediante el flujo seguro oficial para ver tus playlists creadas y sincronizarlas al instante sin salir de la app.")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    Button {
                        showSpotifyLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text("Conectar cuenta de Spotify")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(PulseTheme.spotify)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.spotify)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Spotify Conectado")
                                .font(.headline)
                            Text("Usuario: @workout_beast_reps")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                        Button("Desconectar") {
                            withAnimation {
                                isSpotifyConnected = false
                            }
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12), in: Capsule())
                    }
                    .padding(14)
                    .background(PulseTheme.spotify.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            
            // Spotify Playlists List
            VStack(alignment: .leading, spacing: 14) {
                Text(isSpotifyConnected ? "Tus Playlists en Spotify" : "Playlists Recomendadas")
                    .font(.headline)
                    .padding(.horizontal, 2)
                
                TextField("Buscar en biblioteca o catálogo...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                let filtered = curatedSpotifyPlaylists.filter { playlist in
                    searchText.isEmpty || playlist.title.localizedCaseInsensitiveContains(searchText)
                }
                
                ForEach(filtered) { playlist in
                    Button {
                        onSelect(playlist)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            PlaylistArtMock(title: playlist.title, provider: .spotify)
                                .frame(width: 52, height: 52)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if let notes = playlist.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(PulseTheme.spotify)
                        }
                        .padding(12)
                        .background(PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Logic Helpers
    
    private func checkAppleMusicAuthorization() {
        let status = MusicAuthorization.currentStatus
        isAppleMusicAuthorized = (status == .authorized)
        if isAppleMusicAuthorized {
            loadLibraryPlaylists()
        }
    }

    private func requestAppleMusicPermission() {
        guard !isCheckingAppleMusic else { return }

        isCheckingAppleMusic = true
        Task {
            let status = await MusicAuthorization.request()
            await MainActor.run {
                isAppleMusicAuthorized = (status == .authorized)
                isCheckingAppleMusic = false
                if isAppleMusicAuthorized {
                    loadLibraryPlaylists()
                }
            }
        }
    }
    
    private func loadLibraryPlaylists() {
        isLoadingAppleMusicLibrary = true
        Task {
            do {
                let request = MusicLibraryRequest<Playlist>()
                let response = try await request.response()
                await MainActor.run {
                    self.appleMusicPlaylists = Array(response.items)
                    self.isLoadingAppleMusicLibrary = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingAppleMusicLibrary = false
                }
                print("Error loading library playlists: \(error)")
            }
        }
    }
    
    private func searchPlaylists(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchedCatalogPlaylists = []
            isSearchingCatalog = false
            return
        }

        isSearchingCatalog = true
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                var searchRequest = MusicCatalogSearchRequest(term: query, types: [Playlist.self])
                searchRequest.limit = 10
                let response = try await searchRequest.response()
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchedCatalogPlaylists = Array(response.playlists)
                    self.isSearchingCatalog = false
                }
            } catch {
                await MainActor.run {
                    self.isSearchingCatalog = false
                }
                print("Error searching catalog playlists: \(error)")
            }
        }
    }
    
    // Curated Fallbacks/Catalog mock lists
    private var curatedAppleMusicPlaylists: [PlanPlaylist] {
        [
            PlanPlaylist(
                provider: .appleMusic,
                title: "⚡ Beast Mode Workout",
                urlString: "https://music.apple.com/us/playlist/beast-mode-workout/pl.7c9809cb9f3a4669894e24eb2df4eeec",
                notes: "BPM 135-150 · Heavy Electronic, Trap & Hip Hop"
            ),
            PlanPlaylist(
                provider: .appleMusic,
                title: "🏃‍♂️ Running Cadence 170 BPM",
                urlString: "https://music.apple.com/us/playlist/running-cadence-170-bpm/pl.4e8039c3e98b48ef98d9e2ea2df1e2a1",
                notes: "BPM 170 · Ritmo sostenido y motivacional para Cardio"
            ),
            PlanPlaylist(
                provider: .appleMusic,
                title: "🏋️ Gym Power Flow",
                urlString: "https://music.apple.com/us/playlist/gym-power-flow/pl.2b39e4a3b8d14cc9a29e2da02ff1e13a",
                notes: "BPM 128 · Tech House y Deep House premium"
            ),
            PlanPlaylist(
                provider: .appleMusic,
                title: "🔥 Phonk Workout Hits",
                urlString: "https://music.apple.com/us/playlist/phonk-workout-hits/pl.8a1209b2e3c14ff1aa2e8df1aef9ff2a",
                notes: "BPM 140 · Phonk agresivo para romper récords personales"
            ),
            PlanPlaylist(
                provider: .appleMusic,
                title: "🧘 Yoga & Active Recovery",
                urlString: "https://music.apple.com/us/playlist/yoga-active-recovery/pl.9d837cc9e31a4ab9a23e98b3ee1feec1",
                notes: "BPM 90 · Chill & Ambient para estiramientos y movilidad"
            )
        ]
    }
    
    private var curatedSpotifyPlaylists: [PlanPlaylist] {
        [
            PlanPlaylist(
                provider: .spotify,
                title: "🏋️ Phonk Gym Workout 2026",
                urlString: "https://open.spotify.com/playlist/37i9dQZF1DX1clOu7IL9B1",
                notes: "BPM 130-155 · High Bass Aggressive Phonk"
            ),
            PlanPlaylist(
                provider: .spotify,
                title: "🔥 Beast Mode: Heavy Beats",
                urlString: "https://open.spotify.com/playlist/37i9dQZF1DX76t638V6eg8",
                notes: "BPM 140 · Hip Hop, Hardcore Beats y Rock"
            ),
            PlanPlaylist(
                provider: .spotify,
                title: "🌪️ Hardstyle Gym Motivation",
                urlString: "https://open.spotify.com/playlist/37i9dQZF1DX83Iu5848g5O",
                notes: "BPM 150+ · Hardstyle e Hi-NRG Gym Rushes"
            ),
            PlanPlaylist(
                provider: .spotify,
                title: "🎧 Workout Beats & Electro",
                urlString: "https://open.spotify.com/playlist/37i9dQZF1DX70gQhijC23r",
                notes: "BPM 126 · Tech House, EDM y Fitness club hits"
            ),
            PlanPlaylist(
                provider: .spotify,
                title: "🌿 Lofi Cardio Sessions",
                urlString: "https://open.spotify.com/playlist/37i9dQZF1DWWQRwui0EXPn",
                notes: "BPM 95 · Chill Lofi hip hop para ritmos aeróbicos suaves"
            )
        ]
    }
}

// MARK: - Playlist Art Mock Component

struct PlaylistArtMock: View {
    let title: String
    let provider: PlanPlaylist.Provider
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: provider == .spotify 
                    ? [Color(red: 0.1, green: 0.8, blue: 0.3), Color(red: 0.05, green: 0.35, blue: 0.12)]
                    : [PulseTheme.appleMusic, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: provider == .spotify ? "dot.radiowaves.left.and.right" : "music.note")
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Spotify Login Modal Flow Simulation

struct SpotifyLoginModal: View {
    @Environment(\.dismiss) private var dismiss
    
    let onLoginSuccess: () -> Void
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var agreementStep = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !agreementStep {
                    // Credentials Form
                    ScrollView {
                        VStack(spacing: 24) {
                            // Spotify Big Logo
                            HStack(spacing: 8) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.title.weight(.black))
                                    .foregroundStyle(PulseTheme.spotify)
                                Text("Spotify")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, 40)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Para conectar con Reps, inicia sesión en Spotify.")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                            }
                            
                            VStack(spacing: 14) {
                                TextField("Correo electrónico o usuario", text: $username)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                
                                SecureField("Contraseña", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.horizontal, 8)
                            
                            Button {
                                performLogin()
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.black)
                                            .padding(.trailing, 8)
                                    }
                                    Text(isLoading ? "Iniciando sesión..." : "Iniciar Sesión")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(.black)
                                .background(PulseTheme.spotify)
                                .clipShape(Capsule())
                            }
                            .disabled(username.isEmpty || password.isEmpty || isLoading)
                            .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1.0)
                            .buttonStyle(.plain)
                            
                            Text("Reps nunca tiene acceso a tu contraseña. El inicio de sesión se procesa a través de la autenticación de Spotify.")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.tertiaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    // Scope Agreement Page
                    VStack(spacing: 24) {
                        Image(systemName: "personalhotspot")
                            .font(.system(size: 68))
                            .foregroundStyle(PulseTheme.spotify)
                            .padding(.top, 40)
                        
                        Text("¿Permitir a Reps conectarse a Spotify?")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Esta integración permitirá a Reps:")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            
                            bulletPoint(text: "Ver tu nombre de usuario y foto de perfil.")
                            bulletPoint(text: "Cargar tus playlists guardadas en tu biblioteca.")
                            bulletPoint(text: "Controlar la reproducción de música directamente desde el entrenamiento.")
                        }
                        .padding(16)
                        .background(PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            Button {
                                onLoginSuccess()
                            } label: {
                                Text("Acepto y Conectar")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .foregroundStyle(.black)
                                    .background(PulseTheme.spotify)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Button("Cancelar") {
                                dismiss()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(.vertical, 8)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    private func performLogin() {
        isLoading = true
        // Simulate networking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isLoading = false
            agreementStep = true
        }
    }
    
    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
                .foregroundStyle(PulseTheme.spotify)
            Text(text)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
