# Wakeful

Keep your Mac awake from the menu bar.

> Status: early development. No release yet.

## Features

- Turn on for a set time (10 minutes to 12 hours), a custom time, or until you turn it off.
- Choose whether the display may sleep while the Mac stays awake.
- Stop when the screen is locked or when you unplug the charger, if you want.
- Start at login, start a session at launch, and get a notice when a session ends.
- Control it from scripts with the `wakeful://` URL scheme.
- No tracking. No network access except update checks.

## Requirements

macOS 14 or later, Apple silicon or Intel.

## Install

Signed builds will be on the [Releases](https://github.com/duongdev/wakeful/releases) page. A Homebrew cask will follow the first release.

## URL scheme

```bash
open -g 'wakeful://activate?hours=1.5'
open -g 'wakeful://activate?minutes=30'
open -g 'wakeful://toggle'
open -g 'wakeful://deactivate'
open 'wakeful://settings'
```

With no duration, `activate` and `toggle` use your default duration.

## Build from source

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
