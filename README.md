# DockClick

Click the Dock icon of the app you're already in, and it hides (like ⌘H). Click it again and it comes back.

- It only hides the app if the app has a window open. If it has none, the click works as usual and the app can open a new window.
- Hold ⌘, ⌥, ⌃ or ⇧ while clicking to get the normal Dock behaviour.
- It runs with no icon or window, starts at login, and restarts itself if it crashes.

## Install

Requires macOS 13 or later and the Xcode Command Line Tools (`xcode-select --install`).

```bash
./install.sh
```

This builds `~/Applications/DockClick.app`, signs it, and installs a LaunchAgent (`com.leopoldmeny.DockClick`) that starts it at login.

Then allow it in **System Settings → Privacy & Security → Accessibility**. If it isn't listed, click **+** and add `~/Applications/DockClick.app`. It starts working within about 2 seconds, with no restart.

The log at `~/Library/Logs/DockClick.log` says `listening for Dock clicks` once the permission is active.

## Uninstall

```bash
./uninstall.sh
```

## How it works

DockClick installs an event tap on left clicks. For each click it checks, cheapest first:

1. No modifier key is held.
2. The click is within 300 pt of a display's bottom, left or right edge, where the Dock can be. Every other click goes straight through without touching the Dock.
3. The Dock item under the cursor, found with one Accessibility hit test, is the frontmost app.
4. That app has an on-screen window.

If all four pass, it hides the app and swallows the click so the Dock doesn't react.

## Signing and the Accessibility permission

`install.sh` signs with an Apple Development or Developer ID certificate if one is in your keychain. macOS then ties the Accessibility permission to that identity, so rebuilds keep it.

Without a certificate it falls back to an ad-hoc signature. That ties the permission to the exact build, so after every rebuild you have to remove DockClick from the Accessibility list with **−** and add it again. Settings still shows the switch on, but the permission no longer applies.
