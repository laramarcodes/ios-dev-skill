# DOMAIN: SwiftUI iOS/iPad app development — Testing, Previews & Debugging (Swift Testing, Xcode Previews, Instruments, logging, playgrounds)

## Orientation
 As of mid-2026, Swift Testing is the GA, recommended unit-testing framework — macro-driven (@Test, #expect, #require, @Suite), async-native, parallel-by-default, and configured via composable traits rather than XCTest's class hierarchies and naming conventions. XCTest is now legacy but still required for the two things Swift Testing does not cover: UI automation (XCUIApplication) and performance measurement (XCTMetric/measure). The two frameworks coexist in one target — even one file — and Xcode 27 adds explicit cross-framework interop modes (limited/complete/strict/none) to manage incremental migration. Xcode Previews are macro-based (#Preview) with @Previewable for inline @State, PreviewModifier for cached/shared environments, and PreviewTrait for environment config; Xcode 27 adds resize handles to live previews and previews/playground results in standalone Swift files. Debugging modern SwiftUI leans on Self._printChanges() (why a view re-rendered), the unified os.Logger API, the #Playground macro for inline live evaluation (Xcode 26+), and Instruments tools including the SwiftUI instrument, Time Profiler, Allocations, Hangs/Animation Hitches, and the new Top Functions view. Version-qualify carefully: confirm shipping-in-iOS-26/Xcode-26 vs announced-for-Xcode-27 (pre-GA).

## Key facts
- [since Xcode 16 / iOS 18 (GA)|high] Swift Testing is GA and the recommended unit-test framework; ships with the Swift 6 toolchain and is bundled with Xcode (16+), no package dependency needed.
- [since Xcode 16 (GA)|high] The core macros are @Test (declares a test function — no 'test' prefix or base class needed), #expect (soft assertion that captures sub-expression values on failure), #require (throwing assertion that halts the test on failure / unwraps optionals), and @Suite (groups tests; any struct, final class, or actor).
- [since Xcode 16 (GA)|high] Traits configure tests/suites: .tags(_:), .enabled(if:), .disabled(_:), .bug(_:), .timeLimit(_:), and .serialized (opt out of parallel execution). Tags are declared via 'extension Tag { @Tag static var name: Self }'.
- [since Xcode 16 (GA)|high] Parameterized tests use @Test(arguments:). One collection runs one child test per element; two collections run the full cross-product; wrap in zip(a,b) to pair sequentially. Children run in parallel by default and each appears separately in the Test Navigator.
- [since Xcode 16 (GA)|high] Error assertions: #expect(throws: ErrorType.self){...}, #expect(throws: SpecificError.case){...}, #expect(throws: Never.self){...}, and the closure form #expect(performing:throws:) for custom matching. try #require(throws:) is the requiring variant.
- [since Xcode 16 (GA)|high] confirmation(expectedCount:_:) is the async-event primitive: it confirms an event fired an expected number of times within a block (default expectedCount is 1). It is NOT a general 'wait-until' like XCTestExpectation — use it to assert a callback/closure was invoked.
- [since Xcode 16 (GA)|high] withKnownIssue { } marks expected/known failures (isIntermittent: true for flaky ones) so they don't fail the suite but are tracked. Issue.record(_:) records a failure imperatively (the Swift Testing equivalent of XCTFail).
- [since Xcode 16 (GA)|high] Suite lifecycle uses init()/init() async throws (runs before each test, replacing setUp) and deinit (runs after each test, replacing tearDown); instances are created per-test so tests are isolated.
- [current (iOS 26 / Xcode 26)|high] UI automation (XCUIApplication) and performance tests (XCTMetric / measure) CANNOT be migrated to Swift Testing and remain XCTest-only. Swift Testing and XCTest coexist in the same target and even the same file.
- [since Xcode 15 (XCTest)|high] Accessibility auditing in UI tests uses XCUIApplication.performAccessibilityAudit(for:_:) with XCUIAccessibilityAuditType options (e.g. .contrast, .dynamicType, .elementDetection); throws if issues are found.
- [since Xcode 16|high] Xcode Previews are declared with the #Preview macro. @Previewable lets you inline @State/dynamic properties directly inside the #Preview body (Xcode 16+), removing wrapper-view boilerplate.
- [since Xcode 16 / iOS 18|high] PreviewModifier is a protocol for reusable/shared preview environments: implement static makeSharedContext() async throws -> Context and body(content:context:). Xcode caches the context across previews sharing the same modifier, giving a performance boost (e.g. one shared in-memory model container).
- [since Xcode 16|medium] PreviewTrait configures the preview environment (color scheme, accessibility, localization, device/layout) and is passed as a trait argument to #Preview.
- [since Xcode 26|high] The #Playground macro (Xcode 26, requires 'import Playgrounds') runs Swift code inline in any .swift file with live results rendered in the Canvas — no project, no build artifacts; each #Playground is state-isolated.
- [current|medium] Self._printChanges() (call inside a SwiftUI view's body) prints which @State/@Binding/observed dependency triggered a re-render — the primary tool for diagnosing unnecessary SwiftUI body re-evaluations.
- [since iOS 14, current best practice|high] Structured logging: prefer os.Logger (import os) over print and over the older os_log API on iOS 14+. Define one Logger per subsystem/category; use levels .debug/.notice/.error; control redaction with privacy interpolation (.public / .private, default is private/redacted).
- [Top Functions/expanded metrics = Xcode 27 (pre-GA)|medium] Instruments includes the SwiftUI instrument (view body/update cost), Time Profiler, Allocations, Hangs, and the Animation Hitches instrument. Xcode 27 adds a Top Functions view (fastest path to the most expensive code) and an Animation Hitches metric expanded to cover Liquid Glass and SwiftUI animations, plus a Storage metric.

## Patterns

### Basic Swift Testing suite with #expect / #require  — Writing modern unit tests for any model/logic type.
#expect keeps running after a failure and shows captured operand values; #require halts the test (use to unwrap optionals or guard preconditions). No XCTestCase subclassing, no 'test' prefix.
```swift
import Testing
@testable import MyApp

@Suite("Cart")
struct CartTests {
    let cart = Cart()  // fresh instance per test

    @Test("adding increases count")
    func add() {
        cart.add(.banana)
        #expect(cart.items.count == 1)
    }

    @Test("checkout needs an item")
    func checkout() throws {
        let first = try #require(cart.items.first)  // halts if nil
        #expect(first.price > 0)
    }
}
```

### Parameterized test with tags, traits, and zip  — Running the same logic across many inputs; gating by condition; tagging for filtering.
arguments: a, b is the cross-product; zip(a,b) pairs them. Children run in parallel — add .serialized on the @Suite/@Test if order or shared state matters.
```swift
extension Tag { @Tag static var pricing: Self }

@Test("discount math", .tags(.pricing), .timeLimit(.minutes(1)),
      arguments: zip([100, 200], [90, 180]))
func discount(input: Int, expected: Int) {
    #expect(applyDiscount(input) == expected)
}

@Test(.enabled(if: AppFeatures.couponsEnabled),
      .bug("https://tracker/123"))
func couponFlow() async throws { /* ... */ }
```

### Async event verification with confirmation  — Asserting a callback/closure fired the expected number of times.
confirmation is for 'this happened N times', not 'wait until ready'. For unmet counts it fails. Default expectedCount is 1; pass a range for at-least/at-most semantics.
```swift
@Test func emitsThreeEvents() async {
    await confirmation(expectedCount: 3) { confirm in
        let stream = EventEmitter()
        stream.onEvent = { _ in confirm() }
        await stream.runThreeTimes()
    }
}
```

### XCTest UI test + accessibility audit (stays in XCTest)  — UI automation and accessibility checks — Swift Testing cannot do these.
Keep XCUIApplication, XCTMetric/measure, and performAccessibilityAudit in XCTest targets. They coexist with Swift Testing unit tests in the same scheme.
```swift
import XCTest

final class FlowUITests: XCTestCase {
    func testOnboarding() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Get Started"].tap()
        XCTAssert(app.staticTexts["Welcome"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit()  // throws on a11y issues
    }
}
```

### Preview with @Previewable state and a shared PreviewModifier  — Previewing interactive views or views needing a shared model container / sample data.
makeSharedContext is cached across previews using the same modifier (faster). @Previewable inlines @State without a wrapper view. Use PreviewTrait/.modifier(_:) to inject the environment.
```swift
struct SampleData: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let c = try ModelContainer(for: Item.self,
            configurations: .init(isStoredInMemoryOnly: true))
        c.mainContext.insert(Item(name: "Demo"))
        return c
    }
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

#Preview(traits: .modifier(SampleData())) {
    @Previewable @State var on = false
    Toggle("Flag", isOn: $on)
}
```

### Diagnose SwiftUI re-renders and log structured events  — A view redraws too often, or you need production-grade logging instead of print.
Self._printChanges() (debug only) names the changed dependency. Logger redacts interpolated values by default — mark .public only what's safe. Use .debug for detail, .notice for lifecycle, .error for user-visible failures.
```swift
import os
let log = Logger(subsystem: "com.app.cart", category: "checkout")

struct Row: View {
    var body: some View {
        let _ = Self._printChanges()   // prints what triggered re-render
        Text(item.name)
            .onAppear { log.notice("shown id=\(item.id, privacy: .public)") }
    }
}
```

### Inline experimentation with #Playground (Xcode 26+)  — Prototyping a function or snippet without a separate playground file/project.
Lives in any .swift file, state-isolated, no build artifacts. Great for quick algorithm checks next to the real code. Standalone-file previews/playground results expand further in Xcode 27.
```swift
import Playgrounds

#Playground {
    let total = applyDiscount(200)
    total            // live result shows in the Canvas
}
```

## Pitfalls
- Trying to migrate UI automation (XCUIApplication) or performance (XCTMetric/measure) tests to Swift Testing — these are not supported and must stay in XCTest.
- Treating confirmation() as a 'wait until ready' primitive — it only verifies an event fired an expected number of times; an unmet count fails the test.
- Forgetting that @Test parameterized children and sibling tests run in PARALLEL by default — shared mutable state across tests causes flakiness; add .serialized or isolate state.
- Assuming #expect halts the test — it does not (it records and continues); use #require / try when subsequent code depends on the assertion.
- Logging sensitive data with Logger and expecting to read it — interpolated values are redacted (<private>) by default; you must opt in with privacy: .public, and only for non-sensitive fields.
- Leaving Self._printChanges() in shipping code — it's a debug diagnostic, not a public API guarantee, and adds overhead.
- #Playground requires 'import Playgrounds' (Xcode 26+); SwiftUI views inside a #Playground have known quirks and may need explicit framing.
- Expecting cross-framework assertions to 'just work' silently — in Xcode 27 the interop mode (limited/complete/strict) determines whether an XCTest issue inside a Swift Testing test is a warning, error, or fatal; new Xcode 27 projects default to 'complete' (errors).

## iOS 26 changes
- #Playground macro (import Playgrounds) ships in Xcode 26 — inline, state-isolated live code evaluation in the Canvas from any .swift file.
- PreviewModifier (cached shared preview environments) and PreviewTrait are part of the current preview system used in Xcode 26.

## iOS 27 preview (pre-GA)
- Xcode 27 adds cross-framework test interop modes — limited (XCTest-in-Swift-Testing issues are warnings; default for pre-Xcode-27 test plans), complete (issues become errors; default for new Xcode 27 projects), strict (fatal errors at the cross-framework call), and none. Configure in Test Plan > Test Execution or via SWIFT_TESTING_XCTEST_INTEROP_MODE=strict. | Pre-GA developer beta; exact mode names/defaults may change before release.
- Exit tests: #expect(processExitsWith: .failure){...} runs the body in a child process to test code that crashes (fatalError/precondition). Supported on macOS, Linux, FreeBSD, Windows (not iOS device). | Pre-GA; platform support list may change.
- Test.cancel(_:) skips a running test imperatively (Swift Testing equivalent of XCTSkip); .enabled(if:_:) trait remains the preferred declarative skip. | Pre-GA API name.
- Live Previews gain interactive resize handles to test layout adaptivity without running on device; standalone Swift files support previews + playground results with no project. | Pre-GA.
- Instruments adds a Top Functions view; Animation Hitches metric expanded to Liquid Glass and SwiftUI animations; new Storage metric. Xcode Cloud onboarding streamlined with auto unit+UI tests in parallel across devices/OS/Xcode versions. | Pre-GA.
- Xcode 27 ships built-in coding-agent integrations (Claude, Gemini, OpenAI, plus local Foundation Models) that can assist migrating XCTest to Swift Testing. | Pre-GA; secondary source.

## Deprecations
- Old: XCTestCase subclasses with setUp/tearDown and test-prefixed methods. New: Swift Testing @Suite types with init()/deinit and @Test functions. (XCTest still required for UI & performance tests.)
- Old: XCTAssertEqual/XCTAssertTrue/XCTAssertNil family. New: #expect(...) with plain Swift expressions; #require(...) for halting/unwrapping.
- Old: XCTFail(...). New: Issue.record(...).
- Old: XCTSkip / XCTSkipIf. New: declarative .enabled(if:)/.disabled(_:) traits (preferred), or Test.cancel(...) imperatively (Xcode 27, pre-GA).
- Old: XCTestExpectation + wait(for:). New: confirmation(expectedCount:) for events; for general async, just mark the @Test async and await directly (Swift Concurrency).
- Old: continueAfterFailure = false. New: use try #require(...) — code after a failed requirement does not run.
- Old: print() debugging. New: os.Logger (import os); os_log is superseded by Logger on iOS 14+.
- Old: PreviewProvider struct with previews property. New: #Preview macro (with @Previewable, PreviewModifier, PreviewTrait).

## Uncertainties
- Exact Xcode 27 / Swift Testing API names for exit tests (#expect(processExitsWith:)) and Test.cancel are from a JS-rendered WWDC26 session summary and secondary sources — pre-GA, names/signatures may change before release.
- Whether the Xcode 27 interop default for new projects is precisely 'complete' vs 'strict', and the exact environment-variable name (SWIFT_TESTING_XCTEST_INTEROP_MODE shown in one summary), needs confirmation against final docs.
- Self._printChanges() is an underscored (private/SPI) API; could not confirm an official Apple documentation page — corroborated only via reputable secondary sources.
- The new Xcode 27 'Top Functions' Instruments view and expanded Animation Hitches/Storage metrics are from a WWDC26 session summary; exact instrument/template names not yet verified against shipping Instruments docs.
- PreviewTrait's exact current case names (e.g. for color scheme / size classes) were not fully enumerated from a primary Apple page in this pass.
- Did not separately verify the 'SwiftUI performance' and 'Processor Trace' Instruments tooling names mentioned in the task prompt against a primary source.

## Sources
- Swift Testing — Apple Developer (Xcode): https://developer.apple.com/xcode/swift-testing/
- swiftlang/swift-testing — GitHub: https://github.com/swiftlang/swift-testing
- Migrating a test from XCTest — Apple Developer Documentation: https://developer.apple.com/documentation/testing/migratingfromxctest
- Migrate to Swift Testing — WWDC26 session 267: https://developer.apple.com/videos/play/wwdc2026/267/
- What's new in Xcode 27 — WWDC26 session 258: https://developer.apple.com/videos/play/wwdc2026/258/
- PreviewModifier — Apple Developer Documentation: https://developer.apple.com/documentation/SwiftUI/PreviewModifier
- Previews in Xcode — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/previews-in-xcode
- Previewing your app's interface in Xcode — Apple Developer Documentation: https://developer.apple.com/documentation/xcode/previewing-your-apps-interface-in-xcode
- Mastering the Swift Testing Framework — Fatbobman: https://fatbobman.com/en/posts/mastering-the-swift-testing-framework/
- @Previewable: Dynamic SwiftUI Previews Made Easy — SwiftLee: https://www.avanderlee.com/swiftui/previewable-macro-usage-in-previews/
- Playground Macro: Running Code Snippets in Xcode's Canvas — SwiftLee: https://www.avanderlee.com/swift/playground-macro-running-code-snippets-in-xcodes-canvas/
- OSLog and Unified logging as recommended by Apple — SwiftLee: https://www.avanderlee.com/debugging/oslog-unified-logging/
- Testing your app's accessibility with UI Tests — Create with Swift: https://www.createwithswift.com/testing-your-apps-accessibility-ui-tests/
- The power of previews in Xcode — Swift with Majid: https://swiftwithmajid.com/2024/11/26/the-power-of-previews-in-xcode/
- WWDC26: What's New in Xcode 27 for Developers — Appcircle: https://appcircle.io/blog/wwdc26-whats-new-in-xcode-27-for-developers
