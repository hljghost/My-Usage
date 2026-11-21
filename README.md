# My-Usage

macOS menu bar app for live [Oh My Pi](https://github.com/can1357/oh-my-pi) (`omp`) provider usage.

Port of [Ohm-My-Usage-archy-Pi](https://github.com/AventurineDream/Ohm-My-Usage-archy-Pi) (Omarchy bar widget) to a native SwiftUI menu bar app.

## Features

- Reads `omp usage --json` — no separate auth; OMP already handles providers
- Menu bar shows the chosen provider’s current limit at a glance
- Panel lists every provider’s usage windows and reset countdowns
- Select a provider or use Auto (highest usage)
- Choose `5h` / `7d` / Auto window; show used or remaining
- Collapse sections, drag to reorder; layout persists in `~/.config/my-usage/state.json`
- Failed refresh keeps last good values and marks them stale
- Tone: normal → dim red at ≥90% → full red when exhausted

## Requirements

- macOS 13+
- `omp` from [Oh My Pi](https://omp.sh) on your PATH, with at least one authenticated provider

```sh
# Homebrew
brew install can1357/tap/omp

# or
curl -fsSL https://omp.sh/install | sh
```

## Build & run

```sh
# Generate Xcode project (requires xcodegen: brew install xcodegen)
xcodegen generate

# Build
xcodebuild -scheme My-Usage -configuration Release -derivedDataPath build

# Open the app
open build/Build/Products/Release/My-Usage.app
```

Or open `My-Usage.xcodeproj` in Xcode and run (⌘R). The app is a menu-bar-only agent (`LSUIElement`), so it won’t appear in the Dock.

### Launch at login

System Settings → General → Login Items → add `My-Usage.app`.

## Settings

| Option | Purpose |
|---|---|
| Bar provider | Provider id shown in the menu bar, or Auto |
| Bar window | `auto` / `5h` / `7d` |
| Show as | `used` or `left` |
| Show provider name | Prefix short code (e.g. `cld`) |
| Show value in bar | Include the percentage |
| Show bars in panel | Progress bars under each limit |
| Refresh interval | Poll cadence while the panel is open (halved when closed) |

## Development

```sh
xcodegen generate
xcodebuild test -scheme My-Usage -destination 'platform=macOS' -derivedDataPath build
```

Core parsing / selection logic lives in `Sources/MyUsage/Models/UsageModel.swift` (ported from the original `OmpUsageModel.js`).

## License

MIT. Based on [Ohm-My-Usage-archy-Pi](https://github.com/AventurineDream/Ohm-My-Usage-archy-Pi) by AventurineDream.
