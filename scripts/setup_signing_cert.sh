#!/bin/bash
# One-time setup: creates a free, local, self-signed code-signing certificate
# and trusts it for code signing on this Mac.
#
# Why: build_app.sh ad-hoc signs (`codesign --sign -`) by default, which is
# fine for Gatekeeper but gives every build a different signing identity tied
# to that exact binary's content hash. macOS's permission system (TCC) keys
# folder-access grants ("DirLens would like to access files in your Desktop
# folder") off that identity, so ad-hoc builds lose remembered permissions on
# every rebuild/update. Signing with a real (even self-signed) certificate
# instead gives DirLens a requirement based on the certificate + bundle ID,
# not the binary's content — stable across rebuilds, so macOS keeps
# remembering permission grants the way it should, without needing a paid
# Apple Developer Program membership.
#
# This does NOT change the Gatekeeper "unidentified developer" warning on
# first launch — that's a separate mechanism that only goes away with a paid
# Developer ID + notarization. It only fixes permission persistence.
set -euo pipefail

IDENTITY_NAME="DirLens Local Developer"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY_NAME"; then
  echo "'$IDENTITY_NAME' already exists and is trusted for code signing. Nothing to do."
  exit 0
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Generating a 10-year self-signed code-signing certificate..."
openssl req -x509 -newkey rsa:2048 \
  -keyout "$WORK_DIR/key.pem" \
  -out "$WORK_DIR/cert.pem" \
  -days 3650 -nodes \
  -subj "/CN=$IDENTITY_NAME" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "basicConstraints=critical,CA:false" >/dev/null 2>&1

TEMP_PASS=$(openssl rand -base64 24)

# -legacy: OpenSSL 3.x's default PKCS#12 encryption isn't compatible with
# macOS's `security` import (it expects the older RC2/3DES-based encoding).
openssl pkcs12 -export -legacy \
  -out "$WORK_DIR/cert.p12" \
  -inkey "$WORK_DIR/key.pem" \
  -in "$WORK_DIR/cert.pem" \
  -passout "pass:$TEMP_PASS" >/dev/null 2>&1

echo "Importing into your login keychain..."
security import "$WORK_DIR/cert.p12" \
  -k "$KEYCHAIN" \
  -P "$TEMP_PASS" \
  -T /usr/bin/codesign -T /usr/bin/security

echo "Trusting it for code signing (login keychain only, no admin password needed)..."
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK_DIR/cert.pem"

echo
echo "Done. '$IDENTITY_NAME' is ready — build_app.sh will now sign with it automatically."
echo "To remove it later: open Keychain Access, search \"$IDENTITY_NAME\", and delete the certificate."
