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

struct SessionControlHeader: View {
    let title: String
    let systemImage: String
    let statusTitle: String
    let statusImage: String
    let statusColor: Color

    var body: some View {
        HStack {
            Label(localizedKey(title), systemImage: systemImage)
                .font(.headline)
            Spacer()
            Label(statusTitle, systemImage: statusImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(statusColor)
        }
    }
}


struct SessionMetricStrip: View {
    struct Metric: Identifiable {
        let title: String
        let value: String
        let icon: String

        var id: String { title }
    }

    let metrics: [Metric]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(metrics) { metric in
                MiniSessionPill(title: metric.title, value: metric.value, icon: metric.icon)
            }
        }
    }
}


struct PlannedDurationEditor: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 12) {
            Label("planned_duration", systemImage: "timer")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)

            Spacer(minLength: 8)

            Button {
                minutes = max(0, minutes - 5)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.black))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(PulseTheme.accent)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("reduce_duration")

            Text(minutes == 0 ? localizedString("sin_tiempo_definido") : "\(minutes) min")
                .font(.headline.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(minWidth: 96)

            Button {
                minutes = min(180, minutes + 5)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.black))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("increase_duration")
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}


struct SessionIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 48, height: 48)
                .foregroundStyle(PulseTheme.accent)
                .background(PulseTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
    }
}


struct SessionControlButton: View {
    let title: String
    let systemImage: String
    let foregroundStyle: Color
    let backgroundStyle: Color
    var height: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(localizedKey(title), systemImage: systemImage)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundStyle(foregroundStyle)
                .background(backgroundStyle)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
    }
}


struct MiniSessionPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(PulseTheme.accent)
                .layoutPriority(1)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(localizedKey(title))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
