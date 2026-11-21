import SwiftUI

struct ChallengeSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(ChallengeKind.allCases) { kind in
                    Toggle(isOn: Binding(get: { model.enabledChallenges.contains(kind) },
                                         set: { _ in model.toggleChallenge(kind) })) {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }
            } header: {
                Text("Allowed challenges")
            } footer: {
                Text("When you unlock an app, you pick from these. At least one must stay on.")
            }

            Section {
                ForEach(ChallengeKind.allCases.filter { $0 != .photo }) { kind in
                    Stepper(value: Binding(get: { model.baseAmount(kind) },
                                           set: { model.setBaseAmount($0, for: kind) }),
                            in: 1...(kind == .steps ? 5000 : 100),
                            step: kind == .steps ? 50 : 1) {
                        HStack {
                            Text(kind.title)
                            Spacer()
                            Text("\(model.baseAmount(kind)) \(kind.unit)").foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Effort for a 5-minute unlock")
            } footer: {
                Text("15 min costs 2×, 30 min 3×, 1 hour 5×. Photo hunts need 1, 2, or 3 photos.")
            }

            Section {
                Toggle("Get harder with each unlock", isOn: Binding(get: { model.escalation },
                                                                     set: { model.setEscalation($0) }))
            } footer: {
                Text("Each unlock today adds a few reps to the next one. Resets at midnight.")
            }
        }
        .navigationTitle("Challenges")
    }
}

struct ScheduleView: View {
    @EnvironmentObject private var model: AppModel
    @State private var enabled = false
    @State private var start = Date()
    @State private var end = Date()

    var body: some View {
        Form {
            Section {
                Toggle("Only block during focus hours", isOn: $enabled)
                if enabled {
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text(enabled
                     ? "Apps are blocked every day between these times. Overnight windows (e.g. 10 PM – 7 AM) work too."
                     : "Blocking is on all day while the main switch is on.")
            }
        }
        .navigationTitle("Focus schedule")
        .onAppear {
            enabled = model.scheduleEnabled
            start = date(from: model.scheduleStart)
            end = date(from: model.scheduleEnd)
        }
        .onDisappear {
            model.saveSchedule(enabled: enabled, start: minutes(from: start), end: minutes(from: end))
        }
    }

    private func date(from minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

struct StrictModeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Prevent deleting apps", isOn: Binding(get: { model.strictMode },
                                                              set: { model.setStrictMode($0) }))
            } footer: {
                Text("While blocking is active, no app on this phone (including EarnIt) can be deleted. That stops the \"just reinstall it\" workaround. Turn blocking off to delete apps again.")
            }
            Section("Good to know") {
                Text("You can always revoke EarnIt's Screen Time access in Settings → Screen Time. Apple requires that, and EarnIt will never try to stop it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Strict mode")
    }
}
