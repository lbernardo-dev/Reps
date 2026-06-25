import Charts
import SwiftUI

// MARK: - Heart Rate Zone Model

private enum HRZone: Int, CaseIterable {
    case one = 1, two, three, four, five

    var color: Color {
        switch self {
        case .one:   return Color(red: 0.25, green: 0.72, blue: 1.00)
        case .two:   return Color(red: 0.18, green: 0.85, blue: 0.40)
        case .three: return Color(red: 1.00, green: 0.84, blue: 0.00)
        case .four:  return Color(red: 1.00, green: 0.50, blue: 0.10)
        case .five:  return Color(red: 1.00, green: 0.15, blue: 0.22)
        }
    }

    func lowerBound(maxHR: Double) -> Double {
        [0.0, 0.60, 0.70, 0.80, 0.90][rawValue - 1] * maxHR
    }

    func rangeLabel(maxHR: Double) -> String {
        switch self {
        case .one:   return "<\(Int(maxHR * 0.60))BPM"
        case .two:   return "\(Int(maxHR * 0.60))-\(Int(maxHR * 0.70))BPM"
        case .three: return "\(Int(maxHR * 0.70))-\(Int(maxHR * 0.80))BPM"
        case .four:  return "\(Int(maxHR * 0.80))-\(Int(maxHR * 0.90))BPM"
        case .five:  return "\(Int(maxHR * 0.90))+BPM"
        }
    }

    func label() -> String {
        switch self {
        case .one:   return localizedString("zone_1_label")
        case .two:   return localizedString("zone_2_label")
        case .three: return localizedString("zone_3_label")
        case .four:  return localizedString("zone_4_label")
        case .five:  return localizedString("zone_5_label")
        }
    }
}

// MARK: - WorkoutSession HR/Elevation Extension

extension WorkoutSession {
    var minHeartRate: Double? {
        let s = routePoints.compactMap(\.heartRate)
        return s.isEmpty ? nil : s.min()
    }

    var hrTimeSeries: [(date: Date, bpm: Double)] {
        routePoints.compactMap { p in p.heartRate.map { (p.timestamp, $0) } }
    }

    var elevationTimeSeries: [(date: Date, altitude: Double)] {
        routePoints.compactMap { p in p.altitude.map { (p.timestamp, $0) } }
    }

    fileprivate func heartRateZoneDurations(maxHR: Double) -> [HRZone: TimeInterval] {
        var result: [HRZone: TimeInterval] = Dictionary(
            uniqueKeysWithValues: HRZone.allCases.map { ($0, 0.0) }
        )
        let pts = routePoints.filter { $0.heartRate != nil }
        guard pts.count >= 2 else { return result }
        for i in 1..<pts.count {
            guard let hr = pts[i - 1].heartRate else { continue }
            let dt = pts[i].timestamp.timeIntervalSince(pts[i - 1].timestamp)
            guard dt > 0, dt < 300 else { continue }
            let zone = HRZone.allCases.last { hr >= $0.lowerBound(maxHR: maxHR) } ?? .one
            result[zone, default: 0] += dt
        }
        return result
    }

    fileprivate func enduranceFocus(maxHR: Double) -> (low: TimeInterval, high: TimeInterval, anaerobic: TimeInterval) {
        let z = heartRateZoneDurations(maxHR: maxHR)
        return (
            low:       (z[.one] ?? 0) + (z[.two] ?? 0),
            high:      z[.three] ?? 0,
            anaerobic: (z[.four] ?? 0) + (z[.five] ?? 0)
        )
    }
}

// MARK: - WorkoutHeartRateCard

struct WorkoutHeartRateCard: View {
    let session: WorkoutSession

    private struct HRSample: Identifiable {
        let id: Int
        let date: Date
        let bpm: Double
    }

    private var samples: [HRSample] {
        let raw = session.hrTimeSeries
        guard !raw.isEmpty else { return [] }
        let step = max(1, raw.count / 80)
        var out: [HRSample] = []
        var i = 0
        while i < raw.count {
            out.append(HRSample(id: out.count, date: raw[i].date, bpm: raw[i].bpm))
            i += step
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.white)
                Text("Heart Rate")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 0) {
                hrStat(label: "Avg", value: session.averageHeartRate)
                Divider().frame(height: 44).overlay(Color.white.opacity(0.25))
                hrStat(label: "Min", value: session.minHeartRate)
                Divider().frame(height: 44).overlay(Color.white.opacity(0.25))
                hrStat(label: "Max", value: session.maxHeartRate)
            }

