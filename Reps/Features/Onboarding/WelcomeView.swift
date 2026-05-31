import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showSplash = true
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var subtitleOpacity: Double = 0.0
    @State private var backgroundScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if showSplash {
                // Brand Atmospheric Splash View
                ZStack {
                    PulseTheme.background
                        .ignoresSafeArea()
                    
                    // Radial gradient glow
                    RadialGradient(
                        colors: [PulseTheme.primary.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 360
                    )
                    .scaleEffect(backgroundScale)
                    .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Geometric barbell logo
                        VStack(spacing: 12) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PulseTheme.primaryBright)
                                    .frame(width: 8, height: 48)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PulseTheme.primary)
                                    .frame(width: 14, height: 64)
                                
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [PulseTheme.primary, PulseTheme.accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 90, height: 8)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PulseTheme.primary)
                                    .frame(width: 14, height: 64)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PulseTheme.primaryBright)
                                    .frame(width: 8, height: 48)
                            }
                            .shadow(color: PulseTheme.primary.opacity(0.5), radius: 18)
                            
                            Text("REPS")
                                .font(.system(size: 46, weight: .black, design: .rounded))
                                .tracking(10)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.85)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        
                        Text("INTELIGENCIA MUSCULAR")
                            .font(.caption.weight(.black))
                            .tracking(5)
                            .foregroundStyle(PulseTheme.accent)
                            .opacity(subtitleOpacity)
                        
                        Spacer()
                        
                        // Loading Indicator
                        ProgressView()
                            .tint(PulseTheme.primaryBright)
                            .scaleEffect(1.2)
                            .opacity(logoOpacity)
                            .padding(.bottom, 48)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .onAppear {
                    // Sequence animations
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.72).delay(0.2)) {
                        logoScale = 1.0
                        logoOpacity = 1.0
                    }
                    
                    withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                        subtitleOpacity = 1.0
                    }
                    
                    withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                        backgroundScale = 1.2
                    }
                    
                    // Transition to Setup View after 2.6 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                            showSplash = false
                        }
                    }
                }
            } else {
                ProfileSetupView { result in
                    store.completeOnboarding(result: result)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .preferredColorScheme(.dark)
    }
}
