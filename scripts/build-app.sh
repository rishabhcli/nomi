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
RES_BUNDLE="$BIN_DIR/Mnemo_MnemoApp.bundle"
[ -x "$BIN" ] || { echo "missing binary $BIN"; exit 1; }

APP=".build/Mnemo.app"
echo "== assembling $APP =="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/MnemoApp"
# The SwiftPM resource bundle (default.metallib for the voice orb) — Bundle.module
# resolves it from Contents/Resources in a packaged app.
[ -d "$RES_BUNDLE" ] && cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"
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

echo "== ad-hoc signing (nested bundle first, then the app) =="
[ -d "$APP/Contents/Resources/Mnemo_MnemoApp.bundle" ] && \
  codesign --force --sign - "$APP/Contents/Resources/Mnemo_MnemoApp.bundle" 2>/dev/null || true
codesign --force --sign - "$APP"

echo "== done: $APP =="
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Signature' || true
