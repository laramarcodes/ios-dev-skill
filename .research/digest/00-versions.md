# DOMAIN: SwiftUI iOS app development — Versions, toolchain & hardware (the dating spine: iOS 26 shipping vs iOS 27 pre-GA, Xcode/Swift, SDK mandate, Apple silicon & device landscape)

## Orientation
 As of June 21, 2026, the SHIPPING release is iOS/iPadOS 26.5 (the "26" is Apple's new year-based naming — it succeeds iOS 18, skipping 19-25). iOS 26's defining change is the systemwide "Liquid Glass" redesign, which auto-applies to native UIKit/SwiftUI controls when you build against the iOS 26 SDK. WWDC 2026 (week of June 8) just previewed iOS 27 (next-gen Apple Intelligence + a rebuilt "Siri AI", big launch/Photos/AirDrop performance wins) and dropped Xcode 27 + the iOS 27 SDK in developer beta (pre-GA, ships Fall 2026). For App Store work the load-bearing fact is the SDK mandate: from April 28, 2026, every new submission/update must be built with the iOS 26 SDK (i.e. Xcode 26+). Build with the current SDK but keep your deployment target low (iOS 17/18) to reach older devices; deployment target and SDK are independent. Apple Intelligence requires A17 Pro+ (iPhone 15 Pro and up) or M1+ iPads/Macs with 8GB RAM.

## Key facts
- [iOS 26|high] Current SHIPPING OS is iOS/iPadOS 26, released September 15, 2025; latest point release is iOS 26.5 (May 11, 2026). The '26' is year-based naming and is the direct successor to iOS 18.
- [iOS 26|high] iOS 26's headline is the 'Liquid Glass' design language — a translucent material across controls, tab bars that shrink on scroll, and layered/translucent app icons — spanning iOS/iPadOS/macOS Tahoe/watchOS/tvOS 26.
- [iOS 27 (pre-GA)|high] iOS 27 was previewed at WWDC 2026 (keynote June 8-9, 2026); developer betas released right after the keynote; public ship date Fall 2026 (pre-GA, subject to change).
- [iOS 27 (pre-GA)|high] iOS 27 headline features: next-gen Apple Intelligence on a new privacy-focused architecture; 'Siri AI' (rebuilt Siri with screen awareness, personal context, web search, cross-app actions, a dedicated Siri app); systemwide keyboard Dictation; plus performance claims — apps launch up to 30% faster, photos load up to 70% faster, AirDrop up to 80% faster.
- [iOS 26 / Xcode 26.5|high] Latest GA Xcode is Xcode 26.5: ships Swift 6.3 compiler, bundles the iOS/iPadOS/tvOS/watchOS/visionOS/macOS 26.5 SDKs, requires macOS Tahoe 26.2+. (Installed CLT here is 6.3.2, consistent with the Xcode 26.x / Swift 6.3 line.)
- [Xcode 27 (pre-GA)|high] Xcode 27 exists as a developer beta (announced June 8, 2026): ships Swift 6.4 compiler, bundles the iOS 27 / *OS 27 SDKs, requires macOS Tahoe 26.4+. Pre-GA.
- [iOS 26|high] App Store SDK mandate: starting April 28, 2026, App Store Connect rejects new submissions and updates not built with the iOS 26 (& iPadOS 26) SDK — in practice Xcode 26 or later. tvOS/visionOS require their 26 SDKs too.
- [iOS 26|high] The SDK mandate governs what you BUILD WITH, not your deployment target / minimum OS. You can keep deployment target at iOS 16/17/18 and still ship to older-OS users; only the build SDK must be current.
- [iOS 26|medium] Building against the iOS 26 SDK auto-applies the Liquid Glass appearance to standard UIKit/SwiftUI components unless the developer opts out (e.g. UIDesignRequiresCompatibility Info.plist flag as a temporary escape hatch).
- [iOS 26|high] Apple Intelligence requires iPhone 15 Pro/Pro Max or any iPhone 16+ (A17 Pro or newer, 8GB RAM), iPads with M1+ or iPad mini with A17 Pro, and Apple-silicon Macs; ~7GB free storage.
- [iOS 26|high] Current iPhone hardware (shipped Sept 2025): iPhone 17 (6.3", A19, $799), iPhone Air (5.6mm, 6.5", A19 Pro, $999), iPhone 17 Pro / 17 Pro Max (A19 Pro, from $1,099). All run iOS 26 out of the box and support Apple Intelligence.
- [iOS 26|medium] Foundation Models framework (introduced iOS 26) exposes Apple's on-device ~3B-parameter LLM to apps via Swift, with guided/structured generation (@Generable / macros), tool calling, and Private Cloud Compute escalation — runs only on Apple-Intelligence-capable devices.
- [iOS 26|medium] Modern toolchain idioms to assume: Swift 6 language mode with strict concurrency, the @Observable macro (replacing ObservableObject), NavigationStack (replacing NavigationView), and Swift Testing (the @Test macro framework, replacing XCTest as Apple's recommended default).

## APIs
- `FoundationModels (framework)` (framework; iOS 26+) — On-device LLM access; gated to Apple-Intelligence-capable devices.
- `@Observable` (macro; iOS 17+) — Current state-observation idiom; replaces ObservableObject/@Published for most cases.
- `NavigationStack` (type; iOS 16+) — Replaces deprecated NavigationView; pairs with NavigationPath for type-safe routing.
- `@Test / Swift Testing` (macro; Xcode 16+ / iOS 26 toolchain) — Apple's recommended test framework; replaces XCTest for new code.
- `@Generable / @Guide` (macro; iOS 26+ (FoundationModels)) — Structured/guided output from the on-device model.
- `UIDesignRequiresCompatibility` (modifier; iOS 26 (Info.plist key)) — Temporary opt-out to keep the pre-Liquid-Glass look when built with the iOS 26 SDK; intended as a transition escape hatch.

## Patterns

### Build with current SDK, deploy to older OS  — Setting up a project that must satisfy the App Store SDK mandate yet still reach users on iOS 17/18.
SDK = what you compile against (must be iOS 26 to ship after Apr 28 2026). Deployment target = oldest OS you run on. Keep them independent; gate new APIs with #available and #if canImport.
```swift
// Xcode 26+ (iOS 26 SDK) builds; ship broadly via a low deployment target.
// In the target's Build Settings:
//   IPHONEOS_DEPLOYMENT_TARGET = 18.0   // minimum OS users need
// SDK (what you compile against) is the latest bundled with Xcode 26.
#if canImport(FoundationModels)
import FoundationModels   // only on iOS 26+ devices at runtime
#endif

if #available(iOS 26, *) {
    // Use iOS 26-only APIs guarded by availability.
}
```

### On-device LLM via Foundation Models  — Adding private, free, on-device generative features on Apple-Intelligence-capable hardware.
Runs only where Apple Intelligence is supported (A17 Pro+/M1+, 8GB RAM); check availability and degrade gracefully on older devices. Exact session API surface is iOS 26 and still evolving — verify names against current FoundationModels docs before shipping.
```swift
import FoundationModels

let session = LanguageModelSession()
let reply = try await session.respond(
    to: "Summarize this email in 3 bullets:\n\(emailBody)"
)
print(reply.content)
```

## Pitfalls
- Confusing the SDK mandate with a deployment-target bump: rebuilding in Xcode 26 does NOT force users onto iOS 26; your minimum OS is independent and can stay at iOS 17/18.
- Shipping production apps built with Xcode 27 beta / iOS 27 SDK — beta SDKs are not accepted by App Store Connect; the required build SDK is still iOS 26.
- Forgetting that building against the iOS 26 SDK silently restyles your whole UI to Liquid Glass; audit custom controls, or opt out temporarily, then adopt intentionally.
- Calling Foundation Models / Apple Intelligence APIs without a capability check — they’re absent on pre-A17-Pro iPhones and non-M1 iPads even on iOS 26.
- Assuming 'iOS 19–25' exist; they don’t — version jumped 18 → 26. Don’t reference non-existent intermediate versions in code or docs.
- Treating iOS 27 / Swift 6.4 details as stable; they’re pre-GA (Fall 2026) and may change before release.

## iOS 26 changes
- Liquid Glass systemwide redesign auto-applies to native controls built against the iOS 26 SDK; tab/toolbars are a distinct floating glass layer that morphs and shrinks on scroll.
- Foundation Models framework: on-device LLM available to third-party apps via Swift (guided generation, tool use, PCC escalation).
- Year-based OS versioning begins: iOS 26 succeeds iOS 18 (numbers 19-25 skipped) to unify versioning across iOS/iPadOS/macOS Tahoe/watchOS/tvOS/visionOS.
- Xcode 26 ships Swift 6.3 and adds AI-assisted coding (Swift Assist / coding intelligence with model providers).

## iOS 27 preview (pre-GA)
- Next-generation Apple Intelligence on a new privacy-focused architecture, plus 'Siri AI' — a rebuilt Siri with screen awareness, personal context, in-app actions, web search, and a dedicated Siri app with iCloud-synced history. | Pre-GA developer beta; capabilities and APIs may change before Fall 2026 ship.
- Xcode 27 ships Swift 6.4 and an updated Swift Assist with multi-model routing; SDK bundles iOS 27 / *OS 27. | Beta; not yet valid for App Store submission (mandate is still the iOS 26 SDK).
- Systemwide keyboard Dictation (auto spelling/punctuation/capitalization), Spatial Reframing in Photos, and large platform performance gains (app launch +30%, photo load +70%, AirDrop +80%). | Apple's own first-party performance figures; pre-GA.
- New StoreKit capability: developers can partner to offer bundled cross-app subscriptions at a lower combined price. | Pre-GA; commercial/API details not finalized.

## Deprecations
- NavigationView → NavigationStack / NavigationSplitView (NavigationView deprecated since iOS 16).
- ObservableObject + @Published + @StateObject → @Observable macro + @State (modern idiom since iOS 17).
- XCTest → Swift Testing (@Test, #expect, #require) as the recommended default for new test targets.
- Building against pre-iOS-26 SDKs is no longer accepted for App Store submissions after April 28, 2026 (must use iOS 26 SDK / Xcode 26+).

## Uncertainties
- Exact Foundation Models Swift API surface (LanguageModelSession vs LanguageModel.shared, respond vs generate) differs between secondary sources; confirm against developer.apple.com/documentation/foundationmodels before copying into a skill.
- Whether Swift shipping with Xcode 26.5 is exactly 6.3 vs the installed CLT's 6.3.2 point release — the Xcode support page lists 6.3; treat 6.3.x as the line. A secondary WWDC recap loosely said 'Swift 6.2 shipped through 2025,' which conflicts with Apple's own 6.3/6.4 listing; I trusted the primary Apple support page.
- Precise scope/behavior of the UIDesignRequiresCompatibility opt-out and how long Apple will honor it (transition-only).
- iOS 27 / Xcode 27 / Swift 6.4 specifics are pre-GA and could shift before Fall 2026 GA.
- Did not independently verify the full iPad model matrix beyond the M1/A17 Pro Apple Intelligence floor; confirm current iPad Pro/Air/mini SKUs if the skill needs an exact device table.

## Sources
- Apple Newsroom — Apple unveils next generation of Apple Intelligence, Siri AI, and more (WWDC 2026): https://www.apple.com/newsroom/2026/06/apple-unveils-next-generation-of-apple-intelligence-siri-ai-and-more/
- Apple Developer — Xcode support (versions, Swift, SDKs, macOS requirements): https://developer.apple.com/support/xcode/
- Apple Developer — Upcoming Requirements (iOS 26 SDK mandate, Apr 28 2026): https://developer.apple.com/news/upcoming-requirements/
- Apple Developer — What's new for Apple developers: https://developer.apple.com/whats-new/
- Apple Newsroom — Apple introduces a delightful and elegant new software design (Liquid Glass): https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/
- Apple Newsroom — Apple debuts iPhone 17: https://www.apple.com/newsroom/2025/09/apple-debuts-iphone-17/
- Apple Newsroom — Apple unveils iPhone 17 Pro and iPhone 17 Pro Max: https://www.apple.com/newsroom/2025/09/apple-unveils-iphone-17-pro-and-iphone-17-pro-max/
- Apple Support — How to get Apple Intelligence (device requirements): https://support.apple.com/en-us/121115
- Apple Developer — Xcode 26 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes
- Wikipedia — iOS 26 (release date, versioning): https://en.wikipedia.org/wiki/IOS_26
- TechCrunch — WWDC 2026: everything announced (Siri AI, iOS 27, bundled subscriptions): https://techcrunch.com/2026/06/09/wwdc-2026-everything-announced-on-siri-ai-os-27-apple-intelligence-and-more/
- DEV — iOS 26 SDK is now mandatory: what actually changes: https://dev.to/arshtechpro/ios-26-sdk-is-now-mandatory-here-is-what-actually-changes-for-your-app-39m4
- andrew.ooo — WWDC 2026 Developer Tools: Xcode 27, Swift, Foundation Models: https://andrew.ooo/answers/wwdc-2026-developer-tools-xcode-swift-foundation-models-june-2026/
