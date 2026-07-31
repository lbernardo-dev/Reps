import SwiftUI

// MARK: - Progress Header

struct OnboardingProgressHeader: View {
    let progress: Double
    let currentStepIndex: Int
    let totalSteps: Int
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if canGoBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .navigationGlassCircle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Atrás")
            } else {
                Color.clear
                    .frame(width: 38, height: 38)
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(PulseTheme.grouped)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [PulseTheme.accent, PulseTheme.ringStand],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * min(max(progress, 0), 1))
                            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: progress)
                    }
            }
            .frame(height: 5)

            if totalSteps > 0 {
                Text("\(currentStepIndex)/\(totalSteps)")
                    .font(.caption2.weight(.black).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(PulseTheme.grouped)
                    .clipShape(Capsule())
            }
        }
        .frame(height: 38)
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

// MARK: - Title Header

struct OnboardingTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(localizedKey(title))
                .font(.system(size: 34, weight: .heavy))
                .lineLimit(4)
                .minimumScaleFactor(0.72)
            Text(localizedKey(subtitle))
                .font(.title3.weight(.medium))
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Option Card

struct OnboardingOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? PulseTheme.onColor(tint) : tint)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? tint : tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedKey(title))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(localizedKey(subtitle))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : PulseTheme.tertiaryText)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .background(isSelected ? .white.opacity(0.08) : PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.9) : PulseTheme.separator, lineWidth: isSelected ? 1.8 : 1)
            )
            .shadow(color: isSelected ? tint.opacity(0.20) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .pressableFeedback(scale: 0.965)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Number Picker

struct OnboardingNumberPicker: View {
    let title: String
    @Binding var value: Int
    let options: [Int]
    let unit: String
    let helper: String

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(localizedKey(title))
                        .font(.headline)
                    Spacer()
                    Text(localizedKey(helper))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(value)")
                        .font(.system(size: 68, weight: .heavy))
                        .contentTransition(.numericText(value: Double(value)))
                    Text(localizedKey(unit))
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            value = option
                        } label: {
                            Text(option == 90 && unit == "onboarding_schedule_duration_unit" ? "90+" : "\(option)")
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(value == option ? .black : PulseTheme.secondaryText)
                                .background(value == option ? .white : PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .pressableFeedback(scale: 0.94)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

// MARK: - Metric Slider

struct OnboardingMetricSlider: View {
    let title: String
    let valueText: String
    let unit: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private var progress: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
                    Text(localizedKey(title))
                        .font(.headline)
                    Spacer()
                }

                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text(valueText)
                        .font(.system(size: 56, weight: .heavy))
                        .contentTransition(.numericText(value: value))
                    Text(localizedKey(unit))
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Slider(value: $value, in: range, step: step)
                    .tint(.white)

                TickRail(progress: progress)
                    .frame(height: 30)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

struct TickRail: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let activeX = proxy.size.width * clampedProgress

            ZStack(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<31, id: \.self) { index in
                        Rectangle()
                            .fill(index % 5 == 0 ? PulseTheme.secondaryText.opacity(0.55) : PulseTheme.separator.opacity(0.9))
                            .frame(width: 1.3, height: index % 5 == 0 ? 25 : 15)
                            .frame(maxWidth: .infinity)
                    }
                }

                Rectangle()
                    .fill(.white)
                    .frame(width: 3, height: 30)
                    .offset(x: activeX - 1.5)
                    .shadow(color: .white.opacity(0.36), radius: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Equipment Chip

struct EquipmentChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(localizedKey(title))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .contentShape(Capsule())
                .foregroundStyle(isSelected ? .black : PulseTheme.secondaryText)
                .background(isSelected ? PulseTheme.accent : PulseTheme.grouped)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .pressableFeedback(scale: 0.94)
    }
}

// MARK: - Flow Layout

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 122), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content
        }
    }
}

// MARK: - Generation UI Helpers

struct GenerationPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(localizedKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PulseTheme.card)
        .clipShape(Capsule())
    }
}

struct GenerationStepRow: View {
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    let isLast: Bool
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(PulseTheme.ringStand)
                    } else if isActive {
                        Circle()
                            .stroke(PulseTheme.ringStand, lineWidth: 2.5)
                            .frame(width: 22, height: 22)
                            .scaleEffect(pulse ? 1.15 : 0.88)
                            .opacity(pulse ? 1 : 0.55)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    } else {
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 26, height: 26)

                Text(localizedKey(title))
                    .font(.subheadline.weight(isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : (isCompleted ? .white.opacity(0.75) : PulseTheme.secondaryText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 4)
            .background(isActive ? .white.opacity(0.07) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !isLast {
                HStack(spacing: 14) {
                    Rectangle()
                        .fill(isCompleted ? PulseTheme.ringStand.opacity(0.5) : .white.opacity(0.14))
                        .frame(width: 1.5, height: 14)
                        .frame(width: 26)
                    Spacer()
                }
            }
        }
        .onAppear { pulse = isActive }
        .onChange(of: isActive) { _, v in pulse = v }
    }
}
