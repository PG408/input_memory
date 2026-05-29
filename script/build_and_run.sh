#!/usr/bin/env bash
set -euo pipefail

APP_NAME="InputMemory"
BUNDLE_ID="local.inputmemory"
BUILD_DIR=".build/debug"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

pkill -x "${APP_NAME}" 2>/dev/null || true
while pgrep -x "${APP_NAME}" >/dev/null 2>&1; do
  sleep 0.1
done
swift build --product "${APP_NAME}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${EXECUTABLE}"
chmod +x "${EXECUTABLE}"

if [[ -f "Resources/InputMemory.icns" ]]; then
  cp "Resources/InputMemory.icns" "${APP_BUNDLE}/Contents/Resources/InputMemory.icns"
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>InputMemory</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP_BUNDLE}"
/usr/bin/open -n "${APP_BUNDLE}"
