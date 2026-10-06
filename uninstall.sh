#!/bin/zsh
# Removes the app, widget and saved settings.
pkill -f "WalkScape Widget.app" 2>/dev/null
pluginkit -r "$HOME/Applications/WalkScape Widget.app/Contents/PlugIns/WalkScapeSteps.appex" 2>/dev/null
rm -rf "$HOME/Applications/WalkScape Widget.app" "$HOME/.config/walkscape-widget"
killall chronod 2>/dev/null
echo "Removed. Delete the widget from your desktop if it is still showing."
