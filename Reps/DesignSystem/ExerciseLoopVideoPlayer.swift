import AVFoundation
import AVKit
import MuscleMap
import SwiftUI

// MARK: - Video Poster Thumbnail (lista segura, sin AVPlayerLayer)

/// Extrae el primer fotograma del vídeo como imagen estática.
/// No crea ningún AVPlayerLayer activo → seguro para listas con N elementos.
struct VideoPosterThumbnail<Fallback: View>: View {
    let videoURL: URL
    @ViewBuilder let fallbackContent: () -> Fallback

    @State private var poster: UIImage?
    @State private var tried = false

    var body: some View {
        ZStack {
            if let poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
                // Insignia de vídeo
                Color.black.opacity(0.18)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white, .black.opacity(0.45))
                            .padding(8)
                    }
                }
            } else {
                fallbackContent()
                    .overlay {
                        if !tried {
                            // extrayendo
                        }
                    }
            }
        }
        .task(id: videoURL) {
            await extractPoster()
        }
        .animation(.easeIn(duration: 0.15), value: poster != nil)
    }

    private func extractPoster() async {
        let cacheKey = videoURL as NSURL
        if let cached = VideoPosterCache.shared.image(for: cacheKey) {
            poster = cached
            tried = true
            return
        }
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        do {
            let cgImage = try await generator.image(at: .zero).image
            let image = UIImage(cgImage: cgImage)
            VideoPosterCache.shared.set(image, for: cacheKey)
            poster = image
        } catch {
            // no hay imagen disponible – mostrará el fallback
        }
        tried = true
    }
}

@MainActor
private final class VideoPosterCache {
    static let shared = VideoPosterCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: NSURL) -> UIImage? {
        cache.object(forKey: url)
    }

    func set(_ image: UIImage, for url: NSURL) {
        cache.setObject(image, forKey: url)
    }
}


/// Componente ligero para reproducir demostraciones de ejercicios
/// en bucle silencioso (.ambient) sin detener la música/audio en segundo plano del usuario.
struct ExerciseLoopVideoPlayer: View {
    let videoURL: URL?
    var posterURL: URL? = nil
    var autoPlay: Bool = true
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if let player {
                VideoPlayerContainerView(player: player, videoGravity: videoGravity)
                    .onAppear {
                        if autoPlay {
                            player.play()
                            isPlaying = true
                        }
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                Rectangle()
                    .fill(PulseTheme.grouped)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(PulseTheme.tertiaryText)
                            Text("Sin vídeo de demostración")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.tertiaryText)
                        }
                    }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanUpPlayer()
        }
        .onChange(of: videoURL) { _, _ in
            cleanUpPlayer()
            setupPlayer()
        }
    }

    private func setupPlayer() {
        guard let videoURL else { return }

        // Configurar la sesión de audio como ambient para que el audio del vídeo
        // NO detenga la música que el usuario esté escuchando (Spotify / Apple Music)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)

        let item = AVPlayerItem(url: videoURL)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = true
        
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer

        if autoPlay {
            queuePlayer.play()
            isPlaying = true
        }
    }

    private func cleanUpPlayer() {
        player?.pause()
        looper = nil
        player = nil
        isPlaying = false
    }
}

/// Modal de vídeo a pantalla completa con controles elegantes
struct FullscreenExerciseVideoView: View {
    let videoURL: URL
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FullscreenExerciseMediaView(
            title: title,
            videoURL: videoURL
        )
    }
}

struct FullscreenExerciseMediaView: View {
    let title: String
    var videoURL: URL? = nil
    var videoData: Data? = nil
    var image: UIImage? = nil
    var imageURL: URL? = nil
    var exercise: Exercise? = nil
    var gender: BodyGender = .male
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let videoURL {
                ExerciseLoopVideoPlayer(videoURL: videoURL, videoGravity: .resizeAspect)
                    .ignoresSafeArea()
            } else if let videoData {
                ExerciseGuideVideoPlayerSheet(videoData: videoData, title: title)
                    .ignoresSafeArea()
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFit()
                    case .failure, .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
                .ignoresSafeArea()
            } else if let exercise {
                GeometryReader { proxy in
                    ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: max(proxy.size.width, proxy.size.height) * 0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea()
            }

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(videoURL != nil || videoData != nil ? "DEMOSTRACIÓN TÉCNICA HD" : "REFERENCIA VISUAL HD")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9), .white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()
            }
        }
        .statusBarHidden()
    }
}

/// Representable de UIKit para AVPlayerLayer sin controles visibles
private struct VideoPlayerContainerView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView(player: player, videoGravity: videoGravity)
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

private final class PlayerUIView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    init(player: AVPlayer, videoGravity: AVLayerVideoGravity) {
        super.init(frame: .zero)
        self.player = player
        playerLayer.videoGravity = videoGravity
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
