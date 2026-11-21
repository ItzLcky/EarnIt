import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var showPicker = false
    @State private var draft = FamilyActivitySelection()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            switch step {
            case 0: welcome
            case 1: screenTime
            case 2: notifications
            default: pickApps
            }
            Spacer()
            ProgressDots(count: 4, index: step)
        }
        .padding(24)
        .familyActivityPicker(isPresented: $showPicker, selection: $draft)
        .onChange(of: model.authorized) { _, ok in
            if ok && step == 1 { step = 2 }
        }
    }

    private var welcome: some View {
        OnboardingPage(
            icon: "figure.run.circle.fill",
            title: "Earn your screen time",
            text: "Block the apps that eat your day. To open one, you'll need to do something real first: a few squats, a short walk, or a photo of something in the world.\n\n100% free. No ads, no accounts, no tracking. Supported only by optional tips."
        ) {
            Button("Get started") { step = 1 }.buttonStyle(.primary)
        }
    }

    private var screenTime: some View {
        OnboardingPage(
            icon: "hourglass",
            title: "Allow Screen Time access",
            text: "EarnIt uses Apple's Screen Time framework to block apps. Apple keeps your app list private: EarnIt never sees which apps you use, and nothing leaves your phone."
        ) {
            Button("Allow access") {
                Task {
                    await model.requestAuthorization()
                    if model.authorized { step = 2 }
                }
            }.buttonStyle(.primary)
        }
    }

    private var notifications: some View {
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Turn on notifications",
            text: "When you tap \"Earn an unlock\" on a blocked app, EarnIt sends a notification that takes you straight to your challenge. iOS doesn't let a blocked screen open the app directly."
        ) {
            Button("Enable notifications") {
                Task {
                    _ = await Notifier.requestPermission()
                    step = 3
                }
            }.buttonStyle(.primary)
            Button("Not now") { step = 3 }.foregroundStyle(.secondary)
        }
    }

    private var pickApps: some View {
        OnboardingPage(
            icon: "apps.iphone",
            title: "Pick what to block",
            text: draft.applicationTokens.isEmpty && draft.categoryTokens.isEmpty && draft.webDomainTokens.isEmpty
                ? "Choose the apps, categories, or websites that distract you most. You can change this any time."
                : "\(draft.applicationTokens.count) apps, \(draft.categoryTokens.count) categories, \(draft.webDomainTokens.count) sites selected."
        ) {
            Button("Choose apps") { showPicker = true }.buttonStyle(.secondary)
            Button("Start blocking") {
                model.saveSelection(draft)
                model.finishOnboarding()
            }
            .buttonStyle(.primary)
            .disabled(draft.applicationTokens.isEmpty && draft.categoryTokens.isEmpty && draft.webDomainTokens.isEmpty)
        }
    }
}

private struct OnboardingPage<Actions: View>: View {
    let icon: String
    let title: String
    let text: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
            Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(text).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(spacing: 12) { actions }.padding(.top, 12)
        }
    }
}

private struct ProgressDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
        }
        .animation(.spring, value: index)
    }
}
