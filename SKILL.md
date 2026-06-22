---
name: ios-dev
description: >-
  This skill should be used to build native Apple iOS & iPadOS apps (iPhone /
  iPad) in Swift with SwiftUI, SwiftData, and the iOS 26 stack — whenever the
  user wants to create, scaffold, design, debug, or extend an iPhone or iPad
  app: SwiftUI views and navigation (NavigationStack/NavigationSplitView, the
  value-based Tab API), the Liquid Glass design system, state with the
  @Observable/Observation framework, SwiftData/CloudKit persistence, Swift 6
  concurrency & networking, iPad windowing/multitasking, widgets, App Intents,
  Live Activities & Control Center controls, on-device Apple Intelligence (the
  Foundation Models framework), StoreKit 2 in-app purchases, system frameworks
  (MapKit, HealthKit, Swift Charts, PhotosUI…), accessibility, Swift Testing,
  performance, and App Store submission — even when the request never says "iOS"
  or "SwiftUI" (e.g. "make me an iPhone app", "an app for iPad", "a to-do app
  for my phone"). Also covers Xcode project setup, simulators,
  permissions/privacy manifests, and shipping. NOT for visionOS / Apple Vision
  Pro (use the visionos-dev skill), React / Capacitor / Flutter / web apps
  wrapped for iPad (use ipad-layouts for those), Unity/Unreal games, or pure
  legacy UIKit/Storyboard maintenance.
version: 1.0.0
disable-model-invocation: true
---

# Building native iOS & iPadOS apps

Build **native** iPhone and iPad apps — Swift + SwiftUI + SwiftData, authored in
Xcode and targeting the current **iOS/iPadOS 26** stack. Native is the right
default: it gets the full system look-and-feel (Liquid Glass for free), the
deepest OS integration (widgets, App Intents, on-device AI), the best
performance, and the smoothest App Store path. React Native, Flutter, and
Capacitor are alternatives for teams sharing a web/cross-platform codebase; treat
them as out of scope here — see `ipad-layouts` for React-on-iPad web work.

This skill ships a **buildable, polished starter project** (an adaptive
iPhone+iPad app) and **focused reference files**. Read the references on demand —
do not dump them all into context. The map is the decision tree below.

## Start here: the mental model

A SwiftUI app is four nested ideas. Get these and the rest is detail:

| Layer | What it is | The modern idiom (iOS 26) |
|---|---|---|
| **App → Scene** | The `@main struct …: App` returns `Scene`s — almost always a `WindowGroup`. | One `WindowGroup`; multiple windows/scenes on iPad & Mac. |
| **View** | Value-type structs that describe UI; the framework diffs and re-renders. | Composed small views; navigation via `NavigationStack`/`NavigationSplitView`; tabs via the value-based `Tab` API. |
| **State** | Reference-type models the views observe. | The **`@Observable` macro** (Observation framework) — *not* `ObservableObject`/`@Published`. Read with `@State` (own), `@Environment` (inject), `@Bindable` (bind). |
| **Persistence** | Where data lives across launches. | **SwiftData** (`@Model`, `@Query`, `ModelContainer`), optionally synced with CloudKit. |

Two cross-cutting facts shape *all* current code:

- **Liquid Glass is free, and automatic.** Building against the iOS 26 SDK
  restyles standard controls, tab bars, toolbars, nav bars, and sheets to the
  translucent Liquid Glass material with **no code changes**. Write
  `.glassEffect(...)` only to adopt it on *custom* views. Glass belongs to the
  navigation/chrome layer — never stack glass on glass, never put it on content.
- **Swift 6.2 makes app code single-threaded by default.** A new Xcode 26 app
  target turns on **"Approachable Concurrency"** and **default `@MainActor`
  isolation**, so UI, view models, and SwiftData access all run on the main actor
  with zero `Sendable` ceremony. Opt *into* concurrency explicitly: `@concurrent`
  to offload heavy work, an `actor` to protect shared mutable state, `@ModelActor`
  for background SwiftData.

Everything else is detail in the references.

## Decision tree → which reference to read

- **Setting up the project / Xcode / SDK & deployment target / permissions / Swift 6 build settings?**
  → `references/project-setup.md`, then scaffold with the template (below).
- **App entry, scenes, windows, `NavigationStack`/`NavigationSplitView`, tabs, deep links, state restoration?**
  → `references/app-structure.md`
- **Views, the layout system, lists & scrolling, animation, SF Symbols, custom containers?**
  → `references/swiftui-views.md`
- **Adopting the Liquid Glass design system on custom UI (glass effects, containers, morphing, toolbars)?**
  → `references/liquid-glass.md`
- **State, the `@Observable`/Observation framework, `@Environment`/`@Entry`, data-flow architecture?**
  → `references/state-observation.md`
- **Saving data — SwiftData, schema migration, CloudKit sync, Core Data, files?**
  → `references/data-persistence.md`
- **Swift 6 concurrency (actors, `@MainActor`, `@concurrent`), async/await, URLSession networking?**
  → `references/concurrency-and-networking.md`
- **iPad specifics — the iPadOS 26 windowing system, multitasking, pointer/keyboard/Pencil, drag-and-drop, Catalyst, adaptivity?**
  → `references/ipad.md`
- **Widgets, App Intents, App Shortcuts, Live Activities / Dynamic Island, Control Center controls, Spotlight?**
  → `references/system-integration.md`
- **On-device AI — the Foundation Models framework, Writing Tools, Image Playground, Genmoji, Visual Intelligence?**
  → `references/apple-intelligence.md`
- **In-app purchases, subscriptions, paywalls (StoreKit 2)?**
  → `references/monetization-storekit.md`
- **A system framework (MapKit, HealthKit, Swift Charts, PhotosUI, AVFoundation, Core Location, TipKit, WeatherKit…)?**
  → `references/frameworks.md`
- **Designing it well (HIG, Liquid Glass craft, typography, color, app icon) and accessibility + localization?**
  → `references/design-and-accessibility.md`
- **Gestures, haptics, text input, search, context menus, scroll interactions?**
  → `references/interaction.md`
- **Testing (Swift Testing), Previews, debugging, Instruments, logging?**
  → `references/testing-and-debugging.md`
- **Performance tuning, privacy manifests, App Store Connect, TestFlight, distribution?**
  → `references/performance-and-shipping.md`
- **Dev tooling (Xcode 26 AI features, SPM, swift-format, CI) and which third-party libraries to use (or skip)?**
  → `references/tooling-and-ecosystem.md`
- **What changed across iOS 17 → 18 → 26 → 27, or need the primary-source citations?**
  → `references/versions-and-sources.md`

When the latest API details matter, verify against current Apple docs via the
**context7** MCP (e.g. `/websites/developer_apple_swiftui`, the SwiftData and
Foundation Models sites) or **WebSearch/firecrawl** — Apple's reference pages are
JavaScript-rendered (a plain fetch often returns only the title; use firecrawl
or a rendered scrape), and the platform changes every season, so training data
may lag a release.

## The build workflow

1. **Confirm prerequisites** (see end of this file). Building or running an iOS
   app needs **full Xcode** (not just Command Line Tools) with the iOS 26 SDK;
   the iPhone/iPad Simulator ships inside Xcode. If those are not installed, say
   so up front — scaffolding and editing code is possible, but building or running
   is not.

2. **Scaffold from the template** rather than hand-rolling project files:

   ```bash
   python3 <skill>/scripts/new_ios_app.py "AppName" \
       --bundle-id com.yourco.appname --dest ~/Developer/AppName
   ```

   This produces a verified, renamed source tree (an adaptive iPhone+iPad app
   with SwiftData, Liquid Glass, an `@Observable`-style model, and a Swift
   Testing suite) and runs `xcodegen generate` if XcodeGen is installed. See
   `assets/templates/AppScaffold/README.md`. Then `open AppName.xcodeproj`, pick
   an iPhone **and** an iPad simulator, and Run.

3. **Build features** by reading the relevant reference(s) and following their
   patterns. Keep model state in `@Observable` classes (or SwiftData `@Model`s),
   share them through the SwiftUI environment, and stay on the main actor unless
   there is a measured reason to leave it.

4. **Verify behavior before claiming success.** The user is non-technical and
   cannot read Swift — so run it. In the simulator: launch the app, drive the
   feature, and check it on **both an iPhone and an iPad simulator** (layout
   adapts — test both). Capture a screenshot or describe the observed behavior.
   When only code edits are possible (no Xcode available here), say so plainly and
   give the exact steps for the user to build and verify on their Mac.

5. **Profile and tidy** before shipping — view-update cost, list performance,
   launch time, memory — and complete the App Store checklist (privacy manifest,
   icons, screenshots) using `references/performance-and-shipping.md`.

## High-leverage rules (the things that most often go wrong)

The "why" matters more than the rule — understand it and the rest generalizes.

- **Build SDK ≠ deployment target.** Since **April 28, 2026** the App Store
  rejects uploads not built with the **iOS 26 SDK (Xcode 26+)** — but that does
  *not* force users onto iOS 26. Keep the **deployment target** (minimum OS) as
  low as needed (iOS 18, etc.) and guard iOS 26-only APIs with
  `if #available(iOS 26, *)`. Never ship an App Store build made with the Xcode
  27 / iOS 27 **beta** SDK — it is rejected.

- **Use `@Observable`, not `ObservableObject`.** The modern idiom is the
  `@Observable` macro + `@State`/`@Environment`/`@Bindable`. Avoid
  `@Published`/`@StateObject`/`@ObservedObject`/`@EnvironmentObject` in new code —
  the legacy Combine stack invalidates views far more coarsely.

- **Register a `navigationDestination` once, on the stack's content.** Navigation
  is value-**type**-keyed: `.navigationDestination(for: Item.self)` must be in the
  view tree at push time and declared **once** (not inside a `List` row or a lazy
  branch), or pushes silently fail with "no destination found". Links are
  value-based: `NavigationLink("…", value: item)`. In a `NavigationSplitView`,
  columns are driven by **selection bindings**, not `NavigationLink`.

- **Stay on the main actor; offload deliberately.** With Swift 6.2 default
  isolation, UI and models are `@MainActor` for free. Do not sprinkle
  `@MainActor`/`@unchecked Sendable` to silence errors, and do not assume a plain
  `nonisolated async func` runs in the background — since SE-0461 it runs on the
  caller's actor. To go off-main, mark the one heavy function `@concurrent` or
  move shared state into an `actor`.

- **SwiftData models are not `Sendable`.** `@Model` objects and `ModelContext`
  cannot cross actor/thread boundaries — passing them is a compile error. For
  background work use a `@ModelActor` and pass `PersistentIdentifier`s, then
  re-fetch. Mark `@Model` classes `final`.

- **CloudKit sync imposes a model contract.** SwiftData + CloudKit requires every
  property optional-or-defaulted, every relationship optional, and **no**
  `@Attribute(.unique)`/`#Unique`. Add the iCloud + Background Modes
  (remote notifications) capabilities, and deploy the schema to **Production** in
  the CloudKit console before release.

- **Liquid Glass is chrome, not content.** Glass cannot sample other glass —
  never nest `.glassEffect` inside glass, never make list rows or large content
  surfaces glass, and do not over-tint (reserve tint for the single primary
  action). Group multiple custom glass shapes in a `GlassEffectContainer`. The
  redesign mostly comes **free** from building with Xcode 26; only custom UI needs
  adoption.

- **Apple Intelligence is not everywhere — capability-check it.** The Foundation
  Models framework and other Apple Intelligence APIs only run on
  Apple-Intelligence-capable devices (iPhone 15 Pro and later, iPhone 16 family,
  M1+ iPads/Macs) with the feature enabled. Always check
  `SystemLanguageModel.default.availability` (or the relevant gate) and degrade
  gracefully; on-device inference is absent in the Simulator.

- **Declare required-reason APIs in a privacy manifest.** Using "required reason"
  APIs (e.g. `UserDefaults`, file timestamps, system boot time, disk space)
  without a `PrivacyInfo.xcprivacy` declaration is an automatic App Store
  rejection. Add usage-description Info.plist strings only for capabilities the
  app actually uses.

## Platform status (verify before relying on it — iOS moves fast)

As of mid-2026 (research-dated **2026-06-21**, the week after WWDC 2026):

- **iOS / iPadOS 26** is the current shipping line (year-based numbering jumped
  18 → 26 at WWDC 2025); latest point release **26.5.1** (June 1, 2026). It
  introduced **Liquid Glass**, the **Foundation Models** on-device LLM, and (with
  Swift 6.2) **Approachable Concurrency**.
- **iOS / iPadOS 27** was announced at **WWDC 2026** (June 8–12) and is in
  developer beta — **pre-GA, ships fall 2026**; treat its APIs as subject to
  change. Headline: next-gen Apple Intelligence + a rebuilt "Siri AI".
- **Toolchain:** **Xcode 26.5** is the current released version (Swift **6.3.2**;
  use **Swift 6 language mode**); **Xcode 27** (Swift 6.4) is a developer beta.
  Requires **macOS Tahoe 26.2+**.
- **App Store:** since **April 28, 2026**, uploads must be built with **Xcode 26+
  / the iOS 26 SDK** or later.
- **SF Symbols 7** ships with iOS 26 (added the Draw animations); **SF Symbols 8**
  is the WWDC 2026 / iOS 27 pre-GA version.
- **Hardware:** the 2025 iPhones — **iPhone 17**, **iPhone Air**, **iPhone 17
  Pro / Pro Max** — are current and all support Apple Intelligence.

`references/versions-and-sources.md` has the full iOS 17→18→26→27 delta tables
and the primary-source citation index. Re-confirm "latest" claims against Apple's
docs (context7 / WebSearch) before stating them.

## Prerequisites & environment

- **macOS Tahoe 26.2+** with **full Xcode 26+** and the **iOS 26 SDK** (bundled).
  The iPhone/iPad Simulator ships inside Xcode. *Command Line Tools alone are not
  enough to build or run an app* — they have the Swift compiler but no iOS SDK or
  Simulator.
- **Swift 6 language mode** with Approachable Concurrency (the template enables
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- Optional but recommended: **XcodeGen** (`brew install xcodegen`) for the
  scaffold script's project generation.
- An **Apple Developer account** (free tier works) to run on a physical device;
  testing on-device Apple Intelligence and some entitlements needs real hardware.

If a required piece is missing, surface it immediately and offer to help — do not
generate code and imply it ran when it could not.

## What's in this skill

```
ios-dev/
├── SKILL.md                       (this file — orientation + workflow + map)
├── README.md                      (human-facing overview & install)
├── references/                    (read on demand; see the decision tree)
├── scripts/new_ios_app.py         (scaffold a renamed copy of the template)
└── assets/templates/AppScaffold/  (verified buildable starter: adaptive iPhone+iPad
                                     app — NavigationSplitView + SwiftData + Liquid
                                     Glass + Swift Testing)
```
