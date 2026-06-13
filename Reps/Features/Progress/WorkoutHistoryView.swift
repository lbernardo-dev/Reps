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

    private var rowIcon: String {
        if session.isRouteSession {
            return session.routeSystemImage
        }
        return session.location == .home ? "house.fill" : "dumbbell.fill"
    }

    private var rowDetailText: String {
        if session.isRouteSession {
            var parts = ["\(session.durationMinutes) min"]
            if let distanceKm = session.distanceKm {
                parts.append(String(format: "%.2f km", distanceKm))
            }
            if let pace = session.averagePaceSecondsPerKm {
                parts.append(Self.paceText(pace))
            }
            if let steps = session.steps {
                parts.append("\(Int(steps)) pasos")
            }
            parts.append(session.date.formatted(date: .abbreviated, time: .shortened))
            return parts.joined(separator: " · ")
        }
        return "\(session.durationMinutes) min · \(exerciseCount) ej · \(session.date.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(session.isRouteSession ? PulseTheme.accent.opacity(0.14) : (session.location == .home ? PulseTheme.accent.opacity(0.12) : PulseTheme.primary.opacity(0.12)))
                Image(systemName: rowIcon)
                    .font(.subheadline)
                    .foregroundStyle(session.isRouteSession || session.location == .home ? PulseTheme.accent : PulseTheme.primary)
            }
            .frame(width: 42, height: 42)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(session.isRouteSession ? session.routeKindTitle : session.workoutTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(rowDetailText)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private static func paceText(_ seconds: Double) -> String {
        "\(Int(seconds) / 60):\(String(format: "%02d", Int(seconds) % 60))/km"
    }
}

struct WorkoutSessionDetailView: View {
    @Environment(AppStore.self) private var store
    let session: WorkoutSession
    @State private var isShowingShareSheet = false
    @State private var shareImage: UIImage?

    private var exerciseLogs: [ExerciseLog] {
        FitnessMetrics.completedExerciseLogs(in: session)
    }

    var body: some View {
        Group {
            if session.isRouteSession {
                RouteWorkoutSummaryView(session: session, shareAction: shareSession)
            } else {
                strengthSessionDetail
            }
        }
        .navigationTitle(session.isRouteSession ? "" : "Registro")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(session.isRouteSession)
        .toolbar(session.isRouteSession ? .hidden : .visible, for: .navigationBar)
        .mainTabBarHidden()
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = shareImage {
                ActivityViewController(activityItems: [image])
            }
        }
    }

    private var strengthSessionDetail: some View {
        ScrollView {
            VStack(spacing: 18) {
                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(session.workoutTitle)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .lineLimit(2)

                            Spacer()

                            Button(action: shareSession) {
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

                        if exerciseLogs.isEmpty {
                            PulseEmptyState(
                                title: "Sin ejercicios registrados",
                                message: "Esta sesión no contiene series de fuerza.",
                                systemImage: "list.bullet.clipboard"
                            )
                        } else {
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
            }
            .padding(20)
            .padding(.bottom, 112)
        }
        .screenBackground()
    }

    private func shareSession() {
        guard store.requireFeature(.shareCards, source: .shareCards) else {
            return
        }
        shareImage = WorkoutShareImageRenderer.render(session: session)
        isShowingShareSheet = true
    }

    private static func paceText(_ seconds: Double) -> String {
        "\(Int(seconds) / 60):\(String(format: "%02d", Int(seconds) % 60))"
    }
}

struct RouteWorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    let shareAction: () -> Void
    @State private var showExpandedMap = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                RouteWorkoutHero(
                    session: session,
                    backAction: { dismiss() },
                    shareAction: shareAction,
                    mapAction: { showExpandedMap = true }
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("Workout Details")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }

                    RouteWorkoutDetailsCard(session: session)

                    if !session.routeSplits.isEmpty {
                        RouteWorkoutSplitsCard(splits: session.routeSplits)
                    }

                    if session.isOutdoorRouteSession {
                        RouteWorkoutMapCard(session: session) {
                            showExpandedMap = true
                        }
                    }

                    if let notes = session.notes, !notes.isEmpty {
                        RouteWorkoutNotesCard(notes: notes)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 112)
                .offset(y: -8)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.black)
        .sheet(isPresented: $showExpandedMap) {
            RouteWorkoutExpandedMap(session: session)
        }
    }
}

