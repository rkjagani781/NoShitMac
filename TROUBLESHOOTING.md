# Troubleshooting

## Hotkeys don't work

1. Grant **Input Monitoring** in System Settings
2. Grant **Accessibility**
3. Quit and relaunch NoShitMac
4. Check Settings → Hotkeys for conflicts with macOS shortcuts

## Window switcher shows no windows

1. Grant **Screen Recording** (needed for window list/thumbnails)
2. Grant **Accessibility** (needed to activate windows)
3. Some system windows are intentionally filtered (Dock, Control Center)

## Fullscreen app won't switch

Ensure Accessibility is granted. NoShitMac lists windows across all Spaces and uses the Accessibility API to unminimize, raise, and focus windows. If a fullscreen app on another Space still won't switch, quit and relaunch NoShitMac after granting permissions.

## Screenshot is black or empty

Grant **Screen Recording** and restart the app. ScreenCaptureKit requires this permission on macOS 13+.

## "Open" blocked by Gatekeeper (unsigned build)

Right-click **NoShitMac.app** → **Open** → confirm. Or: System Settings → Privacy & Security → **Open Anyway**.

## High CPU usage

Overlays should only appear during switcher/screenshot use. If CPU stays high, quit and relaunch. File an issue with steps to reproduce.

## Reset configuration

Delete `~/Library/Application Support/NoShitMac/config.json` and relaunch.
