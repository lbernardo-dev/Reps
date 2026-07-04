import SwiftUI

struct ActiveWorkoutPinnedHeader: View {
    let title: String
    let contentWidth: CGFloat
    let isSessionStarted: Bool
    let isPaused: Bool
    let canStartWorkout: Bool
    let isFinishingWorkout: Bool
    let onClose: () -> Void
    let onTogglePause: () -> Void
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                        .destructiveGlassCircle(.secondary)
                }
                .accessibilityLabel("return")

                Text(localizedKey(title))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSessionStarted {
                    Button(action: onTogglePause) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.body.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(isPaused ? PulseTheme.accent : PulseTheme.warning)
                            .navigationGlassCircle(.secondary, tint: isPaused ? PulseTheme.accent : PulseTheme.warning)
                    }
                    .accessibilityLabel(localizedString(isPaused ? "resume_workout" : "pause_workout"))
                }

                if isSessionStarted {
                    Button(action: onPrimaryAction) {
                        Text(localizedString(isFinishingWorkout ? "saving" : "finish"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 90, height: 44)
                            .background(PulseTheme.destructive)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isFinishingWorkout)
                } else {
                    Button(action: onPrimaryAction) {
                        Label(localizedString("start"), systemImage: "play.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .frame(width: 110, height: 44)
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!canStartWorkout)
                    .opacity(canStartWorkout ? 1 : 0.5)
                    .accessibilityLabel(localizedString("start_workout"))
                }
            }
            .frame(width: contentWidth)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PulseTheme.separator)
                    .frame(height: 1)
            }

            LinearGradient(
                colors: [PulseTheme.background.opacity(0.72), PulseTheme.background.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 14)
            .allowsHitTesting(false)
        }
    }
}

struct ActiveWorkoutProgressSummary: View {
    let completedSets: Int
    let totalSets: Int
    let setCompletion: Double
    let isSessionStarted: Bool
    let isPaused: Bool
    let startedAt: Date
    let basePausedSeconds: Int
    let lastPausedAt: Date?
    let fallbackElapsedSeconds: Int
    let totalVolume: Int
    let pausedSeconds: Int
    let nextLoggingTitle: String
    let onCompleteNext: () -> Void

    private var stateTitle: String {
        isSessionStarted ? (isPaused ? localizedString("session_paused_uppercase") : localizedString("session_active_uppercase")) : localizedString("session_ready_uppercase")
    }

