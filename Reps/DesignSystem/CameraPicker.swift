import AVFoundation
import AVKit
import SwiftUI
import PhotosUI
import UIKit

/// UIKit camera picker wrapped for SwiftUI.
/// Falls back gracefully when the camera is not available (simulator, denied).
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onCapture: (UIImage) -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, isPresented: $isPresented)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        var isPresented: Binding<Bool>

        init(onCapture: @escaping (UIImage) -> Void, isPresented: Binding<Bool>) {
            self.onCapture = onCapture
            self.isPresented = isPresented
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            isPresented.wrappedValue = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented.wrappedValue = false
        }
    }
}

/// A combined media source menu that offers both camera and gallery.
/// Use this instead of a bare PhotosPicker to give users the camera option.
struct MediaSourceMenu<LabelContent: View>: View {
    let maxSelectionCount: Int
    @Binding var photoPickerItems: [PhotosPickerItem]
    let onCameraCapture: (UIImage) -> Void
    /// When provided, a "Record video" option is added (video data + poster frame).
    var onVideoCapture: ((Data, UIImage?) -> Void)? = nil
    @ViewBuilder let label: () -> LabelContent

    @StateObject private var permissions = PermissionService.shared
    @State private var showCamera = false
    @State private var showVideoCamera = false
    @State private var showPermissionDenied = false
    @State private var showGalleryPicker = false

    var body: some View {
        Menu {
            if CameraPicker.isAvailable {
                Button {
                    Task {
                        let granted = await permissions.requestCamera()
                        if granted {
                            showCamera = true
                        } else {
                            showPermissionDenied = true
                        }
                    }
                } label: {
                    Label("take_photo", systemImage: "camera.fill")
                }

                if onVideoCapture != nil, VideoCameraPicker.isAvailable {
                    Button {
                        Task {
                            let granted = await permissions.requestCamera()
                            if granted {
                                showVideoCamera = true
                            } else {
                                showPermissionDenied = true
                            }
                        }
                    } label: {
                        Label("record_video", systemImage: "video.fill")
                    }
                }
            } else {
                #if targetEnvironment(simulator)
                Button {
                    if let image = UIImage(systemName: "figure.strengthtraining.traditional") {
                        onCameraCapture(image)
                        HapticService.notification(.success)
                    }
                } label: {
                    Label("simulate_photo", systemImage: "camera.badge.ellipsis")
                }
                if let onVideoCapture {
                    Button {
                        onVideoCapture(Data(), UIImage(systemName: "video.fill"))
                        HapticService.notification(.success)
                    } label: {
                        Label("simulate_video", systemImage: "video.badge.ellipsis")
                    }
                }
                #endif
            }

            Button {
                showGalleryPicker = true
            } label: {
                Label("choose_from_gallery", systemImage: "photo.on.rectangle")
            }
        } label: {
            label()
        }
        .photosPicker(isPresented: $showGalleryPicker, selection: $photoPickerItems, maxSelectionCount: maxSelectionCount, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { image in
                onCameraCapture(image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showVideoCamera) {
            VideoCameraPicker(isPresented: $showVideoCamera) { data, thumbnail in
                onVideoCapture?(data, thumbnail)
            }
            .ignoresSafeArea()
        }
        .alert("permission_denied", isPresented: $showPermissionDenied) {
            Button("abrir_ajustes") {
                permissions.openSettings()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text(permissions.deniedMessage ?? localizedString("camera_access_blocked_message"))
        }
    }
}

/// UIKit camera wrapped for SwiftUI to record a short video clip.
struct VideoCameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onCapture: (Data, UIImage?) -> Void

    static var isAvailable: Bool {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return false }
        return UIImagePickerController.availableMediaTypes(for: .camera)?.contains("public.movie") ?? false
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]   // must precede cameraCaptureMode
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeMedium
        picker.videoMaximumDuration = 60
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, isPresented: $isPresented)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data, UIImage?) -> Void
        var isPresented: Binding<Bool>

        init(onCapture: @escaping (Data, UIImage?) -> Void, isPresented: Binding<Bool>) {
            self.onCapture = onCapture
            self.isPresented = isPresented
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL, let data = try? Data(contentsOf: url) {
                let onCapture = onCapture
                Task {
                    let thumbnail = await VideoThumbnail.generate(from: url)
                    onCapture(data, thumbnail)
                }
            }
            isPresented.wrappedValue = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented.wrappedValue = false
        }
    }
}

enum VideoThumbnail {
    static func generate(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                continuation.resume(returning: cgImage.map(UIImage.init(cgImage:)))
            }
        }
    }
}

