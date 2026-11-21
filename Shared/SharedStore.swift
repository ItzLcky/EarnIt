import Foundation
import FamilyControls

/// All state lives in the App Group so the app and its extensions see the same data.
/// Extensions are short-lived processes, so every accessor reads/writes UserDefaults directly.
final class SharedStore {
    static let appGroup = "group.app.earnit"
    static let shared = SharedStore()

    let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: SharedStore.appGroup) ?? .standard
    }

    private enum Key {
        static let selection = "selection"
        static let blockingEnabled = "blockingEnabled"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleStart = "scheduleStartMinutes"
        static let scheduleEnd = "scheduleEndMinutes"
        static let strictMode = "strictMode"
        static let activeUnlocks = "activeUnlocks"
        static let pendingUnlock = "pendingUnlock"
        static let enabledChallenges = "enabledChallenges"
        static let baseAmounts = "baseAmounts"
        static let escalation = "escalation"
        static let daily = "dailyStats"
        static let lifetime = "lifetimeStats"
        static let onboarded = "onboarded"
    }

    // MARK: Codable helpers

    private func get<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func set<T: Encodable>(_ value: T?, for key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    // MARK: Blocking configuration

    var selection: FamilyActivitySelection {
        get { get(Key.selection, as: FamilyActivitySelection.self) ?? FamilyActivitySelection() }
        set { set(newValue, for: Key.selection) }
    }

    var blockingEnabled: Bool {
        get { defaults.bool(forKey: Key.blockingEnabled) }
        set { defaults.set(newValue, forKey: Key.blockingEnabled) }
    }

    var scheduleEnabled: Bool {
        get { defaults.bool(forKey: Key.scheduleEnabled) }
        set { defaults.set(newValue, forKey: Key.scheduleEnabled) }
    }

    /// Minutes after midnight.
    var scheduleStartMinutes: Int {
        get { defaults.object(forKey: Key.scheduleStart) as? Int ?? 9 * 60 }
        set { defaults.set(newValue, forKey: Key.scheduleStart) }
    }

    var scheduleEndMinutes: Int {
        get { defaults.object(forKey: Key.scheduleEnd) as? Int ?? 17 * 60 }
        set { defaults.set(newValue, forKey: Key.scheduleEnd) }
    }

    /// Hard mode: apps can't be deleted while blocking is active.
    var strictMode: Bool {
        get { defaults.bool(forKey: Key.strictMode) }
        set { defaults.set(newValue, forKey: Key.strictMode) }
    }

    var onboarded: Bool {
        get { defaults.bool(forKey: Key.onboarded) }
        set { defaults.set(newValue, forKey: Key.onboarded) }
    }

    // MARK: Unlocks

    var activeUnlocks: [ActiveUnlock] {
        get { get(Key.activeUnlocks, as: [ActiveUnlock].self) ?? [] }
        set { set(newValue, for: Key.activeUnlocks) }
    }

    var pendingUnlock: PendingUnlock? {
        get { get(Key.pendingUnlock, as: PendingUnlock.self) }
        set { set(newValue, for: Key.pendingUnlock) }
    }

    // MARK: Challenge settings

    var enabledChallenges: Set<ChallengeKind> {
        get {
            let raw = defaults.stringArray(forKey: Key.enabledChallenges)
            guard let raw else { return Set(ChallengeKind.allCases) }
            let set = Set(raw.compactMap(ChallengeKind.init(rawValue:)))
            return set.isEmpty ? Set(ChallengeKind.allCases) : set
        }
        set { defaults.set(newValue.map(\.rawValue), forKey: Key.enabledChallenges) }
    }

    func baseAmount(for kind: ChallengeKind) -> Int {
        let map = get(Key.baseAmounts, as: [String: Int].self) ?? [:]
        return map[kind.rawValue] ?? kind.defaultBase
    }

    func setBaseAmount(_ value: Int, for kind: ChallengeKind) {
        var map = get(Key.baseAmounts, as: [String: Int].self) ?? [:]
        map[kind.rawValue] = max(1, value)
        set(map, for: Key.baseAmounts)
    }

    /// Each unlock today makes the next one a little harder.
    var escalation: Bool {
        get { defaults.object(forKey: Key.escalation) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.escalation) }
    }

    func requiredAmount(for kind: ChallengeKind, duration: UnlockDuration) -> Int {
        if kind == .photo { return duration.photoCount }
        let base = Double(baseAmount(for: kind)) * duration.multiplier
        let extra = escalation ? kind.escalationStep * daily.unlocks : 0
        return Int(base.rounded()) + extra
    }

    // MARK: Stats

    var daily: DailyStats {
        get {
            let stats = get(Key.daily, as: DailyStats.self) ?? DailyStats()
            return stats.day == DailyStats.today() ? stats : DailyStats()
        }
        set { set(newValue, for: Key.daily) }
    }

    var lifetime: LifetimeStats {
        get { get(Key.lifetime, as: LifetimeStats.self) ?? LifetimeStats() }
        set { set(newValue, for: Key.lifetime) }
    }

    func recordCompletion(kind: ChallengeKind, amount: Int, minutes: Int) {
        var d = daily
        var l = lifetime
        d.unlocks += 1
        l.unlocks += 1
        d.minutesEarned += minutes
        switch kind {
        case .photo: d.photos += amount; l.photos += amount
        case .steps: d.steps += amount; l.steps += amount
        default: d.reps += amount; l.reps += amount
        }
        daily = d
        lifetime = l
    }

    func recordResisted() {
        var l = lifetime
        l.resisted += 1
        lifetime = l
    }
}
