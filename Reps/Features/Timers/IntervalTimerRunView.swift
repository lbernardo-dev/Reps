import SwiftUI

/// Configure-then-run screen shared by Timer, Tabata, EMOM, AMRAP, Boxing/MMA and Yoga —
/// they're all the same work/rest/rounds engine (`IntervalTimerEngine`) with different defaults.
struct IntervalTimerRunView: View {
    let kind: TimerKind

    @State private var config: TimerConfig
    @State private var engine: IntervalTimerEngine?
    @State private var lastTransitionPhase: IntervalTimerEngine.Phase?

    init(kind: TimerKind) {
        self.kind = kind
        _config = State(initialValue: TimerConfigStore.config(for: kind))
    }

    var body: some View {
        VStack(spacing: 24) {
            if let engine {
                runningContent(engine: engine)
            } else {
                configContent
            }
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 20)
        .screenBackground()
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }

    // MARK: - Configuration (pre-start)

    @ViewBuilder
    private var configContent: some View {
        PulseCard {
            VStack(spacing: 18) {
                if kind.isSingleDuration {
                    DurationStepperRow(title: "duration", seconds: $config.workSeconds, step: 15, range: 15...3600)
                } else {
                    DurationStepperRow(title: "work", seconds: $config.workSeconds, step: 5, range: 5...900)
                    if kind != .emom {
                        DurationStepperRow(title: "rest", seconds: $config.restSeconds, step: 5, range: 0...600)
                    }
                    RoundsStepperRow(title: kind == .emom ? "minutes" : "rounds", value: $config.rounds, range: 1...60)
                }
            }
        }

        Spacer(minLength: 0)

        Button {
            HapticService.impact()
            TimerConfigStore.save(config, for: kind)
            let newEngine = IntervalTimerEngine(config: config)
            newEngine.start()
            engine = newEngine
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
        .padding(.bottom, 24)
    }

    // MARK: - Running

    @ViewBuilder
    private func runningContent(engine: IntervalTimerEngine) -> some View {
        if engine.phase == .done {
            completionContent(engine: engine)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(spacing: 28) {
                    if engine.totalRounds > 1 {
                        Text(localizedFormat("round_x_of_y_format", engine.currentRound, engine.totalRounds))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Text(phaseLabel(engine.phase))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(engine.phase == .rest ? PulseTheme.ringStand : kind.tint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background((engine.phase == .rest ? PulseTheme.ringStand : kind.tint).opacity(0.14))
                        .clipShape(Capsule())

                    Text(TimerConfig.clockString(engine.remainingSeconds))
                        .font(.system(size: 72, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: engine.remainingSeconds)

                    Spacer(minLength: 0)

                    HStack(spacing: 14) {
                        controlButton(title: engine.isPaused ? "resume" : "pause", systemImage: engine.isPaused ? "play.fill" : "pause.fill") {
                            engine.togglePause()
                        }
                        controlButton(title: "skip", systemImage: "forward.end.fill") {
                            HapticService.selection()
                            engine.skipPhase()
                        }
                    }
                    .padding(.bottom, 24)
                }
                .onChange(of: timeline.date) { _, newDate in
                    if engine.tick(at: newDate) {
                        if engine.phase == .done {
                            TimerSoundCue.finish()
                            HapticService.notification(.success)
                        } else {
                            TimerSoundCue.phaseChange()
                            HapticService.notification(.warning)
                        }
                    }
                }
            }
        }
    }

    private func completionContent(engine: IntervalTimerEngine) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(PulseTheme.growth)
            Text("timer_complete")
                .font(.title2.weight(.bold))
            Spacer(minLength: 0)

            Button {
                HapticService.impact()
                let fresh = IntervalTimerEngine(config: config)
                fresh.start()
                self.engine = fresh
            } label: {
                Label("restart", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.playControl))
                    .background(PulseTheme.playControl)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                HapticService.selection()
                self.engine = nil
            } label: {
                Text("done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.primary)
                    .background(PulseTheme.grouped)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func controlButton(title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        let tint = systemImage == "play.fill" ? PulseTheme.playControl : (systemImage == "pause.fill" ? PulseTheme.pauseControl : PulseTheme.grouped)
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: PulseTheme.minTapTarget)
                .foregroundStyle(systemImage == "play.fill" || systemImage == "pause.fill" ? PulseTheme.onColor(tint) : .primary)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func phaseLabel(_ phase: IntervalTimerEngine.Phase) -> LocalizedStringKey {
        switch phase {
        case .work: kind.isSingleDuration ? "go" : "work"
        case .rest: "rest"
        case .done: "timer_complete"
        }
    }
}

private struct DurationStepperRow: View {
    let title: LocalizedStringKey
    @Binding var seconds: Int
    let step: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Stepper(value: $seconds, in: range, step: step) {
                Text(TimerConfig.clockString(seconds))
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .fixedSize()
        }
    }
}

private struct RoundsStepperRow: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value)")
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .fixedSize()
        }
    }
}

#Preview {
    NavigationStack { IntervalTimerRunView(kind: .tabata) }
        .preferredColorScheme(.dark)
}
