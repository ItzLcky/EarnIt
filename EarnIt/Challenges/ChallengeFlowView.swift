import SwiftUI
import CoreMotion
import AVFoundation

/// Full-screen flow: pick how long → pick a challenge → do it → unlocked.
struct ChallengeFlowView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: ChallengeRequest

    private enum Step: Equatable {
        case duration
        case pick(UnlockDuration)
        case run(ChallengeKind, UnlockDuration)
        case done(UnlockDuration)
    }

    @State private var step: Step = .duration

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .duration: durationPicker
                case .pick(let d): challengePicker(d)
                case .run(let kind, let d): runner(kind, d)
                case .done(let d): success(d)
                }
            }
            .animation(.default, value: step)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .done = step {} else {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: Steps

    private var header: some View {
        VStack(spacing: 8) {
            UnlockTargetLabel(target: request.target)
                .font(.title3.weight(.semibold))
            if model.daily.unlocks > 0 && model.escalation {
                Text("Unlock #\(model.daily.unlocks + 1) today, so it's a bit harder.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var durationPicker: some View {
        VStack(spacing: 20) {
            header
            Text("How long do you need?").font(.largeTitle.bold()).multilineTextAlignment(.center)
            ForEach(UnlockDuration.allCases) { d in
                Button {
                    step = .pick(d)
                } label: {
                    HStack {
                        Text(d.label).font(.title3.bold())
                        Spacer()
                        Text(d == .five ? "easiest" : "\(d.multiplier.formatted())× effort")
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(20)
    }

    private func challengePicker(_ duration: UnlockDuration) -> some View {
        let kinds = ChallengeKind.allCases.filter { model.enabledChallenges.contains($0) && isAvailable($0) }
        return VStack(spacing: 16) {
            header
            Text("Pick your challenge").font(.largeTitle.bold())
            Text("for \(duration.label)").foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(kinds) { kind in
                        Button {
                            step = .run(kind, duration)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: kind.systemImage)
                                    .font(.title)
                                    .frame(width: 44)
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading) {
                                    Text(kind.title).font(.headline)
                                    Text("\(model.required(kind, duration)) \(kind.unit)")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .padding(18)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    if let random = kinds.randomElement() {
                        Button("Surprise me 🎲") { step = .run(random, duration) }
                            .buttonStyle(.secondary)
                    }
                }
            }
            Button("Back") { step = .duration }.foregroundStyle(.secondary)
        }
        .padding(20)
    }

    @ViewBuilder
    private func runner(_ kind: ChallengeKind, _ duration: UnlockDuration) -> some View {
        let amount = model.required(kind, duration)
        let finish: () -> Void = {
            model.completeChallenge(request, kind: kind, amount: amount, duration: duration)
            step = .done(duration)
        }
        switch kind {
        case .photo:
            PhotoChallengeView(count: amount, onComplete: finish)
        case .steps:
            StepsChallengeView(goal: amount, onComplete: finish)
        case .squats, .pushups, .jumpingJacks:
            ExerciseChallengeView(kind: kind, goal: amount, onComplete: finish)
        }
    }

    private func success(_ duration: UnlockDuration) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 96))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: step)
            Text("Earned it!").font(.largeTitle.bold())
            UnlockTargetLabel(target: request.target)
            Text("is open for \(duration.label). Go back to it now. It locks again automatically.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(.primary)
        }
        .padding(24)
    }

    private func isAvailable(_ kind: ChallengeKind) -> Bool {
        switch kind {
        case .steps: return CMPedometer.isStepCountingAvailable()
        case .photo: return UIImagePickerController.isSourceTypeAvailable(.camera)
        default: return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
        }
    }
}
