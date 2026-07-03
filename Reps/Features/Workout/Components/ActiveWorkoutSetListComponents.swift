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

struct ActiveSetRowsList: View {
    let setIndices: [Int]
    let trackingType: Exercise.TrackingType
    let isSessionStarted: Bool
    let setBinding: (Int) -> Binding<SetLog>
    let onCompletionChanged: (Int, Bool) -> Void

    var body: some View {
        ForEach(setIndices, id: \.self) { setIndex in
            SetRow(set: setBinding(setIndex), trackingType: trackingType) { completed in
                onCompletionChanged(setIndex, completed)
            }
            .disabled(!isSessionStarted)
        }
    }
}


struct ActiveAdvancedSetFieldsList: View {
    let setIndices: [Int]
    let showSetType: Bool
    let showRPE: Bool
    let showRIR: Bool
    let showTempo: Bool
    let setBinding: (Int) -> Binding<SetLog>

    var body: some View {
        VStack(spacing: 10) {
            ForEach(setIndices, id: \.self) { setIndex in
                AdvancedSetFields(
                    set: setBinding(setIndex),
                    showSetType: showSetType,
                    showRPE: showRPE,
                    showRIR: showRIR,
                    showTempo: showTempo
                )
            }
        }
        .padding(.top, 8)
    }
}

