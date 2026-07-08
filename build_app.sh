#!/bin/bash
# Builds a release binary and packages it into a double-clickable DirLens.app
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DirLens"
EXECUTABLE_NAME="DirLens"
APP_DIR="dist/${APP_NAME}.app"

echo "Building release binary..."
swift build -c release

echo "Packaging ${APP_NAME}.app..."
rm -rf dist
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/${EXECUTABLE_NAME}" "$APP_DIR/Contents/MacOS/${EXECUTABLE_NAME}"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc sign so Gatekeeper doesn't complain on first launch.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

VERSION=$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
ZIP_PATH="dist/${APP_NAME}-v${VERSION}.zip"

echo "Zipping for distribution..."
# --norsrc drops resource forks/xattrs/ACLs/quarantine bits so the zip
# doesn't get a __MACOSX/ sidecar folder full of Mac-only metadata.
ditto -c -k --norsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Done. App bundle created at $APP_DIR"
echo "Run:      open \"$APP_DIR\""
echo "Install:  cp -R \"$APP_DIR\" /Applications/"
echo "Release:  $ZIP_PATH"
