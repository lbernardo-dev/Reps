import SwiftUI

/// BPM click track — structurally different from every other timer kind (continuous
/// ticking, no duration/rounds), so it gets its own tiny engine instead of reusing
/// `IntervalTimerEngine`.
struct MetronomeView: View {
    @State private var bpm: Int
    @State private var isRunning = false
    @State private var beatPulse = false
    @State private var timer: Timer?

    init() {
        _bpm = State(initialValue: TimerConfigStore.config(for: .metronome).bpm)
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            Circle()
                .fill(TimerKind.metronome.tint.opacity(beatPulse ? 0.35 : 0.12))
                .frame(width: 160, height: 160)
                .scaleEffect(beatPulse ? 1.0 : 0.92)
                .overlay(
                    Text("\(bpm)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                )
                .animation(.easeOut(duration: 0.12), value: beatPulse)

            Text("bpm")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)

            Stepper(value: $bpm, in: 30...240, step: 1) {
                EmptyView()
            }
            .labelsHidden()
            .onChange(of: bpm) { _, newValue in
                TimerConfigStore.save(TimerConfig(bpm: newValue), for: .metronome)
                if isRunning { scheduleTimer() }
            }

            Spacer(minLength: 0)

            Button {
                HapticService.impact()
                toggleRunning()
            } label: {
                Label(isRunning ? "stop" : "start", systemImage: isRunning ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.black)
                    .background(TimerKind.metronome.tint)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .screenBackground()
        .navigationTitle(TimerKind.metronome.title)
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
        .onDisappear { timer?.invalidate() }
    }

    private func toggleRunning() {
        isRunning.toggle()
        if isRunning {
            scheduleTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = 60.0 / Double(max(bpm, 1))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                fireBeat()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        fireBeat()
    }

    private func fireBeat() {
        TimerSoundCue.tick()
        HapticService.impact(.light)
        beatPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { beatPulse = false }
    }
}

#Preview {
    NavigationStack { MetronomeView() }
        .preferredColorScheme(.dark)
}
