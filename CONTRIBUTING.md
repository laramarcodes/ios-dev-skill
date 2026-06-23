# Contributing to ios-dev

Thanks for helping keep this skill accurate. Because it encodes **time-sensitive facts** about Apple's platforms, the bar for changes is simple: *every factual claim must trace to an Apple primary source.*

## The most valuable contributions

1. **Post-WWDC refreshes.** iOS changes every September. After each WWDC / major OS release, the skill needs re-dating: bump the shipping version, move newly-shipped APIs from "pre-GA" to "shipping," and record the new pre-GA wave. See the [post-WWDC refresh checklist](#post-wwdc-refresh-checklist) below — there's also an issue template for tracking it.
2. **Factual corrections.** A version number, API name, deprecation, or behavior that's wrong or stale. Cite the Apple source URL in your PR.
3. **New pitfalls.** A build error or runtime gotcha you hit and fixed, written up so the next person doesn't. Add it to the relevant `references/*.md` file.
4. **Template fixes.** The starter in `assets/templates/AppScaffold/` must compile, test green, and run on the current Simulator. PRs that fix breakage there are always welcome.

## Ground rules

- **Cite primary sources.** Any change to a factual claim must link the Apple page it came from — `developer.apple.com`, the HIG, a WWDC session, or Apple Newsroom. Third-party blogs don't count as the source of record.
- **Version-qualify everything.** State which iOS / Xcode / Swift version a claim applies to, and label pre-GA (unreleased beta) material clearly. Never present an iOS 27 beta API as shipping.
- **Keep the template buildable.** If you touch `AppScaffold`, regenerate the project, build it, and run the test suite on an iOS 26 Simulator before opening the PR. Note what you ran in the PR description.
- **Match the existing voice.** References are concise, idiom-first, and opinionated about the *current* right way to do something. Avoid dumping API reference prose — link to Apple's docs for exhaustive detail.

## Post-WWDC refresh checklist

1. **Re-date `references/versions-and-sources.md`** — bump the shipping version, move newly-shipped APIs out of "pre-GA," and record the new pre-GA wave with sources.
2. **Spot-check the high-traffic references** — `liquid-glass.md`, `app-structure.md`, `apple-intelligence.md`, `data-persistence.md`, `concurrency-and-networking.md` — against the new SDK and WWDC sessions.
3. **Re-run the starter** through the new Xcode / Simulator. Fix any breakage in `assets/templates/AppScaffold/` and refresh `docs/screenshots/` if the UI shifted.
4. **Update the currency date** in `SKILL.md` and `README.md`, and add a `CHANGELOG.md` entry.

## Submitting a change

1. Fork and branch from `main` (`git checkout -b refresh/wwdc-2027`).
2. Make the change; cite sources in the diff or PR body.
3. If you touched the template, run the build + tests and say so.
4. Open a PR using the template. Keep it focused — one topic per PR.

## Reporting issues

Use the issue templates. For factual errors, include the **wrong claim**, the **correct claim**, and the **Apple source URL**. Issues are enabled and watched.
