import UIKit
import SwiftUI
import MapKit

struct WorkoutShareImageRenderer {
    private static let receiptWidth: CGFloat = 375
    private static let renderScale: CGFloat = 3.0

    @MainActor
    static func render(session: WorkoutSession) -> UIImage {
        let view = WorkoutReceiptView(session: session)
        return renderReceipt(view)
    }

    @MainActor
    static func render(payload: WorkoutReceiptSharePayload) -> UIImage {
        let view = WorkoutReceiptView(payload: payload)
        return renderReceipt(view)
    }

    @MainActor
    static func render(title: String, duration: Int, volume: Int, sets: Int) -> UIImage {
        let mockSession = WorkoutSession(
            id: UUID(),
            workoutTitle: title,
            date: Date(),
            startedAt: Date().addingTimeInterval(-Double(duration * 60)),
            endedAt: Date(),
            origin: .free,
            location: .gym,
            contextTag: .normal,
            durationMinutes: duration,
            sets: [],
            notes: nil,
            exerciseLogs: []
        )
        let view = WorkoutReceiptView(session: mockSession)
        return renderReceipt(view)
    }

    // Returns the best shareable image for a session:
    // route sessions → map snapshot with polyline; others → receipt card.
    @MainActor
    static func renderForFeed(session: WorkoutSession) async -> UIImage {
        if session.isOutdoorRouteSession, !session.routePoints.isEmpty {
            if let mapImg = await renderRouteMap(session: session) { return mapImg }
        }
        return render(session: session)
    }

    // Returns the receipt visual-summary map with the route polyline baked in.
    // The polyline is projected with `snap.point(for:)` so it stays perfectly aligned
    // with the underlying map tiles (a linearly-stretched SwiftUI overlay does not).
    static func renderRouteMapBackground(routePoints: [RoutePoint]) async -> UIImage? {
        guard routePoints.count >= 2 else { return nil }
        let coords = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.004),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.004)
        )
        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(center: center, span: span)
        opts.size = CGSize(width: 375, height: 175)
        opts.scale = 2.0

        guard let snap = try? await MKMapSnapshotter(options: opts).start() else { return nil }

        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2.0
        return UIGraphicsImageRenderer(size: opts.size, format: fmt).image { ctx in
            snap.image.draw(at: .zero)
            let cg = ctx.cgContext
            let mapped = coords.map { snap.point(for: $0) }

            // Route polyline (white)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            cg.setLineWidth(3.5); cg.setLineCap(.round); cg.setLineJoin(.round)
            cg.move(to: mapped[0])
            mapped.dropFirst().forEach { cg.addLine(to: $0) }
            cg.strokePath()

            // Start dot (white)
            if let f = mapped.first {
                cg.setFillColor(UIColor.white.cgColor)
                cg.addEllipse(in: CGRect(x: f.x - 4.5, y: f.y - 4.5, width: 9, height: 9)); cg.fillPath()
            }
            // End dot (lime)
            if let l = mapped.last {
                cg.setFillColor(UIColor(red: 0.69, green: 0.99, blue: 0.16, alpha: 1).cgColor)
                cg.addEllipse(in: CGRect(x: l.x - 5.5, y: l.y - 5.5, width: 11, height: 11)); cg.fillPath()
            }
        }
    }

    // Async render that includes a real map background for outdoor route sessions.
    @MainActor
    static func renderReceiptAsync(session: WorkoutSession) async -> UIImage {
        var mapImage: UIImage? = nil
        if session.isOutdoorRouteSession {
            mapImage = await renderRouteMapBackground(routePoints: session.routePoints)
        }
        let view = WorkoutReceiptView(session: session, routeMapImage: mapImage)
        return renderReceipt(view)
    }

    static func renderRouteMap(session: WorkoutSession) async -> UIImage? {
        let pts = session.routePoints
        guard pts.count >= 2 else { return nil }

        let coords = pts.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                             longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.45, 0.004),
            longitudeDelta: max((maxLon - minLon) * 1.45, 0.004)
        )
        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(center: center, span: span)
        opts.size = CGSize(width: 375, height: 375)
        opts.scale = 3.0

        guard let snap = try? await MKMapSnapshotter(options: opts).start() else { return nil }

        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 3.0
        return UIGraphicsImageRenderer(size: opts.size, format: fmt).image { ctx in
            snap.image.draw(at: .zero)
            let cg = ctx.cgContext

            // Route polyline
            let mapped = coords.map { snap.point(for: $0) }
            cg.setStrokeColor(UIColor(red: 0.12, green: 0.92, blue: 0.94, alpha: 1).cgColor)
            cg.setLineWidth(5); cg.setLineCap(.round); cg.setLineJoin(.round)
            cg.move(to: mapped[0])
            mapped.dropFirst().forEach { cg.addLine(to: $0) }
            cg.strokePath()

            // Start dot (white)
            if let f = mapped.first {
                cg.setFillColor(UIColor.white.cgColor)
                cg.addEllipse(in: CGRect(x: f.x - 6, y: f.y - 6, width: 12, height: 12)); cg.fillPath()
            }
            // End dot (green)
            if let l = mapped.last {
                cg.setFillColor(UIColor(red: 0.57, green: 0.91, blue: 0.16, alpha: 1).cgColor)
                cg.addEllipse(in: CGRect(x: l.x - 8, y: l.y - 8, width: 16, height: 16)); cg.fillPath()
            }

            // Stats overlay (distance + duration bottom-left)
            let dist = session.distanceKm.map { String(format: "%.2f km", $0) } ?? ""
            let dur  = "\(Int(session.durationMinutes)) min"
            let label = [dist, dur].filter { !$0.isEmpty }.joined(separator: "  ·  ")
            if !label.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let str = NSString(string: label)
                let sz = str.size(withAttributes: attrs)
                let pad: CGFloat = 10
                let rect = CGRect(x: pad - 4, y: opts.size.height - sz.height - pad - 4,
                                  width: sz.width + 8, height: sz.height + 6)
                cg.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
                cg.fillEllipse(in: rect.insetBy(dx: -4, dy: -2))
                str.draw(at: CGPoint(x: rect.minX + 4, y: rect.minY + 3), withAttributes: attrs)
            }
        }
    }

    @MainActor
    static func renderPR(exerciseName: String, weightKg: Double, reps: Int, date: Date) -> UIImage {
        let view = PRShareCardView(exerciseName: exerciseName, weightKg: weightKg, reps: reps, date: date)
        return renderReceipt(view)
    }

    @MainActor
    private static func renderReceipt<Content: View>(_ view: Content) -> UIImage {
        let content = view
            .frame(width: receiptWidth)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: receiptWidth, height: nil)
        renderer.scale = renderScale

        if let image = renderer.uiImage, image.isUsableReceiptRender {
            return image
        }

        return fallbackReceiptImage()
    }

    private static func fallbackReceiptImage() -> UIImage {
        let size = CGSize(width: receiptWidth, height: 560)
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 32, weight: .black),
                .foregroundColor: UIColor.black.withAlphaComponent(0.85),
                .kern: 6
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.black.withAlphaComponent(0.55)
            ]

            let title = NSString(string: "REPS")
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: 180),
                withAttributes: titleAttributes
            )

            let subtitle = NSString(string: "RECEIPT RENDER UNAVAILABLE")
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            subtitle.draw(
                at: CGPoint(x: (size.width - subtitleSize.width) / 2, y: 236),
                withAttributes: subtitleAttributes
            )
        }
    }
}

