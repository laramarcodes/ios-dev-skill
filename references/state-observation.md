# State management & the Observation framework

How modern SwiftUI models, owns, shares, and observes state. The `@Observable` macro (Observation framework, iOS 17+) is THE idiom on iOS 26 — it replaces the Combine-based `ObservableObject`/`@Published` stack with access-tracked, pull-based invalidation: a view re-renders only when a property it *actually read* in `body` changes. Get this layer right and the rest of the app (data flow, performance, previews) falls into place.

**Contents**
- [The mental model: own / inject / bind](#the-mental-model-own--inject--bind)
- [@Observable models](#observable-models)
- [The property-wrapper toolkit](#the-property-wrapper-toolkit)
- [Custom environment values with @Entry](#custom-environment-values-with-entry)
- [Persisted state: @AppStorage & @SceneStorage](#persisted-state-appstorage--scenestorage)
- [Previews with @Previewable](#previews-with-previewable)
- [Observing models outside a view](#observing-models-outside-a-view)
- [Concurrency: @MainActor isolation (Swift 6.2)](#concurrency-mainactor-isolation-swift-62)
- [Migration mapping](#migration-mapping)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## The mental model: own / inject / bind

Modern SwiftUI collapses toward a lean **Model–View (MV)** shape, not reflexive MVVM. `@Observable` reference types hold state and logic; views consume them through three roles. View models are optional — reach for one only where it earns its keep (heavy formatting, testable orchestration), not by default. Three verbs cover almost everything:

| Role | Wrapper | Use |
|---|---|---|
| **Own** a model (creates/holds it for the view's lifetime) | `@State` | `@State private var model = TripModel()` |
| **Inject** / read a shared model from the environment | `@Environment` | `@Environment(TripModel.self) private var model` |
| **Bind** to a model's property (two-way `$`) | `@Bindable` | `@Bindable var model = model` then `$model.name` |

Value-type state (`Int`, `Bool`, a struct) still uses `@State` to own and `@Binding` to pass an editable reference down. See `app-structure.md` for where in the scene/window tree to place owners, and `swiftui-views.md` for how `body` re-evaluation works.

## @Observable models

`@Observable` (macro, iOS 17+) attaches to a **class** — it is class-only; structs use plain `@State` value semantics. Every stored property is tracked automatically; there is **no `@Published`** (and adding it is wrong — no Combine publisher exists). Opt a property out of tracking with `@ObservationIgnored`. Mark the class `final` for performance.

```swift
import Observation

@Observable
final class TripModel {
    var name = ""
    var stops: [Stop] = []
    @ObservationIgnored var cache: [String: Data] = [:]   // not tracked
}
```

The performance win is granularity. Under the legacy `ObservableObject`, *any* `@Published` change invalidated *every* view observing the object. Under `@Observable`, invalidation cost is (views that read a **specific** property) × (that property's change frequency). To get fine-grained updates, **read only the properties a view needs** in its `body` — reading the whole object or a fat computed property that touches many fields re-renders too often.

### Own, inject, and bind together

```swift
struct RootView: View {
    @State private var model = TripModel()        // owns it (was @StateObject)
    var body: some View {
        DetailView().environment(model)            // inject into subtree
    }
}

struct DetailView: View {
    @Environment(TripModel.self) private var model // read injected
    var body: some View {
        @Bindable var model = model                // local @Bindable to make bindings
        TextField("Name", text: $model.name)
    }
}
```

`@Bindable` is only needed where you actually create a `$`-binding. A common idiom is the local `@Bindable var model = model` inside `body`, shadowing the `@Environment` copy just long enough to bind. When the model is a *stored property* passed in (not from the environment), declare it `@Bindable var model: TripModel` directly.

## The property-wrapper toolkit

| Wrapper | Since | Purpose |
|---|---|---|
| `@State` | iOS 17 (Observable support) | Owns an `@Observable` instance or value-type state; initialized once. Replaces `@StateObject`. |
| `@Environment` | iOS 17 (Observable support) | Reads an injected `@Observable` object **or** a keyed value. Replaces `@EnvironmentObject`. |
| `@Bindable` | iOS 17 | Makes `$`-bindings into an `@Observable` object's properties. |
| `@Binding` | iOS 13 | Two-way binding to **value-type** state owned elsewhere. NOT interchangeable with `@Bindable`. |
| `@ObservationIgnored` | iOS 17 | Excludes a stored property from tracking. |
| `@AppStorage` | iOS 14 | Binds a property to `UserDefaults`; survives launches. |
| `@SceneStorage` | iOS 14 | Per-scene state-restoration storage; scoped to one scene. |

`@Bindable` vs `@Binding` is the most common mix-up: `@Bindable` is for `@Observable` **class** instances (reference types); `@Binding` is for **value** types handed down from an owner. They are not substitutes.

## Custom environment values with @Entry

`@Entry` (macro, Xcode 16+, **back-deploys to iOS 13**) generates the `EnvironmentKey` conformance plus the computed property in one line — replacing the old hand-written `EnvironmentKey` struct + `EnvironmentValues` extension boilerplate. The default value goes right after the declaration and is **required** (it's the value used when no ancestor sets the key).

```swift
extension EnvironmentValues {
    @Entry var theme: Theme = .light
}

// set:  ContentView().environment(\.theme, .dark)
// read: @Environment(\.theme) private var theme
```

`@Entry` also works for `FocusedValues`, `TransactionValues`, and `ContainerValues`. Use `@Entry` for config/services you want to pass down without prop-drilling; use `.environment(model)` (no key path) to inject an `@Observable` object by type.

## Persisted state: @AppStorage & @SceneStorage

`@AppStorage` (iOS 14) is a `UserDefaults`-backed binding — global, survives relaunch. Good for user preferences (a theme toggle, a sort order). `@SceneStorage` (iOS 14) is scoped to a single scene and exists for **state restoration** — the selected tab or scroll position of *this* window, restored when the system relaunches it. Don't use `@SceneStorage` for shared app data; don't put large or sensitive data in either (UserDefaults is plain-text — secrets go in Keychain, see `data-persistence.md`).

```swift
struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false      // global preference
    @SceneStorage("selectedTab") private var selectedTab = "home" // per-window restoration
    var body: some View {
        Toggle("Dark Mode", isOn: $isDarkMode)
    }
}
```

## Previews with @Previewable

`@Previewable` (macro, Xcode 16+, back-deploys to iOS 17) lets a dynamic property — `@State`, `@Binding`, `@FocusState`, `@GestureState` — be declared **inline** inside a `#Preview`, removing the old wrapper-view boilerplate that existed only to host state.

```swift
#Preview {
    @Previewable @State var count = 0
    CounterView(count: $count)
}
```

## Observing models outside a view

For driving non-UI side effects (logging, syncing, a controller reacting to model changes) you need observation outside `body`. Two tools:

**`Observations` AsyncSequence (iOS 26 / Swift 6.2).** `Observations { ... }` builds an `AsyncSequence` that emits a new value whenever a read property changes, with **transactional snapshots** — boundaries align with `await` suspension points, so you get a consistent value per iteration and avoid redundant emissions. This is the modern way to bridge model changes into async code.

```swift
let titles = Observations { [weak model] in
    model?.name ?? ""
}
for await title in titles {
    print("changed to:", title)
}
```

**`withObservationTracking(_:onChange:)` (iOS 17+)** is the low-level primitive `Observations` is built on. It tracks the properties read inside `apply` and calls `onChange` **once**, with **`willSet` timing** — the property still holds its OLD value when `onChange` fires. For continuous observation you must **re-arm** it (recursively). Prefer `Observations` on iOS 26; reach for `withObservationTracking` only when you need the manual single-shot hook or must support iOS 17–18.

> Both retain their closures. Capture `[weak self]` / `[weak model]` or you leak.

## Concurrency: @MainActor isolation (Swift 6.2)

SwiftUI's `View` protocol is `@MainActor` (since the iOS 18 SDK), so view bodies and view-attached code are main-actor isolated automatically. Swift 6.2 (ships with iOS 26, Sept 2025; current toolchain is Swift 6.3.2 / Xcode 26.5) delivers the **approachable concurrency** initiative through **two separate Xcode build settings** that are easy to conflate:

- **Approachable Concurrency** (`SWIFT_APPROACHABLE_CONCURRENCY`) — turns on a bundle of upcoming features, most notably `nonisolated(nonsending)` by default (a `nonisolated async` function runs on the caller's actor/executor instead of hopping to the global concurrent executor). Apple recommends enabling it on **every** target.
- **Default Actor Isolation** (`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, compiler flag `-default-isolation MainActor`, or `.defaultIsolation(MainActor.self)` in `Package.swift`) — implicitly isolates the whole module to the main actor unless code is marked otherwise. New Xcode 26 app targets default to `MainActor`; existing/migrated targets and non-UI library targets default to `nonisolated`.

With Default Actor Isolation set to `MainActor`, `@Observable` UI models are `@MainActor` by default, and you explicitly mark pure/background helpers `nonisolated` so callers don't pay an actor hop.

```swift
@Observable
@MainActor
final class ProfileModel {
    var username = ""
    nonisolated func normalized(_ s: String) -> String {     // no actor hop
        s.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
```

In Swift 6.2, `nonisolated async` functions run on the **caller's** actor by default (the `NonisolatedNonsendingByDefault` behavior), which smooths how model methods interact with main-actor views — fewer surprise hops, fewer `Sendable` errors. See `concurrency-and-networking.md` for the full concurrency model and `project-setup.md` for enabling default isolation.

## Migration mapping

Moving a Combine `ObservableObject` to `@Observable`:

| Legacy (`ObservableObject`) | Modern (`@Observable`) |
|---|---|
| `class M: ObservableObject` | `@Observable final class M` |
| `@Published var x` | `var x` (remove `@Published` entirely) |
| `@StateObject var m = M()` | `@State private var m = M()` |
| `@ObservedObject var m` | plain `var m: M` (or `@Bindable var m` when you need bindings) |
| `@EnvironmentObject var m` | `@Environment(M.self) private var m` |
| `.environmentObject(m)` | `.environment(m)` |
| hand-written `EnvironmentKey` + extension | `@Entry var key: T = default` |
| wrapper view to host `@State` in a preview | `@Previewable @State` inline |

For new unit tests of model logic, prefer **Swift Testing** (`@Test`, `#expect`) over XCTest — see `testing-and-debugging.md`.

## Pitfalls

- **`@Bindable` vs `@Binding` confusion.** `@Bindable` → `@Observable` class instances; `@Binding` → value types. The wrong one won't give the binding you expect.
- **Using legacy wrappers with `@Observable`.** `@StateObject` / `@ObservedObject` / `@EnvironmentObject` are the `ObservableObject` wrappers. With `@Observable` use `@State` / plain property or `@Bindable` / `@Environment`.
- **Leaving `@Published` after migrating** — unnecessary and conceptually wrong; remove it.
- **Over-coarse observation.** Reading a whole model object, or a computed property that touches many fields, re-renders on more changes than needed. Read only the specific properties `body` uses.
- **`withObservationTracking` fires once, with `willSet` timing.** Forgetting to re-arm gives a single notification; expecting the *new* value inside `onChange` is a classic bug — read it asynchronously after the change.
- **Retain cycles** with `Observations { }` and `withObservationTracking` closures — the framework retains the closure. Capture `[weak self]`.
- **Recreating an `@Observable` model on every render.** `@State` initializes once, but passing a freshly-constructed model as a *parameter* each render defeats that. Own it with `@State` at the right level in the tree.
- **Heavy work on a default-main-actor model without `nonisolated`** forces it onto the main thread and can hitch the UI.
- **`@Entry`'s default value is required** and is the fallback when no ancestor sets the key — omitting or misplacing it changes semantics.
- **Assuming `@Observable` works on structs** — it's class-only. Value semantics use plain `@State`.
- **`@SceneStorage` for shared data** — it's per-scene restoration only; cross-scene/global data belongs in `@AppStorage` or a shared `@Observable` model.

> **iOS 27 (pre-GA, ships fall 2026):** No state-management or Observation API changes were confirmed from Apple primary sources at WWDC 2026. The `@Observable` / Observation model is expected to remain the idiom. Treat any iOS 27 specifics as unverified until the release notes and session transcripts confirm them.

## Primary sources

- Observation framework reference — https://developer.apple.com/documentation/Observation
- Migrating from the Observable Object protocol to the Observable macro — https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
- `Previewable()` — https://developer.apple.com/documentation/SwiftUI/Previewable()
- Swift 6.2 Released (Observations, default actor isolation) — https://www.swift.org/blog/swift-6.2-released/
- Sharing `@Observable` objects through the environment (Hacking with Swift) — https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
- A Deep Dive Into Observation (Fatbobman) — https://fatbobman.com/en/posts/mastering-observation/
- Swift Observations AsyncSequence for State Changes (Use Your Loaf) — https://useyourloaf.com/blog/swift-observations-asyncsequence-for-state-changes/
