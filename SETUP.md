# Building EarnIt without a Mac

GitHub Actions builds the app on a cloud Mac, and you install it on your iPhone over USB from Linux.

```
push to GitHub ──► cloud Mac: compile ──► sign ──► EarnIt.ipa ──► scripts/install-on-iphone.sh ──► iPhone
```

There are two stages:
- **Stage A** needs nothing. Every push compiles the app, so you find out right away whether the code builds.
- **Stage B** needs a one-time Apple setup, about 30 minutes. After that, every push produces an installable `.ipa`.

---

## Stage A: compile check (no Apple account needed)

1. Push this repo to GitHub.
2. Open the repo's **Actions** tab. The *Compile (unsigned)* job runs on every push.
3. If it fails, open the `compile-log` artifact, or run `gh run view --log-failed`, and fix the errors.

---

## Stage B: signed builds for your iPhone

### 1. Join the Apple Developer Program ($99/year)
Sign up at <https://developer.apple.com/programs/enroll/>. It works fine from a browser on Linux. Apple's Screen Time API isn't available to free accounts. Approval can take a day or two.

Your **Team ID** is shown at <https://developer.apple.com/account> under *Membership details*. It's 10 characters, like `AB12CD34EF`.

### 2. Pick your bundle ID
Bundle IDs must be globally unique, so swap the placeholder for your own:
```bash
scripts/set-bundle-id.sh com.yourname.earnit
git commit -am "Set bundle ID" && git push
```

### 3. Register your iPhone
1. Plug the iPhone into your PC, unlock it, and tap **Trust**.
2. Get its device ID (UDID):
   ```bash
   sudo pacman -S usbmuxd           # one-time: the service Linux uses to talk to iPhones over USB
   sudo systemctl start usbmuxd     # usually starts by itself when the iPhone is plugged in
   idevice_id -l                    # prints a long ID; if empty, re-plug, unlock, tap Trust
   ```
3. Add it at <https://developer.apple.com/account/resources/devices/add>. Platform is iOS; name it anything and paste the UDID.

### 4. Create the App Group
At <https://developer.apple.com/account/resources/identifiers/add/applicationGroup>, use identifier `group.com.yourname.earnit`. It must match step 2, with `group.` in front.

The cloud build registers the four app IDs and turns on Family Controls automatically. If it complains about the App Group, edit each app ID (`com.yourname.earnit`, `.ShieldConfiguration`, `.ShieldAction`, `.ActivityMonitor`) and tick **App Groups** with that group.

### 5. Create a development certificate (on Linux)
```bash
scripts/make-dev-cert.sh csr
```
1. Go to <https://developer.apple.com/account/resources/certificates/add>.
2. Choose **Apple Development** and upload `signing/EarnIt.certSigningRequest`.
3. Download the `.cer` file, then run:
```bash
scripts/make-dev-cert.sh p12 ~/Downloads/development.cer
```
The private key stays in `signing/`, which is git-ignored. Back that folder up somewhere safe.

### 6. Create an App Store Connect API key
1. Go to <https://appstoreconnect.apple.com/access/integrations/api>.
2. Click **Generate API Key**. Name it `GitHub CI` and give it the **Admin** role.
3. Note the **Key ID** and the **Issuer ID** shown above the key list.
4. Download the `AuthKey_XXXXXX.p8` file. Apple only lets you download it once.

### 7. Hand the credentials to GitHub
```bash
scripts/set-github-secrets.sh <TEAM_ID> <KEY_ID> <ISSUER_ID> ~/Downloads/AuthKey_XXXXXX.p8
gh workflow run ios.yml
```
They're stored as encrypted GitHub Actions secrets. Then delete the `.p8` from Downloads, keeping a backup copy somewhere safe.

### 8. Install on your iPhone
When the run finishes (`gh run watch`), install it:
```bash
pipx install pymobiledevice3      # one-time; or: yay -S ideviceinstaller
scripts/install-on-iphone.sh
```
- **First time only:** turn on **Settings → Privacy & Security → Developer Mode**. The phone restarts.
- After that, open EarnIt and go through onboarding.

From now on, `git push`, wait for the build, then run `scripts/install-on-iphone.sh`.

---

## Costs and limits
- **GitHub Actions Mac minutes:** free and unlimited for **public** repos. Private repos on the free plan get 2,000 minutes a month, and macOS minutes count 10×. That's about 200 real minutes, or roughly 15–25 builds.
- **Development builds:** these run only on devices registered in step 3 (up to 100 iPhones a year), and the provisioning profile expires after a year. Re-running the build refreshes it.

## Later: TestFlight and the App Store
1. Request the **Family Controls (Distribution)** entitlement for all four bundle IDs: <https://developer.apple.com/contact/request/family-controls-distribution>. TestFlight and the App Store won't accept the app without it.
2. Once approved, create the app and the four tip IAPs in App Store Connect.
3. Add an upload step to the workflow using an `app-store-connect` export. `xcrun altool` or `fastlane pilot` can upload to TestFlight with the same API key.

## Troubleshooting
| Problem | Fix |
|---|---|
| `No profiles for '…' were found` | Make sure the iPhone is registered (step 3) and the API key has the Admin role |
| `App Group … not available` | Create the group (step 4) and tick it on all four app IDs |
| `No signing certificate "Apple Development"` | Re-check step 5; `DEV_CERT_PASSWORD` must match `signing/dev-cert.password` |
| `idevice_id -l`: "Unable to retrieve device list" | `usbmuxd` isn't installed or running: `sudo pacman -S usbmuxd && sudo systemctl start usbmuxd` |
| `idevice_id -l` prints nothing | Re-plug, unlock the phone, tap **Trust**, then run `idevicepair pair` |
| Install fails with "Developer Mode" | Settings → Privacy & Security → Developer Mode |
| App installs but blocking does nothing | Finish onboarding; check Settings → Screen Time → Apps with Screen Time Access |
