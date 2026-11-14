# Changelog

All notable changes to this project are listed here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Icon when on: Standard, Green, Blue, Green Dot or Blue Dot, in Settings.
- Display choice in the Turn On and Toggle Shortcuts actions: keep the display awake or let it sleep for that session only.
- Translations: Vietnamese, Spanish, French, German, Italian, Portuguese (Brazil), Russian, Japanese, Korean, and Chinese (Simplified and Traditional).
- Language setting in Settings › General, to use Wakeful in a language other than the system's. It is the same per-app language as System Settings › General › Language & Region › Applications.

### Fixed

- After wake or a user switch, Wakeful checks that macOS still has its keep-awake request and makes it again if not.

## [0.2.0] - 2026-11-15

### Added

- Shortcuts actions: Turn On (with a duration or end time), Turn Off, Toggle, Is Wakeful On, Get Time Left, and Change Time. Siri phrases for turn on, turn off and toggle.
- Global keyboard shortcut to turn on or off, set in Settings.
- Keep awake until a time of day: Until a Time… in the menu, `until=18:00` in the URL scheme, and End Time in Shortcuts.
- `wakeful` command-line tool in `Wakeful.app/Contents/Helpers`: `on`, `off`, `toggle`, `status`.
- `wakeful://activate?indefinitely` to turn on with no end time, whatever the default duration is.
- The time left is read out by VoiceOver when it shows next to the icon.

### Fixed

- Menu bar icon spacing: the icon no longer sits too close to the icon on its right, with or without the time left shown.

## [0.1.0] - 2026-11-15

### Added

- Menu bar app that keeps the Mac awake for a preset or custom time, or until turned off.
- Settings: default duration, display sleep, what to do while the screen is locked (keep awake, let the display sleep, or let the Mac sleep), turn off on unplug, notification at session end, launch at login, turn on at launch, left-click toggle, dim icon.
- `wakeful://` URL scheme: `activate`, `deactivate`, `toggle`, `settings`.
- Log viewer with copy, clear and reveal in Finder.
- Menu: check mark on the running duration, Keep Display Awake toggle, Help menu (About, Release Notes, URL Scheme Help, Report a Bug).
- Optional time left next to the menu bar icon.
- App icon and menu bar icon.
- Automatic updates (can be turned off in Settings) and a Check for Updates menu item.

[Unreleased]: https://github.com/duongdev/wakeful/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/duongdev/wakeful/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/duongdev/wakeful/releases/tag/v0.1.0
