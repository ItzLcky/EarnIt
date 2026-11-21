# EarnIt

A free, donation-supported iOS screen-time blocker. Blocked apps stay locked until you **do something physical**: squats, push-ups, jumping jacks, a walk, or a photo hunt ("take a photo of a plant"). No ads, no accounts, no subscriptions, no tracking. Everything runs on-device.

## How it works

1. **Pick apps, categories, and websites to block** with Apple's Screen Time picker.
2. Open a blocked app and a custom **shield** covers it: *"Earn it first."*
3. Tap **Earn an unlock**. iOS doesn't let a shield open another app, so EarnIt posts a notification. Tap it to go straight to the challenge (or just open EarnIt).
4. Choose how long you need (5 / 15 / 30 / 60 min). Longer unlocks cost more effort.
5. Complete the challenge:
   | Challenge | How it's verified |
   |---|---|
   | Squats / push-ups / jumping jacks | Front camera + Vision body-pose, joint angles with hysteresis count real reps |
   | Walk | CoreMotion pedometer |
   | Photo hunt | Live camera only (no camera roll) + Vision on-device image classification |
6. That app unlocks for the time you earned, then **re-locks automatically**, even if EarnIt is closed (DeviceActivity monitor extension).

Extras: focus-hours schedule (including overnight windows), escalating difficulty with each unlock in a day, "earn a break from everything", strict mode (blocks deleting apps while blocking is on), and daily and lifetime stats including how many times you resisted.

## Project layout

```
project.yml                  XcodeGen spec (app + 3 extensions)
Shared/                      Compiled into every target
  SharedStore.swift          App Group UserDefaults: settings, unlocks, stats
  BlockingManager.swift      ManagedSettings shields + DeviceActivity timers
  Models.swift               Challenge kinds, durations, unlock targets
  Notifier.swift             "Tap to unlock" local notification
EarnIt/                      Main SwiftUI app
  App/                       Entry point, AppModel
  Views/                     Onboarding, Home, settings screens
  Challenges/                Flow, photo, exercise (pose), steps
  Support/                   StoreKit 2 tip jar + local .storekit test config
ShieldConfiguration/         Custom look of the block screen
ShieldAction/                Shield button handling
ActivityMonitor/             Re-locks when unlocks end; runs the schedule
```

## Building

**No Mac?** See [SETUP.md](SETUP.md) to build in the cloud with GitHub Actions and install from Linux.

### On a Mac

1. Install Xcode 16+ and XcodeGen: `brew install xcodegen`
2. Change the identifiers to your own. Replace `app.earnit` and `group.app.earnit` in `project.yml`, `Shared/SharedStore.swift` (`appGroup`) and `EarnIt/Support/TipJar.swift` (product IDs).
3. Set `DEVELOPMENT_TEAM` in `project.yml` (or in Xcode afterwards).
4. `xcodegen generate && open EarnIt.xcodeproj`
5. Run on a **real iPhone** (iOS 17+). The Screen Time APIs don't work in the Simulator.

The StoreKit test file is wired into the scheme, so tips can be tested locally without App Store Connect.

### Required capabilities (Apple Developer account)

- **Family Controls.** The development entitlement works right away for on-device testing. To ship on TestFlight or the App Store you must **request the Family Controls (Distribution) entitlement** from Apple for *each* of the 4 bundle IDs: <https://developer.apple.com/contact/request/family-controls-distribution>. Approval can take days to weeks, so request it early.
- **App Groups.** The same group must be on all 4 targets.

## Donations, App Store rules

Apple requires tips to an individual developer to go through In-App Purchase (guideline 3.1.1), so the tip jar uses four **consumable** IAPs that unlock nothing. Create them in App Store Connect with the IDs in `TipJar.swift`. Only registered nonprofits may take donations outside IAP. You can also list GitHub Sponsors, Ko-fi, or Liberapay on your website or GitHub README. Check the current rules for your storefront before linking to them from inside the app.

## Known iOS limitations

- **No direct open from the shield.** Apple doesn't let a shield extension launch apps, hence the notification hop. Opal and similar apps do the same.
- **DeviceActivity intervals must be at least 15 minutes.** Short unlocks schedule an interval that starts in the past, so only its end time matters.
- **Unlocking a category-blocked app.** It works per app via `.specific(categories, except: apps)`. A shield shown for a whole category with no app token falls back to "break from everything".
- **Screen Time access can be revoked.** Users can always revoke it in Settings. Apple guarantees that and EarnIt doesn't fight it.

## Privacy

No network code, no analytics, no accounts. Camera frames and photos are analyzed in memory and discarded. Apple's Screen Time tokens are opaque, so EarnIt never learns which apps you use.
