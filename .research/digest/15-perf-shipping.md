# DOMAIN: SwiftUI app performance, privacy compliance, and App Store shipping (iOS 26 shipping; iOS 27 / Xcode 27 pre-GA) — for iPhone & iPad

## Orientation
 As of June 2026, iOS 26 is the shipping release and iOS 27 / Xcode 27 are in developer beta (pre-GA). The single most important shipping fact: starting April 28, 2026, every App Store Connect upload must be built with Xcode 26 and an iOS 26 SDK — this is now enforced. Building against the iOS 26 SDK opts your app into Liquid Glass for native chrome by default (deployment target stays your choice). Performance work centers on the Observation framework (@Observable replacing ObservableObject) for precise per-property invalidation, keeping view bodies cheap and dependencies granular, using lazy containers and stable identity, and profiling with the redesigned SwiftUI instrument (Instruments 26) plus MetricKit field data. Privacy is gated on PrivacyInfo.xcprivacy: a privacy manifest declaring tracking, tracking domains, collected data types (which feed the App Privacy nutrition label), and required-reason API categories with approved reason codes — enforced for App Store acceptance. Modern testing has shifted from XCTest to Swift Testing (@Test/#expect), though XCUITest/performance tests remain in XCTest. Bitcode is fully gone; app thinning persists via App Slicing and On-Demand Resources.

## Key facts
- [iOS 26 (enforced 2026-04-28)|high] Starting April 28, 2026, apps and updates uploaded to App Store Connect must be built with Xcode 26 or later using an iOS 26 / iPadOS 26 / tvOS 26 / visionOS 26 / watchOS 26 SDK. Rejection error is ITMS-90725.
- [iOS 26|high] Building with the iOS 26 SDK does NOT change your minimum deployment target — you choose what OS versions your app supports independently of the SDK you build against.
- [iOS 26|high] Apps built with the iOS 26 SDK adopt the Liquid Glass design for native UI (navigation bars, tab bars, toolbars, sheets) by default; this is a visible behavior change on rebuild.
- [iOS 26 (deadline 2026-01-31)|high] By January 31, 2026 developers must answer the updated age-rating questionnaire in App Store Connect; the new age-rating system surfaces on OS 26 devices.
- [since iOS 17|high] Privacy manifest (PrivacyInfo.xcprivacy) has four top-level keys: NSPrivacyTracking (Bool), NSPrivacyTrackingDomains (array of tracking domains), NSPrivacyCollectedDataTypes (array), NSPrivacyAccessedAPITypes (array of required-reason API declarations).
- [since iOS 17 (enforced 2024-05-01)|high] Since May 1, 2024, App Store Connect rejects apps that use a required-reason API without declaring an approved reason in the privacy manifest (covers app code AND third-party SDKs; each SDK must ship its own manifest).
- [since iOS 17|high] The five required-reason API category constants are exactly: NSPrivacyAccessedAPICategoryFileTimestamp, NSPrivacyAccessedAPICategorySystemBootTime, NSPrivacyAccessedAPICategoryDiskSpace, NSPrivacyAccessedAPICategoryActiveKeyboards, NSPrivacyAccessedAPICategoryUserDefaults (note: no 'APIs' suffix).
- [since iOS 17|high] UserDefaults approved reason codes: CA92.1 (app-only access), 1C8F.1 (App Group access), C56D.1 (third-party SDK wrapper), AC6B.1 (MDM managed-config keys). Disk space: 85F4.1 (display to user), E174.1 (check free space before write), 7D9E.1 (bug report), B728.1 (health research). System boot time: 35F9.1, 8FFB.1, 3D61.1. File timestamp: DDA9.1, C617.1, 3B52.1, 0A2A.1. Active keyboards: 3EC4.1, 54BD.1.
- [since iOS 17|high] @Observable (Observation framework) tracks exactly which properties a view's body reads and invalidates only views depending on the changed property — strictly more precise than ObservableObject/objectWillChange, which can over-invalidate. @Observable is iOS 17+; use ObservableObject only when back-deploying earlier.
- [since iOS 14.5|high] App Tracking Transparency: call ATTrackingManager.requestTrackingAuthorization(completionHandler:) (prompt shows only when status == .notDetermined); requires NSUserTrackingUsageDescription in Info.plist. IDFA via ASIdentifierManager is zeroed unless authorized.
- [since Xcode 14|high] Bitcode is fully deprecated and the App Store has not accepted bitcode submissions since Xcode 14. App thinning continues via App Slicing (per-device variants) and On-Demand Resources (tagged, runtime-downloaded assets).
- [iOS 26 / Xcode 26|high] Icon Composer (ships with Xcode 26) produces a single layered .icon file rendering all platforms/sizes and the default/dark/tinted/clear Liquid Glass appearance variants; you add the .icon directly to the Xcode project instead of maintaining a PNG asset catalog set.
- [since iOS 13 (diagnostics iOS 14)|high] MetricKit delivers on-device performance/diagnostic reports (at most once per ~24h) via MXMetricManager.shared subscribers; payloads include applicationLaunchMetrics, applicationHangTimeMetric, animationMetrics (hitches), applicationExitMetrics, and MXSignpost-based custom metrics. Diagnostics include MXCrashDiagnostic, MXHangDiagnostic.
- [iOS 26 / Xcode 26|high] Instruments 26 ships a redesigned SwiftUI instrument with an 'Update Groups' lane and a Cause & Effect Graph tracing user interaction -> state change -> view body update; the SwiftUI template bundles Time Profiler, Hangs, and Hitches instruments to find long/unnecessary body updates.
- [since Xcode 16|high] Swift Testing (@Test, @Suite, #expect, #require) is the modern test framework (ships since Xcode 16); coexists with XCTest in the same target/file. UI automation (XCUIApplication) and performance tests (XCTMetric/measure) remain XCTest-only. WWDC25 added attachments and exit tests.
- [iOS 26 (EU only)|medium] EU/DMA: alternative distribution (alternative app marketplaces and web distribution) requires Notarization for iOS apps (baseline integrity/malware checks), distinct from App Review. Apple announced transitioning the per-install Core Technology Fee (CTF) to a revenue-based Core Technology Commission (CTC) around Jan 1, 2026; exact terms remained in flux with the European Commission as of early 2026.
- [current|high] The App Privacy nutrition label is configured in App Store Connect from NSPrivacyCollectedDataTypes-style declarations; you must declare ALL data you or third-party partners collect (even app-functionality-only data), unless it meets every optional-disclosure criterion. Apple now supports signatures for third-party SDKs plus their privacy manifests to improve supply-chain integrity.

## APIs
- `@Observable` (macro; iOS 17+) — Observation framework; per-property dependency tracking. Replaces ObservableObject for new code.
- `@ObservationTracked` (macro; iOS 17+) — Applied automatically by @Observable to stored properties; replaces @Published.
- `@ObservationIgnored` (macro; iOS 17+) — Exclude a property from observation tracking.
- `@State / @Bindable / @Environment` (property wrapper / macro; iOS 17+ (@Bindable)) — @Bindable creates bindings to @Observable objects; @State holds observable model (init-once, becomes a macro per WWDC26 pre-GA).
- `LazyVStack / LazyHStack / LazyVGrid / LazyHGrid` (type; since iOS 14) — Defer child view creation until visible; use inside ScrollView. Do not nest List in ScrollView (double scrolling).
- `List` (type; since iOS 13) — Already lazy and reuses rows (UICollectionView-backed); prefer for large datasets; use stable Identifiable IDs.
- `EquatableView / .equatable()` (type / modifier; since iOS 13) — Skip body re-eval when Equatable input is unchanged; for expensive subtrees (charts).
- `.id(_:)` (modifier; since iOS 13) — Explicit view identity; unstable IDs cause recreation, lost scroll position, broken animations.
- `ForEach(_, id:)` (type; since iOS 13) — Stable identity for collections; prefer Identifiable over positional/index IDs.
- `.drawingGroup(opaque:)` (modifier; since iOS 13) — Rasterize complex visual subtree into a Metal layer; opaque:true skips transparency handling.
- `.compositingGroup()` (modifier; since iOS 13) — Flatten a view's layers before applying effects/opacity.
- `NSPrivacyTracking / NSPrivacyTrackingDomains / NSPrivacyCollectedDataTypes / NSPrivacyAccessedAPITypes` (plist key; PrivacyInfo.xcprivacy, iOS 17+) — Four top-level privacy manifest keys.
- `NSPrivacyAccessedAPIType / NSPrivacyAccessedAPITypeReasons` (plist key; iOS 17+) — Per-category dict: category constant + array of approved reason codes.
- `NSPrivacyAccessedAPICategoryUserDefaults / FileTimestamp / SystemBootTime / DiskSpace / ActiveKeyboards` (plist value constant; iOS 17+) — Exact category constant strings (no 'APIs' suffix).
- `ATTrackingManager.requestTrackingAuthorization(completionHandler:)` (static method; since iOS 14.5) — Requires NSUserTrackingUsageDescription; prompt shows only when status == .notDetermined.
- `ATTrackingManager.trackingAuthorizationStatus` (property; since iOS 14) — Returns .notDetermined / .restricted / .denied / .authorized.
- `MXMetricManager` (class; since iOS 13) — MXMetricManager.shared.add(subscriber); MXMetricManagerSubscriber.didReceive([MXMetricPayload]).
- `MXMetricPayload / MXDiagnosticPayload` (class; since iOS 13 / 14) — applicationLaunchMetrics, applicationHangTimeMetric, animationMetrics, applicationExitMetrics; MXCrashDiagnostic, MXHangDiagnostic, MXDiskWriteExceptionDiagnostic.
- `mxSignpost / MXSignpost` (function; since iOS 15) — Aggregate custom timing into MetricKit payloads.
- `@Test / @Suite / #expect / #require` (macro; Swift Testing, Xcode 16+) — Modern test framework; coexists with XCTest. XCUITest & performance tests stay in XCTest.
- `@MainActor` (global actor; since iOS 13/Swift concurrency) — Keep UI/state mutations on main; off-main work via Task/async to avoid hangs.

## Patterns

### Granular @Observable models for precise invalidation  — A list where one item changing was redrawing the whole list under ObservableObject.
Per-item observable objects mean toggling one row invalidates only that row. With a shared [struct] array on one @Observable, mutating any element can re-eval the whole list.
```swift
@Observable final class Item { var title: String; var done: Bool; init(_ t:String){title=t;done=false} }
@Observable final class Store { var items: [Item] = [] }

struct ItemRow: View {
  @Bindable var item: Item   // body reads only this item's props
  var body: some View { Toggle(item.title, isOn: $item.done) }
}
struct ItemList: View {
  let store: Store
  var body: some View { List(store.items) { ItemRow(item: $0) } } // only the toggled row re-evaluates
}
```

### Equatable view to skip expensive subtree re-eval  — A chart/heavy subtree re-runs body even when its inputs didn't change.
Only worth it for genuinely expensive bodies with cheap, stable equality. Over-using Equatable on cheap views adds overhead.
```swift
struct PriceChart: View, Equatable {
  let points: [Double]
  static func == (l: PriceChart, r: PriceChart) -> Bool { l.points == r.points }
  var body: some View { /* expensive Canvas/Chart */ Canvas { ctx, size in /* ... */ } }
}
// usage: PriceChart(points: data).equatable()
```

### Lazy container with stable identity in a ScrollView  — Rendering thousands of rows; List styling isn't wanted.
LazyVStack defers off-screen view creation. Keep IDs stable (Identifiable) so SwiftUI reuses rather than recreates rows.
```swift
ScrollView {
  LazyVStack(spacing: 12) {
    ForEach(model.rows) { row in RowView(row: row) }  // row: Identifiable, stable id
  }
}
// Never wrap a List in a ScrollView — List is already lazy/scrolling.
```

### Privacy manifest declaring a required-reason API  — App reads/writes UserDefaults (app-only) — now a required-reason API.
Match each category constant with an approved reason code. App-only UserDefaults = CA92.1; App Group = 1C8F.1. Each third-party SDK must ship its own manifest.
```swift
<!-- PrivacyInfo.xcprivacy -->
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

### App Tracking Transparency request before any tracking/IDFA  — Using IDFA or any cross-app tracking; must prompt first.
Add NSUserTrackingUsageDescription to Info.plist. Also set NSPrivacyTracking=true and list tracking domains in the privacy manifest, or the system blocks the tracking connections.
```swift
import AppTrackingTransparency
import AdSupport
func requestATT() async {
  let status = await ATTrackingManager.requestTrackingAuthorization()
  guard status == .authorized else { return }
  let idfa = ASIdentifierManager.shared().advertisingIdentifier // zeroed unless authorized
}
```

### MetricKit field telemetry subscription  — Monitoring launch time, hangs, and hitches from real users.
Payloads arrive ~once/24h, aggregated and privacy-safe. Pair with Instruments 26 SwiftUI instrument for local reproduction of long body updates.
```swift
final class Metrics: NSObject, MXMetricManagerSubscriber {
  func start() { MXMetricManager.shared.add(self) }
  func didReceive(_ payloads: [MXMetricPayload]) {
    for p in payloads {
      let launch = p.applicationLaunchMetrics?.histogrammedTimeToFirstDraw
      let hangs = p.applicationResponsivenessMetrics?.histogrammedApplicationHangTime
      // upload aggregated data to backend
    }
  }
}
```

### Swift Testing instead of XCTest  — Writing new unit tests.
Use #require for preconditions that should stop the test. Keep XCUITest/performance tests in XCTest — Swift Testing doesn't cover them.
```swift
import Testing
@Suite struct CartTests {
  @Test func appliesDiscount() {
    let cart = Cart(items: [.init(price: 100)])
    #expect(cart.total(discount: 0.1) == 90)
  }
  @Test(arguments: [0, 1, 2]) func nonNegative(qty: Int) { #expect(qty >= 0) }
}
```

## Pitfalls
- Forgetting the iOS 26 SDK mandate: any upload after 2026-04-28 not built with Xcode 26 is rejected (ITMS-90725).
- Rebuilding with the iOS 26 SDK silently changes UI to Liquid Glass — ship a visual QA pass; don't assume chrome looks identical.
- Using UserDefaults, file timestamps, system boot time, disk space, or active-keyboard APIs without declaring the matching required-reason category + approved code in PrivacyInfo.xcprivacy = App Store Connect rejection.
- Using the wrong category constant spelling: it's NSPrivacyAccessedAPICategoryUserDefaults / ...FileTimestamp / ...SystemBootTime / ...DiskSpace / ...ActiveKeyboards (no 'APIs' suffix) — mismatches are silently ineffective.
- Each third-party SDK must include its OWN PrivacyInfo.xcprivacy; your app manifest does not cover them. Missing-manifest/missing-signature SDKs can block submission.
- Putting all UI state on one shared ObservableObject array causes whole-screen re-renders; migrate to per-item @Observable for granular invalidation.
- Nesting a List inside a ScrollView (double scrolling, broken layout) — use LazyVStack in ScrollView, or List alone.
- Unstable ForEach IDs (using array index or recomputed UUIDs each render) cause view recreation, lost scroll position, and wrong animations.
- Heavy work in view body or in init runs on every re-evaluation — move it to onAppear/task or cached model computations.
- Forgetting NSUserTrackingUsageDescription (ATT) or NSPrivacyTracking/tracking domains in the manifest — the prompt won't show or tracking connections get blocked.
- Assuming MetricKit gives real-time data — payloads are delayed ~24h and aggregated; use Instruments for live profiling.
- drawingGroup() on simple views can hurt (extra offscreen Metal pass); reserve it for genuinely expensive composited subtrees.
- Long main-thread work causes hangs (>250ms) and hitches; keep @MainActor work minimal and push computation off-main.

## iOS 26 changes
- Liquid Glass design language is applied by default to native UIKit/SwiftUI chrome when built with the iOS 26 SDK; verify nav/tab/toolbar/sheet appearance after rebuild.
- Icon Composer + single .icon file format replaces multi-PNG app icon asset sets; produces default/dark/tinted/clear variants.
- Redesigned SwiftUI instrument in Instruments 26 (Update Groups lane, Cause & Effect Graph) for diagnosing view body updates.
- Updated App Store age-rating system reflected on OS 26 devices; new questionnaire required by 2026-01-31.

## iOS 27 preview (pre-GA)
- @State becomes a macro so observable classes inside @State initialize only once (announced backported to iOS 17); compiler better type-checks complex view bodies; build-time and data-flow performance improvements. | Pre-GA (WWDC 2026 dev beta); secondary-sourced; API shape may change before GA.
- New reorderable container APIs allow drag-to-rearrange across List, LazyVGrid, and other containers with shared code. | Pre-GA; verify exact API names against final SDK.
- Instruments (Xcode 27) adds Top Functions mode, Run Comparisons (regression vs baseline), and a Swift executors instrument visualizing Main Actor / global / custom executors; improved memory & energy profiling. | Pre-GA; secondary-sourced.

## Deprecations
- ObservableObject + @Published + objectWillChange -> @Observable + @ObservationTracked (iOS 17+); old way over-invalidates views.
- XCTest (XCTAssert*) -> Swift Testing (@Test/#expect/#require) for unit tests; XCTest retained only for UI automation and performance tests.
- Bitcode fully removed — App Store hasn't accepted bitcode since Xcode 14; do not enable ENABLE_BITCODE.
- NavigationView -> NavigationStack / NavigationSplitView (since iOS 16).
- Multi-PNG app icon asset catalogs -> single Icon Composer .icon file (iOS 26 / Xcode 26) for Liquid Glass.
- UIApplication launch-image / old launch storyboards -> SwiftUI/launch screen config; minimize launch-time work to improve time-to-first-draw.
- Core Technology Fee (CTF, per-install, EU) -> Core Technology Commission (CTC, revenue-based) transition announced ~Jan 2026 (terms in flux).

## Uncertainties
- iOS 27 / Xcode 27 details (@State-as-macro, reorderable containers, Instruments Top Functions / Run Comparisons / Swift executors instrument) are pre-GA from WWDC 2026 and largely secondary-sourced; exact API names and behavior may change before GA — verify against the final SDK and Apple session pages.
- The exact current status of the EU Core Technology Fee -> Core Technology Commission transition (and per-install pricing/thresholds) was still being negotiated with the European Commission as of early 2026; confirm current terms on developer.apple.com/support/dma-and-apps-in-the-eu before relying on numbers.
- Did not separately verify the full current list of App Privacy nutrition-label data-type categories and the latest Accessibility Nutrition Labels requirements/deadline from primary App Store Connect help pages.
- Could not load the body of Apple's 'Understanding and improving SwiftUI performance' Xcode doc (WebFetch returned only the title); the SwiftUI performance specifics here are corroborated from the WWDC25 session 306 and reputable secondary sources rather than that exact page.

## Sources
- Upcoming Requirements — Apple Developer (iOS 26 SDK mandate, age rating, EU dates): https://developer.apple.com/news/upcoming-requirements/
- Privacy manifest files — Apple Developer Documentation: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Describing use of required reason API — Apple Developer Documentation: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- NSPrivacyAccessedAPIType — category constants & approved reason codes: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- Migrating from ObservableObject to the Observable macro — Apple Developer Documentation: https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro
- Optimize SwiftUI performance with Instruments — WWDC25 session 306: https://developer.apple.com/videos/play/wwdc2025/306/
- MetricKit — Apple Developer Documentation: https://developer.apple.com/documentation/MetricKit
- App Tracking Transparency — requestTrackingAuthorization: https://developer.apple.com/documentation/apptrackingtransparency/attrackingmanager/requesttrackingauthorization(completionhandler:)
- Swift Testing — Xcode / Apple Developer: https://developer.apple.com/xcode/swift-testing/
- Icon Composer — Apple Developer: https://developer.apple.com/icon-composer/
- App Privacy Details (nutrition label) — App Store / Apple Developer: https://developer.apple.com/app-store/app-privacy-details/
- Update on apps distributed in the EU (DMA, notarization, CTF/CTC) — Apple Developer Support: https://developer.apple.com/support/dma-and-apps-in-the-eu/
- Submit for Notarization — Managing alternative distribution — App Store Connect Help: https://developer.apple.com/help/app-store-connect/managing-alternative-distribution/submit-for-notarization/
- Xcode 14 Release Notes (bitcode deprecation): https://developer.apple.com/documentation/xcode-release-notes/xcode-14-release-notes
- Understanding and improving SwiftUI performance — Apple Developer Documentation: https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance
- WWDC26 SwiftUI guide — Apple Developer (pre-GA iOS 27): https://developer.apple.com/wwdc26/guides/swiftui/
- The iOS 26 SDK Deadline (Liquid Glass on rebuild) — Stora: https://stora.sh/blog/2026-04-01-ios-26-sdk-deadline-liquid-glass-ready
- WWDC26 What's New in SwiftUI breakdown — DEV (pre-GA, secondary): https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333
