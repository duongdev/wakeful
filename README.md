<p align="center">
  <img src=".github/assets/icon.png" width="128" height="128" alt="Wakeful icon">
</p>

<h1 align="center">Wakeful</h1>

<p align="center">Keep your Mac awake from the menu bar.</p>

<p align="center">
  <a href="https://github.com/duongdev/wakeful/releases/latest"><img src="https://img.shields.io/github/v/release/duongdev/wakeful?label=release" alt="Latest release"></a>
  <a href="https://github.com/duongdev/wakeful/actions/workflows/ci.yml"><img src="https://github.com/duongdev/wakeful/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14 or later">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/duongdev/wakeful" alt="MIT License"></a>
</p>

<p align="center">
  <img src=".github/assets/menu.png" width="254" alt="Wakeful menu">
  &nbsp;&nbsp;
  <img src=".github/assets/settings.png" width="368" alt="Wakeful settings">
</p>

## Features

- Turn on for a set time (10 minutes to 12 hours), a custom time, or until you turn it off.
- Choose whether the display may sleep while the Mac stays awake.
- When the screen is locked, let the display sleep or let the Mac sleep, if you want.
- Stop when you unplug the charger, if you want.
- Start at login, start a session at launch, and get a notice when a session ends.
- Control it from scripts with the `wakeful://` URL scheme.
- Show the time left next to the menu bar icon, if you want.
- Automatic updates, which you can turn off.
- No tracking. No network access except update checks.

## Requirements

macOS 14 or later, Apple silicon or Intel.

## Install

Download `Wakeful-<version>.dmg` from the [latest release](https://github.com/duongdev/wakeful/releases/latest), open it, and drag Wakeful to Applications. Builds are signed and notarized by Apple.

A Homebrew cask is coming.

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
