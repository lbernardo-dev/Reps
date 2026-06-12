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
        // Create a mock WorkoutSession to keep compatibility with PRs and general metrics sharing
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
