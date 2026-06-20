import AVFoundation
import SwiftUI
import PhotosUI
import UIKit

/// UIKit camera picker wrapped for SwiftUI.
/// Falls back gracefully when the camera is not available (simulator, denied).
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
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
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
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

            PhotosPicker(selection: $photoPickerItems, maxSelectionCount: maxSelectionCount, matching: .images) {
                Label("choose_from_gallery", systemImage: "photo.on.rectangle")
            }
        } label: {
            label()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                onCameraCapture(image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showVideoCamera) {
            VideoCameraPicker { data, thumbnail in
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
            Text(permissions.deniedMessage ?? "El acceso a la cámara está bloqueado. Actívalo en Ajustes.")
        }
    }
}

/// UIKit camera wrapped for SwiftUI to record a short video clip.
struct VideoCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data, UIImage?) -> Void

    static var isAvailable: Bool {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return false }
        return UIImagePickerController.availableMediaTypes(for: .camera)?.contains("public.movie") ?? false
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .video
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeMedium
        picker.videoMaximumDuration = 60
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data, UIImage?) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (Data, UIImage?) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL, let data = try? Data(contentsOf: url) {
                onCapture(data, VideoThumbnail.generate(from: url))
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
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
