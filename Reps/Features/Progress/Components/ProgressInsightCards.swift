import Charts
import MuscleMap
import SwiftUI

struct ConsistencyPoint: Identifiable {
  let id = UUID()
  let date: Date
  let count: Int
}


struct InsightRow: View {
  let insight: FitnessMetrics.TrainingInsight

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: insight.systemImage)
        .font(.headline)
        .foregroundStyle(PulseTheme.accent)
        .frame(width: 38, height: 38)
        .background(PulseTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(insight.title)
          .font(.headline)
        Text(insight.message)
          .font(.subheadline)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
