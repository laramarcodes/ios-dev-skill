---
name: Post-WWDC refresh
about: Track re-dating the skill after a new WWDC / major OS release
title: "[refresh] WWDC <year> / iOS <version>"
labels: ["refresh"]
---

Tracking the refresh for **iOS &lt;version&gt;** (WWDC &lt;year&gt;).

- [ ] Re-date `references/versions-and-sources.md` — bump shipping version, move shipped APIs out of "pre-GA," record the new pre-GA wave (with sources)
- [ ] Spot-check high-traffic references: `liquid-glass.md`, `app-structure.md`, `apple-intelligence.md`, `data-persistence.md`, `concurrency-and-networking.md`
- [ ] Re-run `AppScaffold` on the new Xcode / Simulator; fix breakage
- [ ] Refresh `docs/screenshots/` if the UI shifted
- [ ] Update the currency date in `SKILL.md` and `README.md`
- [ ] Add a `CHANGELOG.md` entry

### Notable changes this cycle

<!-- Key new/renamed/deprecated APIs and their Apple sources. -->
