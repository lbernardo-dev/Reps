import CoreImage.CIFilterBuiltins
import SwiftUI
import MuscleMap

struct WorkoutReceiptExerciseLine: Codable, Hashable {
    var name: String
    var sets: Int

    private enum CodingKeys: String, CodingKey {
        case name = "n"
        case sets = "s"
    }
}

struct WorkoutReceiptSharePayload: Codable, Hashable {
    var id: UUID
    var workoutTitle: String
    var date: Date
    var durationMinutes: Int
    var totalVolumeKg: Int
    var completedSetsCount: Int
    var exercises: [WorkoutReceiptExerciseLine]

    private enum CodingKeys: String, CodingKey {
        case id = "i"
        case workoutTitle = "t"
        case date = "d"
        case durationMinutes = "m"
        case totalVolumeKg = "v"
        case completedSetsCount = "c"
        case exercises = "e"
    }

    init(
        id: UUID,
        workoutTitle: String,
        date: Date,
        durationMinutes: Int,
        totalVolumeKg: Int,
        completedSetsCount: Int,
        exercises: [WorkoutReceiptExerciseLine]
    ) {
        self.id = id
        self.workoutTitle = workoutTitle
        self.date = date
        self.durationMinutes = durationMinutes
        self.totalVolumeKg = totalVolumeKg
        self.completedSetsCount = completedSetsCount
        self.exercises = exercises
    }

    init(session: WorkoutSession) {
        let logs = FitnessMetrics.completedExerciseLogs(in: session)
        self.init(
            id: session.id,
            workoutTitle: session.workoutTitle,
            date: session.date,
            durationMinutes: session.durationMinutes,
            totalVolumeKg: Int(FitnessMetrics.totalVolumeKg(for: [session])),
            completedSetsCount: FitnessMetrics.completedSets(in: session).count,
            exercises: logs.prefix(6).map { log in
                WorkoutReceiptExerciseLine(
                    name: RepsText.exerciseName(log.exercise.name, language: localizedString("en_2")),
                    sets: log.sets.count
                )
            }
        )
    }

    var receiptCode: String {
        "REPS-FIT-\(id.uuidString.prefix(8).uppercased())"
    }
}

enum WorkoutReceiptDeepLink {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6775801149")!
    static let webReceiptBaseURL = URL(string: "https://reps.fit/receipt")!

    static func qrURL(for payload: WorkoutReceiptSharePayload) -> URL {
        guard let encodedPayload = encode(payload) else {
            return appStoreURL
        }

        var components = URLComponents(url: webReceiptBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "p", value: encodedPayload)
        ]
        return components.url ?? appStoreURL
    }

    static func payload(from url: URL) -> WorkoutReceiptSharePayload? {
        guard url.scheme == "reps" || url.scheme == "https" else {
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encodedPayload = components.queryItems?.first(where: { $0.name == "p" })?.value else {
            return nil
        }

        if url.scheme == "reps" {
            guard url.host == "receipt" else { return nil }
        } else {
            guard url.host == webReceiptBaseURL.host else { return nil }
        }

        return decode(encodedPayload)
    }

    static func session(from payload: WorkoutReceiptSharePayload) -> WorkoutSession {
        WorkoutSession(
            id: payload.id,
            workoutTitle: payload.workoutTitle,
            date: payload.date,
            startedAt: payload.date.addingTimeInterval(TimeInterval(-payload.durationMinutes * 60)),
            endedAt: payload.date,
            origin: .free,
            location: .gym,
            contextTag: .normal,
            durationMinutes: payload.durationMinutes,
            sets: (0..<payload.completedSetsCount).map { index in
                SetLog(setNumber: index + 1, weightKg: 0, reps: 0, completed: true)
            },
            notes: localizedString("imported_from_a_reps_receipt_qr"),
            exerciseLogs: payload.exercises.map { line in
                ExerciseLog(
                    exercise: Exercise(
                        name: line.name,
                        muscleGroup: "General",
                        secondaryMuscles: [],
                        equipment: "StreakReps QR"
                    ),
                    notes: "",
                    sets: (0..<line.sets).map { index in
                        SetLog(setNumber: index + 1, weightKg: 0, reps: 0, completed: true)
                    }
                )
            }
        )
    }

    private static func encode(_ payload: WorkoutReceiptSharePayload) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else {
            return nil
        }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decode(_ value: String) -> WorkoutReceiptSharePayload? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WorkoutReceiptSharePayload.self, from: data)
    }
}

