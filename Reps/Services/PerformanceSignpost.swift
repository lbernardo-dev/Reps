import OSLog

enum PerformanceSignpost {
    private static let signposter = OSSignposter(
        subsystem: "com.romerodev.repsfitness",
        category: "Performance"
    )

    @discardableResult
    static func begin(_ name: StaticString, _ message: String = "") -> OSSignpostIntervalState {
        if message.isEmpty {
            return signposter.beginInterval(name)
        }
        return signposter.beginInterval(name, "\(message, privacy: .public)")
    }

    static func end(_ name: StaticString, _ state: OSSignpostIntervalState, _ message: String = "") {
        if message.isEmpty {
            signposter.endInterval(name, state)
        } else {
            signposter.endInterval(name, state, "\(message, privacy: .public)")
        }
    }

    static func event(_ name: StaticString, _ message: String = "") {
        if message.isEmpty {
            signposter.emitEvent(name)
        } else {
            signposter.emitEvent(name, "\(message, privacy: .public)")
        }
    }
}
