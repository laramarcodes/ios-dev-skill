# Project setup: Xcode, SDK, Approachable Concurrency settings, permissions

Everything to get a native iOS/iPadOS SwiftUI project building correctly against the iOS 26 SDK — the SDK mandate, scaffolding, the Approachable Concurrency build settings (introduced in Swift 6.2, current in the Swift 6.3.2 toolchain), permission strings, the privacy manifest, and what the Simulator can't do.

**Contents**
- [Toolchain & the SDK mandate](#toolchain--the-sdk-mandate)
- [Scaffolding](#scaffolding)
- [Approachable Concurrency build settings](#approachable-concurrency-build-settings)
- [Info.plist usage-description keys](#infoplist-usage-description-keys)
- [Capabilities & entitlements](#capabilities--entitlements)
- [Privacy manifest (PrivacyInfo.xcprivacy)](#privacy-manifest-privacyinfoxcprivacy)
- [The Simulator and its limits](#the-simulator-and-its-limits)
- [Pitfalls](#pitfalls)

## Toolchain & the SDK mandate

- **Xcode 26.5** is the current GA release: bundles the **iOS/iPadOS 26.5 SDK** and the **Swift 6.3.2** compiler (the Swift 6.3.x line), requires **macOS Tahoe 26.2+**. *Xcode 27 / iOS 27 SDK / Swift 6.4 are WWDC-2026 developer betas — pre-GA, ship Fall 2026, and are **not** accepted by App Store Connect.*
- **SDK mandate vs deployment target** — the load-bearing distinction:
  - **SDK** = what you *compile against*. Since **April 28, 2026**, every App Store Connect upload must be built with the **iOS 26 SDK (Xcode 26+)** or it's rejected (error `ITMS-90725`).
  - **Deployment target** (`IPHONEOS_DEPLOYMENT_TARGET`) = the *oldest OS* you run on. This is independent of the SDK. Build with the iOS 26 SDK and still ship to iOS 17/18 users.
- Rebuilding against the iOS 26 SDK does **not** force users onto iOS 26, but it **does** silently opt your native chrome (nav bars, tab bars, toolbars, sheets) into **Liquid Glass** — a visible appearance change. Audit it, or temporarily opt out with the `UIDesignRequiresCompatibility` Info.plist flag (transition-only escape hatch; adopt Liquid Glass intentionally — see `liquid-glass.md`).
- Gate iOS 26-only APIs with `if #available(iOS 26, *)` and `#if canImport(...)` so the same binary degrades on a lower deployment target:

```swift
#if canImport(FoundationModels)
import FoundationModels   // module present only on the iOS 26 SDK
#endif

if #available(iOS 26, *) {
    // iOS 26-only API surface, guarded at runtime
}
```

- Note the year-based versioning: iOS **26** succeeds iOS **18** — numbers 19–25 never existed. Don't reference them in availability checks or docs.

## Scaffolding

Two paths, depending on whether the project is committed to plain-text project definition:

1. **Xcode template** — File ▸ New ▸ Project ▸ iOS ▸ App. Choose SwiftUI for the interface and Swift Testing for the test bundle. Fast, but the `.xcodeproj` is opaque binary-ish XML that merges badly.
2. **XcodeGen** (recommended for agents and teams) — `project.yml` is the **source of truth**; the `.xcodeproj` is generated and gitignored. Edit `project.yml`, never the generated project, then regenerate:

```bash
xcodegen generate && open MyApp.xcodeproj
```

A minimal `project.yml` for an iOS 26-SDK app with the modern build settings baked in:

```yaml
name: MyApp
options:
  bundleIdPrefix: com.yourco
settings:
  base:
    IPHONEOS_DEPLOYMENT_TARGET: "18.0"      # min OS — independent of SDK
    SWIFT_VERSION: "6.0"                      # Swift 6 language mode
    SWIFT_STRICT_CONCURRENCY: complete        # data-race safety = error
    SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor  # new-app default (see below)
    SWIFT_APPROACHABLE_CONCURRENCY: YES
targets:
  MyApp:
    type: application
    platform: iOS
    sources: [Sources]
    info:
      path: Sources/Info.plist
```

`SWIFT_VERSION: "6.0"` selects the Swift 6 *language mode* (strict concurrency, the `@Observable`/`NavigationStack`/Swift Testing idioms) — it is the language dialect, not the 6.3.2 compiler version, which is fixed by Xcode 26.5.

## Approachable Concurrency build settings

These two settings shipped in **Swift 6.2** (Sept 2025) and are still the model in the current **Swift 6.3.2** toolchain (Xcode 26.5). They are **two separate build settings**, not one. A new app target in Xcode 26 ships with **main-actor-by-default** isolation, which makes single-threaded UI code "just work" with no `Sendable` ceremony. Three settings matter; full mental model is in `concurrency-and-networking.md`.

| Build setting (Xcode 26) | Value for new apps | What it does |
|---|---|---|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | Compiler implicitly writes `@MainActor` on every type/function with no explicit isolation (SE-0466). (Existing projects default to `nonisolated`.) |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | Separate umbrella flag enabling SE-0461, SE-0401, SE-0434, SE-0470, SE-0418 — cuts `Sendable`/isolation boilerplate. Apple recommends ON for all targets. |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | Full data-race safety; violations are compile **errors**, not warnings. This is the Swift 6 language mode. |

The model is progressive disclosure: stay on the main actor for views and view models; opt **into** concurrency explicitly with `@concurrent` (offload one expensive function to a background thread) or an `actor` (protect shared non-UI mutable state). Note SE-0461's gotcha — under Approachable Concurrency a plain `nonisolated async func` now runs on the **caller's** executor, not the background, so it no longer offloads work by itself.

```swift
@Observable
final class FeedModel {            // implicitly @MainActor in a new app target
    var posts: [Post] = []
    func load() async throws {
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        posts = try await decode(data)         // hops back to main automatically
    }
    @concurrent                                  // this one fn runs off-main
    private func decode(_ data: Data) async throws -> [Post] {
        try JSONDecoder().decode([Post].self, from: data)
    }
}
```

For an **existing** project, don't flip every Approachable Concurrency flag at once — migrate feature-by-feature using Xcode's migration tooling to avoid surprise isolation changes.

## Info.plist usage-description keys

iOS gates sensitive resources behind a usage-description string. **Add a key only when you actually use the matching capability** — App Review rejects unused permission strings, and accessing a resource without its key crashes the app on first use. Common keys:

| Key | Needed for |
|---|---|
| `NSCameraUsageDescription` | `AVCaptureSession`, photo/video capture, code scanning. |
| `NSMicrophoneUsageDescription` | Audio recording, speech, VoIP. |
| `NSPhotoLibraryUsageDescription` / `...AddUsageDescription` | Read / write-only access to Photos (often avoidable with `PhotosPicker`, which needs no string). |
| `NSLocationWhenInUseUsageDescription` | Core Location while the app is foreground. Always-on adds `NSLocationAlwaysAndWhenInUseUsageDescription`. |
| `NSContactsUsageDescription` | Contacts framework. |
| `NSCalendarsFullAccessUsageDescription` / `NSRemindersFullAccessUsageDescription` | EventKit (iOS 17+ split full vs write-only). |
| `NSFaceIDUsageDescription` | LocalAuthentication / Face ID. |
| `NSUserTrackingUsageDescription` | App Tracking Transparency prompt (IDFA / cross-app tracking) — see `performance-and-shipping.md`. |
| `NSBluetoothAlwaysUsageDescription` / `NSLocalNetworkUsageDescription` | Core Bluetooth / local-network discovery. |

Strings are user-facing — write a concrete reason ("Used to attach photos to your notes"), not "We need access." System-integration specifics live in `system-integration.md`.

## Capabilities & entitlements

Capabilities are toggled in the target's **Signing & Capabilities** tab (or declared in `project.yml`), which edits the `.entitlements` file and may provision an App ID feature. Add only what you use:

- **App Groups** (`group.com.yourco.app`) — share `UserDefaults`/files with an app extension or widget.
- **Keychain Sharing**, **Associated Domains** (universal links, web credentials), **Push Notifications** (APNs), **Background Modes** (audio, location, background fetch/processing).
- **iCloud / CloudKit**, **Sign in with Apple**, **HealthKit**, **HomeKit**, **In-App Purchase / StoreKit** (see `monetization-storekit.md`).
- Entitlements that require Apple approval (e.g. CarPlay, certain managed/critical-messaging entitlements) need a request through your developer account before they provision.

## Privacy manifest (PrivacyInfo.xcprivacy)

`PrivacyInfo.xcprivacy` is a property-list file added to the app bundle (and required *separately* inside each third-party SDK). It has exactly four top-level keys (since iOS 17):

| Key | Type | Purpose |
|---|---|---|
| `NSPrivacyTracking` | Bool | Whether the app tracks per ATT definition. |
| `NSPrivacyTrackingDomains` | Array | Domains used for tracking (blocked unless ATT-authorized). |
| `NSPrivacyCollectedDataTypes` | Array | Data you collect — feeds the App Store privacy "nutrition label." |
| `NSPrivacyAccessedAPITypes` | Array | "Required-reason" API declarations (below). |

Two different enforcement levels — don't conflate them:
- **Required-reason APIs (`NSPrivacyAccessedAPITypes`)** are a **hard automated upload gate**: since **May 1, 2024**, App Store Connect mechanically rejects any app that calls a required-reason API without declaring an approved reason.
- **Tracking-domain declarations (`NSPrivacyTrackingDomains` / `NSPrivacyTracking`)** are **not** an automated upload gate — they're enforced at **runtime** (requests to listed domains fail without ATT authorization) and at **review** (misleading disclosures can draw a rejection), but submission isn't blocked mechanically the way an undeclared required-reason API is.

The five required-reason category constants (note: **no `APIs` suffix**) and a common reason code each:

| Category constant | Example approved reason |
|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` (app-only access) |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `E174.1` (check free space before a write) |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | `3EC4.1` |

```xml
<!-- PrivacyInfo.xcprivacy — declaring app-only UserDefaults use -->
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>CA92.1</string></array>
  </dict>
</array>
```

`UserDefaults` is the one most apps trip on — almost everything touches it. Full reason-code tables and the nutrition-label data-type categories are in `performance-and-shipping.md`.

## The Simulator and its limits

The iOS Simulator ships in Xcode and is where most iteration happens, but it is not a device and silently lacks several capabilities — never claim a hardware-dependent feature "works" from the Simulator alone:

- **No on-device Apple Intelligence / Foundation Models** — the on-device model isn't available, so `FoundationModels` features can't be exercised there (see `apple-intelligence.md`). They also require A17 Pro+ / M1+ hardware with 8 GB RAM at runtime.
- **No real camera or microphone capture** — the Simulator can't produce a live camera feed; `AVCaptureSession` won't deliver real frames.
- **No real motion/sensor data** — accelerometer, gyroscope, barometer, true GPS, proximity, ambient light, and the Taptic Engine (haptics) are absent or only crudely simulated (you can inject a static/route location via the Features menu).
- **No biometrics, Wallet/NFC, ARKit world tracking, or Bluetooth/local-network hardware** — Face ID/Touch ID can be *simulated* via the Features menu but not truly tested.
- **Performance is not representative** — frame timing, launch time, and memory differ from device; profile real builds on hardware with Instruments and MetricKit (`performance-and-shipping.md`).

Design and build in the Simulator, but validate camera, sensors, haptics, Apple Intelligence, and performance on a **real device** before reporting a feature done.

## Pitfalls

- **Confusing the SDK mandate with a deployment-target bump.** Rebuilding in Xcode 26 does not raise your minimum OS; the two are independent. Keep the deployment target at iOS 17/18 to retain older-device users.
- **Submitting a build made with Xcode 27 beta / iOS 27 SDK.** Pre-GA SDKs are rejected; the required build SDK is iOS 26 until iOS 27 ships in Fall 2026.
- **Forgetting that the iOS 26 SDK restyles your whole UI to Liquid Glass on rebuild.** Run a visual QA pass on every screen, or opt out with `UIDesignRequiresCompatibility` and adopt deliberately.
- **Adding an unused usage-description string** — App Review flags it. Conversely, calling a gated API with no key in `Info.plist` crashes on first access.
- **Wrong privacy-manifest category spelling.** It's `NSPrivacyAccessedAPICategoryUserDefaults` (no `APIs`); a typo is silently ineffective and still gets you rejected.
- **Assuming each third-party SDK is covered by your app's manifest** — it isn't; every SDK must ship its own `PrivacyInfo.xcprivacy`. Missing manifests/signatures can block submission.
- **Treating `SWIFT_VERSION` as the compiler version.** `6.0` is the *language mode*; the compiler is fixed at 6.3.2 by Xcode 26.5.
- **Slapping `@MainActor` on everything to silence Swift 6 errors** — it serializes genuinely parallel work onto the main thread. Isolate UI to main; move shared non-UI state into actors (see `concurrency-and-networking.md`).
- **Hand-editing the generated `.xcodeproj` in an XcodeGen project** — your changes vanish on the next `xcodegen generate`. Edit `project.yml`.
- **Trusting the Simulator for camera, sensors, haptics, Apple Intelligence, or performance** — none are real there.
- **Enabling `ENABLE_BITCODE`** — bitcode is fully removed and unaccepted since Xcode 14. Leave it off.

## Primary sources

- Upcoming Requirements (iOS 26 SDK mandate, dates) — https://developer.apple.com/news/upcoming-requirements/
- Xcode support (versions, Swift, SDKs, macOS requirements) — https://developer.apple.com/support/xcode/
- Privacy manifest files — https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Describing use of required reason API — https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Migrating to the Observable macro — https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro
- Approachable Concurrency in Swift 6.2 (SwiftLee) — https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/
- Setting default actor isolation in Xcode 26 (Donny Wals) — https://www.donnywals.com/setting-default-actor-isolation-in-xcode-26/
