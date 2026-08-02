//
//  SocialLimitsPanel.swift
//  Reps
//

import SwiftUI

struct SocialLimitsPanel: View {
    @Environment(AppStore.self) private var store

    let activeChallengesCount: Int
    var onUnlockPro: () -> Void

    @State private var postResetTime: String = ""
    @State private var inviteResetTime: String = ""

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        PulseCard(backgroundColor: PulseTheme.card) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "social_limits_title"))
                            .font(.headline)
                        Text(String(localized: "social_limits_subtitle"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Spacer()

                    Text(String(localized: "paywall_free_tier_title"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Divider()

                // 2x2 Grid of Limits
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        limitTile(
                            icon: "square.and.pencil",
                            title: String(localized: "social_limit_posts_label"),
                            countText: "\(1 - SocialLimitsManager.shared.remainingPostsToday(hasProAccess: false))/1",
                            subtitle: String(format: String(localized: "social_limit_resets_in_format"), postResetTime),
                            isFull: !SocialLimitsManager.shared.canPostToday(hasProAccess: false)
                        )

                        limitTile(
                            icon: "person.badge.plus",
                            title: String(localized: "social_limit_invites_label"),
                            countText: "\(3 - SocialLimitsManager.shared.remainingInvitesToday(hasProAccess: false))/3",
                            subtitle: String(format: String(localized: "social_limit_resets_in_format"), inviteResetTime),
                            isFull: !SocialLimitsManager.shared.canSendInviteToday(hasProAccess: false)
                        )
                    }

                    HStack(spacing: 12) {
                        limitTile(
                            icon: "trophy.fill",
                            title: String(localized: "social_limit_challenges_label"),
                            countText: "\(activeChallengesCount)/1",
                            subtitle: String(localized: "social_limit_active_challenge_subtitle"),
                            isFull: activeChallengesCount >= 1
                        )

                        limitTile(
                            icon: "plus.circle.fill",
                            title: String(localized: "social_limit_create_challenge_label"),
                            countText: "🔒 Pro",
                            subtitle: String(localized: "social_limit_locked_premium"),
                            isFull: true
                        )
                    }
                }

                // Unlock Pro CTA Button
                Button(action: onUnlockPro) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.body.weight(.bold))
                        Text(String(localized: "social_unlock_pro_btn"))
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [PulseTheme.accent, PulseTheme.ringStand],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: PulseTheme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { refreshTimers() }
        .onReceive(timer) { _ in refreshTimers() }
    }

    private func limitTile(icon: String, title: String, countText: String, subtitle: String, isFull: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFull ? .orange : PulseTheme.accent)
                .frame(width: 28, height: 28)
                .background(isFull ? Color.orange.opacity(0.12) : PulseTheme.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 2)

                    Text(countText)
                        .font(.caption.bold())
                        .foregroundStyle(isFull ? .orange : .primary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PulseTheme.secondaryText.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func refreshTimers() {
        postResetTime = SocialLimitsManager.shared.timeUntilPostReset()
        inviteResetTime = SocialLimitsManager.shared.timeUntilInviteReset()
    }
}
