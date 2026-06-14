import SwiftUI

struct RepsLoadingView: View {
    enum Layout {
        case splash
        case panel
        case compact
    }

    let messages: [String]
    let progress: Double?
    var layout: Layout = .splash
    var showsPercentage = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messageIndex = 0
    @State private var animatedProgress = 0.08
    @State private var logoScale: CGFloat = 0.92
    @State private var logoOpacity = 0.0
    @State private var glowScale: CGFloat = 1.0

    private var currentMessage: String {
        guard !messages.isEmpty else { return "Preparando Reps..." }
        return messages[messageIndex % messages.count]
    }

    private var progressValue: Double {
        (progress ?? animatedProgress).clamped(to: 0...1)
    }

    var body: some View {
        ZStack {
            if layout == .splash {
                atmosphericBackground
            }

            VStack(spacing: spacing) {
                Spacer(minLength: layout == .splash ? 80 : 0)

                VStack(spacing: layout == .compact ? 14 : 22) {
                    RepsBrandLockup(size: brandSize)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    statusStack
                        .frame(maxWidth: maxContentWidth)
                }

                Spacer(minLength: layout == .splash ? 72 : 0)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: layout == .splash ? .infinity : nil)
        .background {
            if layout != .splash {
                PulseTheme.card
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if layout != .splash {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PulseTheme.separator, lineWidth: 1)
            }
        }
        .task { await startAppearanceAnimation() }
        .task { await cycleMessages() }
        .task { await simulateProgressIfNeeded() }
        .onChange(of: progress) { _, newValue in
            guard let newValue else { return }
            withAnimation(.snappy(duration: 0.28)) {
                animatedProgress = newValue.clamped(to: 0...1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentMessage)
        .accessibilityValue("\(Int(progressValue * 100))%")
    }

    private var atmosphericBackground: some View {
        ZStack {
            PulseTheme.background.ignoresSafeArea()

            RadialGradient(
                colors: [
                    PulseTheme.primary.opacity(0.34),
                    PulseTheme.primary.opacity(0.12),
                    .clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: 380
            )
            .scaleEffect(glowScale)
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.34),
                    .clear,
                    .black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var statusStack: some View {
        VStack(spacing: layout == .compact ? 9 : 12) {
            Text(currentMessage)
                .font(statusFont)
                .foregroundStyle(PulseTheme.secondaryText)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .id(currentMessage)

            progressBar

            if showsPercentage {
                Text("\(Int(progressValue * 100))%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(PulseTheme.accent)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                PulseTheme.primaryBright,
                                PulseTheme.primary,
                                PulseTheme.accent
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, width * progressValue))
                    .shadow(color: PulseTheme.primary.opacity(0.32), radius: 10, y: 2)
            }
        }
        .frame(height: layout == .compact ? 5 : 7)
    }

    private var brandSize: RepsBrandLockup.Size {
        switch layout {
        case .splash: .large
        case .panel: .medium
        case .compact: .small
        }
    }

    private var spacing: CGFloat {
        switch layout {
        case .splash: 36
        case .panel: 20
        case .compact: 14
        }
    }

    private var statusFont: Font {
        switch layout {
        case .splash: .subheadline.weight(.semibold)
        case .panel: .footnote.weight(.semibold)
        case .compact: .caption.weight(.semibold)
        }
    }

    private var maxContentWidth: CGFloat {
        switch layout {
        case .splash: 330
        case .panel: 280
        case .compact: 220
        }
    }

    private var horizontalPadding: CGFloat {
        switch layout {
        case .splash: 30
        case .panel: 24
        case .compact: 16
        }
    }

    private var verticalPadding: CGFloat {
        switch layout {
        case .splash: 40
        case .panel: 24
        case .compact: 16
        }
    }

    private var cornerRadius: CGFloat {
        switch layout {
        case .splash: 0
        case .panel: PulseTheme.cardRadius
        case .compact: 18
        }
    }

    @MainActor
    private func startAppearanceAnimation() async {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        if !reduceMotion {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowScale = 1.18
            }
        }

        guard !reduceMotion else {
            animatedProgress = progress ?? 0.72
            return
        }
    }

    @MainActor
    private func cycleMessages() async {
        guard !reduceMotion, messages.count > 1 else { return }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.15))
            withAnimation(.easeInOut(duration: 0.22)) {
                messageIndex = (messageIndex + 1) % messages.count
            }
        }
    }

    @MainActor
    private func simulateProgressIfNeeded() async {
        guard !reduceMotion, progress == nil else { return }

        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(360))
            let next = animatedProgress >= 0.92 ? 0.18 : animatedProgress + Double.random(in: 0.045...0.11)
            withAnimation(.easeInOut(duration: 0.34)) {
                animatedProgress = next
            }
        }
    }
}

struct RepsBrandLockup: View {
    enum Size {
        case small
        case medium
        case large
    }

    var size: Size = .large

    private var scale: CGFloat {
        switch size {
        case .small: 0.54
        case .medium: 0.74
        case .large: 1.0
        }
    }

    var body: some View {
        VStack(spacing: 16 * scale) {
            RepsBarbellMark(scale: scale)

            Text("reps_2")
                .font(.system(size: 48 * scale, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.84)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            Text("inteligencia_muscular")
                .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                .foregroundStyle(PulseTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct RepsBarbellMark: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 9 * scale) {
            RoundedRectangle(cornerRadius: 5 * scale, style: .continuous)
                .fill(PulseTheme.primaryBright)
                .frame(width: 10 * scale, height: 52 * scale)

            RoundedRectangle(cornerRadius: 5 * scale, style: .continuous)
                .fill(PulseTheme.primary)
                .frame(width: 18 * scale, height: 70 * scale)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            PulseTheme.primary,
                            .white.opacity(0.70),
                            PulseTheme.accent
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 118 * scale, height: 8 * scale)

            RoundedRectangle(cornerRadius: 5 * scale, style: .continuous)
                .fill(PulseTheme.primary)
                .frame(width: 18 * scale, height: 70 * scale)

            RoundedRectangle(cornerRadius: 5 * scale, style: .continuous)
                .fill(PulseTheme.primaryBright)
                .frame(width: 10 * scale, height: 52 * scale)
        }
        .shadow(color: PulseTheme.primary.opacity(0.52), radius: 22 * scale)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

#Preview("Splash") {
    RepsLoadingView(
        messages: ["Preparando tu entrenamiento...", "Ajustando cargas...", "Sincronizando progreso..."],
        progress: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Panel") {
    RepsLoadingView(
        messages: ["Cargando tu biblioteca...", "Buscando playlists..."],
        progress: 0.62,
        layout: .panel
    )
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