private struct PRShareCardView: View {
    let exerciseName: String
    let weightKg: Double
    let reps: Int
    let date: Date

    private var weightText: String {
        weightKg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weightKg)) kg"
            : String(format: "%.1f kg", weightKg)
    }

    private var oneRepMaxText: String {
        let orm = FitnessMetrics.estimatedOneRepMax(weightKg: weightKg, reps: reps)
        return "1RM est. \(Int(orm)) kg"
    }

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                // Top accent bar
                PulseTheme.accent
                    .frame(height: 6)

                VStack(spacing: 24) {
                    // Trophy + label
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(PulseTheme.accent.opacity(0.14))
                                .frame(width: 80, height: 80)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(PulseTheme.accent)
                        }

                        Text("NUEVO RÉCORD PERSONAL")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .kerning(2)
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .padding(.top, 32)

                    // Exercise name
                    Text(exerciseName.uppercased())
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 24)

                    // Weight × reps
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(weightText)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(PulseTheme.accent)
                        Text("×")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("\(reps) reps")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // 1RM estimate
                    Text(oneRepMaxText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))

                    Spacer(minLength: 0)

                    // Footer
                    HStack {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                        Spacer()
                        Text("StreakReps")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(PulseTheme.accent.opacity(0.7))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .frame(width: 375, height: 480)
    }
}

private extension UIImage {
    var isUsableReceiptRender: Bool {
        guard size.width > 10, size.height > 10, let cgImage else {
            return false
        }

        let sampleWidth = 8
        let sampleHeight = 8
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return true
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var luminanceTotal = 0.0
        var alphaTotal = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index]) / 255.0
            let green = Double(pixels[index + 1]) / 255.0
            let blue = Double(pixels[index + 2]) / 255.0
            let alpha = Double(pixels[index + 3]) / 255.0
            luminanceTotal += (0.2126 * red + 0.7152 * green + 0.0722 * blue) * alpha
            alphaTotal += alpha
        }

        let count = Double(sampleWidth * sampleHeight)
        return alphaTotal / count > 0.05 && luminanceTotal / count > 0.05
    }
}
