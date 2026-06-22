# DOMAIN: Dev tooling & third-party ecosystem for native SwiftUI (iPhone/iPad) — Xcode developer experience, Swift Package Manager, the build system, and the third-party SPM library landscape

## Orientation
 As of June 2026, the SHIPPING toolchain is Xcode 26.x with Swift 6.2; Xcode 27 / Swift 6.3 are in developer beta (announced WWDC 2026, June 8, pre-GA, may change). The biggest shift is AI as a first-class part of Xcode. Xcode 26 introduced on-device predictive code completion plus "Coding Intelligence" (a chat assistant with ChatGPT built in and pluggable model providers via API key, including Anthropic Claude). The mid-cycle Xcode 26.3 release (Feb 2026) added true agentic coding by natively hosting the Claude Agent SDK and OpenAI Codex and exposing ~20 Xcode capabilities over the Model Context Protocol (MCP). Xcode 27 deepens this with in-editor agent panes, a /plan command, parallel sub-agents, agent-driven localization, and a unified Device Hub; it is Apple-silicon-only and ~30% smaller. On the build side, explicitly built modules are now the default for Swift (not just C/ObjC), and Apple open-sourced Swift Build (Apache 2.0) and is unifying it under SwiftPM. The third-party library ecosystem has contracted because SwiftUI/SwiftData/Foundation/Observation now absorb much of what libraries used to provide — so the senior instinct is to reach for the SDK first and add a dependency only for genuinely uncovered needs (IAP, image caching at scale, advanced architecture, crash reporting, Lottie). swift-format is now an official Apple/swiftlang package bundled in the toolchain.

## Key facts
- [Xcode 26 (shipping)|high] Xcode 26 ships on-device predictive code completion, powered by a model Apple trained specifically for Swift and Apple SDKs; it runs locally on Apple silicon and suggests multi-line completions and whole function bodies using project context.
- [Xcode 26 (shipping)|high] Xcode 26 'Coding Intelligence' includes a built-in ChatGPT integration with limited free usage; developers can sign in with a ChatGPT account or paste an API key, and can add other providers (e.g. Anthropic Claude) by entering an API key. Configured under Xcode Settings > Intelligence.
- [Xcode 26 (shipping)|medium] In Xcode 26 you attach context to a prompt by referencing files/symbols with @FileName.swift or @SymbolName; the Coding Assistant sidebar opens with Cmd-0; you can Control-click a symbol and choose Show Coding Tools > (Explain / etc.).
- [Xcode 26.3 (shipping)|high] Xcode 26.3 (released Feb 2026) added native agentic coding: it hosts the Claude Agent SDK (the same harness behind Claude Code, including subagents, background tasks, plugins) and OpenAI Codex, and exposes ~20 built-in Xcode tools over the Model Context Protocol (MCP) so any MCP-compatible agent/tool can drive Xcode.
- [Xcode 26 / Swift 6.2 (shipping)|high] The #Playground macro (import Playgrounds) lets you run a Swift block inline in any .swift file and see results in the Canvas, with named variants like #Playground("name") { }; it can access file-private entities. Available from Xcode 26 / Swift 6.2. Best for deterministic expressions (no async/IO/networking in the basic form).
- [Xcode 26 (shipping)|high] Explicitly Built Modules: enabled by default for C/Objective-C in Xcode 16, and now the default for SWIFT code in Xcode 26. Splits compilation into scan / build-imported-modules / build-source phases for faster, more parallel builds and clearer errors.
- [shipping (since 2025)|high] Apple open-sourced Swift Build in Feb 2025 — the build engine used by Xcode and Swift Playground — under Apache 2.0 on GitHub (swiftlang/swift-build), with plugins for Apple platforms, Linux, Android, Windows, QNX; Apple is integrating it into SwiftPM to unify the build experience.
- [shipping|high] swift-format is now an official swiftlang/Apple package (github.com/swiftlang/swift-format), bundled with the Xcode toolchain and used as the formatting engine for SourceKit-LSP. It can run as a CLI, an SPM plugin ('Format Source Code'), or be linked as a library. Xcode has a built-in Format/Editor format action.
- [shipping|high] swift-collections 1.3 added RigidArray and UniqueArray (accepted in principle); Apple's first-party algorithmic packages — swift-collections, swift-algorithms, swift-async-algorithms, swift-numerics — remain the recommended way to get Deque/OrderedSet/Heap, chunking/windowing, async debounce/throttle/merge, and complex/numeric math.
- [Xcode 27 (pre-GA)|high] Xcode 27 (WWDC 2026, dev beta) adds: coding-agent panes as first-class editor tabs (split/tabbable), a /plan command to scope work before edits, parallel sub-agents, a Coding Assistant sidebar tracking concurrent agent tasks, and plugin extensibility via Model Context Protocol and Agent Client Protocol; integrates GitHub and Figma.
- [Xcode 27 (pre-GA)|high] Xcode 27 introduces the Device Hub: a unified window to run/inspect/evaluate apps across simulators and physical devices, with quick actions (home, screenshots, rotation), an inspector for accessibility settings (contrast, dynamic type, dark appearance), and dynamic simulator resizing.
- [Xcode 27 (pre-GA)|high] Xcode 27 adds agent-driven localization: it auto-discovers localizable content, creates String Catalogs, generates context-aware translations per language ('Generate Translations' button), and helps review localized UI previews.
- [Xcode 27 (pre-GA)|high] Xcode 27 is Apple-silicon-only, ~30% smaller, with a fully customizable toolbar and a new theme system (preset themes, per-workspace themes, slider color/intensity, font customization). Instruments adds a 'Top Functions' view; the Organizer is redesigned with Storage and Animation Hitches metrics and expanded Metric Goals.
- [Xcode 27 / Xcode Cloud (pre-GA cycle)|medium] Xcode Cloud is up to 2x faster in the WWDC 2026 cycle, gains Metal-app support and visionOS builds, and a streamlined onboarding flow — all Apple-silicon powered.
- [shipping|medium] Tuist (Swift-based manifests, local+remote build caching, scaffolding, modularization) and XcodeGen (lightweight YAML project generation) remain the two main .xcodeproj-generation tools in 2026; Tuist suits large modular apps needing caching, XcodeGen suits simpler declarative needs. Both feed into fastlane or Xcode Cloud for CI/CD.

