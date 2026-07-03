import CoreLocation
import MapKit
import SwiftUI

struct RouteWorkoutMapBackdrop: View {
    let session: WorkoutSession

    var body: some View {
        if session.isOutdoorRouteSession {
            HistoryRouteMap(routePoints: session.routePoints, style: .hero)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        PulseTheme.card,
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle watermark kept in the upper third so it never collides
                // with the title/metrics that sit at the bottom of the hero.
                VStack(spacing: 10) {
                    Image(systemName: session.location == .outdoor ? "map" : "figure.run.treadmill")
                        .font(.system(size: 72, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.14))

                    Text(session.location == .outdoor ? localizedString("no_gps_route") : localizedString("treadmill_workout"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.22))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 96)
            }
        }
    }
}

struct RouteWorkoutDetailsCard: View {
    let session: WorkoutSession

    private let columns = [
        GridItem(.flexible(), spacing: 18, alignment: .topLeading),
        GridItem(.flexible(), spacing: 18, alignment: .topLeading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
            RouteWorkoutMetric(title: localizedString("workout_time"), value: session.workoutTimeText, color: PulseTheme.hrZones[2])
            RouteWorkoutMetric(title: localizedString("distance"), value: session.distanceKm.map { WorkoutHistoryFormat.distanceUppercase($0) } ?? "--", color: PulseTheme.ringStand)
            RouteWorkoutMetric(title: localizedString("active_kilocalories"), value: session.activeKilocaloriesText, color: PulseTheme.ringMove)
            RouteWorkoutMetric(title: localizedString("total_kilocalories"), value: session.totalKilocaloriesText, color: PulseTheme.ringMove)
            RouteWorkoutMetric(title: localizedString("elevation_gain"), value: session.elevationGainText, color: PulseTheme.ringExercise)
            RouteWorkoutMetric(title: localizedString("hr_recovery"), value: session.heartRateRecoveryText, color: PulseTheme.hrZones[3])
            RouteWorkoutMetric(title: localizedString("avg_cadence"), value: session.averageCadenceText, color: PulseTheme.ringStand)
            RouteWorkoutMetric(title: localizedString("avg_pace"), value: session.averagePaceSecondsPerKm.map { WorkoutHistoryFormat.paceAppleStyle($0, includesUnit: true) } ?? "--", color: PulseTheme.ringStand)
            RouteWorkoutMetric(title: localizedString("avg_heart_rate"), value: session.averageHeartRate.map { "\(Int($0))BPM" } ?? "--", color: PulseTheme.ringMove)
            RouteWorkoutMetric(title: localizedString("max_heart_rate"), value: session.maxHeartRate.map { "\(Int($0))BPM" } ?? "--", color: PulseTheme.ringMove)
        }
        .padding(24)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct RouteWorkoutSplitsCard: View {
    let splits: [RouteSplit]

    private var showsHeartRate: Bool { splits.contains { $0.averageHeartRate != nil } }
    private var showsCadence: Bool { splits.contains { $0.cadenceSpm != nil } }
    private var showsSensors: Bool { showsHeartRate || showsCadence }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("splits")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            VStack(spacing: 0) {
                HStack {
                    Text("")
                        .frame(width: 26, alignment: .leading)
                    if !showsSensors {
                        Text("time_2")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("pace_2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showsHeartRate {
                        Image(systemName: "heart.fill")
                            .frame(width: 52, alignment: .trailing)
                    }
                    if showsCadence {
                        Image(systemName: "figure.run")
                            .frame(width: 52, alignment: .trailing)
                    }
                    Text("distance_3")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.48))
                .padding(.bottom, 8)

                ForEach(splits) { split in
                    HStack {
                        Text("\(split.index)")
                            .foregroundStyle(Color.white.opacity(0.48))
                            .frame(width: 26, alignment: .leading)
                        if !showsSensors {
                            Text(WorkoutHistoryFormat.timeText(split.elapsedSeconds))
                                .foregroundStyle(PulseTheme.hrZones[2])
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(WorkoutHistoryFormat.paceAppleStyle(split.paceSecondsPerKm, includesUnit: false))
                            .foregroundStyle(PulseTheme.ringStand)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if showsHeartRate {
                            Text(split.averageHeartRate.map { "\(Int($0.rounded()))" } ?? "--")
                                .foregroundStyle(PulseTheme.ringMove)
                                .frame(width: 52, alignment: .trailing)
                        }
                        if showsCadence {
                            Text(split.cadenceSpm.map { "\(Int($0.rounded()))" } ?? "--")
                                .foregroundStyle(PulseTheme.ringExercise)
                                .frame(width: 52, alignment: .trailing)
                        }
                        Text(split.distanceText)
                            .foregroundStyle(Color.white.opacity(0.58))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: showsSensors ? 16 : 18, weight: .medium, design: .rounded).monospacedDigit())
                    .padding(.vertical, 8)

                    if split.id != splits.last?.id {
                        Divider().background(Color.white.opacity(0.12))
                    }
                }
            }
            .padding(18)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

struct RouteWorkoutMapCard: View {
    let session: WorkoutSession
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onExpand) {
                HStack(spacing: 8) {
                    Text("map_2")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            ZStack(alignment: .topTrailing) {
                HistoryRouteMap(routePoints: session.routePoints, style: .card)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                    .navigationGlassCircle(.secondary, tint: .clear)
                    .padding(12)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture(perform: onExpand)
        }
    }
}

struct RouteWorkoutExpandedMap: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession

    var body: some View {
        ZStack(alignment: .top) {
            HistoryRouteMap(routePoints: session.routePoints, style: .expanded)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .destructiveGlassCircle(.secondary)
                }
                .buttonStyle(.plain)

                Text(session.distanceKm.map { "\(WorkoutHistoryFormat.distanceUppercase($0, spaced: true)) \(session.appleFitnessRouteTitle)" } ?? session.appleFitnessRouteTitle)
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.72), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
        }
        .presentationBackground(.black)
    }
}

