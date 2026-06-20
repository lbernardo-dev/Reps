import UIKit
import SwiftUI

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
            UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1).setFill()
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
                Color(red: 0.73, green: 1.0, blue: 0.0)
                    .frame(height: 6)

                VStack(spacing: 24) {
                    // Trophy + label
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.73, green: 1.0, blue: 0.0).opacity(0.14))
                                .frame(width: 80, height: 80)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(Color(red: 0.73, green: 1.0, blue: 0.0))
                        }

                        Text("NUEVO RÉCORD PERSONAL")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .kerning(2)
                            .foregroundStyle(Color(red: 0.73, green: 1.0, blue: 0.0))
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
                            .foregroundStyle(Color(red: 0.73, green: 1.0, blue: 0.0))
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
                        Text("StreakRep")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.73, green: 1.0, blue: 0.0).opacity(0.7))
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
