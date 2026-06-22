# Testing, Previews & debugging

How to write tests, preview UI, and diagnose problems in a modern iOS 26 app. Swift Testing is the default unit-test framework; XCTest survives only for UI automation and performance; previews, logging, and Instruments are how you see what your code is actually doing.

**Contents**
- [Swift Testing vs XCTest](#swift-testing-vs-xctest)
- [Writing tests with @Test / #expect / #require](#writing-tests-with-test--expect--require)
- [Suites & lifecycle](#suites--lifecycle)
- [Traits, tags & parameterization](#traits-tags--parameterization)
- [Errors & async events](#errors--async-events)
- [Known issues & imperative failures](#known-issues--imperative-failures)
- [What stays in XCTest](#what-stays-in-xctest)
- [Xcode Previews](#xcode-previews)
- [#Playground (Xcode 26+)](#playground-xcode-26)
- [Debugging: _printChanges, Logger, Instruments](#debugging-_printchanges-logger-instruments)
- [iOS 27 / Xcode 27 (pre-GA)](#ios-27--xcode-27-pre-ga)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## Swift Testing vs XCTest

**Swift Testing** is GA and the recommended unit-test framework since Xcode 16 (2024, Swift 6 toolchain) — it is **not** new in Xcode 26, it simply remains the default here. It ships bundled with Xcode — no package dependency — and is macro-driven, async-native, and **parallel by default**. Write new tests here.

The mental shift from XCTest: no `XCTestCase` subclass, no `test`-prefixed method names, no `XCTAssert*` family. Tests are plain `@Test` functions; assertions are plain Swift expressions inside `#expect`/`#require`; configuration moves from class hierarchy and naming convention to composable **traits**.

| XCTest (legacy) | Swift Testing (modern) |
|---|---|
| `class FooTests: XCTestCase` | `@Suite struct FooTests` (or just free `@Test` funcs) |
| `func testAdd()` | `@Test func add()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTUnwrap(x)` | `try #require(x)` |
| `XCTFail("msg")` | `Issue.record("msg")` |
| `setUp` / `tearDown` | `init()` / `deinit` (per-test instance) |
| `XCTSkip` / `XCTSkipIf` | `.enabled(if:)` / `.disabled(_:)` traits |
| `XCTestExpectation` + `wait(for:)` | `await confirmation(expectedCount:)` or just `async`/`await` |

They **coexist in the same target, even the same file** — you do not migrate everything at once.

## Writing tests with @Test / #expect / #require

The two assertion macros differ in one critical way: `#expect` **records and continues** (soft assertion — the test keeps running, and on failure it captures and prints the sub-expression operand values); `#require` **halts the test** on failure and additionally unwraps optionals. Use `#require` whenever later code depends on the assertion holding.

```swift
import Testing
@testable import MyApp

@Suite("Cart")
struct CartTests {
    let cart = Cart()  // fresh instance per test — see lifecycle below

    @Test("adding increases count")
    func add() {
        cart.add(.banana)
        #expect(cart.items.count == 1)   // continues even if it fails
    }

    @Test("checkout needs an item")
    func checkout() throws {
        let first = try #require(cart.items.first)  // halts here if nil
        #expect(first.price > 0)
    }
}
```

Why `#expect` continues: you often want to see *all* failing assertions in one run, not stop at the first. Reach for `try #require` precisely when continuing would crash or produce noise — it replaces XCTest's `continueAfterFailure = false`.

## Suites & lifecycle

A `@Suite` groups related tests and can carry traits that apply to every test inside it. A suite type can be a `struct`, `final class`, or `actor`. The `@Suite` attribute is optional — a type containing `@Test` methods is treated as an implicit suite — but naming it gives a readable label and a place to hang traits.

Lifecycle is per-test and isolated: Swift Testing creates **a fresh suite instance for each test**, so stored properties are your "set up". `init()` (or `init() async throws`) runs before each test; `deinit` runs after. There is no shared mutable state between tests unless you deliberately introduce it.

```swift
@Suite("Database", .serialized)   // opt out of parallelism for this suite
struct DatabaseTests {
    let db: Database
    init() async throws { db = try await Database.temporary() }  // before each
    deinit { db.close() }                                        // after each
}
```

## Traits, tags & parameterization

Traits configure a `@Test` or `@Suite` declaratively. The common ones (all since Xcode 16):

| Trait | Purpose |
|---|---|
| `.tags(_:)` | Tag for filtering/grouping in the Test Navigator |
| `.enabled(if:)` / `.disabled(_:)` | Conditionally run/skip (replaces `XCTSkip`) |
| `.bug(_:)` | Link a tracker URL/identifier |
| `.timeLimit(_:)` | Fail if the test exceeds a duration |
| `.serialized` | Run children sequentially instead of in parallel |

Tags are declared once via an extension:

```swift
extension Tag { @Tag static var pricing: Self }
```

**Parameterized tests** run the same body across many inputs via `arguments:`. Each element produces a *separate* child test in the navigator, and children run **in parallel**. One collection iterates it; two collections produce the full **cross-product**; wrap in `zip(a, b)` to pair them sequentially.

```swift
@Test("discount math", .tags(.pricing), .timeLimit(.minutes(1)),
      arguments: zip([100, 200], [90, 180]))   // (100→90), (200→180)
func discount(input: Int, expected: Int) {
    #expect(applyDiscount(input) == expected)
}

@Test(.enabled(if: AppFeatures.couponsEnabled), .bug("https://tracker/123"))
func couponFlow() async throws { /* ... */ }
```

## Errors & async events

Async testing needs no `XCTestExpectation` — mark the test `async` and `await` directly. Error assertions are first-class:

```swift
#expect(throws: PaymentError.self)            { try charge(-1) }   // any of that type
#expect(throws: PaymentError.declined)        { try charge(-1) }   // a specific case
#expect(throws: Never.self)                   { try charge(10) }   // must NOT throw
try #require(throws: PaymentError.self)       { try charge(-1) }   // halting variant
```

For "did this callback fire N times", use `confirmation` — but note it is **not** a general wait-until primitive. It verifies an event happened an expected number of times within the block (default `expectedCount` is 1; pass a range for at-least/at-most). An unmet count fails the test.

```swift
@Test func emitsThreeEvents() async {
    await confirmation(expectedCount: 3) { confirm in
        let stream = EventEmitter()
        stream.onEvent = { _ in confirm() }
        await stream.runThreeTimes()
    }
}
```

For genuine "wait until ready" semantics (e.g. polling state), use Swift Concurrency directly (`await someAsyncCondition()`), not `confirmation`. See `concurrency-and-networking.md` for testing async code.

## Known issues & imperative failures

`withKnownIssue { }` marks a block whose failure is *expected* (a known bug) so it doesn't fail the suite but is tracked and will flag if it unexpectedly starts passing. Pass `isIntermittent: true` for flaky ones. `Issue.record(_:)` imperatively records a failure — the equivalent of `XCTFail`.

```swift
@Test func parserHandlesEdgeCase() {
    withKnownIssue("fails until #432 lands") {
        #expect(parse("weird") == .ok)
    }
}
```

## What stays in XCTest

Swift Testing **cannot** do two things, so these remain XCTest-only (current as of iOS 26 / Xcode 26):

- **UI automation** — `XCUIApplication`, taps, `waitForExistence`.
- **Performance measurement** — `XCTMetric` and `measure { }`.

Accessibility auditing in UI tests uses `XCUIApplication.performAccessibilityAudit(for:_:)` (since Xcode 15) with `XCUIAccessibilityAuditType` options (`.contrast`, `.dynamicType`, `.elementDetection`, …); it throws if it finds issues. See `design-and-accessibility.md`.

```swift
import XCTest

final class FlowUITests: XCTestCase {
    func testOnboarding() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Get Started"].tap()
        XCTAssert(app.staticTexts["Welcome"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit()   // throws on a11y issues
    }
}
```

## Xcode Previews

Previews are macro-based since Xcode 16. The deprecated form is the `PreviewProvider` struct with a `previews` property — do not write that for new code; use `#Preview`.

- **`#Preview`** — declares a preview; takes an optional name and traits.
- **`@Previewable`** (Xcode 16+) — inline `@State`/dynamic properties *directly inside* the `#Preview` body, removing the wrapper-view boilerplate previously needed to preview interactive views.
- **`PreviewModifier`** (Xcode 16 / iOS 18) — a protocol for reusable, **cached** preview environments. Implement `static makeSharedContext() async throws -> Context` and `body(content:context:)`; Xcode caches the context across all previews using the same modifier, so e.g. one in-memory `ModelContainer` is built once.
- **`PreviewTrait`** — configures the preview environment (color scheme, accessibility, device/layout) passed as a trait argument.

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
    @Previewable @State var on = false   // inline state, no wrapper view
    Toggle("Flag", isOn: $on)
}
```

See `data-persistence.md` for the in-memory `ModelContainer` pattern and `swiftui-views.md` for view composition.

## #Playground (Xcode 26+)

The `#Playground` macro (Xcode 26, `import Playgrounds`) runs Swift code inline in **any** `.swift` file with live results in the Canvas — no separate playground file, no project, no build artifacts. Each `#Playground` is state-isolated. Ideal for a quick algorithm check sitting right next to the real code.

```swift
import Playgrounds

#Playground {
    let total = applyDiscount(200)
    total            // live result renders in the Canvas
}
```

This supersedes the old standalone `.playground` files for quick experiments. SwiftUI views inside a `#Playground` can have framing quirks — give them an explicit frame if they render oddly.

## Debugging: _printChanges, Logger, Instruments

**Why did this view re-render?** Call `Self._printChanges()` inside a SwiftUI view's `body`; it prints which `@State`/`@Binding`/observed dependency triggered the re-evaluation. It is the fastest way to find unnecessary body re-runs. It is an underscored/SPI API and a debug diagnostic — **never ship it** in release code.

**Structured logging** beats `print`. Use `os.Logger` (`import os`) — it is the recommended API since iOS 14 and supersedes the older `os_log`. Define one `Logger` per subsystem/category. Levels: `.debug` (verbose), `.notice` (lifecycle), `.error` (user-visible failures). **Interpolated values are redacted (`<private>`) by default** — you must opt in with `privacy: .public`, and only for non-sensitive fields.

```swift
import os
let log = Logger(subsystem: "com.app.cart", category: "checkout")

struct Row: View {
    var body: some View {
        let _ = Self._printChanges()   // debug only — names the changed dependency
        Text(item.name)
            .onAppear { log.notice("shown id=\(item.id, privacy: .public)") }
    }
}
```

**Instruments** for deeper profiling: the **SwiftUI** instrument (view body/update cost), **Time Profiler** (CPU hot paths), **Allocations** (memory), **Hangs** (main-thread stalls), and **Animation Hitches** (dropped frames). Profile on a real device, not the simulator — frame timing in the simulator is not representative. See `performance-and-shipping.md`.

## iOS 27 / Xcode 27 (pre-GA)

The following are WWDC-2026 developer-beta material, shipping fall 2026 — **labels/signatures may change before GA**:

- **Cross-framework interop modes** for XCTest issues inside Swift Testing tests: `limited` (warnings; default for pre-Xcode-27 test plans), `complete` (errors; default for new Xcode 27 projects), `strict` (fatal at the call), `none`. Configure in Test Plan ▸ Test Execution or via `SWIFT_TESTING_XCTEST_INTEROP_MODE`.
- **Exit tests**: `#expect(processExitsWith: .failure) { … }` runs the body in a child process to test crashing code (`fatalError`/`precondition`). macOS/Linux/FreeBSD/Windows — not iOS device.
- **`Test.cancel(_:)`** imperatively skips a running test (declarative `.enabled(if:)` remains preferred).
- **Live Previews** gain interactive resize handles; standalone `.swift` files support previews + playground results with no project.
- **Instruments** adds a **Top Functions** view; the Animation Hitches metric expands to cover Liquid Glass and SwiftUI animations; a new **Storage** metric. Xcode Cloud streamlines parallel unit+UI test runs across devices/OS/Xcode versions.
- Xcode 27 ships built-in coding-agent integrations that can assist migrating XCTest → Swift Testing.

## Pitfalls

- **Trying to migrate UI or performance tests to Swift Testing.** `XCUIApplication` and `XCTMetric`/`measure` are unsupported there — they stay in XCTest.
- **In-memory `ModelContainer` helper that returns only `mainContext`.** The `ModelContext` does **not** keep its `ModelContainer` alive — return (and hold) the *container*, then read `container.mainContext`. Returning a bare context lets the container deallocate mid-test and **crashes** on the next fetch/insert. (`let config = ModelConfiguration(isStoredInMemoryOnly: true); let container = try ModelContainer(for: Item.self, configurations: config)` — keep `container` in scope.)
- **Using `#Predicate` in a test target without `import Foundation`.** `#Predicate` is a Foundation macro; app code usually gets it transitively via `import SwiftUI`, but a test target importing only `Testing`/`SwiftData` sees *no macro named 'Predicate'*. Add `import Foundation`.
- **SwiftData tests crashing because the host app launches.** Hosted unit tests run the app's `@main`, so its on-disk `ModelContainer(for:)` + seeding execute (and log CoreData store noise). Keep tests on isolated in-memory containers; don't assert against the app's shared store.
- **Treating `confirmation()` as wait-until-ready.** It only verifies an event fired an expected count; an unmet count fails. Use plain `async`/`await` for polling.
- **Forgetting tests run in PARALLEL by default.** Parameterized children and sibling tests run concurrently; shared mutable state causes flakiness. Add `.serialized` or isolate state.
- **Assuming `#expect` halts the test.** It records and continues. Use `try #require` when later code depends on the assertion.
- **Logging sensitive data and expecting to read it.** `Logger` redacts interpolated values to `<private>` by default; opt in with `privacy: .public` only for non-sensitive fields.
- **Shipping `Self._printChanges()`.** It is a debug-only SPI with overhead — strip it before release.
- **`#Playground` without `import Playgrounds`.** Required (Xcode 26+); SwiftUI views inside may need explicit framing.
- **Writing `PreviewProvider`.** Deprecated — use `#Preview` with `@Previewable`/`PreviewModifier`.
- **Cross-framework assertions in Xcode 27.** The interop mode decides whether an XCTest issue inside a Swift Testing test is a warning, error, or fatal; new Xcode 27 projects default to `complete` (errors).

## Primary sources

- Swift Testing (Xcode): https://developer.apple.com/xcode/swift-testing/
- swift-testing on GitHub: https://github.com/swiftlang/swift-testing
- Migrating a test from XCTest: https://developer.apple.com/documentation/testing/migratingfromxctest
- PreviewModifier: https://developer.apple.com/documentation/SwiftUI/PreviewModifier
- Previews in Xcode: https://developer.apple.com/documentation/swiftui/previews-in-xcode
- Migrate to Swift Testing (WWDC26 session 267): https://developer.apple.com/videos/play/wwdc2026/267/
- What's new in Xcode 27 (WWDC26 session 258): https://developer.apple.com/videos/play/wwdc2026/258/