            if !samples.isEmpty {
                Chart(samples) { s in
                    BarMark(x: .value("T", s.date), y: .value("BPM", s.bpm))
                        .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.50).opacity(0.85))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.25))
                        AxisValueLabel {
                            if let bpm = v.as(Double.self) {
                                Text("\(Int(bpm))")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.65))
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.background(Color.clear) }
                .frame(height: 100)
            }

            if let after = session.heartRateAfter,
               let peak = session.maxHeartRate ?? session.averageHeartRate,
               peak > after {
                Text("Recovery (1 min): -\(Int((peak - after).rounded())) bpm")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.70))
            }
        }
        .padding(18)
        .background(Color(red: 0.44, green: 0.05, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func hrStat(label: String, value: Double?) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.70))
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value.map { "\(Int($0))" } ?? "--")
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text("bpm")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.70))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - WorkoutHeartRateZonesCard

struct WorkoutHeartRateZonesCard: View {
    let session: WorkoutSession
    let maxHR: Double

    private var durations: [HRZone: TimeInterval] { session.heartRateZoneDurations(maxHR: maxHR) }
    private var maxDuration: TimeInterval { durations.values.max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Heart Rate Zones")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Estimated time in each heart rate zone.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            VStack(spacing: 12) {
                ForEach(HRZone.allCases, id: \.rawValue) { zone in
                    let duration = durations[zone] ?? 0
                    HStack(spacing: 10) {
                        Circle()
                            .fill(zone.color)
                            .frame(width: 10, height: 10)
                        Text(Self.durationText(duration))
                            .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(duration > 0 ? .white : Color.white.opacity(0.30))
                            .frame(width: 52, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 6)
                                if maxDuration > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(zone.color)
                                        .frame(
                                            width: geo.size.width * CGFloat(duration / maxDuration),
                                            height: 6
                                        )
                                }
                            }
                        }
                        .frame(height: 6)
                        Text(zone.rangeLabel(maxHR: maxHR))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 96, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        let t = max(0, Int(seconds.rounded()))
        return "\(t / 60):\(String(format: "%02d", t % 60))"
    }
}

// MARK: - WorkoutEnduranceFocusCard

struct WorkoutEnduranceFocusCard: View {
    let session: WorkoutSession
    let maxHR: Double

    private var focus: (low: TimeInterval, high: TimeInterval, anaerobic: TimeInterval) {
        session.enduranceFocus(maxHR: maxHR)
    }

    private var total: TimeInterval { max(1, focus.low + focus.high + focus.anaerobic) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Endurance Focus")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            VStack(spacing: 14) {
                enduranceRow(name: "Low Aerobic",  duration: focus.low,       color: Color(red: 0.20, green: 0.90, blue: 0.65))
                enduranceRow(name: "High Aerobic", duration: focus.high,      color: Color(red: 1.00, green: 0.60, blue: 0.00))
                enduranceRow(name: "Anaerobic",    duration: focus.anaerobic, color: Color(red: 1.00, green: 0.25, blue: 0.32))
            }
        }
        .padding(18)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func enduranceRow(name: String, duration: TimeInterval, color: Color) -> some View {
        let pct = duration / total
        let mins = Int(duration / 60)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(mins) min")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 8)
                    if pct > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: max(8, geo.size.width * CGFloat(pct)), height: 8)
                    }
                }
            }
            .frame(height: 8)
            Text(pct > 0 ? "\(Int((pct * 100).rounded()))%" : "--")
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(pct > 0 ? color : Color.white.opacity(0.35))
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - WorkoutElevationCard

struct WorkoutElevationCard: View {
    let session: WorkoutSession

    private struct AltSample: Identifiable {
        let id: Int
        let date: Date
        let altitude: Double
    }

    private var samples: [AltSample] {
        let raw = session.elevationTimeSeries
        guard !raw.isEmpty else { return [] }
        let step = max(1, raw.count / 100)
        var out: [AltSample] = []
        var i = 0
        while i < raw.count {
            out.append(AltSample(id: out.count, date: raw[i].date, altitude: raw[i].altitude))
            i += step
        }
        return out
    }

    private var minAlt: Double { samples.map(\.altitude).min() ?? 0 }
    private var maxAlt: Double { samples.map(\.altitude).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(.white)
                Text("Elevation")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            if !samples.isEmpty {
                Chart(samples) { s in
                    AreaMark(
                        x: .value("T", s.date),
                        yStart: .value("Base", minAlt),
                        yEnd: .value("Alt", s.altitude)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.38), Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(x: .value("T", s.date), y: .value("Alt", s.altitude))
                        .foregroundStyle(.white)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 2)) { v in
                        AxisValueLabel {
                            if let d = v.as(Date.self) {
                                Text(Self.timeLabel(d))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.65))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [minAlt, maxAlt]) { v in
                        AxisValueLabel {
                            if let alt = v.as(Double.self) {
                                Text("\(Int(alt))m")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.65))
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.background(Color.clear) }
                .frame(height: 140)
            }
        }
        .padding(18)
        .background(Color(red: 0.05, green: 0.26, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private static func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f.string(from: date)
    }
}