struct RouteWorkoutMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(localizedKey(title))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RouteWorkoutNotesCard: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("notes_2")
                .font(.headline)
                .foregroundStyle(.white)
            Text(notes)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct HistoryRouteMap: View {
    enum Style {
        case card
        case hero
        case expanded
    }

    let routePoints: [RoutePoint]
    var style: Style = .card
    @State private var position: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(style == .card ? PulseTheme.accent : PulseTheme.hrZones[2], lineWidth: style == .card ? 5 : 7)
            }
            if let first = coordinates.first {
                Annotation(localizedString("route_start"), coordinate: first) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: style == .card ? 18 : 26, height: style == .card ? 18 : 26)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if let last = coordinates.last {
                Annotation(localizedString("route_end"), coordinate: last) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: style == .card ? 18 : 26, height: style == .card ? 18 : 26)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .modifier(HeroRouteMapColorScheme(isEnabled: style != .card))
        .mapControls {
            if style != .hero {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
        }
        .onAppear(perform: fitRoute)
    }

    private func fitRoute() {
        let coords = coordinates
        guard let first = coords.first else { return }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coords {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.8, 0.005), longitudeDelta: max((maxLon - minLon) * 1.8, 0.005))
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}

private struct HeroRouteMapColorScheme: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.colorScheme(.dark)
        } else {
            content
        }
    }
}

struct RouteSplit: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let distanceMeters: CLLocationDistance
    let elapsedSeconds: TimeInterval
    var averageHeartRate: Double? = nil
    var cadenceSpm: Double? = nil

    var paceSecondsPerKm: TimeInterval {
        guard distanceMeters > 0 else { return 0 }
        return elapsedSeconds / (distanceMeters / 1_000)
    }

    var distanceText: String {
        if distanceMeters >= 999 {
            return "1 KM"
        }
        return "\(Int(distanceMeters.rounded())) M"
    }
}

