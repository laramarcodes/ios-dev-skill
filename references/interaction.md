# Gestures, haptics, text input & search

SwiftUI's interaction layer is value-type and declarative: gesture structs compose with `simultaneously`/`sequenced`/`exclusively`, haptics are a one-line modifier, and text input drives focus and search through bindings. Get the composition and arbitration right and most "why doesn't my tap fire / why did scrolling stop" bugs disappear.

**Contents**
- [Gestures](#gestures)
- [Gesture composition & @GestureState](#gesture-composition--gesturestate)
- [Gesture vs scroll arbitration](#gesture-vs-scroll-arbitration)
- [Scroll-driven effects](#scroll-driven-effects)
- [Haptics](#haptics)
- [Context menus & menus](#context-menus--menus)
- [Text input & focus](#text-input--focus)
- [Rich-text editing (iOS 26)](#rich-text-editing-ios-26)
- [Search](#search)
- [iOS 27 (pre-GA)](#ios-27-pre-ga)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## Gestures

A gesture is a value type whose `Value` carries the recognized data. Attach with `.gesture(_:)`, `.simultaneousGesture(_:)`, or `.highPriorityGesture(_:)`. For simple taps/long-presses, the `onTapGesture`/`onLongPressGesture` convenience modifiers are fine; reach for the structs when you need composition, gesture state, or velocity.

| Gesture | Since | Value highlights |
|---|---|---|
| `TapGesture(count:)` | iOS 13 | none (fires on tap) |
| `SpatialTapGesture` | iOS 16 | `.location` — tap point in a coordinate space |
| `LongPressGesture(minimumDuration:maximumDistance:)` | iOS 13 | `Bool` (pressing) |
| `DragGesture(minimumDistance:coordinateSpace:)` | iOS 13 | `.translation`, `.location`, `.velocity`, `.predictedEndTranslation` |
| `MagnifyGesture` | iOS 17 | `.magnification`, `.velocity` |
| `RotateGesture` | iOS 17 | `.rotation` (an `Angle`), `.velocity` |
| `RotateGesture3D` | visionOS 1 | 3D rotation |

Modern idiom: use **`MagnifyGesture`** and **`RotateGesture`** — `MagnificationGesture`/`RotationGesture` still compile but are **deprecated since iOS 17** and expose a poorer `Value` (the new `RotateGesture.Value.rotation` is an `Angle`, not a bare `CGFloat`).

```swift
view.gesture(
    MagnifyGesture()
        .onChanged { scale = $0.magnification }
        .onEnded { _ in withAnimation { scale = 1 } }
)
```

## Gesture composition & @GestureState

Three combinators (instance methods, or the wrapper types `SimultaneousGesture`/`SequenceGesture`/`ExclusiveGesture`):

- **`.simultaneously(with:)`** — both recognize at once (pinch + rotate).
- **`.sequenced(before:)`** — the second only starts after the first recognizes (press-then-drag for reordering).
- **`.exclusively(before:)`** — only one wins (tap *or* drag, never both).

`@GestureState` (iOS 13) holds **transient** state that auto-resets to its initial value the instant the gesture ends or cancels. You mutate it **only** inside `.updating(_:body:)`. Use plain `@State` (set in `.onChanged`/`.onEnded`) for anything that must persist after the finger lifts — by the time `.onEnded` runs, the `@GestureState` is already back to its initial value.

```swift
@GestureState private var dragOffset: CGSize = .zero
@State private var position: CGSize = .zero

card
    .offset(x: position.width + dragOffset.width,
            y: position.height + dragOffset.height)
    .gesture(
        DragGesture()
            .updating($dragOffset) { value, state, _ in state = value.translation }
            .onEnded { value in position.width += value.translation.width
                                  position.height += value.translation.height }
    )

// Press-then-drag (manual reorder; prefer reorderable() on iOS 27 pre-GA — see below):
let press = LongPressGesture(minimumDuration: 0.4)
let drag = DragGesture()
view.gesture(press.sequenced(before: drag).onEnded { _ in /* commit */ })
```

## Gesture vs scroll arbitration

The cardinal interaction pitfall. **iOS 18 changed how custom gestures arbitrate against the system scroll gesture** — a `highPriorityGesture` inside a `ScrollView` now starves the scroll recognizer and scrolling silently stops.

- Inside a scroll view, prefer **`.simultaneousGesture(_:)`** so both the custom gesture and the system scroll gesture recognize.
- Give the custom gesture a `minimumDistance:` (drag) or `minimumDuration:` (long-press) so it doesn't steal quick scroll flicks.
- `DragGesture` defaults to `minimumDistance: 10` — a `TapGesture` and `DragGesture` on the same view will fight. Compose them with `.exclusively`/`.sequenced` rather than stacking two `.gesture` modifiers and hoping.

```swift
ScrollView {
    content.simultaneousGesture(            // NOT highPriorityGesture
        LongPressGesture(minimumDuration: 0.5).onEnded { _ in showMenu() }
    )
}
```

## Scroll-driven effects

Two supported, layout-cheap tools. Avoid the old `GeometryReader` + `PreferenceKey` offset-tracking hack — it forces extra layout passes and is fragile.

- **`scrollTransition(_:axis:transition:)`** (iOS 17) animates a child relative to the viewport. The closure gets a `ScrollTransitionPhase` whose `.value` runs −1 (`.topLeading`) → 0 (`.identity`) → 1 (`.bottomTrailing`); `.isIdentity` is true at rest. Children must participate in `scrollTargetLayout()` or edge behavior looks wrong.
- **`onScrollGeometryChange(for:of:action:)`** (iOS 18) reports `contentOffset`/`contentSize`/`containerSize`/`contentInsets`/`bounds` via `ScrollGeometry`; the transform maps to an `Equatable` and the action fires on change.

```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            CardView(item).scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.3)
                    .scaleEffect(phase.isIdentity ? 1 : 0.85)
            }
        }
    }
    .scrollTargetLayout()
}
.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
    headerCollapsed = y > 80
}
```

## Haptics

**`.sensoryFeedback(_:trigger:)`** (iOS 17) is the modern SwiftUI API and the default for ~95% of cases. SwiftUI watches the `Equatable` trigger and plays feedback whenever it changes — no generator object, no `prepare()`. The UIKit `UIFeedbackGenerator` family is legacy; only drop to it when you're outside SwiftUI (and then call `prepare()` first to avoid latency).

Three overloads: fixed feedback + trigger; feedback + trigger + a `(old, new) -> Bool` gate; and trigger + a `(old, new) -> SensoryFeedback?` that picks the haptic dynamically (return `nil` to skip).

`SensoryFeedback` cases: `.success`/`.warning`/`.error` (notification-style), `.selection`, `.impact(flexibility:.soft/.solid/.rigid, intensity:)` or `.impact(weight:.light/.medium/.heavy, intensity:)`, `.increase`/`.decrease`, `.start`/`.stop`, `.alignment`, `.levelChange`, `.pathComplete` (iOS 17.5).

```swift
@State private var liked = false

Image(systemName: liked ? "heart.fill" : "heart")
    .onTapGesture { liked.toggle() }
    .sensoryFeedback(trigger: liked) { _, isLiked in
        isLiked ? .success : .impact(flexibility: .soft, intensity: 0.5)
    }
```

For bespoke continuous, parametric, or audio-synced haptics that `.sensoryFeedback` can't express, drop to **CoreHaptics** (`CHHapticEngine`/`CHHapticPattern`/`CHHapticEvent`, iOS 13). Always gate on `capabilitiesForHardware().supportsHaptics` — it silently no-ops on hardware without a Taptic Engine and in the simulator — and restart the engine on its `stoppedHandler`/app-foreground.

```swift
import CoreHaptics

final class Haptics {
    private var engine: CHHapticEngine?
    func start() { engine = try? CHHapticEngine(); try? engine?.start() }
    func buzz() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let event = CHHapticEvent(eventType: .hapticContinuous,
            parameters: [.init(parameterID: .hapticIntensity, value: 0.8),
                         .init(parameterID: .hapticSharpness, value: 0.4)],
            relativeTime: 0, duration: 0.4)
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        try engine?.makePlayer(with: pattern).start(atTime: 0)
    }
}
```

## Context menus & menus

- **`contextMenu(menuItems:preview:)`** (iOS 16) renders any view in the rounded preview card next to the menu.
- **`contextMenu(forSelectionType:menu:primaryAction:)`** (iOS 16) gives true multi-select menus in `List`/`Table`; `primaryAction` handles the tap/double-tap.
- **`Menu(...) primaryAction:`** (iOS 16) makes a tap run the primary action while a long-press opens the menu. `menuIndicator(.hidden)` drops the chevron; `menuActionDismissBehavior(.disabled)` (iOS 16.4) keeps the menu open after a tap (e.g. a stepper inside a menu).

```swift
row.contextMenu {
    Button("Share", systemImage: "square.and.arrow.up") { share() }
    Button("Delete", systemImage: "trash", role: .destructive) { delete() }
} preview: { DetailPreview(item) }

List(selection: $selection) { /* rows */ }
    .contextMenu(forSelectionType: Item.ID.self) { ids in
        Button("Delete \(ids.count)", role: .destructive) { delete(ids) }
    } primaryAction: { ids in open(ids) }
```

For controls that must nest correctly inside Liquid Glass capsules, use **`ConcentricRectangle`** / `Shape.rect(corners:)` with concentric corner style (iOS 26) — it auto-derives inner radii (see `liquid-glass.md`). Control Center / Lock Screen / Action-button controls are authored in WidgetKit via `ControlWidgetButton`/`ControlWidgetToggle` (iOS 18, Liquid-Glass-refined in 26; see `system-integration.md`).

## Text input & focus

`@FocusState` (iOS 15) drives focus declaratively — bind with `focused(_:)` (Bool) or `focused(_:equals:)` (enum) and **set it to `nil` to dismiss the keyboard**. `submitLabel(_:)` sets the return-key label; `onSubmit(of:_:)` reacts to submission. Keyboard avoidance is automatic; opt out only with `ignoresSafeArea(.keyboard)`. `scrollDismissesKeyboard(_:)` (iOS 16) controls dismissal on scroll (`.interactively`/`.immediately`/`.never`).

```swift
enum Field { case email, password }
@FocusState private var focus: Field?

TextField("Email", text: $email)
    .focused($focus, equals: .email)
    .submitLabel(.next)
    .onSubmit { focus = .password }
SecureField("Password", text: $password)
    .focused($focus, equals: .password)
    .submitLabel(.go)
    .onSubmit { logIn() }
```

`writingToolsBehavior(_:)` (iOS 18, Apple Intelligence) controls Writing Tools per text view: `.automatic`/`.complete`/`.limited`/`.disabled`. Use `.disabled` where a rewrite would corrupt structured input — code editors, formatted or machine-parsed fields.

## Rich-text editing (iOS 26)

`TextEditor` gains **first-class rich text in iOS 26**: bind it to a `$text` of type `AttributedString` plus a `$selection` of type `AttributedTextSelection`. A native bold/italic/underline format menu appears on selection automatically. `AttributedTextSelection` tracks stable selection state (not raw indices); apply formatting to just the selection with `transformAttributes(in:)` so ranges stay valid as the string mutates.

This overload is **iOS 26-only** — gate with `#available`; on earlier OSes `TextEditor` takes a plain `String` and you had to bridge to `UITextView` for rich text.

```swift
@State private var text = AttributedString("Edit me")
@State private var selection = AttributedTextSelection()

TextEditor(text: $text, selection: $selection)
    .toolbar {
        Button("Bold") {
            text.transformAttributes(in: &selection) { container in
                let isBold = container.font?.weight == .bold
                container.font = (container.font ?? .body).weight(isBold ? .regular : .bold)
            }
        }
    }
```

## Search

`searchable(text:tokens:suggestedTokens:placement:prompt:)` (iOS 16) adds a search field, optionally **tokenized**. `searchScopes(_:scopes:)` (iOS 16) adds a scope picker (segmented on iOS). Read `@Environment(\.isSearching)` and call `dismissSearch` to cancel.

**iOS 26 Liquid Glass search** floats and minimizes: `searchToolbarBehavior(.minimize)` collapses the field into a toolbar button (the system may auto-apply based on device size / toolbar item count). `DefaultToolbarItem(kind: .search)` reserves the search slot and `ToolbarSpacer(_:placement:)` controls spacing so search can sit in the iPhone bottom bar / iPad top-trailing. Note `searchToolbarBehavior(_:)` (iOS 26) is distinct from the older `searchPresentationToolbarBehavior(.avoidHidingContent)` (iOS 17.1) — both exist.

```swift
@State private var query = ""
@State private var tokens: [Tag] = []
@State private var scope: Scope = .all

NavigationStack { list }
    .searchable(text: $query, tokens: $tokens) { token in Text(token.name) }
    .searchScopes($scope) { ForEach(Scope.allCases) { Text($0.title).tag($0) } }
    .searchToolbarBehavior(.minimize)
```

## iOS 27 (pre-GA)

Incremental for this domain. **Pre-GA (WWDC 2026 developer beta, ships fall 2026) — signatures may change before GA; gate with `#available`.**

- **Universal drag-to-reorder**: `reorderable()` on dynamic content + `reorderContainer(for:)` scope — works in `LazyVStack`/`LazyVGrid`/custom layouts, not just `List`. SwiftUI provides the drag preview, placeholder, and drop animation. Prefer this over hand-rolled `LongPressGesture.sequenced(before: DragGesture)` reorder logic.
- **`swipeActionsContainer()`** on `ScrollView` extends `swipeActions` beyond `List` to any scroll container.
- **`toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)`** auto-hides chrome on scroll.
- **`CrossFadeNavigationTransition`** and **`AnyNavigationTransition`** (runtime-selectable navigation transitions) added.

## Pitfalls

- **`highPriorityGesture` inside a `ScrollView` starves the system scroll gesture (iOS 18+)** — scrolling silently stops. Use `simultaneousGesture` with a `minimumDistance`/`minimumDuration`.
- **`@GestureState` is read-only outside `.updating()` and auto-resets the instant the gesture ends** — reading it in `.onEnded` gives the initial value. Persist final state in a separate `@State`.
- **`DragGesture` defaults to `minimumDistance: 10`** — a tap and a drag on the same view conflict. Use `.exclusively`/`.sequenced` composition.
- **`.sensoryFeedback` fires only when the trigger value actually changes** — re-assigning the same value plays nothing. Toggle a `Bool`/counter or use the condition overload.
- **Several `SensoryFeedback` cases are no-ops or remapped on iPhone** (`.increase`, `.decrease`, `.alignment`, `.levelChange`) — meaningful mainly on watchOS/macOS. Don't rely on them for iPhone-only UX.
- **CoreHaptics silently does nothing without a Taptic Engine** (older devices, simulator) — always guard `capabilitiesForHardware().supportsHaptics`, and restart the engine after it stops (interruptions, backgrounding).
- **Rich-text `TextEditor` (AttributedString + AttributedTextSelection) is iOS 26-only** — gate with `#available`; earlier OSes only accept a plain `String`.
- **`MagnificationGesture`/`RotationGesture` are deprecated (iOS 17)** — new code uses `MagnifyGesture`/`RotateGesture`, whose `Value` types differ (`.rotation` is now an `Angle`).
- **`scrollTransition` only animates children inside the scroll target layout** — forgetting `scrollTargetLayout()` makes transitions look wrong at the edges.
- **`writingToolsBehavior(.disabled)` is required for structured/code fields** — otherwise Apple Intelligence may rewrite content the user didn't intend.

## Primary sources

- sensoryFeedback(_:trigger:) — https://developer.apple.com/documentation/SwiftUI/View/sensoryFeedback(_:trigger:)
- Gesture — https://developer.apple.com/documentation/swiftui/gesture
- onScrollGeometryChange(for:of:action:) — https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)
- scrollTransition(_:axis:transition:) — https://developer.apple.com/documentation/swiftui/view/scrolltransition(_:axis:transition:)
- WritingToolsBehavior — https://developer.apple.com/documentation/swiftui/writingtoolsbehavior
- SwiftUI Search Enhancements in iOS and iPadOS 26 (Nil Coalescing) — https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/
- contextMenu(menuItems:preview:) — https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:preview:)
- New SwiftUI APIs for reordering and drag and drop on iOS 27 (Nil Coalescing, pre-GA) — https://nilcoalescing.com/blog/NewSwiftUIAPIsForReorderingAndDragAndDropOniOS27/
