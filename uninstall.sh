#!/bin/zsh
# Stops DockClick and removes the app and its login agent.
LABEL="com.leopoldmeny.DockClick"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/DockClick.app" "$HOME/Library/Logs/DockClick.log"
tccutil reset Accessibility "$LABEL" 2>/dev/null
echo "Removed."