## APIs
- `#Playground` (macro; Xcode 26 / Swift 6.2; import Playgrounds) — Inline, in-file live execution shown in the Canvas; supports named variants #Playground("name"){ }; can access file-private symbols.
- `Playgrounds` (framework/module; Xcode 26+) — Module you import to use the #Playground macro.
- `swift-format` (official SPM package / CLI / build plugin; swiftlang/swift-format; bundled in toolchain) — Apple's official formatter; 'Format Source Code' SPM command plugin; powers SourceKit-LSP formatting. Config via .swift-format JSON.
- `Explicitly Built Modules` (build-system feature; Default for Swift in Xcode 26) — Build setting; scan / build-modules / build-sources phases for faster parallel builds.
- `Swift Build (swift-build)` (open-source build engine; swiftlang/swift-build, Apache 2.0, since 2025) — Engine behind Xcode; being unified into SwiftPM.
- `Model Context Protocol (MCP)` (protocol / integration surface; Xcode 26.3 (host) and Xcode 27) — Xcode exposes ~20 built-in tools over MCP; any MCP-compatible agent can drive Xcode.
- `Agent Client Protocol` (protocol / plugin surface; Xcode 27 (pre-GA)) — New plugin/extensibility surface for coding agents alongside MCP.
- `swift-collections` (Apple SPM package; apple/swift-collections (1.3 adds RigidArray/UniqueArray)) — Deque, OrderedSet/OrderedDictionary, Heap, BitSet, TreeDictionary.
- `swift-algorithms` (Apple SPM package; apple/swift-algorithms) — chunked, windows, combinations, uniqued, etc.
- `swift-async-algorithms` (Apple SPM package; apple/swift-async-algorithms) — debounce, throttle, merge, zip, chunked for AsyncSequence.
- `swift-numerics` (Apple SPM package; apple/swift-numerics) — Complex, Real, elementary functions for numeric/scientific code.
- `swift-dependencies` (third-party SPM (Point-Free); pointfreeco/swift-dependencies) — Macro-driven DI used by TCA; @Dependency property wrapper, withDependencies override.
- `swift-sharing` (third-party SPM (Point-Free); pointfreeco/swift-sharing) — @Shared property wrapper for shared/persisted state (appStorage, fileStorage) outside TCA too.

## Patterns

