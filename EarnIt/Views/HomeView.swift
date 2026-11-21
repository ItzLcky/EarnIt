import SwiftUI
import FamilyControls

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPicker = false
    @State private var draft = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    if !model.activeUnlocks.isEmpty { unlocksCard }
                    blockedCard
                    statsCard
                    settingsLinks
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("EarnIt")
            .familyActivityPicker(isPresented: $showPicker, selection: $draft)
            .onChange(of: showPicker) { _, open in
                if !open { model.saveSelection(draft) }
            }
            .refreshable { model.refresh() }
        }
    }

    // MARK: Cards

    private var statusCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle).font(.title2.bold())
                    Text(statusDetail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { model.blockingEnabled }, set: { model.setBlocking($0) }))
                    .labelsHidden()
            }
            if model.blockingEnabled && model.isBlockingNow {
                Button {
                    model.requestBreak()
                } label: {
                    Label("Earn a break from everything", systemImage: "cup.and.saucer.fill")
                }
                .buttonStyle(.secondary)
            }
        }
    }

    private var statusTitle: String {
        if !model.blockingEnabled { return "Blocking is off" }
        return model.isBlockingNow ? "Blocking is on" : "Outside focus hours"
    }

    private var statusDetail: String {
        if !model.blockingEnabled { return "Your apps are open. Flip the switch to block them." }
        if model.scheduleEnabled {
            return "Focus hours \(formatMinutes(model.scheduleStart)) – \(formatMinutes(model.scheduleEnd))"
        }
        return "Blocked apps need a challenge to open."
    }

    private var unlocksCard: some View {
        Card {
            Text("Unlocked right now").font(.headline)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 10) {
                    ForEach(model.activeUnlocks) { unlock in
                        HStack {
                            UnlockTargetLabel(target: unlock.target)
                            Spacer()
                            Text(remaining(unlock.expires, now: context.date))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Button("Lock") { model.lockNow(unlock) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private func remaining(_ end: Date, now: Date) -> String {
        let s = max(0, Int(end.timeIntervalSince(now)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var blockedCard: some View {
        Card {
            HStack {
                Text("Blocked").font(.headline)
                Spacer()
                Button("Edit") {
                    draft = model.selection
                    showPicker = true
                }
            }
            if model.selectionCount == 0 {
                Text("Nothing blocked yet.").foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(model.selection.applicationTokens), id: \.self) { token in
                            Label(token).labelStyle(.iconOnly).font(.largeTitle)
                        }
                        ForEach(Array(model.selection.categoryTokens), id: \.self) { token in
                            Label(token).labelStyle(.iconOnly).font(.largeTitle)
                        }
                        ForEach(Array(model.selection.webDomainTokens), id: \.self) { token in
                            Label(token).labelStyle(.iconOnly).font(.largeTitle)
                        }
                    }
                }
                Text(summary).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var summary: String {
        let s = model.selection
        var parts: [String] = []
        if !s.applicationTokens.isEmpty { parts.append("\(s.applicationTokens.count) apps") }
        if !s.categoryTokens.isEmpty { parts.append("\(s.categoryTokens.count) categories") }
        if !s.webDomainTokens.isEmpty { parts.append("\(s.webDomainTokens.count) websites") }
        return parts.joined(separator: " · ")
    }

    private var statsCard: some View {
        Card {
            Text("Today").font(.headline)
            HStack {
                Stat(value: model.daily.unlocks, label: "unlocks")
                Stat(value: model.daily.reps, label: "reps")
                Stat(value: model.daily.steps, label: "steps")
                Stat(value: model.daily.photos, label: "photos")
            }
            Divider()
            HStack {
                Text("All time: \(model.lifetime.reps) reps, \(model.lifetime.steps) steps, resisted \(model.lifetime.resisted)×")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsLinks: some View {
        VStack(spacing: 0) {
            NavLinkRow(icon: "figure.strengthtraining.functional", title: "Challenges") { ChallengeSettingsView() }
            Divider().padding(.leading, 52)
            NavLinkRow(icon: "calendar.badge.clock", title: "Focus schedule") { ScheduleView() }
            Divider().padding(.leading, 52)
            NavLinkRow(icon: "lock.shield", title: "Strict mode") { StrictModeView() }
            Divider().padding(.leading, 52)
            NavLinkRow(icon: "heart.fill", title: "Support EarnIt") { SupportView() }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct UnlockTargetLabel: View {
    let target: UnlockTarget
    var body: some View {
        switch target {
        case .app(let token): Label(token)
        case .web(let token): Label(token)
        case .everything: Label("Everything", systemImage: "square.grid.2x2")
        }
    }
}

private struct Stat: View {
    let value: Int
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NavLinkRow<Destination: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundStyle(Color.accentColor)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }
}
