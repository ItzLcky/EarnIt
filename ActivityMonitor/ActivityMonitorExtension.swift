import DeviceActivity
import Foundation

/// Runs in the background (even when EarnIt is closed) at the edges of scheduled intervals.
/// - Focus schedule start/end → turn shields on/off.
/// - Unlock interval end → re-lock the app that was earned.
class ActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == .focusSchedule {
            BlockingManager.applyShields(scheduleOverride: true)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .focusSchedule {
            BlockingManager.applyShields(scheduleOverride: false)
        } else if let id = activity.unlockID {
            BlockingManager.endUnlock(id: id)
        }
    }
}
