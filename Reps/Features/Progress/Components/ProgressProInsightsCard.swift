import Charts
import MuscleMap
import SwiftUI

struct ProInsightsTeaserCard: View {
  let onUnlock: () -> Void

  private struct LockedInsightRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(PulseTheme.accent)
          .frame(width: 28, height: 28)
          .background(PulseTheme.accent.opacity(0.14), in: Circle())
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.subheadline.weight(.semibold))
          Text(detail)
            .font(.caption)
            .foregroundStyle(PulseTheme.secondaryText)
        }
        Spacer()
        Image(systemName: "lock.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(PulseTheme.accent)
      }
      .blur(radius: 3.5)
      .overlay(alignment: .trailing) {
        Image(systemName: "lock.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(PulseTheme.accent)
          .padding(.trailing, 2)
      }
    }
  }

  var body: some View {
    PulseCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Label(localizedString("pro_insights_title"), systemImage: "sparkles")
            .font(.headline)
          Spacer()
          Text(localizedString("pro_badge"))
            .font(.caption2.weight(.black))
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PulseTheme.accent, in: Capsule())
        }

        VStack(spacing: 10) {
          LockedInsightRow(
            icon: "chart.line.uptrend.xyaxis",
            title: localizedString("pro_insight_volume_title"),
            detail: localizedString("pro_insight_volume_detail")
          )
          Divider()
          LockedInsightRow(
            icon: "bolt.heart.fill",
            title: localizedString("pro_insight_recovery_title"),
            detail: localizedString("pro_insight_recovery_detail")
          )
          Divider()
          LockedInsightRow(
            icon: "trophy.fill",
            title: localizedString("pro_insight_pr_velocity_title"),
            detail: localizedString("pro_insight_pr_velocity_detail")
          )
        }

        Button(action: onUnlock) {
          Label(localizedString("unlock_pro_insights_cta"), systemImage: "crown.fill")
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(.black)
            .background(PulseTheme.accent, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }
}