private struct RouteWorkoutHero: View {
    let session: WorkoutSession
    let backAction: () -> Void
    let shareAction: () -> Void
    let mapAction: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RouteWorkoutMapBackdrop(session: session)
                .frame(height: 610)
                .contentShape(Rectangle())
                .onTapGesture(perform: mapAction)

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.82),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "location.north.circle")
                        .font(.system(size: 19, weight: .semibold))
                    Text(session.routeLocationText)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(.white)

                Text(session.appleFitnessRouteTitle)
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(session.distanceKm.map { Self.distanceText($0) } ?? "--")
                    .font(.system(size: 45, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.62, green: 1.0, blue: 0.03))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 6) {
                    Text(session.routeDateRangeText)
                    Image(systemName: "applewatch")
                    Text(session.routeSourceText)
                }
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.66)

                if session.hasRouteSensorSummary {
                    HStack(spacing: 16) {
                        if let averageHeartRate = session.averageHeartRate {
                            RouteHeroSensor(
                                icon: "heart.fill",
                                iconColor: Color(red: 1.0, green: 0.15, blue: 0.36),
                                value: "\(Int(averageHeartRate))",
                                label: "Avg. Heart Rate"
                            )
                        }

                        if let steps = session.steps {
                            RouteHeroSensor(
                                icon: "shoeprints.fill",
                                iconColor: Color(red: 0.22, green: 0.78, blue: 1.0),
                                value: Self.compactNumber(steps),
                                label: "Steps"
                            )
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)

            HStack {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: shareAction) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if session.isOutdoorRouteSession {
                    Button(action: mapAction) {
                        Image(systemName: "map")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 74, height: 74)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 610)
    }

    private static func distanceText(_ distanceKm: Double) -> String {
        "\(localizedDecimal(distanceKm, fractionDigits: 2))KM"
    }

    private static func compactNumber(_ value: Double) -> String {
        if value >= 10_000 {
            return "\(localizedDecimal(value / 1_000, fractionDigits: 1))K"
        }
        return "\(Int(value))"
    }

    private static func localizedDecimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

private struct RouteHeroSensor: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(value)
                    .foregroundStyle(.white)
            }
            .font(.system(size: 20, weight: .semibold, design: .rounded))

            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.48))
        }
    }
}

private struct RouteWorkoutMapBackdrop: View {
    let session: WorkoutSession

    var body: some View {
        if session.isOutdoorRouteSession {
            HistoryRouteMap(routePoints: session.routePoints, style: .hero)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.11, blue: 0.13),
                        Color(red: 0.02, green: 0.02, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: session.location == .outdoor ? "map" : "figure.run.treadmill")
                    .font(.system(size: 96, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.18))

                Text(session.location == .outdoor ? "No GPS Route" : "Treadmill Workout")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.top, 148)
            }
        }
    }
}

private struct RouteWorkoutDetailsCard: View {
    let session: WorkoutSession

    private let columns = [
        GridItem(.flexible(), spacing: 18, alignment: .topLeading),
        GridItem(.flexible(), spacing: 18, alignment: .topLeading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
            RouteWorkoutMetric(title: "Workout Time", value: session.workoutTimeText, color: Color(red: 1.0, green: 0.90, blue: 0.03))
            RouteWorkoutMetric(title: "Distance", value: session.distanceKm.map { "\(Self.localizedDecimal($0, fractionDigits: 2))KM" } ?? "--", color: Color(red: 0.0, green: 0.72, blue: 1.0))
            RouteWorkoutMetric(title: "Active Kilocalories", value: session.activeKilocaloriesText, color: Color(red: 1.0, green: 0.08, blue: 0.34))
            RouteWorkoutMetric(title: "Total Kilocalories", value: session.totalKilocaloriesText, color: Color(red: 1.0, green: 0.08, blue: 0.34))
            RouteWorkoutMetric(title: "Elevation Gain", value: "--", color: Color(red: 0.33, green: 1.0, blue: 0.36))
            RouteWorkoutMetric(title: "HR Recovery", value: session.heartRateRecoveryText, color: Color(red: 1.0, green: 0.55, blue: 0.0))
            RouteWorkoutMetric(title: "Avg. Cadence", value: session.averageCadenceText, color: Color(red: 0.0, green: 0.86, blue: 0.90))
            RouteWorkoutMetric(title: "Avg. Pace", value: session.averagePaceSecondsPerKm.map(Self.paceText) ?? "--", color: Color(red: 0.0, green: 0.86, blue: 0.90))
            RouteWorkoutMetric(title: "Avg. Heart Rate", value: session.averageHeartRate.map { "\(Int($0))BPM" } ?? "--", color: Color(red: 1.0, green: 0.20, blue: 0.30))
            RouteWorkoutMetric(title: "Max Heart Rate", value: session.maxHeartRate.map { "\(Int($0))BPM" } ?? "--", color: Color(red: 1.0, green: 0.20, blue: 0.30))
        }
        .padding(24)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private static func paceText(_ seconds: Double) -> String {
        "\(Int(seconds) / 60)'\(String(format: "%02d", Int(seconds) % 60))\"/KM"
    }

    private static func localizedDecimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

private struct RouteWorkoutSplitsCard: View {
    let splits: [RouteSplit]

    private var showsHeartRate: Bool { splits.contains { $0.averageHeartRate != nil } }
    private var showsCadence: Bool { splits.contains { $0.cadenceSpm != nil } }
    private var showsSensors: Bool { showsHeartRate || showsCadence }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Splits")
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
                        Text("Time")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Pace")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showsHeartRate {
                        Image(systemName: "heart.fill")
                            .frame(width: 52, alignment: .trailing)
                    }
                    if showsCadence {
                        Image(systemName: "figure.run")
                            .frame(width: 52, alignment: .trailing)
                    }
                    Text("Distance")
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
                            Text(Self.timeText(split.elapsedSeconds))
                                .foregroundStyle(Color(red: 1.0, green: 0.90, blue: 0.03))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(Self.paceText(split.paceSecondsPerKm))
                            .foregroundStyle(Color(red: 0.0, green: 0.86, blue: 0.90))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if showsHeartRate {
                            Text(split.averageHeartRate.map { "\(Int($0.rounded()))" } ?? "--")
                                .foregroundStyle(Color(red: 1.0, green: 0.20, blue: 0.30))
                                .frame(width: 52, alignment: .trailing)
                        }
                        if showsCadence {
                            Text(split.cadenceSpm.map { "\(Int($0.rounded()))" } ?? "--")
                                .foregroundStyle(Color(red: 0.62, green: 1.0, blue: 0.30))
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
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private static func timeText(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded()), 0)
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }

