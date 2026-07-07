import SwiftUI

/// A short, brand-forward animated splash shown immediately after the static
/// system launch screen (`UILaunchScreen` in Info.plist) hands off to
/// SwiftUI. The system launch screen can only ever render a flat image over
/// a flat color — no gradients, motion, or particles are possible there —
/// so this view exists to give that first moment the atmosphere, glow and
/// motion the static one structurally cannot.
struct AnimatedSplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoScale: CGFloat = 0.55
    @State private var logoOpacity: Double = 0
    @State private var breathe: CGFloat = 1.0
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.85
    @State private var shimmerOffset: CGFloat = -260
    @State private var stageOpacity: Double = 1
    @State private var particles = SplashParticle.makeField(count: 22)

    private let logoSize: CGFloat = 148

    private var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some View {
        ZStack {
            PulseTheme.background

            if !reduceMotion {
                PulseRingField(colors: [PulseTheme.ringStand, PulseTheme.playControl])
                    .opacity(logoOpacity)
                    .allowsHitTesting(false)
            }

            if !reduceMotion {
                SplashParticleField(particles: particles)
                    .allowsHitTesting(false)
            }

            radialGlow

            logo
        }
        .opacity(stageOpacity)
        .ignoresSafeArea()
        .task { await runSequence() }
    }

    // MARK: - Layers

    // A single hue kept tight around the icon. Two washes covering the same
    // broad area always average toward a muddy olive/brown where they
    // overlap, no matter how the gradient stops are arranged — orange stays
    // confined to the icon shadow, pulse rings and particles instead, where
    // it reads as an accent rather than a wash.
    private var radialGlow: some View {
        RadialGradient(
            colors: [PulseTheme.ringStand.opacity(0.24), .clear],
            center: .center,
            startRadius: 4,
            endRadius: 170
        )
        .scaleEffect(glowScale)
        .opacity(glowOpacity)
        .allowsHitTesting(false)
    }

    private var logo: some View {
        Image("LaunchLogo")
            .resizable()
            .scaledToFit()
            .frame(width: logoSize, height: logoSize)
            .overlay(shimmer)
            .shadow(color: PulseTheme.ringStand.opacity(0.45), radius: 26)
            .shadow(color: PulseTheme.playControl.opacity(0.38), radius: 40)
            .shadow(color: PulseTheme.accent.opacity(0.22), radius: 60)
            .scaleEffect(logoScale * breathe)
            .opacity(logoOpacity)
    }

    private var shimmer: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.65), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .rotationEffect(.degrees(24))
        .frame(width: logoSize * 0.6, height: logoSize * 1.6)
        .offset(x: shimmerOffset)
        .mask(
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
        )
        .allowsHitTesting(false)
    }

    // MARK: - Sequencing

    @MainActor
    private func runSequence() async {
        HapticService.impact(.light)

        withAnimation(.spring(response: 0.62, dampingFraction: 0.68)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.18)) {
            glowOpacity = 1
        }

        guard !reduceMotion else {
            try? await Task.sleep(for: .milliseconds(isTesting ? 60 : 550))
            await finish()
            return
        }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            breathe = 1.045
            glowScale = 1.14
        }
        Task { await runShimmerLoop() }

        try? await Task.sleep(for: .milliseconds(isTesting ? 60 : 950))
        await finish()
    }

    @MainActor
    private func runShimmerLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.85)) {
                shimmerOffset = 260
            }
            try? await Task.sleep(for: .milliseconds(1400))
            shimmerOffset = -260
        }
    }

    @MainActor
    private func finish() async {
        withAnimation(.easeInOut(duration: 0.42)) {
            stageOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(420))
        onFinished()
    }
}

// MARK: - Pulse rings

/// Rings that detach from the icon and expand outward while fading, like a
/// radar ping, rather than fixed circle outlines sitting statically around
/// it — no static strokes or "container" lines left on screen at any moment.
private struct PulseRingField: View {
    let colors: [Color]

    private let ringCount = 3
    private let cycleDuration: Double = 2.4
    private let startRadius: CGFloat = 76
    private let maxExpansion: CGFloat = 190

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for i in 0..<ringCount {
                    let offset = Double(i) * (cycleDuration / Double(ringCount))
                    let phase = (t + offset).truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
                    let radius = startRadius + CGFloat(phase) * maxExpansion
                    let opacity = (1 - phase) * 0.5

                    var layer = ctx
                    layer.opacity = opacity
                    layer.stroke(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(colors[i % colors.count]),
                        lineWidth: 1.6
                    )
                }
            }
        }
    }
}

// MARK: - Particle field

private struct SplashParticle {
    let x: CGFloat
    let baseY: CGFloat
    let size: CGFloat
    let speed: CGFloat
    let driftAmplitude: CGFloat
    let driftFrequency: Double
    let twinkleFrequency: Double
    let phase: Double
    let colorIndex: Int

    static func makeField(count: Int) -> [SplashParticle] {
        (0..<count).map { _ in
            SplashParticle(
                x: .random(in: 0.06...0.94),
                baseY: .random(in: 0...1),
                size: .random(in: 2...5),
                speed: .random(in: 0.028...0.07),
                driftAmplitude: .random(in: 6...18),
                driftFrequency: .random(in: 0.15...0.4),
                twinkleFrequency: .random(in: 0.6...1.4),
                phase: .random(in: 0...(2 * .pi)),
                colorIndex: .random(in: 0...2)
            )
        }
    }
}

private struct SplashParticleField: View {
    let particles: [SplashParticle]

    private var colors: [Color] {
        [PulseTheme.ringStand, PulseTheme.accent, PulseTheme.playControl]
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvasContext, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let rawProgress = particle.baseY - CGFloat(t) * particle.speed
                    let progress = rawProgress.truncatingRemainder(dividingBy: 1)
                    let normalized = progress < 0 ? progress + 1 : progress
                    let y = normalized * size.height
                    let drift = sin(t * particle.driftFrequency + particle.phase) * particle.driftAmplitude
                    let x = particle.x * size.width + drift
                    let twinkle = (sin(t * particle.twinkleFrequency + particle.phase) + 1) / 2
                    let opacity = 0.15 + twinkle * 0.55
                    let radius = particle.size * (0.75 + twinkle * 0.5)

                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    var layer = canvasContext
                    layer.opacity = opacity
                    layer.addFilter(.blur(radius: radius * 0.6))
                    layer.fill(Path(ellipseIn: rect), with: .color(colors[particle.colorIndex]))
                }
            }
        }
    }
}

#Preview("Animated Splash") {
    AnimatedSplashView(onFinished: {})
        .preferredColorScheme(.dark)
}
