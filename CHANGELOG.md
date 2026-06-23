# Changelog

All notable changes to this skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project tracks Apple's platform releases rather than a conventional
semantic version — entries are dated and labeled by the iOS cycle they target.

## [Unreleased]

### Added
- `LICENSE` (MIT) and a `NOTICE` file with the Apple trademark notice.
- `CONTRIBUTING.md` with the post-WWDC refresh checklist and sourcing rules.
- `CHANGELOG.md` (this file).
- GitHub issue templates (bug report, post-WWDC refresh) and a pull request template.
- Table of contents and an MIT license badge in the README.

### Changed
- README install command now references the real repository path.

## [2026-06-22] — Initial release · iOS 26 cycle

### Added
- `SKILL.md` playbook for building native iPhone & iPad apps on the iOS 26 stack
  (Swift 6.2, SwiftUI, SwiftData, Liquid Glass, Observation, Foundation Models).
- 18 on-demand reference files under `references/` covering UI, navigation, state,
  persistence, concurrency, iPad windowing, system integration, on-device AI,
  StoreKit 2, system frameworks, design & accessibility, interaction, testing,
  performance & shipping, tooling, and a versions/sources index.
- Buildable `AppScaffold` starter (XcodeGen) — an adaptive iPhone + iPad app with
  SwiftData, Liquid Glass controls, and a Swift Testing suite, verified green on
  the iOS 26 Simulator.
- `scripts/new_ios_app.py` scaffold script to stamp out a renamed copy of the starter.
- Research provenance under `.research/` (digests, findings, adversarial verifications).

[Unreleased]: https://github.com/laramarcodes/ios-dev-skill/compare/main...HEAD
