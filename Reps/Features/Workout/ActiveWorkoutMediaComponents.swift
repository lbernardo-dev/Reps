import PhotosUI
import SwiftUI
import UIKit

struct ExerciseMediaNotesPanel: View {
    @Binding var notes: String
    let isRecording: Bool
    let elapsedSeconds: Int
    @Binding var photoPickerItems: [PhotosPickerItem]
    let attachments: [WorkoutMediaAttachment]
    let onToggleAudio: () -> Void
    let onCameraCapture: (UIImage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("feelings_of_exercise", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            HStack(spacing: 10) {
                Button(action: onToggleAudio) {
                    Label(localizedString(isRecording ? "save_audio_note" : "record_audio_note"), systemImage: isRecording ? "stop.fill" : "mic.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .foregroundStyle(isRecording ? .white : PulseTheme.accent)
                        .background(isRecording ? Color.red : PulseTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                if isRecording {
                    Text(timeString(elapsedSeconds))
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 72, height: 46)
                        .background(Color.red.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                MediaSourceMenu(
                    maxSelectionCount: 6,
                    photoPickerItems: $photoPickerItems,
                    onCameraCapture: onCameraCapture
                ) {
                    Image(systemName: "camera.fill")
                        .font(.headline)
                        .frame(width: 46, height: 46)
                        .foregroundStyle(PulseTheme.accent)
                        .background(PulseTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }

            if !attachments.isEmpty {
                AttachmentPreviewStrip(attachments: attachments)
            }
        }
        .padding(.top, 10)
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct MusicTransportControls: View {
    let provider: PlanPlaylist.Provider
    let isPlaying: Bool
    let onBack: () -> Void
    let onPlayPause: () -> Void
    let onForward: () -> Void

    private var tint: Color {
        isPlaying ? PulseTheme.pauseControl : PulseTheme.playControl
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: 32, height: PulseTheme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("anterior")

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(PulseTheme.onColor(tint))
                    .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                    .background(tint)
                    .clipShape(Circle())
                    .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizedString(isPlaying ? "pause_media" : "play_media"))

            Button(action: onForward) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: 32, height: PulseTheme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("next")
        }
    }
}

struct AttachmentPreviewStrip: View {
    let attachments: [WorkoutMediaAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    AttachmentPreview(attachment: attachment)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct ShareableAttachment: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct AttachmentPreview: View {
    let attachment: WorkoutMediaAttachment
    @State private var shareable: ShareableAttachment?

    var body: some View {
        Button {
            prepareShare()
        } label: {
            preview
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(localizedString("share"))
        .sheet(item: $shareable) { item in
            ActivityViewController(activityItems: item.items)
        }
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            switch attachment.kind {
            case .image:
                if let data = attachment.data, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    iconPlaceholder("photo", label: nil)
                }
            case .video:
                if let data = attachment.thumbnailData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    iconPlaceholder("video.fill", label: "video")
                }
            case .audio:
                iconPlaceholder("mic.fill", label: "audio")
            }

            if attachment.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let note = attachment.note, !note.isEmpty {
                Text(note)
                    .font(.caption2.weight(.bold))
                    .lineLimit(2)
                    .padding(6)
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(6)
            }

            // Per-attachment share affordance.
            Image(systemName: "square.and.arrow.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(5)
                .background(.black.opacity(0.45), in: Circle())
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: 96, height: 116)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }

    private func iconPlaceholder(_ systemImage: String, label: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.title2)
            if let label {
                Text(localizedString(label)).font(.caption.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(PulseTheme.accent)
        .background(PulseTheme.accent.opacity(0.10))
    }

    private var accessibilityLabel: String {
        switch attachment.kind {
        case .image: return localizedString("image_label")
        case .video: return localizedString("video")
        case .audio: return localizedString("audio")
        }
    }

    private func prepareShare() {
        HapticService.selection()
        var items: [Any] = []
        switch attachment.kind {
        case .image:
            if let data = attachment.data, let image = UIImage(data: data) {
                items.append(image)
            }
        case .video, .audio:
            if let url = writeTempFile() {
                items.append(url)
            }
        }
        if let note = attachment.note, !note.isEmpty {
            items.append(note)
        }
        guard !items.isEmpty else { return }
        shareable = ShareableAttachment(items: items)
    }

    private func writeTempFile() -> URL? {
        guard let data = attachment.data, !data.isEmpty else { return nil }
        let ext = attachment.kind == .video ? "mov" : "m4a"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reps-\(attachment.id.uuidString).\(ext)")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
