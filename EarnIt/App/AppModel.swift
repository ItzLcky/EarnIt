import SwiftUI
import FamilyControls

/// A request to earn an unlock, shown full-screen as the challenge flow.
struct ChallengeRequest: Identifiable, Equatable {
    let id = UUID()
    let target: UnlockTarget
}

@MainActor
final class AppModel: ObservableObject {
    private let store = SharedStore.shared

    @Published var authorized = false
    @Published var onboarded: Bool
    @Published var selection: FamilyActivitySelection
    @Published var blockingEnabled: Bool
    @Published var scheduleEnabled: Bool
    @Published var scheduleStart: Int
    @Published var scheduleEnd: Int
    @Published var strictMode: Bool
    @Published var escalation: Bool
    @Published var enabledChallenges: Set<ChallengeKind>
    @Published var activeUnlocks: [ActiveUnlock] = []
    @Published var daily = DailyStats()
    @Published var lifetime = LifetimeStats()
    @Published var challengeRequest: ChallengeRequest?

    init() {
        onboarded = store.onboarded
        selection = store.selection
        blockingEnabled = store.blockingEnabled
        scheduleEnabled = store.scheduleEnabled
        scheduleStart = store.scheduleStartMinutes
        scheduleEnd = store.scheduleEndMinutes
        strictMode = store.strictMode
        escalation = store.escalation
        enabledChallenges = store.enabledChallenges
        refresh()
    }

    var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var isBlockingNow: Bool { BlockingManager.isBlockingActive() }

    // MARK: Sync

    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        BlockingManager.applyShields()
        activeUnlocks = store.activeUnlocks
        daily = store.daily
        lifetime = store.lifetime
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            NSLog("EarnIt: authorization failed: \(error)")
        }
        refresh()
    }

    func finishOnboarding() {
        store.onboarded = true
        onboarded = true
        setBlocking(true)
    }

    // MARK: Settings

    func saveSelection(_ new: FamilyActivitySelection) {
        selection = new
        store.selection = new
        BlockingManager.applyShields()
    }

    func setBlocking(_ on: Bool) {
        blockingEnabled = on
        store.blockingEnabled = on
        if !on { BlockingManager.endAllUnlocks() }
        BlockingManager.updateSchedule()
        refresh()
    }

    func saveSchedule(enabled: Bool, start: Int, end: Int) {
        scheduleEnabled = enabled
        scheduleStart = start
        scheduleEnd = end
        store.scheduleEnabled = enabled
        store.scheduleStartMinutes = start
        store.scheduleEndMinutes = end
        BlockingManager.updateSchedule()
        refresh()
    }

    func setStrictMode(_ on: Bool) {
        strictMode = on
        store.strictMode = on
        BlockingManager.applyShields()
    }

    func setEscalation(_ on: Bool) {
        escalation = on
        store.escalation = on
    }

    func toggleChallenge(_ kind: ChallengeKind) {
        var set = enabledChallenges
        if set.contains(kind) {
            guard set.count > 1 else { return } // keep at least one
            set.remove(kind)
        } else {
            set.insert(kind)
        }
        enabledChallenges = set
        store.enabledChallenges = set
    }

    func baseAmount(_ kind: ChallengeKind) -> Int { store.baseAmount(for: kind) }
    func setBaseAmount(_ value: Int, for kind: ChallengeKind) {
        store.setBaseAmount(value, for: kind)
        objectWillChange.send()
    }

    func required(_ kind: ChallengeKind, _ duration: UnlockDuration) -> Int {
        store.requiredAmount(for: kind, duration: duration)
    }

    // MARK: Unlock flow

    /// Called when the app opens; if the user just tapped "Earn an unlock" on a shield, jump straight in.
    func checkPendingUnlock() {
        guard challengeRequest == nil, let pending = store.pendingUnlock else { return }
        store.pendingUnlock = nil
        Notifier.clearUnlockPrompt()
        if pending.isFresh {
            challengeRequest = ChallengeRequest(target: pending.target)
        }
    }

    func requestBreak() {
        challengeRequest = ChallengeRequest(target: .everything)
    }

    func completeChallenge(_ request: ChallengeRequest, kind: ChallengeKind, amount: Int, duration: UnlockDuration) {
        store.recordCompletion(kind: kind, amount: amount, minutes: duration.minutes)
        BlockingManager.grantUnlock(request.target, minutes: duration.minutes)
        refresh()
    }

    func lockNow(_ unlock: ActiveUnlock) {
        BlockingManager.endUnlock(id: unlock.id)
        refresh()
    }
}
