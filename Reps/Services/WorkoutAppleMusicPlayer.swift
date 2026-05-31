import Combine
import Foundation
import MusicKit

@MainActor
final class WorkoutAppleMusicPlayer: ObservableObject {
    static let shared = WorkoutAppleMusicPlayer()

    @Published var isPlaying = false
    @Published var message: String?

    @Published var currentSongTitle: String?
    @Published var currentSongArtist: String?
    @Published var currentSongArtwork: Artwork?

    @Published var isSpotifyPlaying = false
    @Published var spotifyTrackIndex = 0

    private var currentPlaylistID: PlanPlaylist.ID?
    private var cancellables = Set<AnyCancellable>()

    struct MockTrack {
        let title: String
        let artist: String
    }

    private let mockSpotifyTracks = [
        MockTrack(title: "Metamorphosis", artist: "INTERWORLD"),
        MockTrack(title: "Rapture", artist: "RVDY"),
        MockTrack(title: "Override", artist: "KSLV Noh"),
        MockTrack(title: "Vendetta", artist: "MUPP, Sadfriendd"),
        MockTrack(title: "Neon Blade", artist: "MoonDeity"),
        MockTrack(title: "Disaster", artist: "KSLV Noh"),
        MockTrack(title: "Close Eyes", artist: "DVRST")
    ]

    private init() {
        ApplicationMusicPlayer.shared.state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAppleMusicState()
            }
            .store(in: &cancellables)

