import AudioToolbox
import SwiftUI

/// The 8 standalone timer types available from the Timers screen — mirrors the
/// competitive audit's "a timer for every metcon" list (Stopwatch, Timer, Tabata,
/// EMOM, AMRAP, Boxing/MMA, Metronome, Yoga).
enum TimerKind: String, CaseIterable, Identifiable, Codable {
    case stopwatch
    case countdown
    case tabata
    case emom
    case amrap
    case boxing
    case metronome
    case yoga

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .stopwatch: "timer_kind_stopwatch"
        case .countdown: "timer_kind_countdown"
        case .tabata: "timer_kind_tabata"
        case .emom: "timer_kind_emom"
        case .amrap: "timer_kind_amrap"
        case .boxing: "timer_kind_boxing"
        case .metronome: "timer_kind_metronome"
        case .yoga: "timer_kind_yoga"
        }
    }

    var systemImage: String {
        switch self {
        case .stopwatch: "stopwatch.fill"
        case .countdown: "timer"
        case .tabata: "flame.fill"
        case .emom: "clock.fill"
        case .amrap: "bolt.fill"
        case .boxing: "figure.boxing"
        case .metronome: "metronome"
        case .yoga: "figure.cooldown"
        }
    }

    var tint: Color {
        switch self {
        case .stopwatch: PulseTheme.warning
        case .countdown: PulseTheme.growth
        case .tabata: PulseTheme.ringMove
        case .emom: PulseTheme.warning
        case .amrap: .purple
        case .boxing: PulseTheme.destructive
        case .metronome: PulseTheme.growth
        case .yoga: PulseTheme.ringStand
        }
    }

    /// Whether this kind is a simple single "work" phase with no rest/rounds —
    /// covers Timer, AMRAP and Yoga, which are all just a plain countdown by another name.
    var isSingleDuration: Bool {
        switch self {
        case .countdown, .amrap, .yoga: true
        default: false
        }
    }

    var defaultConfig: TimerConfig {
        switch self {
        case .stopwatch:  TimerConfig()
        case .countdown:  TimerConfig(workSeconds: 300, restSeconds: 0, rounds: 1)
        case .tabata:     TimerConfig(workSeconds: 20, restSeconds: 10, rounds: 8)
        case .emom:       TimerConfig(workSeconds: 60, restSeconds: 0, rounds: 10)
        case .amrap:      TimerConfig(workSeconds: 600, restSeconds: 0, rounds: 1)
        case .boxing:     TimerConfig(workSeconds: 180, restSeconds: 60, rounds: 5)
        case .metronome:  TimerConfig(bpm: 90)
        case .yoga:       TimerConfig(workSeconds: 30, restSeconds: 0, rounds: 1)
        }
    }
}

/// A single persisted configuration (work/rest/rounds or BPM) for one `TimerKind`.
struct TimerConfig: Codable, Equatable {
    var workSeconds: Int = 20
    var restSeconds: Int = 10
    var rounds: Int = 8
    var bpm: Int = 90

    func summary(for kind: TimerKind) -> String {
        switch kind {
        case .stopwatch:
            return "00:00"
        case .countdown, .amrap, .yoga:
            return Self.clockString(workSeconds)
        case .tabata, .boxing:
            return "\(workSeconds)/\(restSeconds)s"
        case .emom:
            return "\(rounds)m"
        case .metronome:
            return "\(bpm)"
        }
    }

    static func clockString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// Persists the last-used config per timer kind so the list can show it inline
/// (e.g. "20/10s" under Tabata) without needing a backing model/CoreData table.
enum TimerConfigStore {
    private static func key(for kind: TimerKind) -> String { "timer_config_\(kind.rawValue)" }

    static func config(for kind: TimerKind) -> TimerConfig {
        guard
            let data = UserDefaults.standard.data(forKey: key(for: kind)),
            let decoded = try? JSONDecoder().decode(TimerConfig.self, from: data)
        else {
            return kind.defaultConfig
        }
        return decoded
    }

    static func save(_ config: TimerConfig, for kind: TimerKind) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key(for: kind))
    }
}

/// Short system-sound cues for phase/round transitions — kept deliberately minimal
/// (no bundled audio assets) since haptics via `HapticService` carry the primary feedback.
enum TimerSoundCue {
    static func start(enabled: Bool = true) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1113)
    }

    static func tick(enabled: Bool = true) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1057)
    }

    static func phaseChange(enabled: Bool = true) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1013)
    }

    static func finish(enabled: Bool = true) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1025)
    }
}