### Run a quick experiment inline with #Playground  — You want to test a pure function or view logic without a separate .playground file.
Keep it deterministic (no async/IO). Lives in the same file, so it can see file-private symbols. Available Xcode 26+.
```swift
import Playgrounds

struct Math { static func fib(_ n: Int) -> Int { n < 2 ? n : fib(n-1)+fib(n-2) } }

#Playground("fib") {
    let values = (0..<10).map(Math.fib)
    values   // shown live in the Canvas
}
```

### Add Apple's algorithmic packages instead of hand-rolling utilities  — You need ordered/deque collections, chunking, or async stream operators.
First-party, ABI-friendly, no heavyweight transitive deps. Prefer over bespoke implementations or large utility libs.
```swift
// Package.swift
dependencies: [
  .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
  .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
],
// usage
import Collections
import AsyncAlgorithms
var q = Deque<Int>()
for await batch in stream.chunked(by: .repeating(every: .seconds(1))) { /* ... */ }
```

### Format and lint in CI without a third-party formatter  — Setting up code style on a new project.
Use the official swift-format for formatting. Add SwiftLint only if you want lint RULES (code smells/API-misuse) it doesn't cover — they are complementary, not redundant.
```swift
# swift-format ships with the toolchain
swift format lint --recursive Sources/
swift format format --in-place --recursive Sources/
# or as an SPM command plugin:
swift package plugin --allow-writing-to-package-directory format-source-code
```

### Drive Xcode with an agent over MCP (Xcode 26.3+)  — You want Claude Code/Codex or another MCP client to build, run previews, and fix issues in an Xcode project.
Pre-existing for agentic workflows; the agent validates its own work via builds/previews/tests. In Xcode 27 this becomes first-class editor panes with /plan and parallel sub-agents.
```swift
// Xcode 26.3 hosts the Claude Agent SDK / Codex and exposes ~20 tools via MCP.
// In Xcode: open the Coding Assistant (Cmd-0), pick a provider/agent.
// External MCP clients connect to Xcode's MCP server to search docs,
// explore files, edit project settings, capture Previews, and iterate builds.
```

## Pitfalls
- Confusing the two formatters: nicklockwood/SwiftFormat (third-party) and swiftlang/swift-format (Apple) are different tools with near-identical names and different config files. Pick one deliberately.
- swift-format formats, SwiftLint lints — they are not interchangeable. SwiftLint won't reformat; swift-format won't catch API-misuse code smells.
- #Playground only handles deterministic expressions in its basic form — no async/networking/file IO; trying those silently does nothing useful or fails.
- Adding Alamofire/AsyncImage-replacements/Combine-bridges out of habit when URLSession async-await, AsyncImage, and @Observable already cover the need adds dead weight and slows builds.
- TCA is powerful but heavy — adopting it for a small app imposes large conceptual + dependency overhead (swift-dependencies, swift-sharing transitively). Match the architecture to app size.
- Explicitly built modules being default for Swift in Xcode 26 can surface previously-hidden implicit-module errors when migrating older projects; treat new build errors as latent issues, not regressions.
- Xcode 27 features (Device Hub, agent panes, /plan, agent localization) are pre-GA beta — do not assume final API/UX names or that they ship as described.
- Xcode 27 is Apple-silicon-only and ~30% smaller — Intel Mac build hosts/CI must be retired before adopting it.
- Pasting a third-party model API key into Xcode Coding Intelligence sends code context to that provider — a privacy/compliance consideration distinct from the on-device predictive completion.

## iOS 26 changes
- Predictive on-device code completion (Swift-specific model) shipped in Xcode 26.
- Coding Intelligence chat assistant with built-in ChatGPT and pluggable API-key providers (incl. Anthropic).
- #Playground macro (Playgrounds framework) for inline, in-file live code execution in the Canvas.
- Explicitly Built Modules became the default for Swift compilation (was C/ObjC-only in Xcode 16).
- Xcode 26.3 dot-release added native agentic coding via Claude Agent SDK + OpenAI Codex, with ~20 Xcode tools exposed over MCP.

## iOS 27 preview (pre-GA)
- In-editor coding-agent panes (tabbable/splittable), /plan command, parallel sub-agents, Coding Assistant sidebar tracking concurrent tasks; MCP + Agent Client Protocol plugins; GitHub & Figma integration. | Xcode 27 developer beta; APIs/UX may change before GA.
- Device Hub: unified run/inspect/evaluate across simulators + physical devices; accessibility inspector; dynamic simulator resizing. | Pre-GA beta.
- Agent-driven localization (auto String Catalog creation + context-aware translations + preview review). | Pre-GA beta.
- Apple-silicon-only Xcode, ~30% smaller; customizable toolbar + theme system; Instruments 'Top Functions'; redesigned Organizer (Storage, Animation Hitches, Metric Goals). | Pre-GA beta.
- Xcode Cloud up to 2x faster, adds Metal-app and visionOS build support. | Pre-GA cycle; performance figures from Apple.

