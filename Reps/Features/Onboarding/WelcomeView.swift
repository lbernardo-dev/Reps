import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                RepsLoadingView(
                    messages: [
                        "Preparando inteligencia muscular...",
                        "Analizando tu punto de partida...",
                        "Ajustando la experiencia Reps..."
                    ],
                    progress: nil,
                    layout: .splash
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                            showSplash = false
                        }
                    }
                }
            } else {
                ProfileSetupView(
                    onFinish: { result in
                        store.completeOnboarding(result: result)
                    },
                    onSkip: {
                        store.skipOnboarding()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .preferredColorScheme(.dark)
    }
}
