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

struct ActiveGymPassCard: View {
    let pass: GymPass

    var body: some View {
        HStack(spacing: 12) {
            ActiveCodePreview(value: pass.codeValue, type: pass.codeType)
                .frame(width: 84, height: 84)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Label("tarjeta_gym", systemImage: pass.codeType == .qr ? "qrcode" : "barcode")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.accent)
                Text(pass.gymName)
                    .font(.headline)
                    .lineLimit(1)
                Text(pass.membershipID)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}


struct ActiveCodePreview: View {
    let value: String
    let type: GymPass.CodeType

    var body: some View {
        if let image = generatedImage {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Image(systemName: type == .qr ? "qrcode" : "barcode")
                .font(.largeTitle)
                .foregroundStyle(.black)
        }
    }

    private var generatedImage: UIImage? {
        let filterName = type == .qr ? "CIQRCodeGenerator" : "CICode128BarcodeGenerator"
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        guard let output = filter.outputImage else { return nil }
        return UIImage(ciImage: output.transformed(by: CGAffineTransform(scaleX: 8, y: 8)))
    }
}

