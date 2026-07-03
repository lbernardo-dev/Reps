import Charts
import MuscleMap
import SwiftUI

struct ExerciseAnalyticsListView: View {
  let exercises: [Exercise]

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(spacing: 14) {
        if exercises.isEmpty {
          PulseCard {
            PulseEmptyState(
              title: "no_exercise_history",
              message: "finish_workout_to_see_progress_message",
              systemImage: "chart.line.uptrend.xyaxis"
            )
          }
        } else {
          ForEach(exercises) { exercise in
            NavigationLink {
              ExerciseProgressView(exercise: exercise)
            } label: {
              PulseCard {
                ExerciseProgressRow(exercise: exercise)
              }
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, PulseTheme.screenHorizontalPadding)
      .padding(.vertical, 20)
      .padding(.bottom, 112)
    }
    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    .screenBackground()
    .navigationTitle("exercises_3")
    .navigationBarTitleDisplayMode(.inline)
    .mainTabBarHidden()
  }
}

