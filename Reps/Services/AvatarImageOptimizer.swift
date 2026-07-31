import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AvatarImageOptimizer {
    /// Resizes and compresses image data to optimal dimensions (max 512x512) and quality (0.82)
    /// for high-retina avatar rendering while maintaining pristine visual quality and minimal RAM/file footprint (~40-70KB).
    static func optimize(_ data: Data, maxDimension: CGFloat = 512.0) -> Data {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return data }
        let size = uiImage.size
        guard size.width > 0, size.height > 0 else { return data }

        // If dimensions are already within boundary, compress to JPEG 0.82
        if size.width <= maxDimension && size.height <= maxDimension {
            return uiImage.jpegData(compressionQuality: 0.82) ?? data
        }

        // Calculate aspect ratio aspect-fit boundaries
        let aspect = size.width / size.height
        let targetSize: CGSize
        if aspect > 1 {
            targetSize = CGSize(width: maxDimension, height: maxDimension / aspect)
        } else {
            targetSize = CGSize(width: maxDimension * aspect, height: maxDimension)
        }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.scale = 2.0

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.82) ?? data
        #else
        return data
        #endif
    }
}
