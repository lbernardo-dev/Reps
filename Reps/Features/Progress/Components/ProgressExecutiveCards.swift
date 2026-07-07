import Charts
import MuscleMap
import SwiftUI

struct ProgressExecutiveCard: View {
  let sessions: Int
  let volumeKg: Int
  let bestEstimatedOneRepMaxKg: Int
  let rangeTitle: LocalizedStringKey
  let primaryInsight: FitnessMetrics.TrainingInsight?
  let onOpenExercises: () -> Void
  let onOpenHistory: () -> Void
  let onOpenPRs: () -> Void

  private var headline: String {
    if sessions == 0 {
      return localizedString("start_and_finish_workout_message")
    }
    if let primaryInsight {
      return primaryInsight.title
    }
    return localizedString("performance")
  }

  private var message: String {
    if let primaryInsight {
      return primaryInsight.message
    }
    return localizedString("complete_a_session_with_sets_and_reps_to_unlock_practical_signals")
  }

  var body: some View {
	    PulseCard(contentPadding: 15) {
	      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
	          Image(systemName: primaryInsight?.systemImage ?? "chart.bar.fill")
	            .font(.title3.weight(.black))
	            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
	            .frame(width: 48, height: 48)
	            .background(PulseTheme.fitActionGradient, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
	            .overlay(
	              RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
	                .stroke(PulseTheme.accent.opacity(0.18), lineWidth: 1)
	            )

          VStack(alignment: .leading, spacing: 5) {
            Text(localizedKey(rangeTitle))
              .font(.caption.weight(.black))
              .textCase(.uppercase)
              .foregroundStyle(PulseTheme.accent)
            Text(headline)
              .font(.title3.weight(.black))
              .lineLimit(2)
              .minimumScaleFactor(0.76)
            Text(message)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(PulseTheme.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        HStack(spacing: 8) {
          ProgressExecutiveMetric(value: "\(sessions)", label: "sessions", systemImage: "dumbbell.fill", color: PulseTheme.accent)
          ProgressExecutiveMetric(value: "\(volumeKg)", label: "kg_total", systemImage: "scalemass.fill", color: PulseTheme.ringStand)
          ProgressExecutiveMetric(value: "\(bestEstimatedOneRepMaxKg)kg", label: "estimated_maximum", systemImage: "trophy.fill", color: PulseTheme.accent)
        }

	        HStack(spacing: 8) {
	          Button(action: onOpenExercises) {
	            Label("exercises_3", systemImage: "chart.line.uptrend.xyaxis")
	              .font(.caption.weight(.black))
	              .frame(maxWidth: .infinity)
	              .frame(height: 40)
	              .foregroundStyle(PulseTheme.onColor(PulseTheme.ringStand))
	              .background(PulseTheme.ringStand, in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
	          }
          .buttonStyle(.plain)

	          Button(action: onOpenHistory) {
	            Label("history_label", systemImage: "list.clipboard")
	              .font(.caption.weight(.black))
	              .frame(maxWidth: .infinity)
	              .frame(height: 40)
	              .foregroundStyle(PulseTheme.textSecondary)
	              .background(PulseTheme.grouped.opacity(0.62), in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
	              .overlay(
	                RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous)
	                  .stroke(PulseTheme.separator, lineWidth: 1)
	              )
	          }
          .buttonStyle(.plain)

	          Button(action: onOpenPRs) {
	            Image(systemName: "trophy.fill")
	              .font(.headline.weight(.black))
	              .frame(width: 40, height: 40)
	              .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
	              .background(PulseTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(localizedString("personal_records"))
        }
      }
    }
  }
}


struct ProgressExecutiveMetric: View {
  let value: String
  let label: LocalizedStringKey
  let systemImage: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Image(systemName: systemImage)
        .font(.caption.weight(.black))
        .foregroundStyle(color)
      Text(value)
        .font(.headline.weight(.black).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(localizedKey(label))
        .font(.caption2.weight(.bold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}


struct ProgressToolTile: View {
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey
  let systemImage: String
  let color: Color

  var body: some View {
    PulseCard(minHeight: 132, contentPadding: 14) {
    VStack(alignment: .leading, spacing: 9) {
      Image(systemName: systemImage)
        .font(.headline.weight(.black))
        .foregroundStyle(color)
        .frame(width: 38, height: 38)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      Text(localizedKey(title))
        .font(.subheadline.weight(.black))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(localizedKey(subtitle))
        .font(.caption.weight(.semibold))
        .foregroundStyle(PulseTheme.secondaryText)
        .lineLimit(2)
        .minimumScaleFactor(0.76)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}


struct ProgressSectionTile: View {
  let section: ProgressSection
  let isSelected: Bool
	  let value: String
	  let isLocked: Bool
	  var showsChevron: Bool = false

		  private var tileFill: Color {
		    isSelected ? PulseTheme.grouped.opacity(0.72) : PulseTheme.card
		  }

		  private var tileStroke: Color {
		    isSelected ? section.tint.opacity(0.28) : PulseTheme.separator
		  }
	
	  var body: some View {
	    HStack(spacing: 10) {
	      Image(systemName: isLocked ? "lock.fill" : section.systemImage)
	        .font(.headline.weight(.black))
	        .foregroundStyle(section.tint)
	        .frame(width: 42, height: 42)
	        .background(section.tint.opacity(isSelected ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(localizedKey(section.title))
          .font(.subheadline.weight(.black))
	          .foregroundStyle(PulseTheme.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        Text(value)
          .font(.caption.weight(.black).monospacedDigit())
	          .foregroundStyle(PulseTheme.secondaryText)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(PulseTheme.secondaryText.opacity(0.5))
      }
	    }
	    .padding(12)
	    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
	    .background(tileBackground)
	    .overlay(
	      RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
	        .stroke(tileStroke, lineWidth: 1)
	    )
	    .accessibilityElement(children: .combine)
	  }

	  private var tileBackground: some View {
	    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
	      .fill(tileFill)
	      .overlay(
	        LinearGradient(
		          colors: [
		            PulseTheme.cardStroke.opacity(isSelected ? 0.22 : 0.08),
		            section.tint.opacity(isSelected ? 0.10 : 0.018),
		            PulseTheme.surfaceShadow.opacity(0.28)
		          ],
	          startPoint: .topLeading,
	          endPoint: .bottomTrailing
	        )
	      )
	  }
	}