        ApplicationMusicPlayer.shared.queue.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNowPlaying()
            }
            .store(in: &cancellables)

        updateAppleMusicState()
        updateNowPlaying()
    }

    func statusText(for playlist: PlanPlaylist) -> String {
        if playlist.provider == .spotify {
            return isSpotifyPlaying ? "Reproduciendo con Spotify (Interno)" : "Pausado (Spotify)"
        }

        if isPlaying(playlist) {
            return "Reproduciendo con Apple Music"
        }

        return message ?? "Apple Music listo"
    }

    func isPlaying(_ playlist: PlanPlaylist) -> Bool {
        playlist.provider == .appleMusic && currentPlaylistID == playlist.id && isPlaying
    }

    private func updateAppleMusicState() {
        isPlaying = (ApplicationMusicPlayer.shared.state.playbackStatus == .playing)
    }

    private func updateNowPlaying() {
        if let entry = ApplicationMusicPlayer.shared.queue.currentEntry,
           case .song(let song) = entry.item {
            currentSongTitle = song.title
            currentSongArtist = song.artistName
            currentSongArtwork = song.artwork
        } else {
            currentSongTitle = nil
            currentSongArtist = nil
            currentSongArtwork = nil
        }
    }

    func playOrPause(_ playlist: PlanPlaylist) async {
        if playlist.provider == .spotify {
            isSpotifyPlaying.toggle()
            if isSpotifyPlaying {
                currentSongTitle = mockSpotifyTracks[spotifyTrackIndex].title
                currentSongArtist = mockSpotifyTracks[spotifyTrackIndex].artist
            }
            return
        }

        if currentPlaylistID != playlist.id {
            await play(playlist)
        } else if isPlaying {
            ApplicationMusicPlayer.shared.pause()
            isPlaying = false
            message = "Pausado"
        } else {
            do {
                try await ApplicationMusicPlayer.shared.play()
                isPlaying = true
                message = "Reproduciendo con Apple Music"
            } catch {
                await play(playlist)
            }
        }
    }

    func skipForward(_ playlist: PlanPlaylist? = nil) async {
        if let playlist, playlist.provider == .spotify {
            spotifyTrackIndex = (spotifyTrackIndex + 1) % mockSpotifyTracks.count
            if isSpotifyPlaying {
                currentSongTitle = mockSpotifyTracks[spotifyTrackIndex].title
                currentSongArtist = mockSpotifyTracks[spotifyTrackIndex].artist
            }
            return
        }

        do {
            try await ApplicationMusicPlayer.shared.skipToNextEntry()
            updateNowPlaying()
        } catch {
            print("Error skipping forward: \(error)")
        }
    }

    func skipBackward(_ playlist: PlanPlaylist? = nil) async {
        if let playlist, playlist.provider == .spotify {
            spotifyTrackIndex = (spotifyTrackIndex - 1 + mockSpotifyTracks.count) % mockSpotifyTracks.count
            if isSpotifyPlaying {
                currentSongTitle = mockSpotifyTracks[spotifyTrackIndex].title
                currentSongArtist = mockSpotifyTracks[spotifyTrackIndex].artist
            }
            return
        }

        do {
            try await ApplicationMusicPlayer.shared.skipToPreviousEntry()
            updateNowPlaying()
        } catch {
            print("Error skipping backward: \(error)")
        }
    }

    func toggle(_ playlist: PlanPlaylist) async {
        await playOrPause(playlist)
    }

    private func play(_ playlist: PlanPlaylist) async {
        let authorization = await MusicAuthorization.request()
        guard authorization == .authorized else {
            message = "Autoriza Apple Music para reproducir aquí"
            return
        }

        do {
            try await verifySubscriptionIfAvailable(for: playlist)

            guard let musicPlaylist = try await resolvePlaylist(playlist) else {
                message = "No pude resolver la playlist"
                return
            }

            ApplicationMusicPlayer.shared.queue = [musicPlaylist]
            try await ApplicationMusicPlayer.shared.play()
            currentPlaylistID = playlist.id
            isPlaying = true
            message = "Reproduciendo con Apple Music"
            updateNowPlaying()
        } catch AppleMusicPlaybackError.subscriptionRequired {
            message = "Necesitas una suscripción activa de Apple Music"
        } catch {
            print("Apple Music playback failed: \(error)")
            message = "Apple Music no pudo iniciar esta playlist"
        }
    }

    private func verifySubscriptionIfAvailable(for playlist: PlanPlaylist) async throws {
        do {
            let subscription = try await MusicSubscription.current
            if !playlist.urlString.hasPrefix("library://"), !subscription.canPlayCatalogContent {
                throw AppleMusicPlaybackError.subscriptionRequired
            }
        } catch AppleMusicPlaybackError.subscriptionRequired {
            message = "Necesitas una suscripción activa de Apple Music"
            throw AppleMusicPlaybackError.subscriptionRequired
        } catch {
            print("Apple Music subscription check failed, continuing to playback attempt: \(error)")
        }
    }

    private func resolvePlaylist(_ playlist: PlanPlaylist) async throws -> Playlist? {
        if let candidateID = appleMusicPlaylistID(from: playlist.urlString) {
            if candidateID.hasPrefix("p.") {
                var request = MusicLibraryRequest<Playlist>()
                request.filter(matching: \.id, equalTo: MusicItemID(candidateID))
                let response = try await request.response()
                if let resolved = response.items.first {
                    return resolved
                }
            } else {
                let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: MusicItemID(candidateID))
                let response = try await request.response()
                if let resolved = response.items.first {
                    return resolved
                }
            }
        }

        var search = MusicCatalogSearchRequest(term: playlist.title, types: [Playlist.self])
        search.limit = 5
        let response = try await search.response()
        if let catalogPlaylist = response.playlists.first {
            return catalogPlaylist
        }

        var librarySearch = MusicLibrarySearchRequest(term: playlist.title, types: [Playlist.self])
        librarySearch.limit = 5
        let libraryResponse = try await librarySearch.response()
        return libraryResponse.playlists.first
    }

    private func appleMusicPlaylistID(from urlString: String) -> String? {
        if urlString.hasPrefix("library://playlist/") {
            return urlString.replacingOccurrences(of: "library://playlist/", with: "")
        }

        guard let url = URL(string: urlString) else {
            return nil
        }

        let pathCandidates = url.pathComponents.filter { $0.hasPrefix("pl.") || $0.hasPrefix("p.") }
        if let candidate = pathCandidates.last {
            return candidate
        }

        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "i" || $0.name == "id" })?
            .value
    }
}

private enum AppleMusicPlaybackError: Error {
    case subscriptionRequired
}
