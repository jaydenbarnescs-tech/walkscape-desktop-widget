#!/bin/zsh
# One-step install: build from source, put the app in ~/Applications, register the widget, open setup.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
DEST="$HOME/Applications"
APP="$DEST/WalkScape Widget.app"
mkdir -p "$DEST"
pkill -f "WalkScape Widget.app" 2>/dev/null || true
rm -rf "$APP"
cp -R "build/WalkScape Widget.app" "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
pluginkit -a "$APP/Contents/PlugIns/WalkScapeSteps.appex"
pluginkit -e use -i "${BUNDLE_PREFIX:-io.github.walkscape-widget}.steps"
killall chronod 2>/dev/null || true
echo
echo "Installed. Opening setup — pick your character, then:"
echo "  right-click the desktop → Edit Widgets → search “WalkScape” → drag it onto the desktop."
open "$APP"
