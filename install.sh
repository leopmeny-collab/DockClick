#!/bin/zsh
# Builds DockClick.app into ~/Applications and starts it at every login.
set -euo pipefail

SRC="${0:A:h}"
APP="$HOME/Applications/DockClick.app"
LABEL="com.leopoldmeny.DockClick"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

mkdir -p "$APP/Contents/MacOS"
# Command Line Tools compiler + SDK (the Xcode toolchain is blocked by its license prompt here)
/Library/Developer/CommandLineTools/usr/bin/swiftc -O -swift-version 5 \
    -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    "$SRC/main.swift" -o "$APP/Contents/MacOS/DockClick"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$LABEL</string>
    <key>CFBundleName</key><string>DockClick</string>
    <key>CFBundleExecutable</key><string>DockClick</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
EOF

# Sign with a real certificate when there is one, so the Accessibility grant survives
# rebuilds (an ad-hoc signature ties it to this exact binary).
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')
codesign --force --sign "${IDENTITY:--}" --identifier "$LABEL" "$APP"

cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/DockClick</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardErrorPath</key><string>$HOME/Library/Logs/DockClick.log</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$AGENT"
echo "Installed. Grant Accessibility to DockClick in System Settings if asked."
