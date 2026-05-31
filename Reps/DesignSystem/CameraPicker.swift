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
    @ViewBuilder let label: () -> LabelContent

    @StateObject private var permissions = PermissionService.shared
    @State private var showCamera = false
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
                    Label("Tomar foto", systemImage: "camera.fill")
                }
            } else {
                #if targetEnvironment(simulator)
                Button {
                    if let image = UIImage(systemName: "figure.strengthtraining.traditional") {
                        onCameraCapture(image)
                        HapticService.notification(.success)
                    }
                } label: {
                    Label("Simular foto", systemImage: "camera.badge.ellipsis")
                }
                #endif
            }

            PhotosPicker(selection: $photoPickerItems, maxSelectionCount: maxSelectionCount, matching: .images) {
                Label("Elegir de galería", systemImage: "photo.on.rectangle")
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
        .alert("Permiso denegado", isPresented: $showPermissionDenied) {
            Button("Abrir Ajustes") {
                permissions.openSettings()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(permissions.deniedMessage ?? "El acceso a la cámara está bloqueado. Actívalo en Ajustes.")
        }
    }
}