struct WorkoutReceiptView: View {
    private let session: WorkoutSession?
    private let importedPayload: WorkoutReceiptSharePayload?
    var gender: BodyGender = .male
    var routeMapImage: UIImage? = nil

    init(session: WorkoutSession, gender: BodyGender = .male, routeMapImage: UIImage? = nil) {
        self.session = session
        self.importedPayload = nil
        self.gender = gender
        self.routeMapImage = routeMapImage
    }

    init(payload: WorkoutReceiptSharePayload, gender: BodyGender = .male) {
        self.session = nil
        self.importedPayload = payload
        self.gender = gender
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = RepsLocalization.locale
        return formatter.string(from: sharePayload.date).uppercased()
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = RepsLocalization.locale
        return formatter.string(from: sharePayload.date)
    }
    
    private var completedSetsCount: Int {
        sharePayload.completedSetsCount
    }
    
    private var totalVolume: Int {
        sharePayload.totalVolumeKg
    }
    
    private var completedLogs: [ExerciseLog] {
        guard let session else { return [] }
        return FitnessMetrics.completedExerciseLogs(in: session)
    }

    private var exercises: [Exercise] {
        completedLogs.map(\.exercise)
    }
    
    private var heatmap: [MuscleIntensity] {
        var primary = Set<Muscle>()
        var secondary = Set<Muscle>()
        for exercise in exercises {
            let descriptor = ExerciseAnatomyDescriptor(exercise: exercise)
            primary.formUnion(descriptor.primaryMuscles)
            secondary.formUnion(descriptor.secondaryMuscles)
        }
        secondary.subtract(primary)

        return primary.map {
            MuscleIntensity(muscle: $0, intensity: 0.92, color: PulseTheme.ringStand)
        } + secondary.map {
            MuscleIntensity(muscle: $0, intensity: 0.34, color: PulseTheme.accent.opacity(0.38))
        }
    }

    private var routePoints: [RoutePoint] {
        session?.routePoints ?? []
    }

    private var isRouteReceipt: Bool {
        session?.isRouteSession ?? false
    }

    private var hasRouteMetrics: Bool {
        session?.hasRouteMetrics ?? false
    }

    private var routeTitle: String {
        session?.routeKindTitle.uppercased() ?? (localizedString("route"))
    }

    private var isTreadmillReceipt: Bool {
        guard let session else { return false }
        return session.isRouteSession && session.location != .outdoor && routePoints.isEmpty
    }

    private var sharePayload: WorkoutReceiptSharePayload {
        if let importedPayload {
            return importedPayload
        }

        guard let session else {
            return WorkoutReceiptSharePayload(
                id: UUID(),
                workoutTitle: "StreakReps Workout",
                date: .now,
                durationMinutes: 0,
                totalVolumeKg: 0,
                completedSetsCount: 0,
                exercises: []
            )
        }

        return WorkoutReceiptSharePayload(session: session)
    }

