<p align="center">
  <img src="https://raw.githubusercontent.com/rkjagani781/NoShitMac/main/docs/assets/logo-1024.png" alt="NoShitMac — The Helix Tab Mark" width="160" height="160">
</p>

<h1 align="center">NoShitMac</h1>

<p align="center"><strong>Two windows. One snap. Zero ceremony.</strong></p>

<p align="center">
  A native macOS menu-bar <strong>super-app</strong> — fast utilities that stay out of your way until you need them.<br>
  Built in Swift. No Dock icon. No Electron. No subscription. Just power, one click away.
</p>

---

## What is NoShitMac?

NoShitMac is a **modular productivity command center** for macOS. Instead of installing five separate utilities, you get one lightweight menu-bar app with a plug-in architecture — each tool is an independent feature you can enable, rebind, and extend.

**Today:** window switching, screenshots, and window cleanup.  
**Tomorrow:** clipboard history, batch rename, and more — shipped as individual features, not bloat.

The logo is the **Helix Tab Mark** — two interlocking window panes twisted mid-switch. The gap between them forms a *void-bolt*: speed implied by geometry, not a stock icon. See [BRAND.md](BRAND.md).

---

## Features

### Window Switcher

Windows-style `⌥ Tab` switching — but it actually works on a Mac.

- Cycle **every open window** across Spaces and fullscreen
- Hold modifier to browse, release to switch
- Thumbnails load on demand — fast, not flashy
- Rebind hotkey in Settings

**Default hotkey:** `⌥ Tab`

---

### Screenshot Studio

Capture, annotate, and ship — without opening Preview.

- Region or full-screen capture (`⌥⇧ 4` by default)
- Auto-copy to clipboard on capture
- Native editor: pencil, highlighter (with color palettes), crop
- Save as PNG, copy, delete, or close
- macOS-standard editor window with toolbar

**Default hotkey:** `⌥⇧ 4`

---

### Window Cleanup

One button to kill background clutter.

- **Clean Up Windows** in the menu bar panel
- Closes windows from background apps (minimized, hidden, or off-screen)
- Your frontmost app is always protected
- Confirmation dialog before anything closes

Requires Accessibility permission.

---

### System & Controls

| Capability | Details |
|---|---|
| **Custom hotkeys** | Rebind any action — conflict warnings for system shortcuts |
| **Launch at login** | Optional — tools ready after reboot |
| **Per-feature toggles** | Enable/disable tools individually in Settings |
| **Permissions panel** | One-click links to System Settings |

---

## Coming Soon

NoShitMac is built to grow. Each item below ships as its own `FeatureModule` — independent, optional, and fast.

| Feature | What it will do |
|---|---|
| **Clipboard Manager** | History tray, paste from recent copies, pin favorites |
| **Batch File Rename** | Regex, sequence, and preview-before-apply |
| **Window Switcher Pro** | Mouse pick, app-only mode, per-app blacklist |
| **Screenshot Pro** | Window capture, arrows, shapes, screenshot history |
| **Auto-update** | Silent updates from GitHub releases |

Want something else? [Open an issue](https://github.com/rkjagani781/NoShitMac/issues) — the architecture is ready for it.

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

Look for the **Helix Tab Mark** (interlocking panes icon) in the top-right menu bar. Check the `>>` overflow if hidden.

### 4. Grant permissions

Click the menu bar icon → **Grant** for each permission, or enable manually in **System Settings → Privacy & Security**:

- Accessibility
- Screen Recording
- Input Monitoring

Details: [PERMISSIONS.md](PERMISSIONS.md)

Quit and relaunch after granting (⌘. in Xcode, then ⌘R again).

---

## Settings

**Menu bar icon → Settings…** (or **⌘,**)

- **General** — Launch at login
- **Hotkeys** — Rebind actions
- **Features** — Enable/disable tools, screenshot mode

Config file: `~/Library/Application Support/NoShitMac/config.json`

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
| [BRAND.md](BRAND.md) | Logo, tagline, colors, voice |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Modular `FeatureModule` design |
| [PERMISSIONS.md](PERMISSIONS.md) | Permission setup guide |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common fixes |

---

## License

MIT · [Rohit Maheshwari](https://github.com/rkjagani781)
