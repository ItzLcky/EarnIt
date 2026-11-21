import SwiftUI
import CoreMotion

@MainActor
final class StepCounter: ObservableObject {
    @Published var steps = 0
    @Published var error: String?
    private let pedometer = CMPedometer()

    func start() {
        guard CMPedometer.isStepCountingAvailable() else {
            error = "Step counting isn't available on this device."
            return
        }
        pedometer.startUpdates(from: Date()) { [weak self] data, err in
            Task { @MainActor in
                if let err {
                    self?.error = "Couldn't read steps. Allow Motion & Fitness in Settings. (\(err.localizedDescription))"
                } else if let n = data?.numberOfSteps.intValue {
                    self?.steps = n
                }
            }
        }
    }

    func stop() { pedometer.stopUpdates() }
}

struct StepsChallengeView: View {
    let goal: Int
    let onComplete: () -> Void
    @StateObject private var counter = StepCounter()
    @State private var finished = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 22)
                Circle()
                    .trim(from: 0, to: min(1, Double(counter.steps) / Double(goal)))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: counter.steps)
                VStack {
                    Text("\(counter.steps)").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("of \(goal) steps").foregroundStyle(.secondary)
                }
            }
            .frame(width: 260, height: 260)
            Text("Put the phone in your pocket and go for a walk. Steps update as you move.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let error = counter.error {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { counter.start() }
        .onDisappear { counter.stop() }
        .onChange(of: counter.steps) { _, n in
            if n >= goal && !finished {
                finished = true
                counter.stop()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete()
            }
        }
    }
}
