#!/usr/bin/env bash
# Replace the placeholder bundle ID prefix (app.earnit) with your own, everywhere it's used.
# Usage: scripts/set-bundle-id.sh com.yourname.earnit
set -euo pipefail
cd "$(dirname "$0")/.."

new="${1:-}"
if [[ ! "$new" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "Usage: $0 com.yourname.earnit   (reverse-DNS, letters/digits/hyphens/dots)" >&2
  exit 1
fi

old="$(sed -n 's/^  bundleIdPrefix: //p' project.yml)"
if [[ -z "$old" ]]; then echo "Couldn't find bundleIdPrefix in project.yml" >&2; exit 1; fi
if [[ "$old" == "$new" ]]; then echo "Already set to $new"; exit 0; fi

files=(project.yml Shared/SharedStore.swift EarnIt/Support/TipJar.swift EarnIt/Support/Tips.storekit README.md)
old_re="${old//./\\.}"
for f in "${files[@]}"; do
  sed -i "s/\\b${old_re}\\b/${new}/g" "$f"
done

echo "Bundle ID prefix: $old → $new"
grep -n "$new" project.yml | head -20
