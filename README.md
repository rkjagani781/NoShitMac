# NoShitMac

Lightweight Mac menu-bar toolkit — Windows-style window switcher and screenshot editor with custom hotkeys.

## Features (Phase 1)

- **Window Switcher** — Hold `⌥ Tab` to cycle open windows (including fullscreen apps), release to switch
- **Screenshot** — Region or full-screen capture, auto-copy to clipboard, inline editor (pencil, highlight, crop)
- **Custom hotkeys** — Rebind any feature from Settings
- **Menu bar app** — No Dock clutter; optional launch at login

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ to build from source
- Permissions: Accessibility, Screen Recording, Input Monitoring

## Quick Start

```bash
git clone https://github.com/rkjagani781/NoShitMac.git
cd NoShitMac
brew install xcodegen   # if needed
xcodegen generate
open NoShitMac.xcodeproj
```

Press **⌘R** in Xcode to run. Grant permissions when prompted (see [PERMISSIONS.md](PERMISSIONS.md)).

## Default Hotkeys

| Action | Default | Configurable |
|---|---|---|
| Window Switcher | `⌥ Tab` | Settings → Hotkeys |
| Screenshot | `⌥⇧ 4` | Settings → Hotkeys |

## Configuration

Settings open from the menu bar icon → **Settings…** or `⌘,`.

Hotkeys persist to:

```
~/Library/Application Support/NoShitMac/config.json
```

## Download

Releases: [github.com/rkjagani781/NoShitMac/releases](https://github.com/rkjagani781/NoShitMac/releases)

Unsigned builds: right-click the app → **Open** the first time (Gatekeeper).

## Architecture

Modular feature system — see [ARCHITECTURE.md](ARCHITECTURE.md).

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Roadmap (Phase 2)

- Window switcher: mouse selection, app-only mode, blacklist
- Screenshot: window capture, arrows, history tray
- Clipboard manager, batch file rename
- Sparkle auto-update

## License

MIT
