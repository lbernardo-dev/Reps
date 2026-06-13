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
            TextField("Sensaciones del ejercicio", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            HStack(spacing: 10) {
                Button(action: onToggleAudio) {
                    Label(isRecording ? "Guardar audio" : "Grabar audio", systemImage: isRecording ? "stop.fill" : "mic.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .foregroundStyle(isRecording ? .white : PulseTheme.primary)
                        .background(isRecording ? Color.red : PulseTheme.primary.opacity(0.12))
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
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.12))
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
        PulseTheme.appleMusic
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PulseTheme.primary)
                    .frame(width: 32, height: PulseTheme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Anterior")

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                    .background(tint)
                    .clipShape(Circle())
                    .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pausar" : "Reproducir")

            Button(action: onForward) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PulseTheme.primary)
                    .frame(width: 32, height: PulseTheme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Siguiente")
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

private struct AttachmentPreview: View {
    let attachment: WorkoutMediaAttachment

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if attachment.kind == .image,
               let data = attachment.data,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                    Text("Audio")
                        .font(.caption.weight(.bold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(PulseTheme.primary)
                .background(PulseTheme.primary.opacity(0.10))
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
        }
        .frame(width: 96, height: 116)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}