    private var qrImage: UIImage? {
        Self.makeQRCode(from: WorkoutReceiptDeepLink.qrURL(for: sharePayload).absoluteString)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header Logo
            VStack(spacing: 4) {
                Text("reps_3")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(Color.black.opacity(0.85))
                
                Text("virtual_training_ticket")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .padding(.top, 14)
            
            // Date and serial
            HStack {
                Text(dateString)
                Spacer()
                Text(timeString)
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.72))
            .padding(.horizontal, 4)
            
            dividerLine
            
            visualSummary
            .frame(height: 175)
            .allowsHitTesting(false)
            .padding(.vertical, 4)
            
            dividerLine
            
            // Exercise rows in Receipt format
            VStack(alignment: .leading, spacing: 6) {
                if !sharePayload.exercises.isEmpty {
                    ForEach(sharePayload.exercises, id: \.self) { line in
                        HStack(alignment: .bottom, spacing: 2) {
                            Text(receiptTrim(line.name, maxChars: 24))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))

                            Text(String(repeating: ".", count: max(2, 30 - line.name.count)))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.black.opacity(0.35))
                                .lineLimit(1)

                            Spacer(minLength: 2)

                            let setsLabel = localizedString("sets_2")
                            Text("\(line.sets) \(setsLabel)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color.black.opacity(0.85))
                    }
                } else if isRouteReceipt {
                    VStack(spacing: 4) {
                        Text(routeTitle)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.78))
                        Text(routeStatusText)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.46))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(localizedString("no_exercises_completed"))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 4)
            
            dividerLine
            
            // Stats section
            VStack(alignment: .leading, spacing: 6) {
                Text("stats")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.bottom, 2)
                
                statRow(title: "duration_2", value: "\(sharePayload.durationMinutes) MIN")
                if let session, let kcal = session.estimatedCalories ?? session.activeEnergyKcal, kcal > 0 {
                    statRow(title: "calories_2", value: "\(Int(kcal)) KCAL")
                }
                if !isRouteReceipt || totalVolume > 0 {
                    statRow(title: "total_volume", value: "\(totalVolume) KG")
                }
                if !isRouteReceipt || completedSetsCount > 0 {
                    statRow(title: "completed_sets", value: "\(completedSetsCount) \(localizedString("series").uppercased())")
                }
                if let session, let heartRate = session.averageHeartRate {
                    statRow(title: "avg_hr_2", value: "\(Int(heartRate)) \(localizedString("lpm").uppercased())")
                }
                if isRouteReceipt, let session {
                    if let distanceKm = session.distanceKm {
                        statRow(title: "distance_2", value: String(format: "%.2f KM", distanceKm))
                    }
                    if let pace = session.averagePaceSecondsPerKm {
                        statRow(title: "pace", value: paceText(pace).uppercased())
                    }
                    if let steps = session.steps {
                        statRow(title: "steps_2", value: "\(Int(steps))")
                    }
                    if let before = session.heartRateBefore, let after = session.heartRateAfter {
                        statRow(title: "before_after", value: "\(Int(before))/\(Int(after)) \(localizedString("lpm").uppercased())")
                    }
                }
            }
            .padding(.horizontal, 4)
            
            dividerLine
            
            // Share QR
            VStack(spacing: 6) {
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 74, height: 74)
                        .padding(6)
                        .background(Color.white.opacity(0.9))
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 54, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .frame(width: 86, height: 86)
                }
                
                Text(sharePayload.receiptCode)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .padding(18)
        .padding(.bottom, 6)
        .background(Color.white.opacity(0.92))
        .clipShape(SerratedCardShape(cornerRadius: 16, toothWidth: 8, toothHeight: 6))
        .overlay(
            SerratedCardShape(cornerRadius: 16, toothWidth: 8, toothHeight: 6)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
    }
    
    private var dividerLine: some View {
        Text(String(repeating: "-", count: 32))
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.24))
            .lineLimit(1)
            .frame(height: 12)
    }

    @ViewBuilder
    private var visualSummary: some View {
        if isRouteReceipt {
            ReceiptRoutePanel(routePoints: routePoints, title: routeTitle, isTreadmill: isTreadmillReceipt, mapSnapshot: routeMapImage)
        } else {
            HStack(spacing: 16) {
                Spacer()
                BodyView(gender: gender, side: .front, style: .repsReceipt)
                    .heatmap(heatmap, configuration: .repsVolumeReceipt)
                    .showSubGroups()
                    .frame(width: 80, height: 165)
                    .scaleEffect(1.08)

                BodyView(gender: gender, side: .back, style: .repsReceipt)
                    .heatmap(heatmap, configuration: .repsVolumeReceipt)
                    .showSubGroups()
                    .frame(width: 80, height: 165)
                    .scaleEffect(1.08)
                Spacer()
            }
        }
    }

    private var routeStatusText: String {
        if routePoints.count >= 2 {
            return localizedString("gps_map_recorded")
        }
        if isTreadmillReceipt {
            return localizedString("no_gps_treadmill")
        }
        return localizedString("no_gps_trace_saved")
    }
    
    private func statRow(title: String, value: String) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(localizedKey(title))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text(String(repeating: ".", count: max(2, 28 - title.count)))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.black.opacity(0.3))
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(Color.black.opacity(0.8))
    }
    
    private func receiptTrim(_ text: String, maxChars: Int) -> String {
        if text.count <= maxChars {
            return text.uppercased()
        }
        return text.prefix(maxChars - 3).uppercased() + "..."
    }

    private func paceText(_ seconds: Double) -> String {
        "\(Int(seconds) / 60):\(String(format: "%02d", Int(seconds) % 60))/km"
    }

    private static func makeQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else {
            return nil
        }

        let transformed = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let image = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }

        return UIImage(cgImage: image)
    }
}

