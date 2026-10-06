#!/bin/bash
# One-line installer for Widget for WalkScape (unofficial fan project).
# Downloads the latest release from GitHub, installs it to ~/Applications and opens the setup app.
# Nothing is built on your Mac and no developer tools are needed.
set -euo pipefail

REPO="jaydenbarnescs-tech/walkscape-desktop-widget"
DEST="${WALKSCAPE_INSTALL_DIR:-$HOME/Applications}"
APP="$DEST/WalkScape Widget.app"

if [ "$(uname)" != "Darwin" ]; then echo "This widget is for macOS only."; exit 1; fi
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$MAJOR" -lt 14 ]; then echo "Needs macOS 14 (Sonoma) or newer. You have $(sw_vers -productVersion)."; exit 1; fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "→ Downloading the latest version…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/WalkScape-Widget.zip" -o "$TMP/widget.zip"
unzip -q "$TMP/widget.zip" -d "$TMP"

echo "→ Installing to $DEST"
mkdir -p "$DEST"
pkill -f "WalkScape Widget.app" 2>/dev/null || true
rm -rf "$APP"
ditto "$TMP/WalkScape Widget.app" "$APP"
xattr -cr "$APP" 2>/dev/null || true

if [ -z "${WALKSCAPE_INSTALL_DIR:-}" ]; then
  LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  "$LSREG" -f "$APP"
  pluginkit -a "$APP/Contents/PlugIns/WalkScapeSteps.appex"
  pluginkit -e use -i io.github.walkscape-widget.steps
  killall chronod 2>/dev/null || true
  echo
  echo "✓ Installed. The setup window is opening:"
  echo "   1. Type your character name and click it."
  echo "   2. Right-click your desktop → Edit Widgets → search “WalkScape” → drag it onto the desktop."
  open "$APP"
else
  echo "✓ Copied to $DEST (test mode, not registered)."
fi
