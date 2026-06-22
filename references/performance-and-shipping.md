# Performance, privacy & App Store shipping

How to keep a SwiftUI app fast, pass Apple's privacy gates, and get it through review onto the App Store. Performance is mostly about feeding SwiftUI precise dependencies; shipping is mostly about not tripping the automated upload gates.

**Contents**
- [SwiftUI performance model](#swiftui-performance-model)
- [Lists, lazy stacks & identity](#lists-lazy-stacks--identity)
- [Launch time & field telemetry (MetricKit)](#launch-time--field-telemetry-metrickit)
- [Profiling with Instruments 26](#profiling-with-instruments-26)
- [Privacy manifest (PrivacyInfo.xcprivacy)](#privacy-manifest-privacyinfoxcprivacy)
- [App Privacy nutrition label & ATT](#app-privacy-nutrition-label--att)
- [Building & uploading (the iOS 26 SDK mandate)](#building--uploading-the-ios-26-sdk-mandate)
- [App thinning & icons](#app-thinning--icons)
- [TestFlight, review & EU distribution](#testflight-review--eu-distribution)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## SwiftUI performance model

SwiftUI re-evaluates a view's `body` whenever a dependency it read changes. Performance work is almost entirely about making those dependencies **precise** and each `body` **cheap** — not about clever tricks. The single biggest lever is the Observation framework.

`@Observable` (macro; iOS 17+) tracks exactly which stored properties a given `body` reads, and invalidates only the views that read the property that changed. The old `ObservableObject` + `@Published` + `objectWillChange` (the deprecated idiom) fires one signal for the whole object, so any change can re-evaluate every view observing it — silent over-invalidation. Use `@Observable` for all new code; reach for `ObservableObject` only when back-deploying below iOS 17. See `state-observation.md` for the full observation model.

```swift
@Observable final class Settings {
  var fontScale: Double = 1.0
  var theme: Theme = .system
}
// A view reading only settings.theme is NOT re-evaluated when fontScale changes.
```

Keep `body` a pure, fast function of state:

- **No work in `init` or `body`.** Both run on every re-evaluation. Move expensive computation to `.task`/`.onAppear` or cache it on the model. A network call or a sort in `body` runs far more often than you think.
- **Scope dependencies narrowly.** Pass a child the smallest model it needs (one `@Bindable` item, not the whole store) so a change elsewhere doesn't invalidate it.
- **`@State` holds the source of truth once.** It initializes its value a single time for the view's lifetime. (iOS 27 pre-GA: `@State` becomes a macro so an `@Observable` class created inside `@State` is guaranteed to init only once — verify against the final SDK.)

When a genuinely expensive subtree (a `Canvas`, a `Chart`) re-runs `body` despite unchanged inputs, make it `Equatable` so SwiftUI can skip re-evaluation by comparing inputs:

```swift
struct PriceChart: View, Equatable {
  let points: [Double]
  static func == (l: PriceChart, r: PriceChart) -> Bool { l.points == r.points }
  var body: some View { Canvas { ctx, size in /* expensive draw */ } }
}
// usage: PriceChart(points: data).equatable()   // .equatable() since iOS 13
```

Only do this when the body is expensive **and** equality is cheap and stable — slapping `.equatable()` on trivial views just adds comparison overhead.

For heavy *visual* (not logical) subtrees, `.drawingGroup(opaque:)` (since iOS 13) rasterizes the subtree into one Metal layer, and `.compositingGroup()` (since iOS 13) flattens layers before an opacity/effect pass. Both add an offscreen pass, so they help only for genuinely complex composited content — on simple views they make things slower.

## Lists, lazy stacks & identity

Stable identity is what lets SwiftUI reuse views instead of recreating them. Unstable IDs cause recreation, lost scroll position, and wrong/janky animations.

| API | When | Notes |
|---|---|---|
| `List` (iOS 13) | Large/dynamic datasets | Already lazy, `UICollectionView`-backed, reuses rows. Prefer for big lists. |
| `LazyVStack`/`LazyHStack` (iOS 14) | Custom layout, many rows | Defer off-screen child creation; use **inside** a `ScrollView`. |
| `LazyVGrid`/`LazyHGrid` (iOS 14) | Grids of many cells | Same deferral for grids. |
| `ForEach(_, id:)` (iOS 13) | Any collection | Use `Identifiable` with a stable `id`; never the array index or a fresh `UUID()` per render. |
| `.id(_:)` (iOS 13) | Force/break identity | Use deliberately; a changing `.id` recreates the subtree. |

```swift
ScrollView {
  LazyVStack(spacing: 12) {
    ForEach(model.rows) { RowView(row: $0) }   // row: Identifiable, stable id
  }
}
```

Per-item `@Observable` models give the most precise invalidation in a list — toggling one row re-evaluates only that row, not the whole list:

```swift
@Observable final class Item { var title: String; var done = false; init(_ t: String) { title = t } }

struct ItemRow: View {
  @Bindable var item: Item                       // body reads only this item
  var body: some View { Toggle(item.title, isOn: $item.done) }
}
struct ItemList: View {
  let items: [Item]
  var body: some View { List(items) { ItemRow(item: $0) } }
}
```

Never wrap a `List` in a `ScrollView` — `List` already scrolls and is lazy; nesting them double-scrolls and breaks layout. (iOS 27 pre-GA adds reorderable container APIs for drag-to-rearrange across `List`/`LazyVGrid` — pre-GA, verify final names.)

For images, downsample to the displayed size rather than loading full-resolution assets into many cells; oversized decodes are a common scroll-hitch source.

## Launch time & field telemetry (MetricKit)

Launch time is dominated by work done before first draw: minimize work in your `App`/`@main` init, scene setup, and root `body`. Use a SwiftUI launch screen (the old `UIApplication` launch images / launch storyboards are deprecated) and defer non-essential setup to after first frame.

MetricKit (since iOS 13; diagnostics iOS 14) gives **aggregated, privacy-safe field data** from real users — delivered at most ~once per 24h, never in real time. Subscribe via `MXMetricManager.shared`:

```swift
import MetricKit
final class Metrics: NSObject, MXMetricManagerSubscriber {
  func start() { MXMetricManager.shared.add(self) }
  func didReceive(_ payloads: [MXMetricPayload]) {
    for p in payloads {
      let launch = p.applicationLaunchMetrics?.histogrammedTimeToFirstDraw
      let hangs  = p.applicationResponsivenessMetrics?.histogrammedApplicationHangTime
      // forward aggregated histograms to your backend
    }
  }
}
```

Key payloads: `applicationLaunchMetrics` (time-to-first-draw), `applicationResponsivenessMetrics` (hang time), `animationMetrics` (hitches), `applicationExitMetrics`, plus `MXSignpost`-based custom timing (`mxSignpost`, iOS 15+). Diagnostics (`MXDiagnosticPayload`) include `MXCrashDiagnostic`, `MXHangDiagnostic`, `MXDiskWriteExceptionDiagnostic`. MetricKit is for trends, not live debugging — pair it with Instruments for reproduction. See `concurrency-and-networking.md` for keeping work off the main actor (long `@MainActor` work causes hangs >250ms and animation hitches).

## Profiling with Instruments 26

Instruments 26 (ships with Xcode 26) redesigned the **SwiftUI instrument**: an **Update Groups** lane that bundles related view updates, and a **Cause & Effect Graph** that traces interaction → state change → `body` update so you can see *why* a view re-evaluated. The SwiftUI template bundles Time Profiler, Hangs, and Hitches to find long or unnecessary updates. Profile a Release build on a real device — Simulator timing is not representative.

(iOS 27 / Xcode 27 pre-GA: Instruments adds Top Functions mode, Run Comparisons for regression-vs-baseline, and a Swift executors instrument visualizing Main Actor / global / custom executors — pre-GA, secondary-sourced.)

## Privacy manifest (PrivacyInfo.xcprivacy)

`PrivacyInfo.xcprivacy` (a property-list resource, since iOS 17) declares your app's privacy posture. It has exactly four top-level keys:

| Key | Type | Purpose |
|---|---|---|
| `NSPrivacyTracking` | Bool | Whether the app tracks per Apple's definition. |
| `NSPrivacyTrackingDomains` | [String] | Domains used for tracking (blocked at runtime unless ATT-authorized). |
| `NSPrivacyCollectedDataTypes` | [Dict] | Data types collected — feeds the App Privacy nutrition label. |
| `NSPrivacyAccessedAPITypes` | [Dict] | Required-reason API declarations with approved reason codes. |

**Be precise about which of these is an automated upload gate — they are not the same:**

- **Required-reason APIs (`NSPrivacyAccessedAPITypes`) — HARD automated upload gate since May 1, 2024.** Use one of the five gated API categories without a declared, approved reason code and App Store Connect **rejects the upload** automatically. This covers your code *and* every third-party SDK (each SDK must ship its own manifest, and Apple supports signatures for SDKs + their manifests for supply-chain integrity).
- **Tracking domains (`NSPrivacyTracking` / `NSPrivacyTrackingDomains`) — runtime + review enforced, NOT an automated upload gate.** Listed tracking domains are blocked at runtime unless the user grants ATT; mismatches are caught in review and at runtime, not by an upload validator.

The five required-reason API category constants are exactly (note: **no `APIs` suffix**):

`NSPrivacyAccessedAPICategoryFileTimestamp`, `NSPrivacyAccessedAPICategorySystemBootTime`, `NSPrivacyAccessedAPICategoryDiskSpace`, `NSPrivacyAccessedAPICategoryActiveKeyboards`, `NSPrivacyAccessedAPICategoryUserDefaults`.

Each declares an array of approved reason codes. Common ones: **UserDefaults** — `CA92.1` (app-only access), `1C8F.1` (App Group), `C56D.1` (third-party SDK wrapper), `AC6B.1` (MDM managed config). **Disk space** — `85F4.1` (display to user), `E174.1` (check free space before write), `7D9E.1` (bug report), `B728.1` (health research). **Boot time** — `35F9.1`, `8FFB.1`, `3D61.1`. **File timestamp** — `DDA9.1`, `C617.1`, `3B52.1`, `0A2A.1`. **Active keyboards** — `3EC4.1`, `54BD.1`.

```xml
<!-- PrivacyInfo.xcprivacy: app reads/writes app-only UserDefaults -->
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

A wrong category spelling is silently ineffective (the validator doesn't recognize it), so the gated API still triggers a rejection — copy the exact constant.

## App Privacy nutrition label & ATT

The **App Privacy nutrition label** is configured in App Store Connect (informed by your `NSPrivacyCollectedDataTypes` declarations). You must declare **all** data you or your third-party partners collect — including data used only for app functionality — unless it meets every optional-disclosure criterion. Under-declaring is a common rejection and a trust problem.

**App Tracking Transparency** (`AppTrackingTransparency`, since iOS 14.5): you must call `ATTrackingManager.requestTrackingAuthorization(...)` and be authorized before any cross-app tracking or reading a non-zero IDFA. The system prompt shows only when status is `.notDetermined`. Requires `NSUserTrackingUsageDescription` in Info.plist, plus `NSPrivacyTracking = true` and listed tracking domains in the manifest, or the tracking connections are blocked.

```swift
import AppTrackingTransparency
import AdSupport

func requestATT() async {
  let status = await ATTrackingManager.requestTrackingAuthorization()
  guard status == .authorized else { return }
  let idfa = ASIdentifierManager.shared().advertisingIdentifier  // zeroed unless authorized
}
```

## Building & uploading (the iOS 26 SDK mandate)

**Hard rule (enforced since April 28, 2026):** every binary uploaded to App Store Connect must be built with **Xcode 26 or later** against an **iOS 26 SDK** (and the equivalent 26 SDK for other platforms). A non-compliant upload is rejected with **ITMS-90725**. (Current shipping toolchain: Xcode 26.5, Swift 6.3.2.)

Building against the iOS 26 SDK is independent of your **deployment target** — you still choose the minimum OS you support. But building with the 26 SDK **opts native chrome into Liquid Glass by default** (nav bars, tab bars, toolbars, sheets change appearance on rebuild). Always run a visual QA pass after first building with Xcode 26 — don't assume the chrome looks identical. See `liquid-glass.md` and `project-setup.md`.

Other gates: by Jan 31, 2026 developers had to complete the updated **age-rating questionnaire** in App Store Connect (the new rating system surfaces on OS 26 devices). Bitcode is fully gone — the App Store hasn't accepted bitcode since Xcode 14; never enable `ENABLE_BITCODE`.

## App thinning & icons

App thinning still happens automatically via **App Slicing** (the App Store delivers per-device variants from your universal binary + asset catalog) and **On-Demand Resources** (tagged assets downloaded at runtime, kept out of the initial download). You enable slicing simply by using asset catalogs and device-qualified resources.

App icons now use **Icon Composer** (ships with Xcode 26), producing a single layered `.icon` file that renders all platforms/sizes and the default / dark / tinted / clear Liquid Glass appearance variants. Add the `.icon` directly to the Xcode project — it replaces the old multi-PNG icon asset set. Provide layered artwork so the system can apply Liquid Glass material and the tinted/clear modes correctly.

## TestFlight, review & EU distribution

- **Signing:** let Xcode manage automatic signing for most apps; you need an Apple Developer Program membership and the app's bundle ID registered. Distribution uses an App Store distribution certificate + provisioning profile (handled automatically when signing is automatic).
- **TestFlight:** upload a build to App Store Connect, then distribute to internal testers (up to 100, immediate) or external testers (requires a lightweight Beta App Review). Builds expire after 90 days.
- **Screenshots:** required per device size class in App Store Connect; keep them current with the Liquid Glass UI.
- **Review essentials:** complete + accurate metadata, no placeholder content, working demo account if login is required, no private APIs, declared privacy/permissions matching actual behavior, and a privacy nutrition label that matches your manifest.
- **CI/CD:** **Xcode Cloud** (Apple-hosted, integrates with App Store Connect) or **fastlane** automate build → test → TestFlight/App Store upload.
- **EU alternative distribution (DMA):** distributing outside the App Store (alternative marketplaces via **MarketplaceKit**, or web distribution) requires **Notarization** — Apple's baseline integrity/malware check, distinct from App Review. Apple announced transitioning the per-install **Core Technology Fee (CTF)** to a revenue-based **Core Technology Commission (CTC)** around Jan 1, 2026, but exact terms were still in flux with the European Commission as of early 2026 — confirm current numbers at developer.apple.com/support/dma-and-apps-in-the-eu before relying on them.

See `testing-and-debugging.md` for Swift Testing (`@Test`/`#expect`/`#require`, GA since Xcode 16 (2024) — not new in Xcode 26 — and the default for new unit tests; XCUITest and performance tests stay in XCTest).

## Pitfalls

- **iOS 26 SDK mandate:** any upload after 2026-04-28 not built with Xcode 26 + iOS 26 SDK is rejected (ITMS-90725).
- **Liquid Glass on rebuild:** building with the iOS 26 SDK silently changes native chrome to Liquid Glass — always do a visual QA pass; don't assume it looks the same.
- **Required-reason API gate:** using UserDefaults, file timestamps, system boot time, disk space, or active-keyboard APIs without the matching category + approved reason code in `PrivacyInfo.xcprivacy` is an automatic upload rejection.
- **Wrong category constant spelling** (it's `...UserDefaults` / `...FileTimestamp` / `...SystemBootTime` / `...DiskSpace` / `...ActiveKeyboards`, no `APIs` suffix) is silently ineffective — the gated API still triggers rejection.
- **Third-party SDKs need their own manifest.** Your app manifest does not cover them; a missing manifest or signature on an SDK can block submission.
- **Conflating the gates:** required-reason APIs are an automated *upload* gate; tracking domains are *runtime + review* enforced, not an upload validator — don't expect either to behave like the other.
- **Under-declaring the nutrition label:** you must declare all collected data, including app-functionality-only data, unless it meets every optional-disclosure criterion.
- **Whole-screen re-renders** from putting all state on one shared `ObservableObject` — migrate to per-item `@Observable` for granular invalidation.
- **`List` inside `ScrollView`** double-scrolls and breaks layout — use `LazyVStack` in a `ScrollView`, or `List` alone.
- **Unstable `ForEach` IDs** (array index or a fresh `UUID()` each render) cause view recreation, lost scroll position, and wrong animations.
- **Work in `body`/`init`** runs on every re-evaluation — move it to `.task`/`.onAppear` or cache it on the model.
- **Missing `NSUserTrackingUsageDescription`** or absent `NSPrivacyTracking`/tracking domains: the ATT prompt won't show and tracking connections get blocked.
- **Treating MetricKit as live data:** payloads are delayed ~24h and aggregated — use Instruments for live profiling.
- **`drawingGroup()` on simple views** adds an offscreen Metal pass and hurts; reserve it for genuinely expensive composited subtrees.
- **Long main-thread work** causes hangs (>250ms) and animation hitches — keep `@MainActor` work minimal, push computation off-main.

## Primary sources

- Upcoming Requirements (iOS 26 SDK mandate, age rating, EU dates): https://developer.apple.com/news/upcoming-requirements/
- Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Describing use of required reason API: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Migrating from ObservableObject to the Observable macro: https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro
- Optimize SwiftUI performance with Instruments (WWDC25 306): https://developer.apple.com/videos/play/wwdc2025/306/
- MetricKit: https://developer.apple.com/documentation/MetricKit
- App Privacy Details (nutrition label): https://developer.apple.com/app-store/app-privacy-details/
- Icon Composer: https://developer.apple.com/icon-composer/
- Apps distributed in the EU (DMA, notarization, CTF/CTC): https://developer.apple.com/support/dma-and-apps-in-the-eu/
