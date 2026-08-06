import SwiftUI

struct WhatsNewHighlight: Identifiable {
    let id = UUID()
    let systemImage: String
    let titleKey: String
    let descriptionKey: String
}

struct WhatsNewRelease: Identifiable {
    let id = UUID()
    let version: String
    let date: Date
    let isCurrent: Bool
    let highlights: [WhatsNewHighlight]
}

enum WhatsNewCatalog {
    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: .current, year: year, month: month, day: day).date ?? .now
    }

    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(
            version: "1.0.2",
            date: date(2026, 8, 6),
            isCurrent: true,
            highlights: [
                WhatsNewHighlight(systemImage: "globe", titleKey: "whatsnew_v102_h1_title", descriptionKey: "whatsnew_v102_h1_desc"),
                WhatsNewHighlight(systemImage: "sparkles", titleKey: "whatsnew_v102_h2_title", descriptionKey: "whatsnew_v102_h2_desc"),
                WhatsNewHighlight(systemImage: "figure.strengthtraining.traditional", titleKey: "whatsnew_v102_h3_title", descriptionKey: "whatsnew_v102_h3_desc"),
                WhatsNewHighlight(systemImage: "chart.bar.fill", titleKey: "whatsnew_v102_h4_title", descriptionKey: "whatsnew_v102_h4_desc")
            ]
        ),
        WhatsNewRelease(
            version: "1.0.1",
            date: date(2026, 7, 29),
            isCurrent: false,
            highlights: [
                WhatsNewHighlight(systemImage: "figure.walk.motion", titleKey: "whatsnew_v101_h1_title", descriptionKey: "whatsnew_v101_h1_desc"),
                WhatsNewHighlight(systemImage: "play.rectangle.fill", titleKey: "whatsnew_v101_h2_title", descriptionKey: "whatsnew_v101_h2_desc"),
                WhatsNewHighlight(systemImage: "widget.small", titleKey: "whatsnew_v101_h3_title", descriptionKey: "whatsnew_v101_h3_desc"),
                WhatsNewHighlight(systemImage: "drop.fill", titleKey: "whatsnew_v101_h4_title", descriptionKey: "whatsnew_v101_h4_desc"),
                WhatsNewHighlight(systemImage: "music.note", titleKey: "whatsnew_v101_h5_title", descriptionKey: "whatsnew_v101_h5_desc")
            ]
        ),
        WhatsNewRelease(
            version: "1.0.0",
            date: date(2026, 6, 5),
            isCurrent: false,
            highlights: [
                WhatsNewHighlight(systemImage: "figure.strengthtraining.traditional", titleKey: "whatsnew_v100_h1_title", descriptionKey: "whatsnew_v100_h1_desc"),
                WhatsNewHighlight(systemImage: "map.fill", titleKey: "whatsnew_v100_h2_title", descriptionKey: "whatsnew_v100_h2_desc"),
                WhatsNewHighlight(systemImage: "person.2.fill", titleKey: "whatsnew_v100_h3_title", descriptionKey: "whatsnew_v100_h3_desc"),
                WhatsNewHighlight(systemImage: "applewatch", titleKey: "whatsnew_v100_h4_title", descriptionKey: "whatsnew_v100_h4_desc"),
                WhatsNewHighlight(systemImage: "icloud.fill", titleKey: "whatsnew_v100_h5_title", descriptionKey: "whatsnew_v100_h5_desc")
            ]
        )
    ]
}

/// Interactive version timeline — a node per release, tap to expand its
/// highlights. Replaces the old static "what our app can do" list, which
/// never changed between versions.
struct WhatsNewTimelineView: View {
    let releases: [WhatsNewRelease]

    @State private var expandedID: WhatsNewRelease.ID?

    init(releases: [WhatsNewRelease] = WhatsNewCatalog.releases) {
        self.releases = releases
        _expandedID = State(initialValue: releases.first(where: \.isCurrent)?.id ?? releases.first?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localizedKey("whats_new_intro"))
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.bottom, 18)

            ForEach(Array(releases.enumerated()), id: \.element.id) { index, release in
                WhatsNewReleaseRow(
                    release: release,
                    isLast: index == releases.count - 1,
                    isExpanded: expandedID == release.id,
                    onToggle: {
                        HapticService.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            expandedID = expandedID == release.id ? nil : release.id
                        }
                    }
                )
            }
        }
    }
}

private struct WhatsNewReleaseRow: View {
    let release: WhatsNewRelease
    let isLast: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    private var dateText: String {
        release.date.formatted(.dateTime.month(.wide).year().locale(RepsLocalization.locale))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    if release.isCurrent {
                        Circle()
                            .stroke(PulseTheme.accent.opacity(0.35), lineWidth: 4)
                            .frame(width: 22, height: 22)
                    }
                    Circle()
                        .fill(release.isCurrent ? PulseTheme.accent : PulseTheme.grouped)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().stroke(PulseTheme.separator, lineWidth: release.isCurrent ? 0 : 1)
                        )
                }
                .padding(.top, 5)
                .frame(width: 22)

                if !isLast {
                    Rectangle()
                        .fill(PulseTheme.separator)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 22)

            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("v\(release.version)")
                            .font(.headline.weight(.black))
                            .foregroundStyle(PulseTheme.textPrimary)

                        if release.isCurrent {
                            Text(localizedKey("whats_new_current_badge").uppercased(with: RepsLocalization.locale))
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(PulseTheme.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(PulseTheme.accent)
                        }

                        Spacer(minLength: 8)

                        Text(dateText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PulseTheme.secondaryText.opacity(0.6))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(release.highlights) { highlight in
                                WhatsNewHighlightRow(highlight: highlight)
                            }
                        }
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                        .stroke(release.isCurrent ? PulseTheme.accent.opacity(0.3) : PulseTheme.separator, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
        }
    }
}

private struct WhatsNewHighlightRow: View {
    let highlight: WhatsNewHighlight

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: highlight.systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 24, height: 24)
                .background(PulseTheme.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedKey(highlight.titleKey))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(localizedKey(highlight.descriptionKey))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
