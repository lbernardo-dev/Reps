import SwiftUI
import MusicKit

struct MusicIntegrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    
    let onSelect: (PlanPlaylist) -> Void

    @State private var searchText = ""

    // Apple Music local states
    @State private var isAppleMusicAuthorized = false
    @State private var isCheckingAppleMusic = false
    @State private var isLoadingAppleMusicLibrary = false
    @State private var isSearchingCatalog = false
    @State private var appleMusicPlaylists: [Playlist] = []
    @State private var searchedCatalogPlaylists: [Playlist] = []
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    appleMusicView
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle("connect_music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") { dismiss() }
                        .font(.body.weight(.semibold))
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
                            Text("apple_music_integrado")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("sync_and_search_your_system_playlists")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    )
                    .shadow(color: PulseTheme.appleMusic.opacity(0.3), radius: 12, y: 6)
                    
                    Text("if_you_have_an_active_apple_music_subscription_on_this_device_reps_can_connect_t")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    Button {
                        requestAppleMusicPermission()
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("conectar_apple_music")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(PulseTheme.appleMusic)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Text("or_select_one_of_our_recommended_workout_playlists_below")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.tertiaryText)
                        .padding(.top, 8)
                }
            } else {
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.appleMusic)
                        Text("apple_music_conectado")
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
                Text(localizedString(isAppleMusicAuthorized ? "search_your_music_or_catalog" : "search_playlist"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                
                TextField("buscar_playlist", text: $searchText)
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
                        Text(localizedFormat("your_playlists_count_format", filteredLibrary.count))
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
                                        Text("local_library")
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
                                localizedString("loading_library"),
                                localizedString("sorting_playlists"),
                                localizedString("preparing_workout_music")
                            ],
                            progress: nil,
                            layout: .compact
                        )
                        .padding(.top, 4)
                    }
                }
                
                // 2. Catalog Search Results
                if !searchText.isEmpty {
                    Text("resultados_en_apple_music")
                        .font(.headline)
                        .padding(.horizontal, 2)
                        .padding(.top, 8)
                    
                    if searchedCatalogPlaylists.isEmpty, isSearchingCatalog {
                        RepsLoadingView(
                            messages: [
                                localizedString("searching_apple_music"),
                                localizedString("filtering_playlists"),
                                localizedString("preparing_results")
                            ],
                            progress: nil,
                            layout: .compact
                        )
                        .padding(.top, 4)
                    } else if searchedCatalogPlaylists.isEmpty {
                        Text("no_results_for_this_search")
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
                                            Text("apple_music")
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
                    Text("recommended_for_you")
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
    
}

// MARK: - Playlist Art Placeholder Component

struct PlaylistArtMock: View {
    let title: String
    let provider: PlanPlaylist.Provider

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PulseTheme.appleMusic, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "music.note")
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
