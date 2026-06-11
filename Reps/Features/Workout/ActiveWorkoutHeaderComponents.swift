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
                        .foregroundStyle(PulseTheme.secondaryText)
                        .background(PulseTheme.grouped)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Volver")

                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSessionStarted {
                    Button(action: onTogglePause) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.body.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(isPaused ? PulseTheme.primary : PulseTheme.warning)
                            .background(isPaused ? PulseTheme.primary.opacity(0.12) : PulseTheme.warning.opacity(0.15))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(
                                    isPaused ? PulseTheme.primary.opacity(0.3) : PulseTheme.warning.opacity(0.4),
                                    lineWidth: 1.5
                                )
                            )
                    }
                    .accessibilityLabel(isPaused ? "Reanudar entrenamiento" : "Pausar entrenamiento")
                }

                Button(action: onPrimaryAction) {
                    Text(isFinishingWorkout ? "Guardando" : (isSessionStarted ? "Finalizar" : "Iniciar"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 90, height: 44)
                        .background(isSessionStarted ? PulseTheme.destructive : (canStartWorkout ? PulseTheme.primary : PulseTheme.secondaryText))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isFinishingWorkout || (!isSessionStarted && !canStartWorkout))
                .accessibilityHint(!isSessionStarted && !canStartWorkout ? "Añade al menos un ejercicio o usa una sesión de cardio" : "")
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
        isSessionStarted ? (isPaused ? "SESIÓN PAUSADA" : "SESIÓN ACTIVA") : "SESIÓN PREPARADA"
    }

    private var stateColor: Color {
        isSessionStarted ? (isPaused ? PulseTheme.warning : PulseTheme.primary) : PulseTheme.secondaryText
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
                        Text("\(totalVolume) kg volumen")
                        if pausedSeconds > 0 {
                            Text("· pausa \(timeString(pausedSeconds))")
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
                        Text(completedSets == totalSets ? "Completado" : "Siguiente serie")
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