    private var stateColor: Color {
        isSessionStarted ? (isPaused ? PulseTheme.warning : PulseTheme.accent) : PulseTheme.secondaryText
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(PulseTheme.grouped, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: setCompletion)
                        .stroke(PulseTheme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.snappy(duration: 0.35), value: setCompletion)
                    VStack(spacing: 0) {
                        Text("\(completedSets)")
                            .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(PulseTheme.accent)
                        Text("/\(totalSets)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stateTitle)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(stateColor)
                    WorkoutElapsedText(
                        startedAt: startedAt,
                        basePausedSeconds: basePausedSeconds,
                        lastPausedAt: lastPausedAt,
                        isPaused: isPaused,
                        fallbackElapsedSeconds: fallbackElapsedSeconds
                    )
                    HStack(spacing: 6) {
                        Text(localizedFormat("volume_kg_format", totalVolume))
                        if pausedSeconds > 0 {
                            Text(localizedFormat("pause_duration_prefix_format", timeString(pausedSeconds)))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PulseTheme.grouped)
                        .frame(height: 8)
                    Capsule()
                        .fill(PulseTheme.accent)
                        .frame(width: max(geo.size.width * setCompletion, setCompletion > 0 ? 16 : 0), height: 8)
                        .animation(.snappy(duration: 0.35), value: setCompletion)
                }
            }
            .frame(height: 8)

            Button(action: onCompleteNext) {
                HStack(spacing: 10) {
                    Image(systemName: completedSets == totalSets ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.title3.weight(.bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(completedSets == totalSets ? localizedString("completed_3") : localizedString("next_set"))
                            .font(.headline.weight(.bold))
                        if completedSets < totalSets {
                            Text(nextLoggingTitle)
                                .font(.caption.weight(.semibold))
                                .opacity(0.78)
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.black)
                .background(PulseTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                .shadow(color: PulseTheme.accent.opacity(0.22), radius: 8, x: 0, y: 4)
            }
            .disabled(!isSessionStarted || completedSets == totalSets)
            .opacity(!isSessionStarted || completedSets == totalSets ? 0.55 : 1)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct ActiveWorkoutCommandCard: View {
    let exerciseTitle: String
    let nextSetTitle: String
    let setTarget: String
    let suggestion: String?
    let history: String?
    let isSessionStarted: Bool
    let isPaused: Bool
    let isResting: Bool
    let restSeconds: Int
    let completedSets: Int
    let totalSets: Int
    let completion: Double
    let onDecreaseRest: () -> Void
    let onIncreaseRest: () -> Void
    let onSkipRest: () -> Void
    let onUndo: (() -> Void)?

    private var commandColor: Color {
        if isPaused { return PulseTheme.warning }
        if isResting { return PulseTheme.ringStand }
        return progressColor
    }

    private var progressColor: Color {
        let clamped = min(max(completion, 0), 1)
        if clamped < 0.5 {
            return Color(
                red: 0.90 + (0.95 - 0.90) * (clamped / 0.5),
                green: 0.20 + (0.55 - 0.20) * (clamped / 0.5),
                blue: 0.18
            )
        }
        let progress = (clamped - 0.5) / 0.5
        return Color(
            red: 0.95 + (0.22 - 0.95) * progress,
            green: 0.55 + (0.72 - 0.55) * progress,
            blue: 0.18 + (0.42 - 0.18) * progress
        )
    }

    var body: some View {
        PulseCard(contentPadding: 15) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ProgressRing(
                        progress: completion,
                        completedSets: completedSets,
                        totalSets: totalSets,
                        color: commandColor
                    )
                    .frame(width: 84, height: 84)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(localizedString("actual"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(commandColor)
                        Text(isResting ? localizedString("recover_for_next_set") : nextSetTitle)
                            .font(.title3.weight(.black))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(exerciseTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 0)
                }

                if isResting {
                    RestCommandStrip(
                        restSeconds: restSeconds,
                        color: commandColor,
                        onDecrease: onDecreaseRest,
                        onIncrease: onIncreaseRest,
                        onSkip: onSkipRest,
                        onUndo: onUndo
                    )
                } else {
                    HStack(spacing: 8) {
                        CommandSignal(title: "Target", value: setTarget, systemImage: "scope", color: PulseTheme.accent)
                        if let suggestion {
                            CommandSignal(title: localizedString("suggestion"), value: suggestion, systemImage: "sparkles", color: PulseTheme.accent)
                        } else if let history {
                            CommandSignal(title: localizedString("history_label"), value: history, systemImage: "clock.arrow.circlepath", color: PulseTheme.ringStand)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let completedSets: Int
    let totalSets: Int
    let color: Color

    private var gradient: AngularGradient {
        AngularGradient(
            colors: [PulseTheme.destructive, PulseTheme.warning, PulseTheme.growth],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(PulseTheme.grouped, lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy(duration: 0.35), value: progress)
            VStack(spacing: 0) {
                Text("\(completedSets)")
                    .font(.system(size: 21, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                Text("/\(totalSets)")
                    .font(.caption2.weight(.black).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizedFormat("sets_fraction_format", completedSets, totalSets))
    }
}

private struct CommandSignal: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text(value)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct RestCommandStrip: View {
    let restSeconds: Int
    let color: Color
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onSkip: () -> Void
    let onUndo: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onDecrease) {
                    Image(systemName: "minus")
                        .font(.headline.weight(.black))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(color)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("-15")

                VStack(spacing: 2) {
                    Text(timeString(restSeconds))
                        .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                    Text("Rest")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)

                Button(action: onIncrease) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.black))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(color)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("+15")
            }

            HStack(spacing: 10) {
                if let onUndo {
                    Button(action: onUndo) {
                        Label(localizedString("undo_set"), systemImage: "arrow.uturn.backward")
                            .font(.caption.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .background(PulseTheme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizedString("undo_the_last_completed_set"))
                }

                Button(action: onSkip) {
                    Label(localizedString("end_rest"), systemImage: "forward.fill")
                        .font(.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(.black)
                        .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("end_rest"))
            }
        }
        .padding(10)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct WorkoutElapsedText: View, Equatable {
    let startedAt: Date
    let basePausedSeconds: Int
    let lastPausedAt: Date?
    let isPaused: Bool
    let fallbackElapsedSeconds: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text(timeString(elapsedSeconds(at: timeline.date)))
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
        }
    }

    private func elapsedSeconds(at date: Date) -> Int {
        guard startedAt.timeIntervalSince1970 > 0 else {
            return fallbackElapsedSeconds
        }

        let effectiveDate = isPaused ? (lastPausedAt ?? date) : date
        return max(Int(effectiveDate.timeIntervalSince(startedAt)) - basePausedSeconds, 0)
    }

    private func timeString(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
