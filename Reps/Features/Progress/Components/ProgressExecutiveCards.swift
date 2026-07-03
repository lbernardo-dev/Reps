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
	            .foregroundStyle(.black)
	            .frame(width: 48, height: 48)
	            .background(PulseTheme.fitActionGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
	            .overlay(
	              RoundedRectangle(cornerRadius: 14, style: .continuous)
	                .stroke(.white.opacity(0.18), lineWidth: 1)
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
	              .foregroundStyle(.black)
	              .background(PulseTheme.ringStand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
	          }
          .buttonStyle(.plain)

	          Button(action: onOpenHistory) {
	            Label("history_label", systemImage: "list.clipboard")
	              .font(.caption.weight(.black))
	              .frame(maxWidth: .infinity)
	              .frame(height: 40)
	              .foregroundStyle(.white.opacity(0.82))
	              .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
	              .overlay(
	                RoundedRectangle(cornerRadius: 12, style: .continuous)
	                  .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
    .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
        .stroke(PulseTheme.separator, lineWidth: 1)
    )
  }
}


struct ProgressSectionTile: View {
  let section: ProgressSection
  let isSelected: Bool
	  let value: String
	  let isLocked: Bool
	  var showsChevron: Bool = false

	  private var tileFill: Color {
	    isSelected ? Color.white.opacity(0.06) : PulseTheme.card
	  }

	  private var tileStroke: Color {
	    isSelected ? Color.white.opacity(0.18) : PulseTheme.separator
	  }
	
	  var body: some View {
	    HStack(spacing: 10) {
      Image(systemName: isLocked ? "lock.fill" : section.systemImage)
        .font(.headline.weight(.black))
        .foregroundStyle(isSelected ? .white : section.tint)
        .frame(width: 42, height: 42)
        .background((isSelected ? Color.white.opacity(0.16) : section.tint.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(localizedKey(section.title))
          .font(.subheadline.weight(.black))
          .foregroundStyle(isSelected ? .white : .primary)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        Text(value)
          .font(.caption.weight(.black).monospacedDigit())
          .foregroundStyle(isSelected ? .white.opacity(0.82) : PulseTheme.secondaryText)
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
	    .shadow(color: isSelected ? section.tint.opacity(0.12) : Color.black.opacity(0.10), radius: isSelected ? 10 : 6, x: 0, y: 4)
	    .accessibilityElement(children: .combine)
	  }

	  private var tileBackground: some View {
	    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
	      .fill(tileFill)
	      .overlay(
	        LinearGradient(
	          colors: [
	            Color.white.opacity(isSelected ? 0.16 : 0.045),
	            section.tint.opacity(isSelected ? 0.10 : 0.018),
	            Color.black.opacity(0.08)
	          ],
	          startPoint: .topLeading,
	          endPoint: .bottomTrailing
	        )
	      )
	  }
	}

	private struct ProgressActionPlanCard: View {
  let steps: [RetentionEngine.ActivationStep]
  let weeklyCompletion: Double
  let battery: FitnessMetrics.TrainingBatteryStatus
  let completionRate: Double
  let onAction: (RetentionEngine.ActivationAction?) -> Void

  private var pendingStep: RetentionEngine.ActivationStep? {
    steps.first { !$0.isCompleted } ?? steps.first
  }

  private var completedSteps: Int {
    steps.filter(\.isCompleted).count
  }

  private var planProgress: Double {
    guard !steps.isEmpty else { return 0 }
    return Double(completedSteps) / Double(steps.count)
  }

  private var visibleSteps: [RetentionEngine.ActivationStep] {
    guard let pendingStep else {
      return Array(steps.prefix(2))
    }

    var result = [pendingStep]
    if let supportStep = steps.first(where: { $0.id != pendingStep.id && $0.isCompleted }) {
      result.append(supportStep)
    }
    return result
  }

  private var batteryColor: Color {
    switch battery.state {
    case .charged:
      return PulseTheme.recovery
    case .steady:
      return PulseTheme.accent
    case .low:
      return PulseTheme.warning
    case .critical:
      return PulseTheme.destructive
    }
  }

  var body: some View {
    PulseCard(contentPadding: 18) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .center, spacing: 16) {
          ProgressPlanRing(
            progress: max(planProgress, min(max(weeklyCompletion, 0), 1) * 0.85),
            color: batteryColor,
            centerValue: "\(Int(max(weeklyCompletion, 0) * 100))%"
          )
            .frame(width: 82, height: 82)

          VStack(alignment: .leading, spacing: 9) {
            Label(localizedString("progress_direction"), systemImage: "sparkles")
              .font(.caption.weight(.black))
              .textCase(.uppercase)
              .foregroundStyle(PulseTheme.accent)

            Text(pendingStep?.title ?? (localizedString("keep_the_week_stable")))
              .font(.title3.weight(.bold))
              .lineLimit(2)
              .minimumScaleFactor(0.82)

            Text(pendingStep?.message ?? battery.suggestion)
              .font(.subheadline)
              .foregroundStyle(PulseTheme.secondaryText)
              .lineLimit(3)
              .minimumScaleFactor(0.82)
          }

          Spacer(minLength: 0)
        }

        HStack(spacing: 8) {
          ProgressSignalPill(
            title: "adherence",
            value: "\(Int(completionRate * 100))%",
            color: completionRate >= 0.75 ? PulseTheme.recovery : PulseTheme.warning
          )
          ProgressSignalPill(
            title: "battery",
            value: "\(battery.level)%",
            color: batteryColor
          )
          ProgressSignalPill(
            title: "steps_3",
            value: "\(completedSteps)/\(max(steps.count, 1))",
            color: PulseTheme.accent
          )
        }

        VStack(spacing: 0) {
          ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { index, step in
            ProgressActionStepRow(step: step) {
              onAction(step.action)
            }

            if index < visibleSteps.count - 1 {
              Divider()
                .padding(.leading, 52)
            }
          }
        }

        if let pendingStep, !pendingStep.isCompleted, pendingStep.action != nil {
          Button {
            onAction(pendingStep.action)
          } label: {
            Label(pendingStep.actionTitle, systemImage: "arrow.forward.circle.fill")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
              .frame(maxWidth: .infinity)
              .frame(height: 46)
              .background(PulseTheme.accent)
              .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}


struct ProgressPlanRing: View {
  let progress: Double
  let color: Color
  let centerValue: String

  var body: some View {
    ZStack {
      Circle()
        .stroke(PulseTheme.grouped, lineWidth: 12)
      Circle()
        .trim(from: 0, to: min(max(progress, 0), 1))
        .stroke(
          AngularGradient(colors: [color, PulseTheme.accent, color], center: .center),
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        Text(centerValue)
          .font(.system(size: 20, weight: .black, design: .rounded))
        Text("plan_2")
          .font(.system(size: 9, weight: .black, design: .rounded))
          .foregroundStyle(PulseTheme.secondaryText)
      }
    }
    .accessibilityLabel(localizedFormat("weekly_progress_format", centerValue))
  }
}


struct ProgressSignalPill: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(localizedKey(title))
        .font(.caption2.weight(.bold))
        .foregroundStyle(PulseTheme.secondaryText)
      Text(value)
        .font(.caption.weight(.black).monospacedDigit())
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(color.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
  }
}


struct ProgressActionStepRow: View {
  let step: RetentionEngine.ActivationStep
  let onAction: () -> Void

  private var iconColor: Color {
    step.isCompleted ? PulseTheme.recovery : PulseTheme.accent
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
          .fill(iconColor.opacity(step.isCompleted ? 0.18 : 0.12))
        Image(systemName: step.isCompleted ? "checkmark.seal.fill" : step.systemImage)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(iconColor)
      }
      .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(step.title)
            .font(.subheadline.weight(.bold))
            .lineLimit(2)
            .minimumScaleFactor(0.86)

          if step.isCompleted {
            Text(localizedString("done"))
              .font(.caption2.weight(.bold))
              .foregroundStyle(PulseTheme.recovery)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(PulseTheme.recovery.opacity(0.12))
              .clipShape(Capsule())
          }
        }

        Text(step.message)
          .font(.caption)
          .foregroundStyle(PulseTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)

        if !step.isCompleted, step.action != nil {
          Button(action: onAction) {
            Text(step.actionTitle)
              .font(.caption.weight(.bold))
              .foregroundStyle(PulseTheme.accent)
          }
          .buttonStyle(.plain)
          .padding(.top, 2)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 9)
  }
}