private struct ReceiptRouteTrace: View {
    let routePoints: [RoutePoint]
    var hasMapBackground: Bool = false

    var body: some View {
        ZStack {
            if !hasMapBackground {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.16), lineWidth: 1)
                    )
            }

            GeometryReader { proxy in
                let points = normalizedPoints(in: proxy.size)
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    hasMapBackground ? Color.white.opacity(0.95) : Color.black.opacity(0.76),
                    style: StrokeStyle(lineWidth: hasMapBackground ? 3.5 : 4, lineCap: .round, lineJoin: .round)
                )

                if let first = points.first {
                    Circle()
                        .fill(hasMapBackground ? Color.white : Color.green.opacity(0.9))
                        .frame(width: 9, height: 9)
                        .position(first)
                }

                if let last = points.last {
                    Circle()
                        .fill(hasMapBackground ? PulseTheme.accent : PulseTheme.hrZones[0])
                        .frame(width: 11, height: 11)
                        .position(last)
                }
            }
            .padding(12)

            VStack {
                HStack {
                    Text("route")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(hasMapBackground ? Color.white.opacity(0.85) : Color.black.opacity(0.5))
                        .padding(hasMapBackground ? 3 : 0)
                        .background(hasMapBackground ? Color.black.opacity(0.45) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 3))
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !routePoints.isEmpty else { return [] }
        let minLat = routePoints.map(\.latitude).min() ?? 0
        let maxLat = routePoints.map(\.latitude).max() ?? minLat
        let minLon = routePoints.map(\.longitude).min() ?? 0
        let maxLon = routePoints.map(\.longitude).max() ?? minLon
        let latSpan = max(maxLat - minLat, 0.000_01)
        let lonSpan = max(maxLon - minLon, 0.000_01)

        return routePoints.map { point in
            CGPoint(
                x: ((point.longitude - minLon) / lonSpan) * size.width,
                y: (1 - ((point.latitude - minLat) / latSpan)) * size.height
            )
        }
    }
}

private struct ReceiptRoutePanel: View {
    let routePoints: [RoutePoint]
    let title: String
    let isTreadmill: Bool
    var mapSnapshot: UIImage? = nil

    private var hasTrace: Bool {
        routePoints.count >= 2
    }

    private var hasMap: Bool {
        mapSnapshot != nil && hasTrace
    }

