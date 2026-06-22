import AVFoundation
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
                onCapture(data, VideoThumbnail.generate(from: url))
            }
            isPresented.wrappedValue = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented.wrappedValue = false
        }
    }
}

enum VideoThumbnail {
    static func generate(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
