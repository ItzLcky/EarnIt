#!/usr/bin/env bash
# Download the latest signed build from GitHub Actions and install it on a USB-connected iPhone.
#
# Usage:
#   scripts/install-on-iphone.sh            # latest successful run on main
#   scripts/install-on-iphone.sh path.ipa   # install a local .ipa
set -euo pipefail
cd "$(dirname "$0")/.."

ipa="${1:-}"
if [[ -z "$ipa" ]]; then
  run_id="$(gh run list --workflow ios.yml --branch main --status success --limit 1 --json databaseId -q '.[0].databaseId')"
  [[ -n "$run_id" ]] || { echo "No successful build found yet. Check: gh run list" >&2; exit 1; }
  rm -rf build/download && mkdir -p build/download
  echo "⬇️  Downloading EarnIt.ipa from run $run_id…"
  gh run download "$run_id" --name EarnIt-ipa --dir build/download
  ipa="$(find build/download -name '*.ipa' | head -1)"
fi
[[ -f "$ipa" ]] || { echo "No .ipa found" >&2; exit 1; }

udid="$(idevice_id -l 2>/dev/null | head -1 || true)"
if [[ -z "$udid" ]]; then
  echo "No iPhone detected. Plug it in via USB, unlock it, tap 'Trust', and make sure usbmuxd is running:" >&2
  echo "  sudo systemctl start usbmuxd   (or: sudo usbmuxd -f)" >&2
  exit 1
fi
echo "📱 Found iPhone $udid"

if command -v ideviceinstaller >/dev/null; then
  ideviceinstaller -u "$udid" install "$ipa" 2>/dev/null || ideviceinstaller -u "$udid" -i "$ipa"
elif command -v pymobiledevice3 >/dev/null; then
  pymobiledevice3 apps install "$ipa"
else
  echo "Need an installer. Pick one:" >&2
  echo "  pipx install pymobiledevice3      (recommended)" >&2
  echo "  yay -S ideviceinstaller           (AUR)" >&2
  exit 1
fi

echo "✅ Installed. If iOS says 'Developer Mode required':"
echo "   Settings → Privacy & Security → Developer Mode → On (the phone restarts)."
