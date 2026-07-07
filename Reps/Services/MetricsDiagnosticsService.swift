import Foundation

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

#if canImport(MetricKit)
import MetricKit
#endif

final class MetricsDiagnosticsService: NSObject, @unchecked Sendable {
    static let shared = MetricsDiagnosticsService()

    private let isoFormatter = ISO8601DateFormatter()
    private var isSubscribed = false

    private override init() {}

    func start() {
        #if canImport(MetricKit)
        guard !isSubscribed else { return }
        isSubscribed = true
        MXMetricManager.shared.add(self)
        handleDiagnosticPayloads(MXMetricManager.shared.pastDiagnosticPayloads, source: "past")
        #endif
    }

    func stop() {
        #if canImport(MetricKit)
        guard isSubscribed else { return }
        MXMetricManager.shared.remove(self)
        isSubscribed = false
        #endif
    }

    #if canImport(MetricKit)
    private func handleDiagnosticPayloads(_ payloads: [MXDiagnosticPayload], source: String) {
        guard !payloads.isEmpty else { return }
        for payload in payloads {
            persist(payload: payload, source: source)
            recordDiagnostic(payload: payload, source: source)
        }
    }

    private func persist(payload: MXDiagnosticPayload, source: String) {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MetricKitDiagnostics", isDirectory: true)

        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let timestamp = isoFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("diagnostic-\(source)-\(timestamp).json")
        try? payload.jsonRepresentation().write(to: url, options: [.atomic, .completeFileProtection])
    }

    private func recordDiagnostic(payload: MXDiagnosticPayload, source: String) {
        #if canImport(FirebaseCrashlytics)
        let jsonData = payload.jsonRepresentation()
        let preview = String(data: jsonData.prefix(900), encoding: .utf8) ?? ""
        let error = NSError(
            domain: "com.romerodev.repsfitness.metrickit",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "MetricKit diagnostic payload",
                "source": source,
                "payload_bytes": jsonData.count,
                "payload_preview": preview
            ]
        )
        Crashlytics.crashlytics().record(error: error)
        Crashlytics.crashlytics().log("metrickit.diagnostic.\(source)")
        #endif
    }
    #endif
}

#if canImport(MetricKit)
extension MetricsDiagnosticsService: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        handleDiagnosticPayloads(payloads, source: "live")
    }
}
#endif