/// Menu offering to attach a locally-sourced photo or video (camera capture or gallery
/// import) as an exercise's own visual guide. Reused by the custom exercise creation
/// form and the exercise detail "personalization" cards so both flows behave the same way.
struct ExerciseMediaPickerMenu<LabelContent: View>: View {
    var hasCustomImage: Bool
    var hasCustomVideo: Bool
    let onImageCaptured: (Data) -> Void
    let onVideoCaptured: (Data, Data?) -> Void
    let onDeleteImage: () -> Void
    let onDeleteVideo: () -> Void
    @ViewBuilder let label: () -> LabelContent

    @State private var showCamera = false
    @State private var showVideoCamera = false
    @State private var showPermissionDenied = false
    @State private var galleryImageItem: PhotosPickerItem?
    @State private var galleryVideoItem: PhotosPickerItem?

    var body: some View {
        Menu {
            if CameraPicker.isAvailable {
                Button {
                    Task {
                        let granted = await PermissionService.shared.requestCamera()
                        if granted {
                            showCamera = true
                        } else {
                            showPermissionDenied = true
                        }
                    }
                } label: {
                    Label("take_photo", systemImage: "camera.fill")
                }

                if VideoCameraPicker.isAvailable {
                    Button {
                        Task {
                            let granted = await PermissionService.shared.requestCamera()
                            if granted {
                                showVideoCamera = true
                            } else {
                                showPermissionDenied = true
                            }
                        }
                    } label: {
                        Label("record_video", systemImage: "video.fill")
                    }
                }
            } else {
                #if targetEnvironment(simulator)
                Button {
                    if let image = UIImage(systemName: "figure.strengthtraining.traditional"),
                       let data = image.jpegData(compressionQuality: 0.8) {
                        onImageCaptured(data)
                        HapticService.notification(.success)
                    }
                } label: {
                    Label("simulate_photo", systemImage: "camera.badge.ellipsis")
                }
                Button {
                    onVideoCaptured(Data([0]), nil)
                    HapticService.notification(.success)
                } label: {
                    Label("simulate_video", systemImage: "video.badge.ellipsis")
                }
                #endif
            }

            PhotosPicker(selection: $galleryImageItem, matching: .images) {
                Label("choose_from_gallery", systemImage: "photo.on.rectangle")
            }

            PhotosPicker(selection: $galleryVideoItem, matching: .videos) {
                Label("choose_video_from_gallery", systemImage: "video.badge.plus")
            }

            if hasCustomImage {
                Button(role: .destructive, action: onDeleteImage) {
                    Label("delete_custom_photo", systemImage: "trash")
                }
            }

            if hasCustomVideo {
                Button(role: .destructive, action: onDeleteVideo) {
                    Label("delete_custom_video", systemImage: "trash")
                }
            }
        } label: {
            label()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    onImageCaptured(data)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showVideoCamera) {
            VideoCameraPicker(isPresented: $showVideoCamera) { data, thumbnail in
                onVideoCaptured(data, thumbnail?.jpegData(compressionQuality: 0.7))
            }
            .ignoresSafeArea()
        }
        .onChange(of: galleryImageItem) { _, item in
            Task {
                defer { galleryImageItem = nil }
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      UIImage(data: data) != nil else { return }
                onImageCaptured(data)
            }
        }
        .onChange(of: galleryVideoItem) { _, item in
            Task {
                defer { galleryVideoItem = nil }
                guard let data = try? await item?.loadTransferable(type: Data.self), !data.isEmpty else { return }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("reps-gallery-video-\(UUID().uuidString).mov")
                do {
                    try data.write(to: tempURL)
                } catch {
                    return
                }
                let thumbnail = await VideoThumbnail.generate(from: tempURL)
                try? FileManager.default.removeItem(at: tempURL)
                onVideoCaptured(data, thumbnail?.jpegData(compressionQuality: 0.7))
            }
        }
        .alert("permission_denied", isPresented: $showPermissionDenied) {
            Button("abrir_ajustes") {
                PermissionService.shared.openSettings()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text(PermissionService.shared.deniedMessage ?? localizedString("camera_access_blocked_message"))
        }
    }
}

/// Full-screen playback for a locally-stored exercise guide video (`Exercise.customVideoData`).
/// Writes the in-memory data to a temp file since `AVPlayer` needs a URL, and cleans it up on dismiss.
struct ExerciseGuideVideoPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let videoData: Data
    let title: String

    @State private var player: AVPlayer?
    @State private var tempURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.black)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") { dismiss() }
                }
            }
        }
        .task {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("reps-guide-video-\(UUID().uuidString).mov")
            do {
                try videoData.write(to: url)
                tempURL = url
                player = AVPlayer(url: url)
            } catch {
                tempURL = nil
            }
        }
        .onDisappear {
            player?.pause()
            if let tempURL {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }
}
