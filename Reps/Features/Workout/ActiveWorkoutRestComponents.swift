import SwiftUI

/// Which rest countdown is currently running — the short recovery between
/// sets of the same exercise, or the longer window used to change machine /
/// position before the next exercise.
enum RestPhaseKind: Equatable {
    case betweenSets
    case exerciseChange
}

struct ActiveRestPanel: View {
    let isRestActive: Bool
    let currentRestSeconds: Int
    let restStartedAt: Date?
    let restDuration: Int
    let kind: RestPhaseKind
    let nextExerciseName: String?
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onSkipOrRestart: () -> Void
    var onUndo: (() -> Void)? = nil
    var onBackToPreviousExercise: (() -> Void)? = nil

    var body: some View {
        PulseCard(backgroundColor: kind == .exerciseChange ? PulseTheme.ringExercise.opacity(0.08) : PulseTheme.card) {
            if isRestActive {
                activeRestContent
            } else {
                inactiveRestContent
            }
        }
    }

    private var inactiveRestContent: some View {
        HStack(spacing: 14) {
            Image(systemName: "hourglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseTheme.tertiaryText)
                .frame(width: 44, height: 44)
                .background(PulseTheme.grouped)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("rest")
                    .font(.headline.weight(.bold))
                Text("complete_a_series_to_activate")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
        }
    }

    private var activeRestContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                RestCountdownRing(
                    restStartedAt: restStartedAt,
                    restDuration: restDuration,
                    fallbackRestSeconds: currentRestSeconds,
                    kind: kind
                )
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 10) {
                    Text(titleText)
                        .font(.headline.weight(.bold))
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        restAdjustmentButton(title: "-15s", action: onDecrease)
                            .accessibilityLabel("reduce_rest_by_15_seconds")
                        restAdjustmentButton(title: "+15s", action: onIncrease)
                            .accessibilityLabel("extend_rest_15_seconds")

                        Button(currentRestSeconds == 0 ? localizedString("restart") : localizedString("skip_rest"), action: onSkipOrRestart)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: PulseTheme.minTapTarget)
                            .foregroundStyle(PulseTheme.accent)
                            .background(PulseTheme.accent.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
                            .accessibilityLabel(localizedString(currentRestSeconds == 0 ? "restart_rest" : "skip_rest"))
                    }
                    .buttonStyle(.plain)
                }
            }

            if kind == .exerciseChange, let onBackToPreviousExercise {
                Button {
                    onBackToPreviousExercise()
                } label: {
                    Label("back_to_previous_exercise", systemImage: "arrow.uturn.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.ringExercise)
                        .frame(maxWidth: .infinity)
                        .frame(height: PulseTheme.minTapTarget)
                        .background(PulseTheme.ringExercise.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("back_to_previous_exercise")
            }

            if let onUndo {
                Button {
                    onUndo()
                } label: {
                    Label("undo_set", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: PulseTheme.minTapTarget)
                        .background(PulseTheme.grouped.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("undo_the_last_completed_set")
            }
        }
    }

    private var titleText: String {
        switch kind {
        case .betweenSets:
            return localizedString(currentRestSeconds == 0 ? "ready_to_continue" : "resting")
        case .exerciseChange:
            return localizedString(currentRestSeconds == 0 ? "ready_to_continue" : "changing_exercise")
        }
    }

    private var subtitleText: String {
        switch kind {
        case .betweenSets:
            return localizedString(currentRestSeconds == 0 ? "battery_stops_recharging_when_rest_is_skipped" : "completing_rest_reduces_next_set_fatigue")
        case .exerciseChange:
            if currentRestSeconds == 0 {
                return localizedString("battery_stops_recharging_when_rest_is_skipped")
            }
            if let nextExerciseName, !nextExerciseName.isEmpty {
                return localizedFormat("get_ready_next_exercise_format", nextExerciseName)
            }
            return localizedString("moving_to_next_exercise")
        }
    }

    private func restAdjustmentButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(localizedKey(title))
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: PulseTheme.minTapTarget)
                .foregroundStyle(PulseTheme.accent)
                .background(PulseTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
        }
    }
}

private struct RestCountdownRing: View, Equatable {
    let restStartedAt: Date?
    let restDuration: Int
    let fallbackRestSeconds: Int
    let kind: RestPhaseKind

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
            let remaining = preciseRemainingSeconds(at: timeline.date)
            let seconds = Int(remaining.rounded(.up))
            let fraction = restDuration > 0 ? max(0, min(1, remaining / Double(restDuration))) : 0
            let ringColor = color(forFraction: fraction)

            ZStack {
                Circle()
                    .stroke(PulseTheme.grouped, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(timeString(seconds))
                        .font(.system(size: 23, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(ringColor)
                        .animation(.none, value: seconds)
                    Text(seconds == 0 ? localizedString("ready") : localizedString(kind == .exerciseChange ? "next_up" : "rest"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private func preciseRemainingSeconds(at date: Date) -> Double {
        guard let restStartedAt else {
            return Double(fallbackRestSeconds)
        }
        return max(Double(restDuration) - date.timeIntervalSince(restStartedAt), 0)
    }

    /// Continuous three-stop gradient driven by the fraction of time
    /// remaining, instead of jumping between fixed thresholds, so the ring
    /// color shifts smoothly as the countdown runs out. The "plenty of time"
    /// hue differs per kind (cyan for between-sets, green for exercise
    /// change) so the two timers read as visually distinct at a glance.
    private func color(forFraction fraction: Double) -> Color {
        let warmStart = 0.5   // base hue → orange begins at 50% remaining
        let hotStart = 0.15   // orange → red begins at 15% remaining
        let baseColor = kind == .exerciseChange ? PulseTheme.ringExercise : PulseTheme.ringStand

        if fraction > warmStart {
            let t = 1 - ((fraction - warmStart) / (1 - warmStart))
            return blend(baseColor, PulseTheme.warning, t)
        } else if fraction > hotStart {
            let t = 1 - ((fraction - hotStart) / (warmStart - hotStart))
            return blend(PulseTheme.warning, PulseTheme.destructive, t)
        } else {
            return PulseTheme.destructive
        }
    }

    private func blend(_ from: Color, _ to: Color, _ amount: Double) -> Color {
        let amount = max(0, min(1, amount))
        let fromComponents = UIColor(from).rgbaComponents
        let toComponents = UIColor(to).rgbaComponents
        return Color(
            red: fromComponents.red + (toComponents.red - fromComponents.red) * amount,
            green: fromComponents.green + (toComponents.green - fromComponents.green) * amount,
            blue: fromComponents.blue + (toComponents.blue - fromComponents.blue) * amount,
            opacity: fromComponents.alpha + (toComponents.alpha - fromComponents.alpha) * amount
        )
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private extension UIColor {
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}
