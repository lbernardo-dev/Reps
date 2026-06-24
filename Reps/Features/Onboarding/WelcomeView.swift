import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ProfileSetupView(
            onFinish: { result in
                store.completeOnboarding(result: result)
            }
        )
        .preferredColorScheme(.dark)
    }
}
