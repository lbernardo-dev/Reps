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
    @State private var searchedLibraryPlaylists: [Playlist] = []
    @State private var searchedCatalogPlaylists: [Playlist] = []
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Group {
                if !isAppleMusicAuthorized {
                    unauthorizedView
                } else {
                    authorizedView
                }
            }
            .screenBackground()
            .navigationTitle(localizedString("connect_music"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedString("close")) { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
            .presentationDetents(isAppleMusicAuthorized ? [.large] : [.height(390)])
            .presentationDragIndicator(isAppleMusicAuthorized ? .visible : .hidden)
            .onAppear {
                checkAppleMusicAuthorization()
            }
            .onChange(of: searchText) { _, newValue in
                searchPlaylists(query: newValue)
            }
        }
    }

    // MARK: - Views
    
    private var unauthorizedView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Apple Music branding card
                    LinearGradient(
                        colors: [PulseTheme.appleMusic, PulseTheme.semanticEffort, PulseTheme.semanticWarning],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "music.note.house.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(PulseTheme.mediaText)
                            Text(localizedString("apple_music_integrado"))
                                .font(.headline.bold())
                                .foregroundStyle(PulseTheme.mediaText)
                            Text(localizedString("sync_and_search_your_system_playlists"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.mediaSubtext)
                        }
                    )
                    .shadow(color: PulseTheme.surfaceShadow, radius: 6, y: 2)
                    
                    Text(localizedString("if_you_have_an_active_apple_music_subscription_on_this_device_reps_can_connect_t"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 12)
            }

            Spacer(minLength: 0)

            // Fixed Footer Button
            VStack(spacing: 0) {
                Button {
                    requestAppleMusicPermission()
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text(localizedString("conectar_apple_music"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.appleMusic))
                    .background(PulseTheme.appleMusic)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
    }

    private var authorizedView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PulseTheme.appleMusic)
                    Text(localizedString("apple_music_conectado"))
                        .font(.headline)
                    Spacer()
                }
                .padding(14)
                .background(PulseTheme.appleMusic.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Search Input (only shown when real account connected)
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString("search_your_music_or_catalog"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)

                    TextField(localizedString("buscar_playlist"), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }

                // List Playlists (Library & Catalog search)
                VStack(alignment: .leading, spacing: 14) {
                    let filteredLibrary = searchText.isEmpty ? appleMusicPlaylists : searchedLibraryPlaylists

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
                                    notes: localizedString("playlist_from_library")
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
                                        Text(localizedString("local_library"))
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

                    // Catalog Search Results
                    if !searchText.isEmpty {
                        Text(localizedString("resultados_en_apple_music"))
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
                            Text(localizedString("no_results_for_this_search"))
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
                    }
                }
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
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
                var request = MusicLibraryRequest<Playlist>()
                request.limit = 100
                let response = try await request.response()

                // Page through the full library so the user can browse every
                // playlist they own, not just the first batch.
                var collection = response.items
                var all = Array(collection)
                while collection.hasNextBatch, let next = try await collection.nextBatch() {
                    all.append(contentsOf: next)
                    collection = next
                }

                await MainActor.run {
                    self.appleMusicPlaylists = all
                    self.isLoadingAppleMusicLibrary = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingAppleMusicLibrary = false
                }
                #if DEBUG
                print("Error loading library playlists: \(error)")
                #endif
            }
        }
    }
    
    private func searchPlaylists(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchedLibraryPlaylists = []
            searchedCatalogPlaylists = []
            isSearchingCatalog = false
            return
        }

        isSearchingCatalog = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            // Search the user's own library (only when connected) so they can
            // find any playlist in their music, not just the first loaded batch.
            if isAppleMusicAuthorized {
                do {
                    var libraryRequest = MusicLibrarySearchRequest(term: trimmed, types: [Playlist.self])
                    libraryRequest.limit = 15
                    let libraryResponse = try await libraryRequest.response()

                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        self.searchedLibraryPlaylists = Array(libraryResponse.playlists)
                    }
                } catch {
                    #if DEBUG
                    print("Error searching library playlists: \(error)")
                    #endif
                }
            }

            guard !Task.isCancelled else { return }

            // Also search the Apple Music catalog for discovery.
            do {
                var searchRequest = MusicCatalogSearchRequest(term: trimmed, types: [Playlist.self])
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
                #if DEBUG
                print("Error searching catalog playlists: \(error)")
                #endif
            }
        }
    }
    
}

// MARK: - Playlist Art Placeholder Component

struct PlaylistArtMock: View {
    let title: String
    let provider: PlanPlaylist.Provider

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PulseTheme.appleMusic, PulseTheme.semanticEffort],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "music.note")
                .font(.title3.weight(.black))
                .foregroundStyle(PulseTheme.mediaText)
        }
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
    }
}
