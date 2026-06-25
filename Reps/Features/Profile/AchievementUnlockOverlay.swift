import SwiftUI
import UIKit

// MARK: - Confetti Emitter (CAEmitterLayer, GPU-accelerated)

private struct ConfettiEmitterView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .clear
        host.isUserInteractionEnabled = false

        let emitter = CAEmitterLayer()
        emitter.emitterShape  = .line
        emitter.renderMode    = .additive
        emitter.emitterCells  = confettiCells()
        host.layer.addSublayer(emitter)

        // Reposition emitter at full width once layout is known
        DispatchQueue.main.async {
            let w = UIScreen.main.bounds.width
            emitter.emitterPosition = CGPoint(x: w / 2, y: -10)
            emitter.emitterSize     = CGSize(width: w, height: 1)
        }

        // Burst: high birthRate for 1.5 s, then stop spawning
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            emitter.birthRate = 0
        }
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    // MARK: - Cells
    private func confettiCells() -> [CAEmitterCell] {
        let palette: [UIColor] = [
            UIColor(red: 1.00, green: 0.22, blue: 0.32, alpha: 1), // red
            UIColor(red: 0.25, green: 0.55, blue: 1.00, alpha: 1), // blue
            UIColor(red: 0.30, green: 0.90, blue: 0.50, alpha: 1), // green
            UIColor(red: 1.00, green: 0.80, blue: 0.10, alpha: 1), // yellow
            UIColor(red: 1.00, green: 0.35, blue: 0.70, alpha: 1), // pink
            UIColor(red: 0.70, green: 0.35, blue: 1.00, alpha: 1), // purple
            UIColor(red: 1.00, green: 0.55, blue: 0.10, alpha: 1), // orange
            UIColor(red: 0.10, green: 0.85, blue: 0.95, alpha: 1), // cyan
        ]

        var cells: [CAEmitterCell] = []
        for (i, color) in palette.enumerated() {
            cells.append(squareCell(color: color, birthRate: 7, delay: Double(i) * 0.04))
            cells.append(ribbonCell(color: color, birthRate: 3, delay: Double(i) * 0.06))
            cells.append(circleCell(color: color, birthRate: 4, delay: Double(i) * 0.05))
        }
        return cells
    }

    private func squareCell(color: UIColor, birthRate: Float, delay: Double) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents       = makeImage(size: CGSize(width: 9, height: 9), color: color)
        cell.birthRate      = birthRate
        cell.lifetime       = 5.5
        cell.lifetimeRange  = 1.0
        cell.velocity       = 220
        cell.velocityRange  = 90
        cell.emissionRange  = .pi / 3.5
        cell.spin           = 4.5
        cell.spinRange      = 2.5
        cell.scale          = 0.14
        cell.scaleRange     = 0.04
        cell.yAcceleration  = 160
        cell.xAcceleration  = CGFloat(Float.random(in: -25...25))
        cell.alphaSpeed     = -0.12
        return cell
    }

    private func ribbonCell(color: UIColor, birthRate: Float, delay: Double) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents       = makeImage(size: CGSize(width: 3, height: 18), color: color)
        cell.birthRate      = birthRate
        cell.lifetime       = 6.5
        cell.lifetimeRange  = 1.5
        cell.velocity       = 170
        cell.velocityRange  = 70
        cell.emissionRange  = .pi / 4
        cell.spin           = 6.0
        cell.spinRange      = 3.0
        cell.scale          = 0.18
        cell.scaleRange     = 0.06
        cell.yAcceleration  = 130
        cell.xAcceleration  = CGFloat(Float.random(in: -18...18))
        cell.alphaSpeed     = -0.10
        return cell
    }

    private func circleCell(color: UIColor, birthRate: Float, delay: Double) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents       = makeCircleImage(radius: 6, color: color)
        cell.birthRate      = birthRate
        cell.lifetime       = 5.0
        cell.lifetimeRange  = 1.0
        cell.velocity       = 200
        cell.velocityRange  = 80
        cell.emissionRange  = .pi / 4
        cell.spin           = 3.0
        cell.spinRange      = 1.5
        cell.scale          = 0.16
        cell.scaleRange     = 0.05
        cell.yAcceleration  = 145
        cell.xAcceleration  = CGFloat(Float.random(in: -20...20))
        cell.alphaSpeed     = -0.11
        return cell
    }

    // MARK: - Image helpers
    private func makeImage(size: CGSize, color: UIColor) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }.cgImage
    }

    private func makeCircleImage(radius: CGFloat, color: UIColor) -> CGImage? {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}

// MARK: - Achievement Unlock Card

private struct AchievementUnlockCard: View {
    let banner: AchievementUnlockBanner
    let remainingCount: Int
    let onDismiss: () -> Void
    let onShare: () -> Void

    @State private var appeared   = false
    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.10), in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Trophy icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: iconBounce)
            }
            .padding(.top, 12)

            // Title strip
            VStack(spacing: 6) {
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 20)

                Text(banner.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text(banner.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 2)
            }

            // Points badge
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow)
                Text("+\(banner.xpReward) pts")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12), in: Capsule())
            .padding(.top, 16)

            // Share button
            Button(action: onShare) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text(localizedString("achievement_share_button"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 22)

            // More badge
            if remainingCount > 0 {
                Button(action: onDismiss) {
                    Text(localizedFormat("achievement_more_format", remainingCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: 360)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
        // Entrance animation
        .scaleEffect(appeared ? 1.0 : 0.72, anchor: .center)
        .offset(y: appeared ? 0 : 60)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                iconBounce = true
            }
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(.black.opacity(0.52)), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.black.opacity(0.42))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

// MARK: - Full-Screen Achievement Unlock Overlay

struct AchievementUnlockOverlay: View {
    @Environment(AppStore.self) private var store
    @State private var showCard     = false
    @State private var currentBanner: AchievementUnlockBanner?
    @State private var shareItem: String? = nil
    @State private var isSharing  = false

    var body: some View {
        ZStack {
            if let banner = currentBanner, showCard {
                // Dim backdrop
                Color.black.opacity(0.60)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismiss() }

                // Achievement card — rendered before confetti so confetti lands on top
                AchievementUnlockCard(
                    banner: banner,
                    remainingCount: max(0, store.pendingAchievementUnlocks.count - 1),
                    onDismiss: dismiss,
                    onShare: { isSharing = true }
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.8, anchor: .center).combined(with: .opacity))
                .zIndex(1)

                // Confetti ON TOP of the card
                ConfettiEmitterView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(2)
                    .id(banner.id) // restart emitter each new achievement
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.80), value: showCard)
        .onChange(of: store.pendingAchievementUnlocks) { _, unlocks in
            if currentBanner == nil, let first = unlocks.first {
                presentBanner(first)
            }
        }
        .onAppear {
            if let first = store.pendingAchievementUnlocks.first {
                presentBanner(first)
            }
        }
        .sheet(isPresented: $isSharing) {
            if let banner = currentBanner {
                ShareSheet(text: localizedFormat("achievement_share_text_format", banner.title, banner.xpReward))
            }
        }
    }

    private func presentBanner(_ banner: AchievementUnlockBanner) {
        currentBanner = banner
        withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
            showCard = true
        }
        HapticService.notification(.success)
    }

    private func dismiss() {
        HapticService.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showCard = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            store.dequeueAchievementUnlock()
            currentBanner = nil
            if let next = store.pendingAchievementUnlocks.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    presentBanner(next)
                }
            }
        }
    }
}

// MARK: - Share Sheet helper

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
