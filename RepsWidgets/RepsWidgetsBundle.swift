import WidgetKit
import SwiftUI

func nextMidnight() -> Date {
    Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
}

@main
struct RepsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RepsWorkoutWidget()
        RepsBatteryWidget()
        RepsStreakWidget()
        RepsFriendsWidget()
        RepsStartWorkoutControl()
        RepsWorkoutLiveActivity()
    }
}