    private static func paceText(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded()), 0)
        return "\(value / 60)'\(String(format: "%02d", value % 60))\""
    }
}

private struct RouteWorkoutMapCard: View {
    let session: WorkoutSession
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onExpand) {
                HStack(spacing: 8) {
                    Text("Map")
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
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(12)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture(perform: onExpand)
        }
    }
}

private struct RouteWorkoutExpandedMap: View {
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
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(session.distanceKm.map { "\(Self.localizedDecimal($0, fractionDigits: 2)) KM \(session.appleFitnessRouteTitle)" } ?? session.appleFitnessRouteTitle)
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

    private static func localizedDecimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

private struct RouteWorkoutMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.system(size: 42, weight: .regular, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RouteWorkoutNotesCard: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(.white)
            Text(notes)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
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
                    .stroke(style == .card ? PulseTheme.primary : Color(red: 1.0, green: 0.88, blue: 0.0), lineWidth: style == .card ? 5 : 7)
            }
            if let first = coordinates.first {
                Annotation("Inicio", coordinate: first) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: style == .card ? 18 : 26, height: style == .card ? 18 : 26)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if let last = coordinates.last {
                Annotation("Fin", coordinate: last) {
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

private struct RouteSplit: Identifiable, Hashable {
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

private extension WorkoutSession {
    var appleFitnessRouteTitle: String {
        let normalizedTitle = workoutTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let isRun = normalizedTitle.localizedCaseInsensitiveContains("carrera") ||
            normalizedTitle.localizedCaseInsensitiveContains("run")
        let isWalk = normalizedTitle.localizedCaseInsensitiveContains("camina") ||
            normalizedTitle.localizedCaseInsensitiveContains("walk")

        if isRun {
            return location == .outdoor ? "Outdoor Run" : "Treadmill Run"
        }
        if isWalk {
            return location == .outdoor ? "Outdoor Walk" : "Treadmill Walk"
        }
        return location == .outdoor ? "Outdoor Workout" : "Indoor Workout"
    }

    var routeLocationText: String {
        location == .outdoor ? "Outdoor" : "Indoor"
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
        let kcal = activeEnergyKcal ?? estimatedCalories
        return kcal.map { "\(Int($0))KCAL" } ?? "--"
    }

    var totalKilocaloriesText: String {
        if let estimatedCalories {
            return "\(Int(estimatedCalories))KCAL"
        }
        if let activeEnergyKcal {
            return "\(Int(activeEnergyKcal * 1.12))KCAL"
        }
        return "--"
    }

    var averageCadenceText: String {
        guard let steps, durationMinutes > 0 else {
            return "--"
        }
        return "\(Int(steps / Double(durationMinutes)))SPM"
    }

    /// Heart-rate recovery: drop from peak (or average) HR to the post-workout HR.
    var heartRateRecoveryText: String {
        guard let after = heartRateAfter else { return "--" }
        let peak = maxHeartRate ?? averageHeartRate
        guard let peak, peak > after else { return "--" }
        return "\(Int((peak - after).rounded()))BPM"
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
