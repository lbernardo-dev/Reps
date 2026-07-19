import SwiftUI

/// Plain count-up stopwatch — the one timer kind with no config and no upper bound,
/// so it doesn't fit the work/rest/rounds `IntervalTimerEngine`.
struct StopwatchView: View {
    @State private var startedAt: Date?
    @State private var isPaused = false
    @State private var pausedElapsed: TimeInterval = 0

    private var isRunning: Bool { startedAt != nil }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                Text(elapsedString(at: timeline.date))
                    .font(.system(size: 64, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                if isRunning {
                    controlButton(title: isPaused ? "resume" : "pause", systemImage: isPaused ? "play.fill" : "pause.fill", tint: isPaused ? PulseTheme.playControl : PulseTheme.pauseControl) {
                        togglePause()
                    }
                    controlButton(title: "reset", systemImage: "arrow.counterclockwise", tint: PulseTheme.grouped, foreground: .primary) {
                        reset()
                    }
                } else {
                    Button {
                        HapticService.impact()
                        startedAt = .now
                        isPaused = false
                        pausedElapsed = 0
                    } label: {
                        Label("start", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.playControl))
                            .background(PulseTheme.playControl)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .screenBackground()
        .navigationTitle(TimerKind.stopwatch.title)
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }

    private func elapsedString(at date: Date) -> String {
        let elapsed: TimeInterval
        if let startedAt {
            elapsed = isPaused ? pausedElapsed : date.timeIntervalSince(startedAt)
        } else {
            elapsed = 0
        }
        let total = Int(elapsed)
        let minutes = total / 60
        let seconds = total % 60
        let tenths = Int((elapsed - Double(total)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    private func togglePause() {
        guard let startedAt else { return }
        HapticService.selection()
        if isPaused {
            self.startedAt = Date.now.addingTimeInterval(-pausedElapsed)
            isPaused = false
        } else {
            pausedElapsed = Date.now.timeIntervalSince(startedAt)
            isPaused = true
        }
    }

    private func reset() {
        HapticService.selection()
        startedAt = nil
        isPaused = false
        pausedElapsed = 0
    }

    private func controlButton(
        title: String,
        systemImage: String,
        tint: Color,
        foreground: Color = .black,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(localizedKey(title), systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: PulseTheme.minTapTarget)
                .foregroundStyle(foreground)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { StopwatchView() }
        .preferredColorScheme(.dark)
}
