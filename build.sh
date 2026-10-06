#!/bin/zsh
# Builds "WalkScape Widget.app" (setup app + embedded desktop widget) with just the
# Xcode Command Line Tools — no Xcode project or Apple developer account needed.
set -euo pipefail
cd "$(dirname "$0")"
command -v swiftc >/dev/null || { echo "swiftc not found. Run: xcode-select --install"; exit 1; }

ARCH=$(uname -m)
# Bundle id prefix. Change it (BUNDLE_PREFIX=com.you.walkscape) if you want a unique id.
PREFIX="${BUNDLE_PREFIX:-io.github.walkscape-widget}"
OUT="build/WalkScape Widget.app"
APPX="$OUT/Contents/PlugIns/WalkScapeSteps.appex"
rm -rf build
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources" "$APPX/Contents/MacOS" "$APPX/Contents/Resources"

echo "• compiling widget"
swiftc -O -parse-as-library -application-extension -target "$ARCH-apple-macos14.0" \
  Shared/*.swift Widget/*.swift -o "$APPX/Contents/MacOS/WalkScapeSteps" \
  -Xlinker -e -Xlinker _NSExtensionMain

echo "• compiling setup app"
swiftc -O -parse-as-library -target "$ARCH-apple-macos14.0" \
  Shared/*.swift App/*.swift -o "$OUT/Contents/MacOS/WalkScapeWidget"

sed "s|@PREFIX@|$PREFIX|g" Info-app.plist > "$OUT/Contents/Info.plist"
sed "s|@PREFIX@|$PREFIX|g" Info-widget.plist > "$APPX/Contents/Info.plist"
cp Resources/bg-*.jpg "$APPX/Contents/Resources/" 2>/dev/null || echo "  (no background images found, using gradient)"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$OUT/Contents/Resources/"

echo "• signing (ad-hoc, local only)"
codesign --force --sign - --entitlements widget.entitlements "$APPX"
codesign --force --sign - "$OUT"
echo "built: $OUT"