    var body: some View {
        ZStack {
            if let snapshot = mapSnapshot, hasTrace {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.16), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.16), lineWidth: 1)
                    )
            }

            if hasMap {
                // The route polyline is already baked into the snapshot image
                // (correctly projected), so no overlay trace is needed here.
                EmptyView()
            } else if hasTrace {
                ReceiptRouteTrace(routePoints: routePoints, hasMapBackground: false)
                    .padding(10)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: isTreadmill ? "figure.run.treadmill" : "map")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.32))
                    Text(emptyTitle)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.55))
                    Text(emptySubtitle)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.42))
                }
                .multilineTextAlignment(.center)
            }

            VStack {
                HStack {
                    Text(localizedKey(title))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(hasMap ? Color.white.opacity(0.9) : Color.black.opacity(0.58))
                        .padding(hasMap ? 3 : 0)
                        .background(hasMap ? Color.black.opacity(0.45) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 3))
                    Spacer()
                    Text(hasTrace ? "\(routePoints.count) GPS" : emptyBadge)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(hasMap ? Color.white.opacity(0.85) : Color.black.opacity(0.46))
                        .padding(hasMap ? 3 : 0)
                        .background(hasMap ? Color.black.opacity(0.45) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
            }
            .padding(10)
        }
    }

    private var emptyTitle: String {
        if isTreadmill {
            return localizedString("treadmill_no_gps")
        }
        return localizedString("no_gps_map")
    }

    private var emptySubtitle: String {
        if isTreadmill {
            return localizedString("stationary_workout")
        }
        return localizedString("no_saved_route_points")
    }

    private var emptyBadge: String {
        if isTreadmill {
            return localizedString("treadmill")
        }
        return localizedString("no_gps")
    }
}

// Receipt specific styling helpers
extension BodyViewStyle {
    static let repsReceipt = BodyViewStyle(
        defaultFillColor: Color.black.opacity(0.10),
        strokeColor: Color.white.opacity(0.92),
        strokeWidth: 0.55,
        selectionColor: PulseTheme.hrZones[0],
        selectionStrokeColor: Color.white.opacity(0.92),
        selectionStrokeWidth: 0.8,
        headColor: Color.black.opacity(0.15),
        hairColor: Color.black.opacity(0.08)
    )
}

extension HeatmapConfiguration {
    static let repsVolumeReceipt = HeatmapConfiguration(
        colorScale: .repsReceiptVolume,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.6
    )
}

extension HeatmapColorScale {
    static let repsReceiptVolume = HeatmapColorScale(colors: [
        PulseTheme.hrZones[0],
        PulseTheme.hrZones[0],
        PulseTheme.hrZones[0]
    ])
}

// MARK: - Serrated saw-tooth card shape
struct SerratedCardShape: Shape {
    var cornerRadius: CGFloat = 16
    var toothWidth: CGFloat = 8
    var toothHeight: CGFloat = 6
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Start at top left corner (after the radius)
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
        
        // Top right corner
        path.addArc(tangent1End: CGPoint(x: w, y: 0),
                    tangent2End: CGPoint(x: w, y: cornerRadius),
                    radius: cornerRadius)
        
        // Right edge down to bottom right (excluding the tooth depth)
        path.addLine(to: CGPoint(x: w, y: h - toothHeight))
        
        // Bottom edge - Serrated teeth going from right (w) to left (0)
        let numberOfTeeth = max(2, Int(w / toothWidth))
        let actualToothWidth = w / CGFloat(numberOfTeeth)
        
        for i in 0..<numberOfTeeth {
            let currentX = w - CGFloat(i) * actualToothWidth
            let nextX = w - CGFloat(i + 1) * actualToothWidth
            let midX = (currentX + nextX) / 2
            
            // Draw tooth peak
            path.addLine(to: CGPoint(x: midX, y: h))
            // Draw tooth base
            path.addLine(to: CGPoint(x: nextX, y: h - toothHeight))
        }
        
        // Left edge up to top left corner
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        
        // Top left corner
        path.addArc(tangent1End: CGPoint(x: 0, y: 0),
                    tangent2End: CGPoint(x: cornerRadius, y: 0),
                    radius: cornerRadius)
        
        path.closeSubpath()
        return path
    }
}
