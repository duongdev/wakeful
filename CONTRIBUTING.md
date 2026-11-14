# Contributing

Thanks for helping. Bug reports, ideas and pull requests are welcome.

## Before you start

- For a bug, open an issue with the bug template. Attach the app logs (Settings > Advanced > Copy logs).
- For a new feature, open an issue first, so we can agree on the idea before you write code.

## Build

Requirements: Xcode 26 or later (for the `.icon` app icon), macOS 14 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open Wakeful.xcodeproj
```

The Xcode project is generated from `project.yml` and is not committed. Run `xcodegen generate` again after you pull changes to `project.yml`.

Debug builds are "Wakeful Dev" (`dev.duongdev.Wakeful.debug`, URL scheme `wakeful-dev://`) with updates off, so they can run next to an installed copy. Both copies write to the same log folder.

Run the core tests without Xcode:

```bash
swift test --package-path WakefulCore
```

## Pull requests

- Keep each pull request to one change.
- Add or update tests for logic in `WakefulCore`.
- Put all user-facing text in the String Catalog.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit titles, for example `feat(menu): add custom duration` or `fix(power): stop session on unplug`.
- Add a line to the `Unreleased` section of [CHANGELOG.md](CHANGELOG.md) for user-visible changes.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
