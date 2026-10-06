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

# UNIVERSAL=1 builds for Apple silicon and Intel (used for releases); default is this Mac only.
ARCHS=("$ARCH"); [ "${UNIVERSAL:-0}" = "1" ] && ARCHS=(arm64 x86_64)
mkdir -p build/tmp
for A in $ARCHS; do
  echo "• compiling widget ($A)"
  swiftc -O -parse-as-library -application-extension -target "$A-apple-macos14.0" \
    Shared/*.swift Widget/*.swift -o "build/tmp/widget-$A" \
    -Xlinker -e -Xlinker _NSExtensionMain
  echo "• compiling setup app ($A)"
  swiftc -O -parse-as-library -target "$A-apple-macos14.0" \
    Shared/*.swift App/*.swift -o "build/tmp/app-$A"
done
lipo -create build/tmp/widget-* -output "$APPX/Contents/MacOS/WalkScapeSteps"
lipo -create build/tmp/app-* -output "$OUT/Contents/MacOS/WalkScapeWidget"
rm -rf build/tmp

sed "s|@PREFIX@|$PREFIX|g" Info-app.plist > "$OUT/Contents/Info.plist"
sed "s|@PREFIX@|$PREFIX|g" Info-widget.plist > "$APPX/Contents/Info.plist"
# Release builds stamp the version (VERSION=1.2.0, BUILD_NUMBER=7). Defaults come from the plists.
for P in "$OUT/Contents/Info.plist" "$APPX/Contents/Info.plist"; do
  [ -n "${VERSION:-}" ] && /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$P"
  [ -n "${BUILD_NUMBER:-}" ] && /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$P"
done
cp Resources/bg-*.jpg "$APPX/Contents/Resources/" 2>/dev/null || echo "  (no background images found, using gradient)"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$OUT/Contents/Resources/"

echo "• signing (ad-hoc, local only)"
codesign --force --sign - --entitlements widget.entitlements "$APPX"
codesign --force --sign - "$OUT"
echo "built: $OUT"