## Deprecations
- Old way → new way (observation): ObservableObject + @Published + @StateObject/@ObservedObject → the @Observable macro (Observation framework) with @State/@Bindable. New code should use @Observable.
- Old way → new way (navigation): NavigationView → NavigationStack / NavigationSplitView (NavigationView deprecated). Use value-based navigationDestination.
- Old way → new way (testing): XCTest's XCTestCase/XCTAssert → Swift Testing (@Test, #expect, #require, @Suite). Xcode supports both; new test suites should prefer Swift Testing.
- Often-redundant now: Alamofire — URLSession with async/await + Codable covers most networking; only reach for Alamofire for advanced multipart/retry/interceptor needs.
- Often-redundant now: Combine for simple cases — @Observable + async/await + AsyncAlgorithms replaces many Combine pipelines in new SwiftUI code.
- Often-redundant now: image loading for simple cases — SwiftUI's AsyncImage handles basic remote images; add Nuke/Kingfisher only when you need real caching/prefetching/processing.
- Often-redundant now: persistence for simple cases — SwiftData (@Model, @Query) replaces hand-rolled Core Data stacks and many lightweight DB libs; use GRDB only when you need raw SQL control.
- Often-redundant now: SnapKit/Lottie-for-everything — SnapKit is UIKit Auto Layout sugar, irrelevant in pure SwiftUI; only relevant in UIKit code.
- SwiftFormat (nicklockwood, third-party) vs swift-format (Apple/swiftlang): distinct tools with similar names — prefer the official Apple swift-format for new projects; SwiftFormat is still widely used and more aggressive/opinionated.

