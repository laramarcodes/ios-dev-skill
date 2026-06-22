# Dev tooling & third-party ecosystem

How to use Xcode's AI and build features well, and — just as important — which third-party packages to *skip* because the SDK now covers them. The senior instinct in 2026 is SDK-first: reach for SwiftUI/SwiftData/Foundation/Observation before adding a dependency, and add one only for genuinely uncovered needs (IAP entitlements, image caching at scale, heavy architecture, crash reporting, vector animation).

**Contents**
- [Xcode coding intelligence](#xcode-coding-intelligence)
- [#Playground for inline experiments](#playground-for-inline-experiments)
- [Swift Package Manager](#swift-package-manager)
- [Build system: explicitly built modules](#build-system-explicitly-built-modules)
- [Formatting & linting](#formatting--linting)
- [Project generation & CI/CD](#project-generation--cicd)
- [Library decision table](#library-decision-table)
- [What the SDK made redundant](#what-the-sdk-made-redundant)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## Xcode coding intelligence

Xcode 26 (shipping) made AI a first-class part of the IDE. Two distinct features — don't conflate them:

- **On-device predictive code completion** — a model Apple trained specifically for Swift and the Apple SDKs, running locally on Apple silicon. Suggests multi-line completions and whole function bodies from project context. Fully offline; no code leaves the machine.
- **Coding Intelligence** (chat assistant) — built-in ChatGPT with limited free usage; sign in with a ChatGPT account or paste an API key. You can add other providers (e.g. **Anthropic Claude — Sonnet/Opus**, or any OpenAI Chat-Completions-compatible endpoint, including local models) by entering an API key. Configured under **Xcode ▸ Settings ▸ Intelligence**.

Open the Coding Assistant sidebar with **Cmd-0**. Attach context to a prompt by referencing files/symbols with `@FileName.swift` / `@SymbolName`. Control-click a symbol → **Show Coding Tools** for explain/edit actions.

| Version | Capability |
|---|---|
| Xcode 26 | On-device predictive completion; Coding Intelligence chat with ChatGPT + pluggable API-key providers (incl. Claude). |
| Xcode 26.3 (Feb 2026, shipping) | Native **agentic coding** — hosts the Claude Agent SDK (same harness behind Claude Code: subagents, background tasks, plugins) and OpenAI Codex; exposes ~20 built-in Xcode tools over the **Model Context Protocol (MCP)** so any MCP client can drive Xcode (search docs, edit files/settings, capture Previews, iterate builds). |
| Xcode 27 (pre-GA, ships fall 2026) | Coding-agent panes as first-class editor tabs (split/tabbable); `/plan` command to scope work before edits; parallel sub-agents; multi-vendor agents via **MCP + Agent Client Protocol**; GitHub & Figma integration; agent-driven localization. |

Pasting a third-party model API key sends code context to that provider — a privacy/compliance decision distinct from the strictly on-device predictive completion.

## #Playground for inline experiments

`#Playground` (macro; Xcode 26 / Swift 6.2; `import Playgrounds`) runs a Swift block inline in any `.swift` file and shows results live in the Canvas — no separate `.playground` file. Because it lives in the same file, it can see file-private symbols. Use it to sanity-check a pure function or view-model logic.

```swift
import Playgrounds

struct Math { static func fib(_ n: Int) -> Int { n < 2 ? n : fib(n-1) + fib(n-2) } }

#Playground("fib") {
    let values = (0..<10).map(Math.fib)
    values   // shown live in the Canvas
}
```

Keep it deterministic: the basic form is for synchronous expressions. Async/networking/file IO either silently does nothing useful or fails — don't reach for `#Playground` to test a network call.

## Swift Package Manager

SPM is the default dependency and build manifest. `Package.swift` declares dependencies, targets, and (since Swift 5.6) **build/command plugins**. Package *registries* (since Swift 5.7) let you resolve by identity instead of a Git URL.

```swift
// Package.swift — swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MyFeature",
    platforms: [.iOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    ],
    targets: [
        .target(name: "MyFeature", dependencies: [
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        ]),
        .testTarget(name: "MyFeatureTests", dependencies: ["MyFeature"]),
    ]
)
```

Apple open-sourced **Swift Build** (`swiftlang/swift-build`, Apache 2.0, since Feb 2025) — the engine behind Xcode and Swift Playground — and is unifying it under SwiftPM, so the SwiftPM and Xcode build experience are converging. Prefer pinning with `from:` (semantic-version range) over exact versions unless reproducibility demands it.

## Build system: explicitly built modules

**Explicitly Built Modules** became the **default for Swift in Xcode 26** (it was C/Objective-C-only in Xcode 16). Compilation splits into discrete *scan → build-imported-modules → build-source* phases, which parallelizes better, makes builds faster, and produces clearer diagnostics.

Migration gotcha: making this the default for Swift can *surface* implicit-module errors that older projects were silently relying on. Treat new build errors after upgrading as latent issues finally exposed — not as a regression in Xcode.

## Formatting & linting

Two jobs, two tools — they are complementary, not interchangeable:

| Tool | Job | Notes |
|---|---|---|
| **swift-format** (`swiftlang/swift-format`) | Reformats code | Now **official Apple**, bundled in the toolchain, and the formatting engine behind SourceKit-LSP. Runs as a CLI, an SPM **"Format Source Code"** command plugin, or a linked library. Config via a `.swift-format` JSON file. Prefer this for new projects. |
| **SwiftLint** (`realm/SwiftLint`) | Lints code *smells* / API misuse | Won't reformat. Add it only when you want rules swift-format doesn't enforce. |

```bash
# swift-format ships with the toolchain
swift format lint --recursive Sources/
swift format format --in-place --recursive Sources/
# or via the SPM command plugin:
swift package plugin --allow-writing-to-package-directory format-source-code
```

Name-collision warning: `nicklockwood/SwiftFormat` (third-party, more aggressive/opinionated) and `swiftlang/swift-format` (Apple) are **different tools with near-identical names and different config files**. Pick one deliberately; for new work prefer Apple's official `swift-format`.

## Project generation & CI/CD

Hand-editing `project.pbxproj` causes merge conflicts; generate it instead.

| Tool | When |
|---|---|
| **Tuist** (`tuist/tuist`) | Swift-based manifests, local+remote build caching, scaffolding, modularization. Suits large modular apps that need caching. |
| **XcodeGen** (`yonaskolb/XcodeGen`) | Lightweight YAML-driven `.xcodeproj` generation, no caching. Suits simpler declarative needs. |
| **fastlane** (`fastlane/fastlane`) | Cross-CI automation for signing, builds, screenshots, TestFlight/App Store upload. The portable alternative/complement to Xcode Cloud. |
| **Xcode Cloud** | Apple-hosted CI tied to App Store Connect; least setup if you're all-in on Apple. (WWDC 2026 cycle: up to 2x faster, adds Metal-app and visionOS builds — *pre-GA figures, vendor claims*.) |

## Library decision table

Reach for first-party packages before any third-party utility lib.

| Package | Use it for | URL |
|---|---|---|
| **apple/swift-collections** | `Deque`, `OrderedSet`/`OrderedDictionary`, `Heap`, `BitSet`, `TreeDictionary`. (1.3 adds `RigidArray`/`UniqueArray`.) | github.com/apple/swift-collections |
| **apple/swift-algorithms** | `chunked`, `windows`, `combinations`, `uniqued`, etc. | github.com/apple/swift-algorithms |
| **apple/swift-async-algorithms** | `debounce`, `throttle`, `merge`, `zip`, `chunked` for `AsyncSequence`. | github.com/apple/swift-async-algorithms |
| **apple/swift-numerics** | `Complex`, `Real`, elementary functions for numeric/scientific code. | github.com/apple/swift-numerics |
| **The Composable Architecture (TCA)** | Rigorous unidirectional, testable architecture for large state-heavy apps. Overkill (and heavy: pulls swift-dependencies + swift-sharing transitively) for small apps. | github.com/pointfreeco/swift-composable-architecture |
| **swift-dependencies** (Point-Free) | Macro/property-wrapper DI (`@Dependency`, `withDependencies`); usable standalone without TCA. | github.com/pointfreeco/swift-dependencies |
| **swift-sharing** (Point-Free) | `@Shared` property wrapper for shared/persisted state (appStorage, fileStorage) outside TCA. | github.com/pointfreeco/swift-sharing |
| **Factory** | Compile-time container DI; lighter/more modern than Swinject for SwiftUI. | github.com/hmlongco/Factory |
| **Nuke** / **Kingfisher** | Image loading/caching beyond `AsyncImage` — fine-grained caching, prefetching, processors. `NukeUI.LazyImage` / `KFImage` are drop-in SwiftUI views. | github.com/kean/Nuke · github.com/onevcat/Kingfisher |
| **RevenueCat** (purchases-ios) | IAP/subscriptions with server-side entitlement state, cross-platform receipts, paywalls. Common even though the In-App Purchase (Swift) API — marketed as "StoreKit 2" — covers basics. See `monetization-storekit.md`. | github.com/RevenueCat/purchases-ios |
| **Sentry** (sentry-cocoa) | Crash reporting + performance + error tracking with symbolication, beyond Xcode Organizer/MetricKit. | github.com/getsentry/sentry-cocoa |
| **Lottie** (lottie-ios) | Render After Effects/JSON vector animations natively. No SDK equivalent — reach for it when designers ship Lottie files. | github.com/airbnb/lottie-ios |
| **GRDB** | Type-safe SQLite with SwiftUI observation; choose when you need raw SQL control SwiftData doesn't expose. See `data-persistence.md`. | github.com/groue/GRDB.swift |

## What the SDK made redundant

Adding these out of habit just adds dead weight and slows builds:

- **Alamofire** → `URLSession` with async/await + `Codable` covers most networking. Only reach for Alamofire for advanced multipart/retry/interceptor needs. See `concurrency-and-networking.md`.
- **Combine (simple cases)** → `@Observable` + async/await + swift-async-algorithms replaces many Combine pipelines in new SwiftUI code.
- **AsyncImage replacements (simple cases)** → SwiftUI's `AsyncImage` handles basic remote images; add Nuke/Kingfisher only when you need real caching/prefetching/processing.
- **Hand-rolled Core Data stacks / lightweight DB libs** → SwiftData (`@Model`, `@Query`) covers most; GRDB only for raw SQL.
- **SnapKit** → UIKit Auto Layout sugar, irrelevant in pure SwiftUI; only relevant in UIKit code.
- **Swinject** → mature but heavier runtime DI; prefer macro-based swift-dependencies or Factory in new code.

And the core modern idioms the rest of this skill assumes: **`@Observable`** (Observation framework) not `ObservableObject`+`@Published`; **`NavigationStack`/`NavigationSplitView`** not `NavigationView`; **Swift Testing** (`@Test`, `#expect`, `#require`, `@Suite`) for new unit tests — GA since Xcode 16 / Swift 6 (2024), bundled in the toolchain, *not* new in Xcode 26. It coexists with XCTest, which is still required for UI automation (XCUITest) and performance tests (`measure { }`); see `testing-and-debugging.md`.

## Pitfalls

- **Two formatters, near-identical names.** `nicklockwood/SwiftFormat` vs `swiftlang/swift-format` are different tools with different config files. Choosing the wrong one silently applies the wrong style.
- **swift-format formats, SwiftLint lints — not interchangeable.** SwiftLint won't reformat; swift-format won't catch API-misuse smells. You often want both.
- **`#Playground` is for deterministic expressions only.** Async/networking/file IO in the basic form silently does nothing useful or fails.
- **Habitual dependencies.** Adding Alamofire/AsyncImage-replacements/Combine-bridges when URLSession async-await, `AsyncImage`, and `@Observable` already cover the need bloats the build.
- **TCA is heavy.** It imposes large conceptual + transitive-dependency overhead. Match the architecture to app size; don't adopt it for a small app.
- **Explicitly built modules can expose latent errors.** New build errors after upgrading to Xcode 26 are usually pre-existing implicit-module issues, not regressions.
- **API-key providers send code off-device.** Pasting a Claude/OpenAI key into Coding Intelligence is a privacy/compliance choice distinct from on-device predictive completion.
- **Xcode 27 is pre-GA and Apple-silicon-only.** Device Hub, agent panes, `/plan`, agent localization — names/UX may change before the fall-2026 GA. Xcode 27 is also ~30% smaller and drops Intel Mac build hosts, so retire Intel CI before adopting it.

## Primary sources

- Writing code with intelligence in Xcode — https://developer.apple.com/documentation/Xcode/writing-code-with-intelligence-in-xcode
- Running code snippets using the playground macro — https://developer.apple.com/documentation/Xcode/running-code-snippets-using-the-playground-macro
- Building your project with explicit module dependencies — https://developer.apple.com/documentation/xcode/building-your-project-with-explicit-module-dependencies
- What's new in Xcode 27 — WWDC26 Session 258 (pre-GA) — https://developer.apple.com/videos/play/wwdc2026/258/
- Xcode 26.3 unlocks agentic coding — https://www.apple.com/newsroom/2026/02/xcode-26-point-3-unlocks-the-power-of-agentic-coding/
- Apple's Xcode now supports the Claude Agent SDK — https://www.anthropic.com/news/apple-xcode-claude-agent-sdk
- swiftlang/swift-format — https://github.com/swiftlang/swift-format
- apple/swift-collections — https://github.com/apple/swift-collections
