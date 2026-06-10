import CoreLocation
import MapKit
import SwiftUI

struct WorkoutHistoryView: View {
    let sessions: [WorkoutSession]
    
    @State private var searchText = ""
    @State private var selectedLocationFilter: LocationFilter = .all
    @State private var selectedOriginFilter: OriginFilter = .all
    
    enum LocationFilter: String, CaseIterable, Identifiable {
        case all = "Todos"
        case gym = "Gym"
        case home = "Casa"
        
        var id: String { rawValue }
    }
    
    enum OriginFilter: String, CaseIterable, Identifiable {
        case all = "Todos"
        case routine = "Rutina"
        case free = "Libre"
        
        var id: String { rawValue }
    }
    
    // Group and filter workouts
    private var filteredAndGroupedSessions: [(month: String, sessions: [WorkoutSession])] {
        let filtered = sessions.filter { session in
            // Search text filter
            let matchesSearch = searchText.isEmpty ||
                session.workoutTitle.localizedCaseInsensitiveContains(searchText) ||
                (session.notes ?? "").localizedCaseInsensitiveContains(searchText)
            
            // Location filter
            let matchesLocation: Bool
            switch selectedLocationFilter {
            case .all: matchesLocation = true
            case .gym: matchesLocation = session.location == .gym
            case .home: matchesLocation = session.location == .home
            }
            
            // Origin filter
            let matchesOrigin: Bool
            switch selectedOriginFilter {
            case .all: matchesOrigin = true
            case .routine: matchesOrigin = session.origin == .routine
            case .free: matchesOrigin = session.origin == .free
            }
            
            return matchesSearch && matchesLocation && matchesOrigin
        }
        
        // Group by month
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "LLLL yyyy"
        dateFormatter.locale = Locale(identifier: "es")
        
        let grouped = Dictionary(grouping: filtered) { session -> String in
            dateFormatter.string(from: session.date).capitalized
        }
        
        // Sort groups by date
        return grouped.map { key, value in
            (month: key, sessions: value.sorted { $0.date > $1.date })
        }
        .sorted { group1, group2 in
            guard let date1 = dateFormatter.date(from: group1.month.lowercased()),
                  let date2 = dateFormatter.date(from: group2.month.lowercased()) else {
                return false
            }
            return date1 > date2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and Filters Bar
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PulseTheme.secondaryText)
                    TextField("Buscar por título o notas...", text: $searchText)
                        .font(.subheadline)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Segmented Filters
                HStack(spacing: 10) {
                    // Location filter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lugar")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                        Picker("Lugar", selection: $selectedLocationFilter) {
                            ForEach(LocationFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Origin filter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tipo")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                        Picker("Origen", selection: $selectedOriginFilter) {
                            ForEach(OriginFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(PulseTheme.background)
            
            ScrollView {
                VStack(spacing: 20) {
                    if filteredAndGroupedSessions.isEmpty {
                        PulseCard {
                            PulseEmptyState(
                                title: searchText.isEmpty && selectedLocationFilter == .all && selectedOriginFilter == .all ? "Sin entrenos registrados" : "No hay resultados",
                                message: "Las sesiones completadas que coincidan con los filtros aparecerán aquí.",
                                systemImage: "list.clipboard"
                            )
                        }
                        .padding(.top, 20)
                    } else {
                        ForEach(filteredAndGroupedSessions, id: \.month) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.month)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.leading, 6)
                                    .padding(.top, 10)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(group.sessions) { session in
                                        NavigationLink {
                                            WorkoutSessionDetailView(session: session)
                                        } label: {
                                            PulseCard {
                                                WorkoutLogRow(session: session)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 116)
            }
        }
        .screenBackground()
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }
}

struct WorkoutLogRow: View {
    let session: WorkoutSession

    private var exerciseCount: Int {
        FitnessMetrics.completedExerciseLogs(in: session).count
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(session.location == .home ? PulseTheme.accent.opacity(0.12) : PulseTheme.primary.opacity(0.12))
                Image(systemName: session.location == .home ? "house.fill" : "dumbbell.fill")
                    .font(.subheadline)
                    .foregroundStyle(session.location == .home ? PulseTheme.accent : PulseTheme.primary)
            }
            .frame(width: 42, height: 42)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(session.workoutTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(session.durationMinutes) min · \(exerciseCount) ej · \(session.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

struct WorkoutSessionDetailView: View {
    @EnvironmentObject private var store: AppStore
    let session: WorkoutSession
    @State private var isShowingShareSheet = false
    @State private var shareImage: UIImage?

    private var exerciseLogs: [ExerciseLog] {
        FitnessMetrics.completedExerciseLogs(in: session)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(session.workoutTitle)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .lineLimit(2)
                            
                            Spacer()
                            
                            Button {
                                guard store.requireFeature(.shareCards, source: .shareCards) else {
                                    return
                                }
                                // Generate a share card for the session
                                shareImage = WorkoutShareImageRenderer.render(session: session)
                                isShowingShareSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body)
                                    .foregroundStyle(PulseTheme.primary)
                                    .padding(10)
                                    .background(PulseTheme.grouped)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(session.date.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                        
                        HStack(spacing: 14) {
                            Label("\(session.durationMinutes) min", systemImage: "timer")
                            Label("\(exerciseLogs.count) ejercicios", systemImage: "list.bullet")
                            Label(session.location == .home ? "Casa" : "Gimnasio", systemImage: session.location == .home ? "house" : "building")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.primary)
                    }
                }

                HStack(spacing: 14) {
                    MetricCard(title: "Volumen", value: "\(Int(FitnessMetrics.totalVolumeKg(for: [session])))", subtitle: "kg", systemImage: "scalemass", badgeColor: PulseTheme.primaryBright)
                    MetricCard(title: "Series", value: "\(FitnessMetrics.completedSets(in: session).count)", subtitle: "completadas", systemImage: "checkmark.circle", badgeColor: PulseTheme.primary)
                }

                if session.hasRouteMetrics {
                    RouteSessionMetricsCard(session: session)
                }

                if let notes = session.notes, !notes.isEmpty {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas de la sesión")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Text(notes)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Ejercicios")
                            .font(.headline)
                        
                        ForEach(exerciseLogs) { log in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(log.exercise.name)
                                            .font(.headline)
                                        Text("\(log.sets.count) series · \(Int(log.sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) })) kg")
                                            .font(.subheadline)
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    Spacer()
                                    NavigationLink {
                                        ExerciseProgressView(exercise: log.exercise)
                                    } label: {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.subheadline)
                                            .foregroundStyle(PulseTheme.primary)
                                            .padding(8)
                                            .background(PulseTheme.grouped)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                ForEach(log.sets) { set in
                                    WorkoutSessionSetRow(set: set)
                                }
                                
                                if !log.notes.isEmpty {
                                    Text(log.notes)
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            if log.id != exerciseLogs.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 112)
        }
        .screenBackground()
        .navigationTitle("Registro")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = shareImage {
                ActivityViewController(activityItems: [image])
            }
        }
    }
}

private struct RouteSessionMetricsCard: View {
    let session: WorkoutSession

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(routeTitle, systemImage: "map.fill")
                        .font(.headline)
                    Spacer()
                    Text(session.routePoints.isEmpty ? "Sin GPS" : "\(session.routePoints.count) puntos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                if !session.routePoints.isEmpty {
                    HistoryRouteMap(routePoints: session.routePoints)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    RouteMetricTile(title: "Distancia", value: session.distanceKm.map { String(format: "%.2f km", $0) } ?? "--", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    RouteMetricTile(title: "Ritmo", value: session.averagePaceSecondsPerKm.map(Self.paceText) ?? "--", systemImage: "speedometer")
                    RouteMetricTile(title: "Pasos", value: session.steps.map { "\(Int($0))" } ?? "--", systemImage: "figure.walk")
                    RouteMetricTile(title: "Kcal activas", value: session.activeEnergyKcal.map { "\(Int($0))" } ?? session.estimatedCalories.map { "\(Int($0))" } ?? "--", systemImage: "flame.fill")
                    RouteMetricTile(title: "Pulso medio", value: session.averageHeartRate.map { "\(Int($0)) lpm" } ?? "--", systemImage: "heart.fill")
                    RouteMetricTile(title: "Pulso max", value: session.maxHeartRate.map { "\(Int($0)) lpm" } ?? "--", systemImage: "waveform.path.ecg")
                    RouteMetricTile(title: "Antes", value: session.heartRateBefore.map { "\(Int($0)) lpm" } ?? "--", systemImage: "arrow.backward.heart")
                    RouteMetricTile(title: "Después", value: session.heartRateAfter.map { "\(Int($0)) lpm" } ?? "--", systemImage: "arrow.forward.heart")
                }
            }
        }
    }

    private var routeTitle: String {
        if session.workoutTitle.localizedCaseInsensitiveContains("camina") {
            return "Caminata"
        }
        if session.workoutTitle.localizedCaseInsensitiveContains("carrera") || session.workoutTitle.localizedCaseInsensitiveContains("run") {
            return "Carrera"
        }
        return "Ruta"
    }

    private static func paceText(_ seconds: Double) -> String {
        "\(Int(seconds) / 60):\(String(format: "%02d", Int(seconds) % 60))/km"
    }
}

private struct RouteMetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 28, height: 28)
                .background(PulseTheme.primary.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct HistoryRouteMap: View {
    let routePoints: [RoutePoint]
    @State private var position: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(PulseTheme.primary, lineWidth: 5)
            }
            if let first = coordinates.first {
                Marker("Inicio", systemImage: "play.fill", coordinate: first)
                    .tint(.green)
            }
            if let last = coordinates.last {
                Marker("Fin", systemImage: "flag.checkered", coordinate: last)
                    .tint(.purple)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
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

private extension WorkoutSession {
    var hasRouteMetrics: Bool {
        !routePoints.isEmpty ||
        distanceKm != nil ||
        steps != nil ||
        activeEnergyKcal != nil ||
        averageHeartRate != nil ||
        maxHeartRate != nil ||
        heartRateBefore != nil ||
        heartRateAfter != nil
    }
}

struct WorkoutSessionSetRow: View {
    let set: SetLog
    
    private var typeText: String? {
        switch set.setType {
        case .warmUp: return "Calentamiento"
        case .dropSet: return "Drop"
        case .topSet: return "Top"
        case .backOff: return "Backoff"
        case .restPause: return "Rest-Pause"
        case .activation: return "Activación"
        case .failure: return "Fallo"
        case .work: return nil
        }
    }
    
    var body: some View {
        HStack {
            Text("Serie \(set.setNumber)")
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
            
            if let typeText {
                Text(typeText)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PulseTheme.grouped)
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Text("\(set.weightKg, specifier: "%.1f") kg x \(set.reps)")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.bold)
                .foregroundStyle(set.isPersonalRecord ? PulseTheme.accent : .white)
            
            if set.isPersonalRecord {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseTheme.accent)
            }
        }
        .padding(.vertical, 2)
    }
}