## Libraries
- Apple swift-collections / swift-algorithms / swift-async-algorithms / swift-numerics: First-party data structures (Deque, OrderedSet, Heap), sequence algorithms, async-sequence operators, and numeric/complex math. Reach for these before any third-party utility lib. (https://github.com/apple/swift-collections)
- The Composable Architecture (TCA): Opinionated, testable unidirectional architecture for SwiftUI; built on swift-dependencies and swift-sharing. Use for large, state-heavy apps that need rigorous testing; overkill for small apps. (https://github.com/pointfreeco/swift-composable-architecture)
- swift-dependencies (Point-Free): Lightweight, macro/property-wrapper dependency injection (@Dependency); usable standalone without TCA. Modern alternative to Swinject/Factory. (https://github.com/pointfreeco/swift-dependencies)
- swift-sharing (Point-Free): @Shared property wrapper for shared/persisted state (appStorage, fileStorage, custom backends) outside TCA. (https://github.com/pointfreeco/swift-sharing)
- Factory: Compile-time, container-based dependency injection; lighter and more modern than Swinject for SwiftUI apps. (https://github.com/hmlongco/Factory)
- Swinject: Classic runtime DI container (Container/register/resolve); mature but heavier than macro-based options; still common in established UIKit/SwiftUI codebases. (https://github.com/Swinject/Swinject)
- Nuke: High-performance image loading/caching pipeline (NukeUI's LazyImage for SwiftUI). Use when you need fine-grained caching/prefetching beyond AsyncImage. (https://github.com/kean/Nuke)
- Kingfisher: Popular image downloading/caching library; KFImage as a drop-in SwiftUI image view with caching, placeholders, processors. (https://github.com/onevcat/Kingfisher)
- RevenueCat (purchases-ios): In-app purchase & subscription infrastructure (entitlements, cross-platform receipts, paywalls). Common even though StoreKit 2 covers basics, because it handles server-side entitlement state. (https://github.com/RevenueCat/purchases-ios)
- Lottie (lottie-ios): Render After Effects/JSON vector animations natively. No SDK equivalent; reach for it when designers ship Lottie files. (https://github.com/airbnb/lottie-ios)
- Sentry (sentry-cocoa): Crash reporting + performance monitoring + error tracking with symbolication. Use for production observability beyond Xcode Organizer/MetricKit. (https://github.com/getsentry/sentry-cocoa)
- GRDB: Robust SQLite toolkit with type-safe records and SwiftUI observation; choose when you need raw SQL power/control that SwiftData doesn't expose. (https://github.com/groue/GRDB.swift)
- Tuist: Swift-based Xcode project generation with local+remote build caching, scaffolding, and modularization for large codebases. (https://github.com/tuist/tuist)
- XcodeGen: Lightweight YAML-driven .xcodeproj generation to kill merge conflicts; simpler than Tuist with no caching. (https://github.com/yonaskolb/XcodeGen)
- fastlane: CI/CD automation for signing, builds, screenshots, TestFlight/App Store uploads; the cross-CI alternative/complement to Xcode Cloud. (https://github.com/fastlane/fastlane)
- SwiftLint: Lint rules for code smells and API misuse (complements, not replaces, swift-format which only formats). (https://github.com/realm/SwiftLint)

## Uncertainties
- Exact Xcode Settings UI labels for Coding Intelligence provider setup (e.g. precise menu names, whether it's 'Intelligence' vs 'Coding Intelligence' tab) are corroborated mostly from secondary sources; Apple's setup-coding-intelligence doc page rendered thin on fetch.
- Whether the '#'-prefixed document/context mention syntax exists distinct from the '@FileName.swift' syntax in Xcode 26 could not be confirmed; verified syntax is '@'.
- Precise version where swift-collections RigidArray/UniqueArray land (1.3 'in principle') — confirm exact released minor before quoting in a skill.
- Xcode Cloud '2x faster', '30% smaller', and visionOS/Metal support figures come from Apple's WWDC 2026 marketing/newsroom and the session; treat performance numbers as vendor claims.
- Exact count of Xcode tools exposed over MCP is reported as '~20 built-in tools' from secondary coverage of Xcode 26.3; verify against Apple's own docs before stating a precise number.
- Whether swift-format ships a stable default Swift style guide yet — historically Apple stated the style is 'one possibility' and not finalized; confirm current status.

## Sources
- Writing code with intelligence in Xcode — Apple Developer Documentation: https://developer.apple.com/documentation/Xcode/writing-code-with-intelligence-in-xcode
- Setting up coding intelligence — Apple Developer Documentation: https://developer.apple.com/documentation/xcode/setting-up-coding-intelligence
- Running code snippets using the playground macro — Apple Developer Documentation: https://developer.apple.com/documentation/Xcode/running-code-snippets-using-the-playground-macro
- Building your project with explicit module dependencies — Apple Developer Documentation: https://developer.apple.com/documentation/xcode/building-your-project-with-explicit-module-dependencies
- What's new in Xcode 27 — WWDC26 Session 258: https://developer.apple.com/videos/play/wwdc2026/258/
- Apple aids app development with new intelligence frameworks and advanced tools — Apple Newsroom (June 2026): https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/
- Xcode 26.3 unlocks the power of agentic coding — Apple Newsroom (Feb 2026): https://www.apple.com/newsroom/2026/02/xcode-26-point-3-unlocks-the-power-of-agentic-coding/
- Apple's Xcode now supports the Claude Agent SDK — Anthropic: https://www.anthropic.com/news/apple-xcode-claude-agent-sdk
- Beyond ChatGPT: Xcode 26 will support multiple AI models, like Claude — 9to5Mac: https://9to5mac.com/2025/06/10/beyond-chatgpt-xcode-26-will-support-multiple-ai-models-like-claude/
- Apple open sources Swift Build — DevClass: https://www.devclass.com/development/2025/02/04/apple-open-sources-swift-build/1627751
- swiftlang/swift-format — GitHub: https://github.com/swiftlang/swift-format
- Swift Code Formatters — NSHipster: https://nshipster.com/swift-format/
- apple/swift-collections — GitHub: https://github.com/apple/swift-collections
- apple/swift-async-algorithms — GitHub: https://github.com/apple/swift-async-algorithms
- Xcode Explicitly Built Modules — Use Your Loaf: https://useyourloaf.com/blog/xcode-explicitly-built-modules/
- XcodeGen vs. Tuist — Medium (Saiefeddine Hayouni): https://medium.com/@sayefeddineh/xcodegen-vs-tuist-choosing-the-right-tool-for-xcode-project-generation-bea093c6e105
- What's New in Xcode 26 — WWDC25 Session 247: https://developer.apple.com/videos/play/wwdc2025/247/
- What's New — Xcode — Apple Developer: https://developer.apple.com/xcode/whats-new/
