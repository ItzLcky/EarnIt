import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.onboarded && model.authorized {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $model.challengeRequest) { request in
            ChallengeFlowView(request: request)
        }
    }
}
