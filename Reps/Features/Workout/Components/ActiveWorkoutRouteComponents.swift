import AVFoundation
import Combine
import CoreImage
import CoreMotion
import WebKit
import CoreLocation
import MapKit
import MediaPlayer
import MuscleMap
import MusicKit
import PhotosUI
import SwiftUI

struct RouteTrackingPanel: View {
    let isTracking: Bool
    let statusText: String
    let statusBadge: String
    let primaryMetrics: [SessionMetricStrip.Metric]
    let secondaryMetrics: [SessionMetricStrip.Metric]

    private var statusColor: Color {
        isTracking ? PulseTheme.accent : PulseTheme.secondaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: isTracking ? "location.fill" : "map")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PulseTheme.onColor(statusColor))
                    .frame(width: 54, height: 54)
                    .background(statusColor)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("gps_y_ruta")
                        .font(.headline)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
                Text(statusBadge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            SessionMetricStrip(metrics: primaryMetrics)
            SessionMetricStrip(metrics: secondaryMetrics)
        }
    }
}


struct LiveRouteMapPanel: View {
    let routePoints: [RoutePoint]
    let isSessionStarted: Bool
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("mapa_en_vivo", systemImage: "map.fill")
                    .font(.headline)
                Spacer()
                Text(routePoints.isEmpty ? "Esperando GPS" : "\(routePoints.count) puntos")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            ZStack {
                RouteMapPreview(routePoints: routePoints)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                if routePoints.count < 2 {
                    VStack(spacing: 10) {
                        Image(systemName: "location.magnifyingglass")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                        Text(localizedString(isSessionStarted ? "route_drawing_started" : "route_drawing_pending"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                Button(action: onExpand) {
                    Label("ampliar_mapa", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .disabled(routePoints.isEmpty)
                .opacity(routePoints.isEmpty ? 0 : 1)
            }
        }
    }
}


struct ExpandedRouteMapView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let routePoints: [RoutePoint]

    var body: some View {
        ZStack(alignment: .top) {
            RouteMapPreview(routePoints: routePoints, followsRoute: false, showsControls: true)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Text(localizedKey(title))
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .destructiveGlassCircle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
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


struct RouteResumePrompt: View {
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(PulseTheme.accent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("movement_detected")
                    .font(.subheadline.weight(.bold))
                Text("resume_to_continue_tracking_route_and_distance")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Button("reanudar", action: onResume)
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(PulseTheme.accent)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(PulseTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}


struct RouteMapPreview: View {
    let routePoints: [RoutePoint]
    var followsRoute = true
    var showsControls = false
    @State private var position: MapCameraPosition = .automatic
    @State private var userHasInteracted = false

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(PulseTheme.accent, lineWidth: 5)
            }
            if let first = coordinates.first {
                Marker("Inicio", systemImage: "play.fill", coordinate: first)
                    .tint(.green)
            }
            if let last = coordinates.last {
                Marker("Actual", systemImage: "location.fill", coordinate: last)
                    .tint(.purple)
            }
        }
        .mapControls {
            if showsControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in userHasInteracted = true })
        .simultaneousGesture(MagnifyGesture().onChanged { _ in userHasInteracted = true })
        .onAppear {
            fitRoute()
        }
        .onChange(of: routePoints.count) { _, _ in
            if followsRoute, !userHasInteracted {
                fitRoute()
            }
        }
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

@MainActor

final class WorkoutRouteTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var routePoints: [RoutePoint] = []
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var totalDistanceMeters: CLLocationDistance = 0
    private var shouldStartAfterAuthorization = false
    private var startedAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 8
        authorizationStatus = manager.authorizationStatus
    }

    var distanceKm: Double {
        totalDistanceMeters / 1_000
    }

    var statusText: String {
        if isTracking {
            return localizedString("recording_live_route")
        }
        switch authorizationStatus {
        case .denied, .restricted:
            return localizedString("location_permission_denied")
        case .notDetermined:
            return localizedString("ready_to_request_permission")
        default:
            return routePoints.isEmpty ? localizedString("no_route_started") : localizedString("route_paused")
        }
    }

    func requestAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startNewRoute(startedAt: Date) {
        routePoints = []
        lastLocation = nil
        totalDistanceMeters = 0
        self.startedAt = startedAt
        startUpdatingLocation()
    }

    func resume() {
        startUpdatingLocation()
    }

    private func startUpdatingLocation() {
        if authorizationStatus == .notDetermined {
            shouldStartAfterAuthorization = true
            requestAuthorization()
            return
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            shouldStartAfterAuthorization = false
            return
        }
        shouldStartAfterAuthorization = false
        isTracking = true
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        shouldStartAfterAuthorization = false
        isTracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func paceText(elapsedSeconds: Int) -> String {
        SharedWorkoutSnapshot.routePaceText(averagePaceSecondsPerKm(elapsedSeconds: elapsedSeconds))
    }

    func averagePaceSecondsPerKm(elapsedSeconds: Int) -> Double? {
        guard distanceKm > 0.02 else {
            return nil
        }
        return Double(max(elapsedSeconds, 1)) / distanceKm
    }

    func averageSpeedKmh(elapsedSeconds: Int) -> Double? {
        guard elapsedSeconds > 0, distanceKm > 0.02 else {
            return nil
        }
        return distanceKm / (Double(elapsedSeconds) / 3_600)
    }

    func speedText(elapsedSeconds: Int) -> String {
        SharedWorkoutSnapshot.routeSpeedText(averageSpeedKmh(elapsedSeconds: elapsedSeconds))
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            if shouldStartAfterAuthorization,
               status == .authorizedWhenInUse || status == .authorizedAlways {
                startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                shouldStartAfterAuthorization = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations where shouldAccept(location) {
                if let lastLocation {
                    let segmentDistance = location.distance(from: lastLocation)
                    if segmentDistance >= 1, segmentDistance <= 250 {
                        totalDistanceMeters += segmentDistance
                    }
                }
                lastLocation = location
                routePoints.append(
                    RoutePoint(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        altitude: location.altitude,
                        horizontalAccuracy: location.horizontalAccuracy,
                        timestamp: location.timestamp
                    )
                )
            }
        }
    }

    private func shouldAccept(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 35 else {
            return false
        }
        if let startedAt, location.timestamp < startedAt.addingTimeInterval(-3) {
            return false
        }
        if location.speed > 8.5 {
            return false
        }
        if let lastLocation, location.timestamp <= lastLocation.timestamp {
            return false
        }
        return true
    }
}

@MainActor

final class WorkoutMotionResumeDetector: ObservableObject {
    @Published var shouldSuggestResume = false

    private let activityManager = CMMotionActivityManager()
    private var startedAt: Date?

    func start() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        guard startedAt == nil else { return }

        startedAt = Date()
        shouldSuggestResume = false
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self else { return }
            guard let startedAt = self.startedAt,
                  Date().timeIntervalSince(startedAt) > 8 else {
                return
            }

            let isMovingOnFoot = activity?.walking == true || activity?.running == true
            let isReliable = activity?.confidence == .medium || activity?.confidence == .high
            self.shouldSuggestResume = isMovingOnFoot && isReliable
        }
    }

    func stop() {
        activityManager.stopActivityUpdates()
        startedAt = nil
        shouldSuggestResume = false
    }
}
