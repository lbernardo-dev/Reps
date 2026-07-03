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

struct ExerciseReplacementTarget: Identifiable {
    let index: Int
    var id: Int { index }
}


struct UndoSetContext {
    let exerciseIndex: Int
    let setIndex: Int
    let previousLastSetCompletedAtSeconds: Int?
}

