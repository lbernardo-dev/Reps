import SwiftUI

/// Which rest countdown is currently running — the short recovery between
/// sets of the same exercise, or the longer window used to change machine /
/// position before the next exercise.
enum RestPhaseKind: Equatable {
    case betweenSets
    case exerciseChange
}
