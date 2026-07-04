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

struct SessionFeedbackPanel: View {
    @Binding var isExpanded: Bool
    let title: String
    let systemImage: String
    let notesPrompt: String
    let audioIdleTitle: String
    let audioRecordingTitle: String
    @Binding var sessionRPE: Double
    @Binding var energyBefore: Double
    @Binding var energyAfter: Double
    @Binding var notes: String
    @Binding var photoItems: [PhotosPickerItem]
    let attachments: [WorkoutMediaAttachment]
    let isRecordingAudio: Bool
    let onToggleAudio: () -> Void
    let onCameraCapture: (UIImage) -> Void
    let onVideoCapture: (Data, UIImage?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                HapticService.selection()
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Label(localizedKey(title), systemImage: systemImage)
                        .font(.headline)
                        .foregroundStyle(PulseTheme.accent)
                    
                    Spacer(minLength: 8)
                    
                    if !isExpanded {
                        HStack(spacing: 9) {
                            Image(systemName: "text.alignleft")
                            Image(systemName: "mic.fill")
                            Image(systemName: "camera.fill")
                            Image(systemName: "video.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    effortFields

                    TextField(notesPrompt, text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    HStack(spacing: 10) {
                        Button(action: onToggleAudio) {
                            Label(isRecordingAudio ? audioRecordingTitle : audioIdleTitle, systemImage: isRecordingAudio ? "stop.fill" : "mic.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(isRecordingAudio ? .white : PulseTheme.accent)
                                .background(isRecordingAudio ? PulseTheme.destructive : PulseTheme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }

                        MediaSourceMenu(
                            maxSelectionCount: 8,
                            photoPickerItems: $photoItems,
                            onCameraCapture: onCameraCapture,
                            onVideoCapture: onVideoCapture
                        ) {
                            let mediaCount = attachments.filter { $0.kind == .image || $0.kind == .video }.count
                            Label("\(mediaCount)", systemImage: "photo.badge.plus")
                                .font(.headline)
                                .frame(width: 72, height: 48)
                                .foregroundStyle(PulseTheme.accent)
                                .background(PulseTheme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                    }

                    if !attachments.isEmpty {
                        AttachmentPreviewStrip(attachments: attachments)
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private var effortFields: some View {
        VStack(spacing: 18) {
            HStack {
                Label("esfuerzo_rpe", systemImage: "flame.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                InlineStepper(
                    value: $sessionRPE,
                    range: 1...10,
                    step: 0.5,
                    formatter: { String(format: "%.1f", $0) }
                )
                .frame(width: 156)
            }

            Divider()

            HStack {
                Label("energy_before", systemImage: "battery.50")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                InlineStepper(
                    value: $energyBefore,
                    range: 1...5,
                    step: 1,
                    formatter: { "\(Int($0))/5" }
                )
                .frame(width: 156)
            }

            Divider()

            HStack {
                Label("energy_after", systemImage: "battery.100")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                InlineStepper(
                    value: $energyAfter,
                    range: 1...5,
                    step: 1,
                    formatter: { "\(Int($0))/5" }
                )
                .frame(width: 156)
            }
        }
        .padding(.vertical, 4)
    }
}


struct ExerciseBookmarkStrip: View {
    let bookmarks: [ExerciseMediaBookmark]
    @Binding var activeBookmark: ExerciseMediaBookmark?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("quick_bookmarks", systemImage: "bookmark.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            activeBookmark = bookmark
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: icon(for: bookmark.source))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.title)
                                        .font(.caption.weight(.bold))
                                        .lineLimit(1)
                                    if let timestamp = bookmark.timestampSeconds {
                                        Text("\(timestamp / 60):\(String(format: "%02d", timestamp % 60))")
                                            .font(.caption2.monospacedDigit())
                                    }
                                }
                            }
                            .foregroundStyle(PulseTheme.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 46)
                            .background(PulseTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func icon(for source: ExerciseMediaBookmark.Source) -> String {
        switch source {
        case .youtube, .youtubeShorts: "play.rectangle.fill"
        case .tiktok: "music.note.tv"
        case .instagram: "camera.fill"
        case .other: "link"
        }
    }
}

