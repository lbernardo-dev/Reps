import AVFoundation
import CoreLocation
import Photos
import SwiftUI
import UserNotifications

/// Centralised permission gate. Every feature that touches a protected resource
/// MUST call the matching `request*` method **before** using the API.
/// Results are cached per-session so repeated calls are cheap.
@MainActor
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    @Published var microphone: PermissionStatus = .notDetermined
    @Published var camera: PermissionStatus = .notDetermined
    @Published var notifications: PermissionStatus = .notDetermined
    @Published var location: PermissionStatus = .notDetermined
    @Published var photoLibrary: PermissionStatus = .notDetermined

    /// Human-readable message shown when a permission was denied.
    @Published var deniedMessage: String?

    enum PermissionStatus: Equatable {
        case notDetermined
        case granted
        case denied
    }

    // MARK: - Microphone

    func requestMicrophone() async -> Bool {
        let current = AVAudioApplication.shared.recordPermission
        if current == .granted {
            microphone = .granted
            return true
        }
        if current == .denied {
            microphone = .denied
            deniedMessage = localizedString("perm_mic_blocked")
            return false
        }

        let granted = await AVAudioApplication.requestRecordPermission()
        microphone = granted ? .granted : .denied
        if !granted {
            deniedMessage = localizedString("perm_mic_needed")
        }
        return granted
    }

    // MARK: - Camera

    func requestCamera() async -> Bool {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        if current == .authorized {
            camera = .granted
            return true
        }
        if current == .denied || current == .restricted {
            camera = .denied
            deniedMessage = localizedString("perm_camera_blocked")
            return false
        }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        camera = granted ? .granted : .denied
        if !granted {
            deniedMessage = localizedString("perm_camera_needed")
        }
        return granted
    }

    // MARK: - Notifications

    func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized {
            notifications = .granted
            return true
        }
        if settings.authorizationStatus == .denied {
            notifications = .denied
            deniedMessage = localizedString("perm_notifications_blocked")
            return false
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            notifications = granted ? .granted : .denied
            if !granted {
                deniedMessage = localizedString("perm_notifications_needed")
            }
            return granted
        } catch {
            notifications = .denied
            return false
        }
    }

    // MARK: - Photo Library (full access – for saving)

    func requestPhotoLibrary() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            photoLibrary = .granted
            return true
        }
        if current == .denied || current == .restricted {
            photoLibrary = .denied
            deniedMessage = localizedString("perm_photos_blocked")
            return false
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let granted = status == .authorized || status == .limited
        photoLibrary = granted ? .granted : .denied
        if !granted {
            deniedMessage = localizedString("perm_photos_needed")
        }
        return granted
    }

    // MARK: - Open Settings

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Refresh cached state

    func refreshAll() {
        microphone = mapAVPermission(AVAudioApplication.shared.recordPermission)
        camera = mapAVCapturePermission(AVCaptureDevice.authorizationStatus(for: .video))

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notifications = settings.authorizationStatus == .authorized ? .granted
                : settings.authorizationStatus == .denied ? .denied
                : .notDetermined
        }

        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoLibrary = (photoStatus == .authorized || photoStatus == .limited) ? .granted
            : photoStatus == .denied ? .denied
            : .notDetermined
    }

    private func mapAVPermission(_ p: AVAudioApplication.recordPermission) -> PermissionStatus {
        switch p {
        case .granted: .granted
        case .denied: .denied
        default: .notDetermined
        }
    }

    private func mapAVCapturePermission(_ s: AVAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized: .granted
        case .denied, .restricted: .denied
        default: .notDetermined
        }
    }
}
