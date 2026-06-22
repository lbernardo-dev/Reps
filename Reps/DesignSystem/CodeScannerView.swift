import SwiftUI
import Vision
import VisionKit

/// Result of scanning/detecting a barcode or QR code.
struct ScannedCode: Equatable {
    let value: String
    let type: GymPass.CodeType
}

/// Live barcode / QR scanner backed by VisionKit's `DataScannerViewController`
/// (available on iOS 17). Returns the first recognised code with its mapped
/// `GymPass.CodeType`. Request camera permission via `PermissionService`
/// **before** presenting this view.
struct CodeScannerView: UIViewControllerRepresentable {
    let onScan: (ScannedCode) -> Void
    let onCancel: () -> Void

    /// Whether the live scanner can run on this device (camera + Neural Engine).
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (ScannedCode) -> Void
        private var didScan = false

        init(onScan: @escaping (ScannedCode) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(item)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let first = addedItems.first else { return }
            handle(first)
        }

        private func handle(_ item: RecognizedItem) {
            guard !didScan, case let .barcode(barcode) = item else { return }
            guard let value = barcode.payloadStringValue, !value.isEmpty else { return }
            didScan = true
            let type = CodeSymbologyMapper.codeType(for: barcode.observation.symbology)
            HapticService.notification(.success)
            onScan(ScannedCode(value: value, type: type))
        }
    }
}

/// Detects a barcode / QR code inside a still image using the Vision framework.
/// Used for the "import from photo" flow.
enum BarcodeImageDetector {
    static func detect(in image: UIImage) -> ScannedCode? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgImageOrientation(image.imageOrientation))
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let result = (request.results)?
            .compactMap({ $0 as VNBarcodeObservation })
            .first(where: { ($0.payloadStringValue?.isEmpty == false) }),
            let value = result.payloadStringValue
        else { return nil }
        return ScannedCode(value: value, type: CodeSymbologyMapper.codeType(for: result.symbology))
    }

    private static func cgImageOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

/// Maps Vision barcode symbologies to the two code families the app renders.
enum CodeSymbologyMapper {
    static func codeType(for symbology: VNBarcodeSymbology) -> GymPass.CodeType {
        switch symbology {
        case .qr, .aztec, .dataMatrix, .microQR:
            return .qr
        default:
            return .barcode
        }
    }
}
