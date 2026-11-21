#!/usr/bin/env bash
# Create an "Apple Development" signing certificate entirely on Linux.
#
#   Step 1:  scripts/make-dev-cert.sh csr
#            → upload signing/EarnIt.certSigningRequest at developer.apple.com
#   Step 2:  scripts/make-dev-cert.sh p12 ~/Downloads/development.cer
#            → creates signing/dev-cert.p12 (+ random password) for GitHub secrets
#
# Everything lands in ./signing/, which is git-ignored. Keep it private.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p signing
chmod 700 signing

case "${1:-}" in
  csr)
    if [[ -f signing/dev-key.pem ]]; then
      echo "signing/dev-key.pem already exists; reusing it."
    else
      openssl genrsa -out signing/dev-key.pem 2048
      chmod 600 signing/dev-key.pem
    fi
    openssl req -new -key signing/dev-key.pem \
      -subj "/CN=EarnIt CI Development/C=US" \
      -out signing/EarnIt.certSigningRequest
    echo
    echo "✅ Created signing/EarnIt.certSigningRequest"
    echo "Next: https://developer.apple.com/account/resources/certificates/add"
    echo "  → choose 'Apple Development' → upload that file → download the .cer"
    echo "  → run: $0 p12 /path/to/development.cer"
    ;;
  p12)
    cer="${2:-}"
    [[ -f "$cer" ]] || { echo "Usage: $0 p12 /path/to/development.cer" >&2; exit 1; }
    [[ -f signing/dev-key.pem ]] || { echo "signing/dev-key.pem missing. Run '$0 csr' first." >&2; exit 1; }
    openssl x509 -inform DER -in "$cer" -out signing/dev-cert.pem
    # Random password; macOS's `security import` needs the legacy (3DES/SHA1) PKCS#12 encoding.
    openssl rand -base64 24 | tr -d '\n' > signing/dev-cert.password
    chmod 600 signing/dev-cert.password
    openssl pkcs12 -export \
      -inkey signing/dev-key.pem -in signing/dev-cert.pem \
      -name "EarnIt Development" \
      -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
      -passout file:signing/dev-cert.password \
      -out signing/dev-cert.p12
    chmod 600 signing/dev-cert.p12
    echo "✅ Created signing/dev-cert.p12 (password in signing/dev-cert.password)"
    openssl x509 -in signing/dev-cert.pem -noout -subject -enddate
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac
