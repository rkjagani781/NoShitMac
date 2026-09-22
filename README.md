# NoShitMac

**Lightweight Mac menu-bar toolkit** — Windows-style window switching and screenshots with inline editing.

Built native in Swift. No Dock icon. Runs from the menu bar only.

---

## Features

| Feature | What it does |
|---|---|
| **Window Switcher** | Hold `⌥ Tab` to cycle all open windows (including fullscreen & other Spaces), release to switch |
| **Screenshot** | Capture a region or full screen, auto-copy to clipboard, annotate with pencil / highlight / crop |
| **Custom Hotkeys** | Rebind any action in Settings |
| **Launch at Login** | Optional — keep tools available after reboot |

---

## Requirements

- **macOS 14** (Sonoma) or later
- **Xcode 15+** to build from source
- **Permissions:** Accessibility · Screen Recording · Input Monitoring

---

## Quick Start

### 1. Clone & open

```bash
git clone https://github.com/rkjagani781/NoShitMac.git
cd NoShitMac
brew install xcodegen   # first time only
xcodegen generate
open NoShitMac.xcodeproj
```

### 2. Run

Press **⌘R** in Xcode.

### 3. Find the app

NoShitMac is a **menu bar app** — there is no Dock icon.

Look for the **⚡ bolt icon** in the top-right menu bar (check the `>>` overflow if hidden).

### 4. Grant permissions

Click **⚡** → click **Grant** for each permission, or enable manually in **System Settings → Privacy & Security**:

- Accessibility
- Screen Recording
- Input Monitoring

Details: [PERMISSIONS.md](PERMISSIONS.md)

Quit and relaunch after granting (⌘. in Xcode, then ⌘R again).

---

## Default Hotkeys

| Action | Hotkey | Change in |
|---|---|---|
| Window Switcher | `⌥ Tab` | Settings → Hotkeys |
| Screenshot | `⌥⇧ 4` | Settings → Hotkeys |

Hold modifier keys while cycling in the switcher; release to confirm.

Screenshot mode (region vs full screen): **Settings → Features → Screenshot**.

Config file: `~/Library/Application Support/NoShitMac/config.json`

---

## Settings

**⚡ menu bar icon → Settings…** (or **⌘,**)

- **General** — Launch at login
- **Hotkeys** — Rebind actions (conflict warnings for system shortcuts)
- **Features** — Enable/disable tools, screenshot mode

---

## Download

Pre-built releases: [github.com/rkjagani781/NoShitMac/releases](https://github.com/rkjagani781/NoShitMac/releases)

First launch on unsigned builds: right-click the app → **Open**.

---

## Build Release (.dmg)

Requires full Xcode:

```bash
./scripts/build-release.sh
./scripts/create-dmg.sh 0.1.0
```

---

## Docs

| Doc | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Modular `FeatureModule` design |
| [PERMISSIONS.md](PERMISSIONS.md) | Permission setup guide |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common fixes |

---

## Roadmap (Phase 2)

- Window switcher: mouse pick, app-only mode, app blacklist
- Screenshot: window capture, arrows, history tray
- Clipboard manager · batch file rename · auto-update

---

## License

MIT · [Rohit Maheshwari](https://github.com/rkjagani781)
