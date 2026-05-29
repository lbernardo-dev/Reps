import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ProfileSetupView { result in
            store.completeOnboarding(result: result)
        }
    }
}
