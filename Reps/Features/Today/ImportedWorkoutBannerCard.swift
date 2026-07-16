import SwiftUI

/// Proactive, time-limited card shown on Today for the first 24 hours after a
/// HealthKit workout is auto-imported with no strength data. Distinct from
/// `ImportedWorkoutCompletionBanner` (`ImportedWorkoutCompletionView.swift`),
/// which stays on the session's own detail screen indefinitely — this one is
/// meant to be seen without the user having to go looking for it, and stops
/// appearing once `AppStore.recentlyImportedSessionsNeedingCompletion` ages it
/// out, even though the workout remains completable from history either way.
struct ImportedWorkoutBannerCard: View {
    let session: WorkoutSession

    private var tint: Color { PulseTheme.semanticWarning }

    private var importedTimeAgo: String? {
        guard let importedAt = session.importedAt, importedAt > .distantPast else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: importedAt, relativeTo: Date())
    }

    var body: some View {
        NavigationLink {
            ImportedWorkoutCompletionView(session: session)
        } label: {
            PulseCard(backgroundColor: tint.opacity(0.16)) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.18))
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(localizedString("imported_workout_banner_badge"))
                                .font(.caption2.weight(.black))
                                .tracking(1.0)
                                .textCase(.uppercase)
                                .foregroundStyle(tint)
                            if let importedTimeAgo {
                                Text(importedTimeAgo)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(PulseTheme.tertiaryText)
                            }
                        }

                        Text(localizedString("imported_workout_banner_title"))
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(PulseTheme.textPrimary)

                        Text(localizedString("imported_workout_banner_subtitle"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedString("imported_workout_banner_title"))
        .accessibilityValue(localizedString("imported_workout_banner_subtitle"))
    }
}