extension WorkoutSession {
    var appleFitnessRouteTitle: String {
        let normalizedTitle = workoutTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let isRun = normalizedTitle.localizedCaseInsensitiveContains("carrera") ||
            normalizedTitle.localizedCaseInsensitiveContains("run")
        let isWalk = normalizedTitle.localizedCaseInsensitiveContains("camina") ||
            normalizedTitle.localizedCaseInsensitiveContains("walk")

        if isRun {
            return location == .outdoor ? localizedString("outdoor_run") : localizedString("treadmill_run")
        }
        if isWalk {
            return location == .outdoor ? localizedString("outdoor_walk") : localizedString("treadmill_walk")
        }
        return location == .outdoor ? localizedString("outdoor_workout") : localizedString("indoor_workout")
    }

    var routeLocationText: String {
        location == .outdoor ? localizedString("outdoor") : localizedString("indoor")
    }

    var routeSourceText: String {
        if isImportedFromHealth || healthKitUUIDString != nil || !healthKitActivityTypes.isEmpty {
            return "Apple Watch"
        }
        return "Reps"
    }

    var routeDateRangeText: String {
        let start = startedAt ?? date
        let end = endedAt ?? Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateFormat = "d MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = .current
        timeFormatter.dateFormat = "HH:mm"

        return "\(dateFormatter.string(from: start)), \(timeFormatter.string(from: start))-\(timeFormatter.string(from: end))"
    }

    var workoutTimeText: String {
        let start = startedAt ?? date
        let fallbackEnd = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
        let end = endedAt ?? fallbackEnd
        let measuredElapsed = Int(end.timeIntervalSince(start)) - pausedDurationSeconds
        let elapsed = measuredElapsed > 0 ? measuredElapsed : max(durationMinutes, 1) * 60
        let hours = elapsed / 3_600
        let minutes = (elapsed % 3_600) / 60
        let seconds = elapsed % 60
        return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
    }

    var activeKilocaloriesText: String {
        if let kcal = activeEnergyKcal ?? estimatedCalories, kcal > 0 {
            return "\(Int(kcal))KCAL"
        }
        // Fall back to a duration-based estimate so the field is never blank when
        // no sensor energy is available (e.g. strength logged without a watch).
        let perMinute = isRouteSession ? 7.0 : 5.5
        let estimate = Double(durationMinutes) * perMinute
        return estimate > 0 ? "\(Int(estimate))KCAL" : "0KCAL"
    }

    var totalKilocaloriesText: String {
        if let estimatedCalories, estimatedCalories > 0 {
            return "\(Int(estimatedCalories))KCAL"
        }
        if let activeEnergyKcal, activeEnergyKcal > 0 {
            return "\(Int(activeEnergyKcal * 1.12))KCAL"
        }
        // Mirror the active-energy estimate (plus basal) so this is never blank.
        let perMinute = isRouteSession ? 7.0 : 5.5
        let estimate = Double(durationMinutes) * perMinute * 1.12
        return estimate > 0 ? "\(Int(estimate))KCAL" : "0KCAL"
    }

    var averageCadenceText: String {
        guard durationMinutes > 0 else { return "0SPM" }
        // Prefer measured steps; otherwise estimate step count from distance using
        // a typical stride for the pace so the field is never blank for a walk/run.
        if let steps, steps > 0 {
            return "\(Int(steps / Double(durationMinutes)))SPM"
        }
        if let distanceKm, distanceKm > 0 {
            let paceSecPerKm = averagePaceSecondsPerKm ?? (Double(durationMinutes) * 60 / distanceKm)
            let strideMeters = paceSecPerKm < 360 ? 1.15 : 0.78 // running vs walking stride
            let estimatedSteps = (distanceKm * 1_000) / strideMeters
            return "\(Int(estimatedSteps / Double(durationMinutes)))SPM"
        }
        return "0SPM"
    }

