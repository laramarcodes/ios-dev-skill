# DOMAIN: SwiftUI State Management & the Observation framework (iOS 26 shipping / iOS 27 pre-GA)

## Orientation
 In modern SwiftUI (iOS 17+, and the default for any new app on iOS 26), the Observation framework's @Observable macro is THE way to model reference-type state. It replaces the Combine-based ObservableObject/@Published/@EnvironmentObject stack. The key win is access-tracked, pull-based invalidation: a view re-renders only when a property it actually read in `body` changes, instead of any @Published change firing every observer. The data-flow story collapses toward a lean "MV" (Model–View) shape: @Observable model objects hold state and logic, views read them via @State (owning), @Environment (injected/shared), and @Bindable (to make Bindings), and dependency injection runs through the SwiftUI environment. View models are optional, not mandatory — Apple's own guidance steers away from reflexive MVVM. Swift 6.2 (shipping alongside iOS 26, Sept 2025) layers in "approachable concurrency": SwiftUI Views are @MainActor, new projects can default-isolate to @MainActor, and the new `Observations` AsyncSequence lets you observe model changes transactionally outside a view. Custom environment keys are now one-liners via the @Entry macro, and previews use @Previewable to host @State inline.

## Key facts
- [since iOS 17|high] @Observable is a macro on classes (not structs) from the Observation framework; it auto-synthesizes per-property change tracking so SwiftUI re-renders a view only when a property that view actually read changes. This is the default for new SwiftUI state in iOS 26.
- [since iOS 17|high] With @Observable you do NOT mark properties @Published — all stored properties are tracked by default. Use @ObservationIgnored to opt a property out of tracking.
- [since iOS 17|high] Migration mapping: ObservableObject class -> @Observable class; @StateObject -> @State; @ObservedObject -> plain property or @Bindable; @EnvironmentObject / .environmentObject() -> @Environment / .environment(); @Published -> nothing (remove it).
- [since iOS 17|high] @Bindable creates two-way Bindings to properties of an @Observable class (e.g. $model.name). @Binding is for value types / non-Observable. With @Observable you no longer need @ObservedObject to get bindings; @Bindable is the bridge.
- [since iOS 17|high] Granularity: invalidation cost shifts from (views observing the object x any property change) under ObservableObject, to (views that read a SPECIFIC property x that property's change frequency) under @Observable — a major performance improvement.
- [since Xcode 16 / iOS 18 SDK; back-deploys to iOS 13 when built with Xcode 16+|high] @Entry macro generates the EnvironmentKey + computed property for custom environment values in one line: `extension EnvironmentValues { @Entry var myValue: T = default }`. Also works for TransactionValues, ContainerValues, and FocusedValues.
- [since Xcode 16|high] @Previewable lets a dynamic property (@State, @Binding, @FocusState, @GestureState) be declared inline inside a #Preview body, removing the old wrapper-view boilerplate. Back-deploys to iOS 17.
- [iOS 26 / Swift 6.2|high] Swift 6.2 (Sept 15, 2025, ships with iOS 26) adds the `Observations` AsyncSequence: `Observations { model.someProperty }` emits a new value whenever read properties change, with transactional snapshots (boundaries align with await suspension points), avoiding redundant updates. Use it to observe @Observable models OUTSIDE a SwiftUI view.
- [since iOS 17|high] withObservationTracking(_:onChange:) is the low-level manual observation primitive: it tracks the @Observable properties READ inside the apply closure and calls onChange ONCE when one of them is about to change. For continuous observation you re-arm it (recursive call). onChange has willSet timing — the property still holds its OLD value when onChange fires.
- [since iOS 18 SDK|high] SwiftUI's View protocol is @MainActor (since the iOS 18 SDK), so view bodies and most view-attached code are main-actor isolated automatically.
- [iOS 26 / Swift 6.2|high] Swift 6.2 'approachable concurrency': new projects can opt into default main-actor isolation (`-default-isolation MainActor`, or `.defaultIsolation(MainActor.self)` in Package.swift). Then @Observable UI models are main-actor isolated by default, while background services are explicitly marked `nonisolated`.
- [iOS 26|medium] Apple's own data-flow guidance favors a lean Model-View shape: @Observable model objects + SwiftUI's built-in state/environment, with view models used only where they earn their keep (not reflexively as in classic MVVM).

## APIs
- `@Observable` (macro; iOS 17+) — Attach to a class to synthesize observation. Default for model objects.
- `Observable` (protocol; iOS 17+) — Protocol the macro conforms your type to; rarely written by hand.
- `@ObservationIgnored` (macro/attribute; iOS 17+) — Excludes a stored property from observation tracking.
- `@ObservationTracked` (macro/attribute; iOS 17+) — Marks a property as tracked; normally applied automatically by @Observable, seldom written explicitly.
- `withObservationTracking(_:onChange:)` (function; iOS 17+) — Manual single-fire observation. onChange has willSet timing; re-arm for continuous observation.
- `Observations` (struct (AsyncSequence); iOS 26 / Swift 6.2) — `Observations { ... }` builds an AsyncSequence emitting transactional snapshots when read properties change. Capture [weak self] to avoid retain cycles.
- `@State` (property wrapper; iOS 17+ (Observable support)) — Owns/holds an @Observable model instance (replaces @StateObject).
- `@Bindable` (property wrapper; iOS 17+) — Makes $-bindings into an @Observable object's properties.
- `@Binding` (property wrapper; since iOS 13) — Two-way binding for value types / non-Observable; not interchangeable with @Bindable.
- `@Environment` (property wrapper; iOS 17+ (Observable support)) — Reads injected @Observable objects or keyed values from the environment (replaces @EnvironmentObject).
- `.environment(_:)` (modifier; iOS 17+) — Injects an @Observable object or sets a custom key (replaces .environmentObject).
- `@Entry` (macro; Xcode 16+, back-deploys to iOS 13) — One-line custom EnvironmentValues / FocusedValues / TransactionValues / ContainerValues key.
- `@Previewable` (macro; Xcode 16+, back-deploys to iOS 17) — Allows @State and other dynamic properties inline inside #Preview.
- `@AppStorage` (property wrapper; since iOS 14) — Binds a view property to UserDefaults; survives launches.
- `@SceneStorage` (property wrapper; since iOS 14) — Per-scene state restoration storage; scoped to a scene, not global like @AppStorage.
- `EnvironmentValues` (struct; since iOS 13) — Container extended via @Entry for custom keys.
- `@MainActor` (global actor / attribute; since iOS 13 (concurrency)) — View protocol is @MainActor; Swift 6.2 can default-isolate whole modules to it.
- `nonisolated` (declaration modifier; Swift concurrency) — Opt model helpers/services out of default main-actor isolation.
- `ObservableObject` (protocol (legacy); since iOS 13) — Combine-based; superseded by @Observable. Still valid but not the default.
- `@Published` (property wrapper (legacy); since iOS 13) — Pairs with ObservableObject; NOT used with @Observable — remove on migration.

## Patterns

### Define an @Observable model  — Any reference-type app/screen state. Replaces an ObservableObject + @Published class.
No @Published. All stored props are tracked unless marked @ObservationIgnored. Make it `final` for performance.
```swift
@Observable
final class TripModel {
    var name = ""
    var stops: [Stop] = []
    @ObservationIgnored var cache: [String: Data] = [:]  // not tracked
}
```

### Own, inject, and bind a model  — Sharing one model across a view subtree with two-way editing.
@State owns; @Environment injects; @Bindable (often a local `@Bindable var` inside body) turns it into Bindings. You only need @Bindable where you actually create a $-binding.
```swift
struct RootView: View {
    @State private var model = TripModel()   // owns it (was @StateObject)
    var body: some View {
        DetailView().environment(model)       // inject
    }
}

struct DetailView: View {
    @Environment(TripModel.self) private var model   // read injected
    var body: some View {
        @Bindable var model = model                  // local @Bindable to bind
        TextField("Name", text: $model.name)
    }
}
```

### Custom environment value via @Entry  — Passing config/services down the tree without prop-drilling.
@Entry replaces the old EnvironmentKey struct + computed-property boilerplate. The default value goes right after the declaration.
```swift
extension EnvironmentValues {
    @Entry var theme: Theme = .light
}
// set:  .environment(\.theme, .dark)
// read: @Environment(\.theme) private var theme
```

### Observe a model outside a view (Swift 6.2 Observations)  — Reacting to model changes in a service/controller, logging, or driving non-UI side effects.
iOS 26 / Swift 6.2 only. Transactional: you get a consistent snapshot per await boundary. Use [weak self]/[weak model] — Observations retains its closure and can create a retain cycle.
```swift
let titles = Observations { [weak model] in
    model?.name ?? ""
}
for await title in titles {
    print("changed to:", title)
}
```

### @State inside a preview with @Previewable  — Previewing a view that needs live, mutable state or a binding.
Drop the old wrapper-container hack. Works with @State, @Binding, @FocusState, @GestureState.
```swift
#Preview {
    @Previewable @State var count = 0
    CounterView(count: $count)
}
```

### Main-actor model + nonisolated helper (Swift 6.2)  — UI state that's main-actor isolated but with pure helpers that needn't hop actors.
With default main-actor isolation enabled, UI models are @MainActor automatically; mark pure/background helpers `nonisolated` so callers don't pay an actor hop.
```swift
@Observable
@MainActor
final class ProfileModel {
    var username = ""
    nonisolated func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
```

## Pitfalls
- Using @Bindable and @Binding interchangeably: @Bindable is for @Observable CLASS instances; @Binding is for value types passed down. Wrong one won't give you the binding you expect.
- Reaching for @ObservedObject / @StateObject / @EnvironmentObject with an @Observable type — those are the legacy ObservableObject wrappers. With @Observable use @State (own), @Environment (inject), @Bindable (bind).
- Leaving @Published on properties after migrating to @Observable — it's unnecessary and conceptually wrong (no Combine publisher is involved).
- Over-coarse observation: if a view reads a whole model object or a computed property that touches many fields, it re-renders on more changes than needed. Read only the specific properties a view needs in its body to get fine-grained invalidation.
- withObservationTracking fires onChange only ONCE and with willSet timing (old value still present). Forgetting to re-arm it gives you a single notification; expecting the new value in onChange is a classic bug — read it asynchronously after the change instead.
- Retain cycles with Observations { } (and withObservationTracking closures): the framework retains the closure, so capturing self strongly leaks. Use [weak self].
- Putting an @Observable model in @State but recreating it on each render — @State initializes once, but passing a freshly-constructed model as a parameter every time defeats it. Own it with @State at the right level.
- Marking heavy/background work on a default-main-actor-isolated @Observable model without `nonisolated`, forcing it onto the main thread.
- @Entry's default value is required and is the value used when no ancestor sets the key — omitting/misplacing it changes semantics.
- Assuming @Observable works on structs — it's class-only; value semantics use plain @State.

## iOS 26 changes
- Swift 6.2 (ships with iOS 26) introduces the `Observations` AsyncSequence for transactional, snapshot-consistent observation of @Observable models outside SwiftUI views.
- Approachable concurrency: new projects can default-isolate to @MainActor (`-default-isolation MainActor` / `.defaultIsolation(MainActor.self)`), making @Observable UI models main-actor isolated by default and pushing explicit `nonisolated` for background helpers.
- nonisolated async functions run on the caller's actor by default (NonisolatedNonsendingByDefault), simplifying how model methods interact with main-actor views.

## iOS 27 preview (pre-GA)
- No state-management/Observation API changes confirmed yet for iOS 27 from primary sources at time of research (WWDC 2026 week of June 8). The @Observable / Observation model is expected to remain the idiom; treat any iOS 27 specifics as unverified until Apple docs/session transcripts confirm. | Pre-GA; not yet corroborated by an Apple primary source for iOS 27 specifically. Verify against WWDC 2026 session pages and the iOS 27 release notes before relying on it.

## Deprecations
- ObservableObject + @Published is superseded by @Observable (still compiles, but not the default for new code).
- @StateObject is replaced by @State for @Observable models.
- @ObservedObject is replaced by a plain stored property (or @Bindable when you need bindings).
- @EnvironmentObject / .environmentObject(_:) is replaced by @Environment(Type.self) / .environment(_:).
- Hand-written EnvironmentKey structs + EnvironmentValues computed properties are replaced by the @Entry macro.
- Wrapper container views to host @State in previews are replaced by @Previewable.

## Uncertainties
- Could not load the full body of Apple's 'Migrating from the Observable Object protocol to the Observable macro' page (JS-rendered; returned title only). Migration mappings above are corroborated by Hacking with Swift / Donny Wals but the exact verbatim Apple code samples were not captured — re-scrape with firecrawl before quoting Apple verbatim.
- Exact initializer signatures/overloads of the `Observations` type (e.g. any `untilFinished`/error-throwing variants) were not confirmed from Apple's reference; only the `Observations { }` trailing-closure form is verified via Swift.org + secondary sources.
- Whether iOS 27 (pre-GA) adds anything to Observation/state-management is unverified — no primary WWDC 2026 source confirmed changes in this domain during research.
- Precise iOS-version gating of the `Observations` type (assumed iOS 26 with Swift 6.2 runtime) was inferred from the Swift 6.2 release timing, not read off an Apple availability annotation.

## Sources
- Apple Docs — Observation framework reference: https://developer.apple.com/documentation/Observation
- Apple Docs — Migrating from the Observable Object protocol to the Observable macro: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
- Apple Docs — Previewable(): https://developer.apple.com/documentation/SwiftUI/Previewable()
- Swift.org — Swift 6.2 Released (Observations, default actor isolation): https://www.swift.org/blog/swift-6.2-released/
- Hacking with Swift — Sharing @Observable objects through the environment: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
- Hacking with Swift — @State inside previews with @Previewable: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-state-inside-swiftui-previews-using-previewable
- Donny Wals — @Observable in SwiftUI explained: https://www.donnywals.com/observable-in-swiftui-explained/
- Donny Wals — Using Observations to observe @Observable model properties: https://www.donnywals.com/using-observations-to-observe-observable-model-properties/
- Donny Wals — Adding values to the SwiftUI environment with @Entry: https://www.donnywals.com/adding-values-to-the-swiftui-environment-with-entry/
- SwiftLee — @Entry macro: custom environment values: https://www.avanderlee.com/swiftui/entry-macro-custom-environment-values/
- SwiftLee — Default Actor Isolation in Swift 6.2: https://www.avanderlee.com/concurrency/default-actor-isolation-in-swift-6-2/
- SwiftLee — @Observable macro performance vs ObservableObject: https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/
- SwiftLee — @Previewable macro usage: https://www.avanderlee.com/swiftui/previewable-macro-usage-in-previews/
- Fatbobman — A Deep Dive Into Observation (granularity, withObservationTracking): https://fatbobman.com/en/posts/mastering-observation/
- Fatbobman — SwiftUI Views and @MainActor: https://fatbobman.com/en/posts/swiftui-views-and-mainactor/
- Use Your Loaf — Swift Observations AsyncSequence for State Changes: https://useyourloaf.com/blog/swift-observations-asyncsequence-for-state-changes/
- Michael Tsai — Swift 6.2: Observations: https://mjtsai.com/blog/2025/10/31/swift-6-2-observations/
