# iOS version history & primary sources

What changed across releases, and where the facts come from. Use this to give the
user accurate, version-qualified answers — and **re-verify anything time-sensitive**
against Apple's live docs, because this snapshot is dated **2026-06-21** (the week
after WWDC 2026) and the platform changes every season.

**Contents**
- [Release timeline & numbering](#release-timeline--numbering)
- [Hardware & Apple Intelligence support](#hardware--apple-intelligence-support)
- [Toolchain & App Store](#toolchain--app-store)
- [iOS 26 — the highlights (current, shipping)](#ios-26--the-highlights-current-shipping)
- [iOS 27 — the WWDC 2026 wave (pre-GA)](#ios-27--the-wwdc-2026-wave-pre-ga)
- [Primary-source index](#primary-source-index)
- [Caveats carried from research](#caveats-carried-from-research)

## Release timeline & numbering

iOS uses **year-based numbering** as of 2025. It went **iOS 17 → 18 → 26**, skipping
19–25 at WWDC 2025 to align iOS/iPadOS/macOS (Tahoe)/watchOS/tvOS/visionOS on one
number.

| Release | Debut | Status (mid-2026) | Headline additions for app developers |
|---|---|---|---|
| **iOS 17** | WWDC23 (Sep 2023) | superseded | **SwiftData** (`@Model`/`@Query`), the **Observation** framework (`@Observable`), `#Predicate`, interactive widgets, StoreKit views (`SubscriptionStoreView`/`ProductView`/`StoreView`), `ContentUnavailableView`, `phaseAnimator`/`keyframeAnimator`. (`NavigationStack`/`NavigationSplitView` already arrived in iOS 16.) |
| **iOS 18** | WWDC24 (Sep 2024) | superseded | Value-based **`Tab` API** + `.tabViewStyle(.sidebarAdaptable)`, **Control Center controls** (`ControlWidget`), SwiftData **custom `DataStore`**, the `@Entry`/`@Previewable` macros, **Swift 6** + **Swift Testing** GA (Xcode 16), and the first **Apple Intelligence** developer surfaces (Writing Tools 18.1, Image Playground 18.1, Genmoji 18.2, App Intent assistant schemas). |
| **iOS 26** | WWDC25 (Jun 2025), shipped **Sep 15 2025** | **current shipping line** (latest **26.5.1**, Jun 1 2026) | **Liquid Glass** redesign; the **Foundation Models** on-device LLM; **Swift 6.2 Approachable Concurrency** + default `@MainActor` isolation; **SwiftData class inheritance**; **Visual Intelligence**; **SF Symbols 7** (Draw animations); the **iPadOS 26 windowing system**; floating/minimizing tab bar. |
| **iOS 27** | WWDC26 (**Jun 8–12 2026**) | **announced, ships fall 2026 — pre-GA** | Next-gen **Apple Intelligence** + a rebuilt **"Siri AI"**; **Swift 6.4** / Xcode 27 / **SF Symbols 8**; SwiftData **sectioned `@Query`** + `ResultsObserver`/`HistoryObserver` + enum predicates; nav-transition (`CrossFadeNavigationTransition`) + toolbar (`toolbarMinimizeBehavior`) additions; Liquid Glass refinements + a user transparency slider; large platform performance gains. |

## Hardware & Apple Intelligence support

- **Current iPhones (Sep 2025):** **iPhone 17** (A19, from $799), **iPhone Air**
  (note: branded *iPhone Air*, not "iPhone 17 Air"; A19 Pro, from $999),
  **iPhone 17 Pro** (from $1,099) and **iPhone 17 Pro Max** (from $1,199), both
  A19 Pro. All ship with iOS 26 and support Apple Intelligence.
- **Apple Intelligence / Foundation Models device floor:** iPhone 15 Pro / 15 Pro
  Max and **all** iPhone 16-and-later; iPad mini (A17 Pro) and iPads with **M1+**;
  **M1+** Macs; plus Apple Vision Pro. Needs **8 GB RAM**, ~7 GB free storage, the
  feature enabled in Settings, and a supported region. On-device inference is
  **not** available in the Simulator.

## Toolchain & App Store

- **Build with Xcode 26+** using the **iOS 26 SDK or later** — required for App
  Store uploads since **April 28, 2026**. The current released toolchain is
  **Xcode 26.5** (Swift **6.3.2**), requiring **macOS Tahoe 26.2+**.
- **Xcode 27** (Swift **6.4**, requires macOS Tahoe 26.4+) is a **developer beta**
  from WWDC 2026 — **not valid for App Store submission** (the mandate is still the
  iOS 26 SDK). Don't ship beta-SDK builds.
- Use **Swift 6 language mode** (`SWIFT_VERSION = 6.0`). **Approachable Concurrency**
  arrived in **Swift 6.2** (Sep 2025) and is two distinct build settings:
  `SWIFT_APPROACHABLE_CONCURRENCY = YES` (enables SE-0461 `nonisolated(nonsending)`
  by default, etc.) and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (whole-module
  main-actor isolation — the default for new app targets). Swift 6.3 itself was
  open-sourced **March 24, 2026**, *before* WWDC 2026.
- **Deployment target is independent of the SDK:** build with the iOS 26 SDK and
  still set a low minimum OS (iOS 18, etc.) to reach older devices — just guard
  iOS 26-only APIs with `if #available(iOS 26, *)`.

## iOS 26 — the highlights (current, shipping)

Prefer these on new code; they define the modern idiom:

- **Liquid Glass.** Standard controls, tab/tool/nav bars and sheets restyle
  automatically when you build with the iOS 26 SDK. Adopt on custom views with
  `glassEffect(_:in:)` + `GlassEffectContainer`; primary actions use
  `.buttonStyle(.glassProminent)`. Glass is chrome-only; never glass-on-glass. See
  `liquid-glass.md`.
- **Foundation Models.** On-device LLM via `LanguageModelSession` with
  `respond(to:)`/`streamResponse(to:)`, `@Generable`/`@Guide` guided generation,
  and the `Tool` protocol; gate on `SystemLanguageModel.default.availability`.
  (All types are tagged **Beta** in the iOS 26 SDK even though iOS 26 is shipping.)
  See `apple-intelligence.md`.
- **Approachable Concurrency (Swift 6.2).** App code is `@MainActor` by default;
  opt into concurrency with `@concurrent` / `actor` / `@ModelActor`. See
  `concurrency-and-networking.md`.
- **SwiftData class inheritance**, sortable persistent history, Codable types in
  `#Predicate`. See `data-persistence.md`.
- **Visual Intelligence** for apps (`IntentValueQuery` + `SemanticContentDescriptor`)
  and interactive App Intent **snippets** (`SnippetIntent`). See `system-integration.md`.
- **iPadOS 26 windowing system** (resizable/overlapping windows, traffic-light
  controls, tiling, Exposé, a customizable menu bar) — works *with* Stage Manager.
  See `ipad.md`.
- **SF Symbols 7** (Draw On/Off animations, gradients, Magic Replace). See
  `design-and-accessibility.md`.

## iOS 27 — the WWDC 2026 wave (pre-GA)

Announced WWDC 2026; **developer beta now, ships fall 2026 — verify before shipping**:

- **Next-generation Apple Intelligence** on a new privacy architecture and a rebuilt
  **"Siri AI"** (screen awareness, personal context, cross-app actions, a dedicated
  Siri app). Systemwide keyboard Dictation.
- **Swift 6.4 / Xcode 27** (multi-vendor coding agents); **SF Symbols 8** (7,000+
  symbols, semantic Enhanced Search).
- **SwiftData**: sectioned `@Query(sectionBy:)`, `@Attribute(.codable)`,
  `ResultsObserver`/`HistoryObserver`, native enum/composite predicates.
- **SwiftUI**: `CrossFadeNavigationTransition`/`AnyNavigationTransition`,
  `.toolbarMinimizeBehavior(_:)` + toolbar overflow/visibility-priority, foldable-aware
  adaptive scene APIs.
- **Liquid Glass** second iteration + a user-facing transparency slider your tints
  respond to (the `UIDesignRequiresCompatibility` opt-out is expected to be removed).
- Apple-cited performance: app launch up to ~30% faster, photos up to 70% faster,
  AirDrop up to 80% faster.

## Primary-source index

Apple's documentation and WWDC session pages are **JavaScript-rendered** — a plain
fetch often returns only the page title. Use **firecrawl_scrape** (with a few
seconds' wait) or the **context7** MCP to read them. **Mind the year** — WWDC25 and
WWDC26 reuse session numbers for different content.

**Platform / dating**
- iOS 26 updates (current point release) — `support.apple.com/en-us/123075`
- WWDC 2026 / iOS 27 + Apple Intelligence — `apple.com/newsroom/2026/06/apple-unveils-next-generation-of-apple-intelligence-siri-ai-and-more/`
- Liquid Glass announcement (WWDC25) — `apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/`
- iPadOS 26 windowing — `apple.com/newsroom/2025/06/ipados-26-introduces-powerful-new-features-that-push-ipad-even-further/`
- iPhone 17 / Air hardware — `apple.com/newsroom/2025/09/apple-debuts-iphone-17/`, `.../apple-unveils-iphone-17-pro-and-iphone-17-pro-max/`
- Apple Intelligence device requirements — `support.apple.com/en-us/121115`
- Xcode versions / Swift / SDK mapping — `developer.apple.com/support/xcode/`
- App Store SDK mandate (Apr 28 2026) — `developer.apple.com/news/upcoming-requirements/`
- What's new for Apple developers — `developer.apple.com/whats-new/`
- Xcode 26 release notes — `developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes`

**SwiftUI, navigation & the new design**
- What's new in SwiftUI (WWDC25 256) — `developer.apple.com/videos/play/wwdc2025/256/`
- Build a SwiftUI app with the new design (WWDC25 323) — `.../wwdc2025/323/`
- Meet Liquid Glass (WWDC25 219) / Get to know the new design system (WWDC25 356)
- Applying Liquid Glass to custom views — `developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views`
- `GlassEffectContainer` / `glassEffectUnion` / `GlassEffectTransition` — under `developer.apple.com/documentation/swiftui/`
- Migrating to new navigation types — `developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types`
- Landmarks: Building an app with Liquid Glass (sample) — `developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass`
- HIG — Materials — `developer.apple.com/design/human-interface-guidelines/materials`

**State, data & concurrency**
- Observation framework — `developer.apple.com/documentation/Observation`
- Migrating from ObservableObject to the Observable macro — `developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro`
- SwiftData — `developer.apple.com/documentation/swiftdata`; What's new in SwiftData (WWDC26 274); inheritance & migration (WWDC25 291)
- `CKSyncEngine` — `developer.apple.com/documentation/cloudkit/cksyncengine-5sie5`; sample — `github.com/apple/sample-cloudkit-sync-engine`
- Embracing Swift concurrency (WWDC25 268) — `developer.apple.com/videos/play/wwdc2025/268/`
- SE-0461 (nonisolated async on caller's actor) — `github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md`
- Swift 6.2 released — `swift.org/blog/swift-6.2-released/`
- `URLSession.AsyncBytes` / `AsyncStream` — under `developer.apple.com/documentation/foundation/` and `/swift/`

**iPad, system integration & AI**
- Elevate the design of your iPad app (WWDC25 208) — `developer.apple.com/videos/play/wwdc2025/208/`
- Building/customizing the menu bar with SwiftUI — `developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui`
- App Intents — `developer.apple.com/documentation/appintents`; assistant schemas — `.../appintents/assistantintent(schema:)`
- WidgetKit interactivity / Control widgets — `developer.apple.com/documentation/widgetkit/`
- ActivityKit (Live Activities) — `developer.apple.com/documentation/ActivityKit`; AlarmKit — `.../AlarmKit`
- Foundation Models — `developer.apple.com/documentation/foundationmodels`
- Meet the Foundation Models framework (WWDC25) and App Intents advances (WWDC25 275)

**Commerce, testing & shipping**
- In-App Purchase (StoreKit) — `developer.apple.com/documentation/storekit`; `SubscriptionStoreView` under `/storekit/`
- Privacy manifest files — `developer.apple.com/documentation/bundleresources/privacy-manifest-files`
- Required-reason APIs — `developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api`
- Swift Testing — `developer.apple.com/documentation/testing`; `developer.apple.com/xcode/swift-testing/`

**Community (secondary — corroborate against Apple)**
- Hacking with Swift (`hackingwithswift.com`), Donny Wals (`donnywals.com`),
  SwiftLee (`avanderlee.com`), Fatbobman (`fatbobman.com`), Nil Coalescing,
  Swift with Majid, Point-Free — reputable iOS write-ups; always trace claims back
  to Apple primary docs.

## Caveats carried from research

- **iOS 27 / Xcode 27 / Swift 6.4 / SF Symbols 8 are pre-GA.** Several iOS 27 API
  names (toolbar/foldable APIs, `ResultsObserver`/`HistoryObserver` signatures) come
  from secondary WWDC 2026 recaps, not yet from rendered Apple reference pages —
  re-check before relying on them.
- **Foundation Models** types are tagged **Beta** in the iOS 26 SDK even though
  iOS 26 ships; treat the surface as stable for 26.x but expect Beta annotations.
- **`ImageCreator`** (programmatic Image Playground) is **deprecated** (18.4–27.0) —
  use `imagePlaygroundSheet` / `ImagePlaygroundViewController`.
- **Privacy manifest** enforcement differs by piece: required-reason API and SDK
  manifest declarations are hard automated upload gates; tracking-domain
  declarations are runtime/review-enforced. (See `performance-and-shipping.md`.)
- Apple's reference pages are JS-rendered; some exact availability strings in the
  research were corroborated via secondary sources — confirm verbatim against
  developer.apple.com (rendered) before quoting Apple.
