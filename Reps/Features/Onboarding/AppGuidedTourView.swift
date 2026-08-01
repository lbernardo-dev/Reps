import SwiftUI

struct AppGuidedTourStep: Identifiable {
    let id: Int
    let titleKey: String
    let subtitleKey: String
    let systemImage: String
    let tab: AppTab
}

struct AppGuidedTourView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: AppTab
    var onFinish: (() -> Void)? = nil

    @State private var currentStep = 0

    private let steps: [AppGuidedTourStep] = [
        AppGuidedTourStep(
            id: 0,
            titleKey: "tour_step1_title",
            subtitleKey: "tour_step1_subtitle",
            systemImage: "sparkles",
            tab: .today
        ),
        AppGuidedTourStep(
            id: 1,
            titleKey: "tour_step2_title",
            subtitleKey: "tour_step2_subtitle",
            systemImage: "sun.max.fill",
            tab: .today
        ),
        AppGuidedTourStep(
            id: 2,
            titleKey: "tour_step3_title",
            subtitleKey: "tour_step3_subtitle",
            systemImage: "dumbbell.fill",
            tab: .train
        ),
        AppGuidedTourStep(
            id: 3,
            titleKey: "tour_step4_title",
            subtitleKey: "tour_step4_subtitle",
            systemImage: "chart.line.uptrend.xyaxis",
            tab: .progress
        ),
        AppGuidedTourStep(
            id: 4,
            titleKey: "tour_step5_title",
            subtitleKey: "tour_step5_subtitle",
            systemImage: "figure.strengthtraining.traditional",
            tab: .exercises
        ),
        AppGuidedTourStep(
            id: 5,
            titleKey: "tour_step6_title",
            subtitleKey: "tour_step6_subtitle",
            systemImage: "person.crop.circle.fill",
            tab: .profile
        )
    ]

    var body: some View {
        ZStack {
            // Darkened backdrop overlay
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack {
                Spacer()

                // Floating Modal Card
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: steps[currentStep].systemImage)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .frame(width: 44, height: 44)
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizedString(steps[currentStep].titleKey))
                                .font(.title3.bold())
                                .foregroundStyle(PulseTheme.primaryText)

                            Text(localizedFormat("onboarding_step_format", currentStep + 1, steps.count))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    Text(localizedString(steps[currentStep].subtitleKey))
                        .font(.body)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    // Navigation Footer Row
                    HStack(alignment: .center) {
                        Button(localizedString("tour_skip_guide")) {
                            dismissTour()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .buttonStyle(.plain)

                        Spacer()

                        // Page indicator dots
                        HStack(spacing: 6) {
                            ForEach(0..<steps.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentStep ? PulseTheme.accent : PulseTheme.separator)
                                    .frame(width: idx == currentStep ? 8 : 6, height: idx == currentStep ? 8 : 6)
                                    .animation(.spring(duration: 0.25), value: currentStep)
                            }
                        }

                        Spacer()

                        Button {
                            if currentStep < steps.count - 1 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    currentStep += 1
                                    selectedTab = steps[currentStep].tab
                                }
                                HapticService.selection()
                            } else {
                                dismissTour()
                            }
                        } label: {
                            Text(currentStep == steps.count - 1
                                 ? localizedString("tour_finish_step")
                                 : localizedString("tour_next_step"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(PulseTheme.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)
                }
                .padding(24)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(PulseTheme.separator.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .onAppear {
            selectedTab = steps[currentStep].tab
        }
    }

    private func dismissTour() {
        HapticService.notification(.success)
        withAnimation(.spring(duration: 0.3)) {
            selectedTab = .today
            isPresented = false
        }
        onFinish?()
    }
}