    /// Cumulative positive elevation from the recorded route; indoor sessions with
    /// no GPS legitimately report 0 rather than an empty placeholder.
    var elevationGainMeters: Double {
        guard routePoints.count >= 2 else { return 0 }
        var gain = 0.0
        for index in 1..<routePoints.count {
            let delta = (routePoints[index].altitude ?? 0) - (routePoints[index - 1].altitude ?? 0)
            if delta > 0 { gain += delta }
        }
        return gain
    }

    var elevationGainText: String {
        "\(Int(elevationGainMeters.rounded()))M"
    }

    /// Heart-rate recovery: drop from peak (or average) HR to the post-workout HR.
    var heartRateRecoveryText: String {
        guard let after = heartRateAfter else { return "--" }
        let peak = maxHeartRate ?? averageHeartRate
        guard let peak, peak > after else { return "--" }
        return localizedFormat("heart_rate_bpm_format", Int((peak - after).rounded()))
    }

    var hasRouteSensorSummary: Bool {
        averageHeartRate != nil || steps != nil
    }

    var routeSplits: [RouteSplit] {
        guard routePoints.count >= 2 else { return [] }

        var splits: [RouteSplit] = []
        var splitIndex = 1
        var splitStartDistance: CLLocationDistance = 0
        var splitStartTime = routePoints[0].timestamp
        var cumulativeDistance: CLLocationDistance = 0
        var previousPoint = routePoints[0]
        let targetMeters: CLLocationDistance = 1_000

        for point in routePoints.dropFirst() {
            let previousLocation = CLLocation(latitude: previousPoint.latitude, longitude: previousPoint.longitude)
            let currentLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
            let segmentDistance = currentLocation.distance(from: previousLocation)
            guard segmentDistance > 0 else {
                previousPoint = point
                continue
            }

            let previousDistance = cumulativeDistance
            cumulativeDistance += segmentDistance

            while cumulativeDistance - splitStartDistance >= targetMeters {
                let needed = splitStartDistance + targetMeters
                let ratio = min(max((needed - previousDistance) / segmentDistance, 0), 1)
                let segmentDuration = point.timestamp.timeIntervalSince(previousPoint.timestamp)
                let splitEndTime = previousPoint.timestamp.addingTimeInterval(segmentDuration * ratio)
                let metrics = sensorMetrics(from: splitStartTime, to: splitEndTime)
                splits.append(RouteSplit(
                    index: splitIndex,
                    distanceMeters: targetMeters,
                    elapsedSeconds: splitEndTime.timeIntervalSince(splitStartTime),
                    averageHeartRate: metrics.heartRate,
                    cadenceSpm: metrics.cadence
                ))
                splitIndex += 1
                splitStartDistance = needed
                splitStartTime = splitEndTime
            }

            previousPoint = point
        }

        let remainder = cumulativeDistance - splitStartDistance
        if remainder >= 50, let last = routePoints.last {
            let metrics = sensorMetrics(from: splitStartTime, to: last.timestamp)
            splits.append(RouteSplit(
                index: splitIndex,
                distanceMeters: remainder,
                elapsedSeconds: last.timestamp.timeIntervalSince(splitStartTime),
                averageHeartRate: metrics.heartRate,
                cadenceSpm: metrics.cadence
            ))
        }

        return splits
    }

    /// Average heart rate and cadence of route points whose timestamp falls in [start, end].
    private func sensorMetrics(from start: Date, to end: Date) -> (heartRate: Double?, cadence: Double?) {
        let window = routePoints.filter { $0.timestamp >= start && $0.timestamp <= end }
        let heartRates = window.compactMap(\.heartRate)
        let cadences = window.compactMap(\.cadenceSpm)
        let avgHR = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
        let avgCadence = cadences.isEmpty ? nil : cadences.reduce(0, +) / Double(cadences.count)
        return (avgHR, avgCadence)
    }
}
