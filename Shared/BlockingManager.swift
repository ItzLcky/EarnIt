import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

extension ManagedSettingsStore.Name {
    static let earnIt = Self("earnit")
}

extension DeviceActivityName {
    static let focusSchedule = Self("earnit.schedule")
    static let unlockPrefix = "earnit.unlock."

    static func unlock(_ id: String) -> Self { Self(unlockPrefix + id) }

    var unlockID: String? {
        rawValue.hasPrefix(Self.unlockPrefix) ? String(rawValue.dropFirst(Self.unlockPrefix.count)) : nil
    }
}

/// Applies shields and schedules timers. Safe to call from the app and any extension.
enum BlockingManager {
    private static let store = ManagedSettingsStore(named: .earnIt)
    private static let center = DeviceActivityCenter()
    private static var data: SharedStore { .shared }

    // MARK: State

    /// Whether the focus schedule (if any) says we should be blocking right now.
    static func isWithinSchedule(_ date: Date = Date()) -> Bool {
        guard data.scheduleEnabled else { return true }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let now = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let start = data.scheduleStartMinutes
        let end = data.scheduleEndMinutes
        if start == end { return true }
        return start < end ? (now >= start && now < end) : (now >= start || now < end) // overnight window
    }

    static func isBlockingActive(scheduleOverride: Bool? = nil) -> Bool {
        data.blockingEnabled && (scheduleOverride ?? isWithinSchedule())
    }

    // MARK: Shields

    /// Recomputes every shield from scratch. Call after any state change.
    /// - Parameter scheduleOverride: lets the monitor extension force the schedule state at interval edges,
    ///   where the wall clock can be a few seconds off.
    static func applyShields(scheduleOverride: Bool? = nil) {
        pruneExpiredUnlocks()

        guard isBlockingActive(scheduleOverride: scheduleOverride) else {
            store.clearAllSettings()
            return
        }

        let unlocks = data.activeUnlocks
        if unlocks.contains(where: { $0.target == .everything }) {
            store.clearAllSettings()
            return
        }

        let sel = data.selection
        let freeApps = Set(unlocks.compactMap(\.target.appToken))
        let freeWeb = Set(unlocks.compactMap(\.target.webToken))

        let apps = sel.applicationTokens.subtracting(freeApps)
        store.shield.applications = apps.isEmpty ? nil : apps

        let sites = sel.webDomainTokens.subtracting(freeWeb)
        store.shield.webDomains = sites.isEmpty ? nil : sites

        if sel.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(sel.categoryTokens, except: freeApps)
            store.shield.webDomainCategories = .specific(sel.categoryTokens, except: freeWeb)
        }

        store.application.denyAppRemoval = data.strictMode ? true : nil
    }

    static func pruneExpiredUnlocks() {
        let all = data.activeUnlocks
        let live = all.filter(\.isActive)
        if live.count != all.count { data.activeUnlocks = live }
    }

    // MARK: Unlocks

    /// Grants a timed unlock and schedules a DeviceActivity interval whose end re-locks it,
    /// even if the app is killed.
    @discardableResult
    static func grantUnlock(_ target: UnlockTarget, minutes: Int) -> ActiveUnlock {
        let now = Date()
        let unlock = ActiveUnlock(target: target, expires: now.addingTimeInterval(TimeInterval(minutes * 60)))

        var list = data.activeUnlocks.filter { $0.isActive && $0.target != target }
        list.append(unlock)
        data.activeUnlocks = list
        applyShields()

        // DeviceActivity intervals must be ≥ 15 minutes, so for short unlocks we start the
        // interval in the past; only its *end* matters to us.
        let end = unlock.expires
        let start = min(now, end.addingTimeInterval(-15 * 60 - 30))
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(fields, from: start),
            intervalEnd: Calendar.current.dateComponents(fields, from: end),
            repeats: false
        )
        do {
            try center.startMonitoring(.unlock(unlock.id), during: schedule)
        } catch {
            NSLog("EarnIt: failed to schedule relock: \(error)")
        }
        cleanUpStaleMonitors()
        return unlock
    }

    static func endUnlock(id: String) {
        data.activeUnlocks = data.activeUnlocks.filter { $0.id != id }
        center.stopMonitoring([.unlock(id)])
        applyShields()
    }

    static func endAllUnlocks() {
        let ids = data.activeUnlocks.map { DeviceActivityName.unlock($0.id) }
        data.activeUnlocks = []
        center.stopMonitoring(ids)
        applyShields()
    }

    /// iOS limits how many activities can be monitored, so drop ones for expired unlocks.
    private static func cleanUpStaleMonitors() {
        let live = Set(data.activeUnlocks.map(\.id))
        let stale = center.activities.filter { name in
            guard let id = name.unlockID else { return false }
            return !live.contains(id)
        }
        if !stale.isEmpty { center.stopMonitoring(stale) }
    }

    // MARK: Focus schedule

    static func updateSchedule() {
        center.stopMonitoring([.focusSchedule])
        if data.blockingEnabled && data.scheduleEnabled {
            let s = data.scheduleStartMinutes, e = data.scheduleEndMinutes
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: s / 60, minute: s % 60),
                intervalEnd: DateComponents(hour: e / 60, minute: e % 60),
                repeats: true
            )
            do {
                try center.startMonitoring(.focusSchedule, during: schedule)
            } catch {
                NSLog("EarnIt: failed to start schedule: \(error)")
            }
        }
        applyShields()
    }
}
