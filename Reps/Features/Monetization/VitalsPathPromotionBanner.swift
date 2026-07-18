import SwiftUI

enum VitalsPathPromotionPlacement: CaseIterable, Equatable {
    case top
    case bottom

    var alignment: Alignment {
        switch self {
        case .top: .top
        case .bottom: .bottom
        }
    }

    var transitionEdge: Edge {
        switch self {
        case .top: .top
        case .bottom: .bottom
        }
    }
}

struct VitalsPathPromotion: Equatable {
    let tab: AppTab
    let placement: VitalsPathPromotionPlacement
}

enum VitalsPathPromotionPolicy {
    static let appearanceProbability = 0.38
    static let visibleDuration = 30
    static let minimumInterval: TimeInterval = 90
    static let maximumInterval: TimeInterval = 240

    static func promotion(
        for tab: AppTab,
        appearanceRoll: Double,
        placementRoll: Double
    ) -> VitalsPathPromotion? {
        guard AppTab.tabBarCases.contains(tab), appearanceRoll < appearanceProbability else {
            return nil
        }

        return VitalsPathPromotion(
            tab: tab,
            placement: placementRoll < 0.5 ? .top : .bottom
        )
    }
}

struct VitalsPathPromotionBanner: View {
    @Environment(\.openURL) private var openURL

    let isPremium: Bool
    let remainingSeconds: Int
    let dismissCurrent: () -> Void
    let dismissPermanently: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    @State private var showsDismissOptions = false

    private let deepLink = URL(string: "vitalspath://medications")!
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6760143192")!

    var body: some View {
        HStack(spacing: 10) {
            dragHandle

            Button(action: openVitalsPath) {
                HStack(spacing: 11) {
                    VitalsPathMark()

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: localizedString("vitalspath_promo_eyebrow"))
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.7)
                            .foregroundStyle(PulseTheme.semanticHealth)

                        Text(verbatim: localizedString("vitalspath_promo_title"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(verbatim: localizedString("vitalspath_promo_message"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.semanticHealth)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizedString("vitalspath_promo_accessibility"))
            .accessibilityHint(localizedString("vitalspath_promo_open_hint"))

            Button {
                showsDismissOptions = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PulseTheme.secondaryText)
            .accessibilityLabel(localizedString("vitalspath_promo_close"))
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .fill(PulseTheme.card.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        .stroke(PulseTheme.semanticHealth.opacity(0.34), lineWidth: 1)
                }
                .shadow(color: PulseTheme.surfaceShadow.opacity(0.9), radius: 12, y: 5)
        }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: PulseTheme.compactRadius))
        .overlay(alignment: .topTrailing) {
            Text(verbatim: "\(remainingSeconds)s")
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(PulseTheme.card.opacity(0.9), in: Capsule())
                .padding(5)
                .accessibilityHidden(true)
        }
        .confirmationDialog(
            localizedString("vitalspath_promo_close_title"),
            isPresented: $showsDismissOptions,
            titleVisibility: .visible
        ) {
            Button(localizedString("vitalspath_promo_hide_now"), action: dismissCurrent)
            if isPremium {
                Button(localizedString("vitalspath_promo_hide_forever"), role: .destructive, action: dismissPermanently)
            }
            Button(localizedString("cancel"), role: .cancel) {}
        } message: {
            Text(verbatim: localizedString("vitalspath_promo_close_message"))
        }
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption.weight(.bold))
            .foregroundStyle(PulseTheme.secondaryText)
            .frame(width: 22, height: 44)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in onDragChanged(value.translation) }
                    .onEnded { value in onDragEnded(value.translation) }
            )
            .accessibilityLabel(localizedString("vitalspath_promo_move"))
            .accessibilityHint(localizedString("vitalspath_promo_move_hint"))
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = 24
                switch direction {
                case .increment: onDragEnded(CGSize(width: 0, height: -step))
                case .decrement: onDragEnded(CGSize(width: 0, height: step))
                @unknown default: break
                }
            }
    }

    private func openVitalsPath() {
        TelemetryService.shared.breadcrumb("vitalspath_promo.open")
        openURL(deepLink) { accepted in
            guard !accepted else { return }
            openURL(appStoreURL)
        }
    }
}

private struct VitalsPathMark: View {
    var body: some View {
        Image("VitalsPathAppIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}
