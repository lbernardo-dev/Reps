import Foundation

/// Drives Timer/Tabata/EMOM/AMRAP/Boxing/Yoga — all of these are, mechanically, the same
/// "N rounds of work (+ optional rest)" state machine; only the default config differs.
/// Uses `Date` diffing (not a repeating `Timer`) so it stays accurate across app backgrounding,
/// matching the existing rest-timer pattern in `ActiveWorkoutRestComponents.swift`.
@Observable
final class IntervalTimerEngine {
    enum Phase: Equatable {
        case work
        case rest
        case done
    }

    let config: TimerConfig
    private(set) var currentRound: Int = 1
    private(set) var phase: Phase = .work
    private(set) var phaseStartedAt: Date?
    private(set) var isPaused = false
    private var pausedElapsed: TimeInterval = 0

    init(config: TimerConfig) {
        self.config = config
    }

    var phaseDuration: Int {
        switch phase {
        case .work: config.workSeconds
        case .rest: config.restSeconds
        case .done: 0
        }
    }

    var totalRounds: Int { config.rounds }

    func start(at date: Date = .now) {
        currentRound = 1
        phase = .work
        phaseStartedAt = date
        isPaused = false
        pausedElapsed = 0
    }

    func togglePause(at date: Date = .now) {
        guard phase != .done else { return }
        if isPaused {
            phaseStartedAt = date.addingTimeInterval(-pausedElapsed)
            isPaused = false
        } else {
            pausedElapsed = elapsed(at: date)
            isPaused = true
        }
    }

    func elapsed(at date: Date = .now) -> TimeInterval {
        guard let phaseStartedAt else { return 0 }
        if isPaused { return pausedElapsed }
        return date.timeIntervalSince(phaseStartedAt)
    }

    var remainingSeconds: Int {
        max(phaseDuration - Int(elapsed().rounded()), 0)
    }

    /// Call once per timeline tick. Returns the transition that just happened, if any,
    /// so the caller can fire a haptic/sound exactly once per transition.
    @discardableResult
    func tick(at date: Date = .now) -> Bool {
        guard phase != .done, !isPaused, phaseStartedAt != nil else { return false }
        guard phaseDuration - Int(elapsed(at: date).rounded()) <= 0 else { return false }
        advancePhase(at: date)
        return true
    }

    func skipPhase(at date: Date = .now) {
        guard phase != .done else { return }
        advancePhase(at: date)
    }

    func reset() {
        currentRound = 1
        phase = .work
        phaseStartedAt = nil
        isPaused = false
        pausedElapsed = 0
    }

    private func advancePhase(at date: Date) {
        switch phase {
        case .work:
            if config.restSeconds > 0 {
                phase = .rest
                phaseStartedAt = date
            } else {
                advanceRoundOrFinish(at: date)
            }
        case .rest:
            advanceRoundOrFinish(at: date)
        case .done:
            break
        }
    }

    private func advanceRoundOrFinish(at date: Date) {
        if currentRound >= config.rounds {
            phase = .done
            phaseStartedAt = nil
        } else {
            currentRound += 1
            phase = .work
            phaseStartedAt = date
        }
    }
}
