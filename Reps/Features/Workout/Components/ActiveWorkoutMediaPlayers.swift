import AVFoundation
import Combine
import CoreImage
import CoreMotion
import WebKit
import CoreLocation
import MapKit
import MediaPlayer
import MuscleMap
import MusicKit
import PhotosUI
import SwiftUI

struct YouTubeWebView: UIViewRepresentable {
    let videoID: String
    let startSeconds: Int
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let embedURLString = "https://www.youtube.com/embed/\(videoID)?autoplay=1&playsinline=1&start=\(startSeconds)&enablejsapi=1"
        if let url = URL(string: embedURLString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}


struct UniversalWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}


struct VideoPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bookmark: ExerciseMediaBookmark
    
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if let videoID = extractYouTubeVideoID(from: bookmark.urlString) {
                    YouTubeWebView(videoID: videoID, startSeconds: bookmark.timestampSeconds ?? 0)
                        .cornerRadius(12)
                        .aspectRatio(16/9, contentMode: .fit)
                        .padding()
                } else if let url = URL(string: bookmark.urlString) {
                    UniversalWebView(url: url)
                        .cornerRadius(12)
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("could_not_load_the_video")
                            .font(.headline)
                        Text("the_bookmark_url_is_invalid")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                if let duration = bookmark.playbackDurationSeconds, duration > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(duration - timeRemaining), total: Double(duration))
                            .tint(PulseTheme.accent)
                            .padding(.horizontal)
                        
                        Text(localizedFormat("closing_in_seconds_format", timeRemaining))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
            .navigationTitle(bookmark.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let duration = bookmark.playbackDurationSeconds, duration > 0 {
                    timeRemaining = duration
                    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        Task { @MainActor in
                            if timeRemaining > 1 {
                                timeRemaining -= 1
                            } else {
                                timer?.invalidate()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    private func extractYouTubeVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtu.be") {
            return url.pathComponents.dropFirst().first
        }
        
        if url.pathComponents.contains("shorts") {
            if let index = url.pathComponents.firstIndex(of: "shorts"), index + 1 < url.pathComponents.count {
                return url.pathComponents[index + 1]
            }
        }
        
        if url.pathComponents.contains("embed") {
            if let index = url.pathComponents.firstIndex(of: "embed"), index + 1 < url.pathComponents.count {
                return url.pathComponents[index + 1]
            }
        }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            if let videoID = queryItems.first(where: { $0.name == "v" })?.value {
                return videoID
            }
        }
        
        return nil
    }
}


@MainActor
final class WorkoutAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var elapsedSeconds: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startedAt: Date?
    private var timer: Timer?

    func startRecording() {
        // Permission is already checked by callers via PermissionService.
        beginRecording()
    }

    func stopRecording(note: String?) -> WorkoutMediaAttachment? {
        guard let recorder, let recordingURL else {
            return nil
        }

        recorder.stop()
        self.recorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil

        let data = try? Data(contentsOf: recordingURL)
        let duration = startedAt.map { Date().timeIntervalSince($0) }
        self.recordingURL = nil
        startedAt = nil
        elapsedSeconds = 0

        return WorkoutMediaAttachment(
            kind: .audio,
            data: data,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines),
            durationSeconds: duration
        )
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("reps-audio-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record()

            recordingURL = url
            self.recorder = recorder
            startedAt = .now
            isRecording = true
            elapsedSeconds = 0
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let startedAt = self.startedAt else { return }
                    self.elapsedSeconds = Date().timeIntervalSince(startedAt)
                }
            }
        } catch {
            isRecording = false
        }
    }
}

