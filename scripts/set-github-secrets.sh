#!/usr/bin/env bash
# Upload signing credentials to the GitHub repo as Actions secrets (encrypted, never shown in logs).
#
# Usage:
#   scripts/set-github-secrets.sh <TEAM_ID> <API_KEY_ID> <ISSUER_ID> /path/to/AuthKey_XXXX.p8
#
# Needs: gh CLI logged in, a GitHub repo as `origin`, and signing/dev-cert.p12 from make-dev-cert.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -ne 4 ]]; then
  sed -n '4,7p' "$0"
  exit 1
fi
team="$1" key_id="$2" issuer="$3" p8="$4"

[[ -f "$p8" ]] || { echo "API key file not found: $p8" >&2; exit 1; }
[[ -f signing/dev-cert.p12 && -f signing/dev-cert.password ]] || {
  echo "signing/dev-cert.p12 missing. Run scripts/make-dev-cert.sh first." >&2; exit 1; }

gh secret set ASC_KEY_ID --body "$key_id"
gh secret set ASC_ISSUER_ID --body "$issuer"
gh secret set ASC_KEY_P8 < "$p8"
base64 -w0 signing/dev-cert.p12 | gh secret set DEV_CERT_P12_BASE64
gh secret set DEV_CERT_PASSWORD < signing/dev-cert.password
# Team ID isn't secret; it's a variable, and setting it switches on the signed build job.
gh variable set TEAM_ID --body "$team"

echo "✅ Secrets set. Start a build with:  gh workflow run ios.yml"
