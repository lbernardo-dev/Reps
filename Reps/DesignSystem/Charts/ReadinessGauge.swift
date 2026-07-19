import SwiftUI

/// Circular 0–100 gauge used for readiness and its sub-factors
/// (Recovery, Load ratio, Sleep quality, etc.) — mirrors the Apple
/// Watch / Fitbod-style factor rings shown in the competitive audit.
struct ReadinessGauge: View {
    let value: Double          // 0...100
    var label: String? = nil
    var lineWidth: CGFloat = 6
    var size: CGFloat = 64
    var showsValue: Bool = true

    @State private var animatedValue: Double = 0

    private var clamped: Double { min(max(value, 0), 100) }

    private var tint: Color {
        switch clamped {
        case ..<30:  PulseTheme.destructive
        case ..<50:  PulseTheme.warning
        case ..<70:  PulseTheme.semanticAction
        default:     PulseTheme.growth
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: animatedValue / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if showsValue {
                    Text(Int(clamped.rounded()).formatted())
                        .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: size, height: size)

            if let label {
                Text(localizedKey(label))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.05)) {
                animatedValue = clamped
            }
        }
        .onChange(of: clamped) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.88)) {
                animatedValue = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.map(localizedKey) ?? "")
        .accessibilityValue("\(Int(clamped.rounded()))")
    }
}

/// Large hero variant used for the primary readiness score (e.g. "77 · high").
struct ReadinessHeroGauge: View {
    let value: Double
    let statusLabel: String

    var body: some View {
        HStack(spacing: 16) {
            ReadinessGauge(value: value, lineWidth: 10, size: 92, showsValue: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(Int(value.rounded()).formatted())
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(localizedKey(statusLabel))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview("Readiness Gauge") {
    VStack(spacing: 24) {
        ReadinessHeroGauge(value: 77, statusLabel: "high")
        HStack(spacing: 14) {
            ReadinessGauge(value: 100, label: "recovery")
            ReadinessGauge(value: 49, label: "load_ratio")
            ReadinessGauge(value: 60, label: "sleep_quality")
        }
    }
    .padding()
    .screenBackground()
    .preferredColorScheme(.dark)
}
