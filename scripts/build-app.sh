#!/bin/bash
# Package MnemoApp as a real Mnemo.app bundle so macOS TCC attributes
# microphone / speech-recognition permission to "Mnemo" (ai.mnemo.app) — a bare
# SwiftPM executable is attributed to the launching terminal instead, so the
# grant never sticks. Output: .build/Mnemo.app (under the gitignored .build).
#
# The Metal orb needs the real Metal compiler, which only ships in full Xcode,
# so build with Xcode's toolchain even when Command Line Tools is selected.
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
CONFIG="${1:-debug}"   # debug | release

echo "== building MnemoApp ($CONFIG) with $DEVELOPER_DIR =="
swift build --product MnemoApp -c "$CONFIG"
BIN_DIR=".build/$CONFIG"
BIN="$BIN_DIR/MnemoApp"
RESOURCE_BUNDLES=(
  "$BIN_DIR/Mnemo_MnemoApp.bundle"
  "$BIN_DIR/Mnemo_MnemoDevServer.bundle"
)
[ -x "$BIN" ] || { echo "missing binary $BIN"; exit 1; }

APP=".build/Mnemo.app"
echo "== assembling $APP =="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/MnemoApp"
# Bundle.module resolves every SwiftPM target's resources from Contents/Resources
# in a packaged app. MnemoApp owns the Metal library; MnemoDevServer owns the
# self-contained observatory dashboard. Omitting either makes Bundle.module trap.
for bundle in "${RESOURCE_BUNDLES[@]}"; do
  [ -d "$bundle" ] || { echo "missing resource bundle $bundle"; exit 1; }
  cp -R "$bundle" "$APP/Contents/Resources/"
done
# Ship the config so the app finds it when launched via `open` (cwd = /).
cp mnemo.toml "$APP/Contents/Resources/mnemo.toml"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>ai.mnemo.app</string>
	<key>CFBundleName</key><string>Mnemo</string>
	<key>CFBundleDisplayName</key><string>Mnemo</string>
	<key>CFBundleExecutable</key><string>MnemoApp</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>LSUIElement</key><true/>
	<key>NSSupportsSuddenTermination</key><false/>
	<key>NSMicrophoneUsageDescription</key>
	<string>Mnemo listens only while you hold the notch to dictate. Audio is processed entirely on this Mac and never leaves it.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Dictation is transcribed on-device only. Nothing is sent to Apple or any server — Mnemo works with the network off.</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY="${MNEMO_CODESIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk '/Apple Development/ { print $2; exit }')"
fi
if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="-"
  echo "== no stable signing identity found; falling back to ad-hoc signing =="
else
  echo "== signing with stable identity $SIGN_IDENTITY =="
fi

# A stable certificate gives TCC a stable designated requirement. Ad-hoc signing
# keys grants to the binary CDHash, which changes on every rebuild and makes
# macOS ask for Microphone and Speech Recognition again.
for bundle in "$APP"/Contents/Resources/Mnemo_*.bundle; do
  codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$bundle"
done
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP"

echo "== done: $APP =="
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Signature' || true
