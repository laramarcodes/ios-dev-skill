# Views, layout system & animation

SwiftUI's view layer is value-type `View` structs composed with `@ViewBuilder`, laid out by a three-pass negotiation you can fully customize, and animated by a deep stack from implicit `.animation` up to per-glyph `TextRenderer`. This file is the day-to-day vocabulary: how layout actually resolves, the modern scroll/list stack, and the animation tools — version-qualified so you know what compiles on iOS 26 vs what's pre-GA.

**Contents**
- [The View protocol & @ViewBuilder](#the-view-protocol--viewbuilder)
- [How layout resolves](#how-layout-resolves)
- [Stacks, Grid & the Layout protocol](#stacks-grid--the-layout-protocol)
- [Adaptive layout: ViewThatFits & containerRelativeFrame](#adaptive-layout-viewthatfits--containerrelativeframe)
- [Lists & ScrollView (the modern stack)](#lists--scrollview-the-modern-stack)
- [Custom containers (Group/ForEach subviews)](#custom-containers-groupforeach-subviews)
- [Animation](#animation)
- [SF Symbols 7 (iOS 26)](#sf-symbols-7-ios-26)
- [Visual effects: meshGradient & TextRenderer](#visual-effects-meshgradient--textrenderer)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

For Liquid Glass specifics (`glassEffect`, `GlassEffectContainer`, `scrollEdgeEffectStyle`) see `liquid-glass.md`. For navigation containers see `app-structure.md`; for `@Observable`/`@State` see `state-observation.md`.

## The View protocol & @ViewBuilder

A `View` is a value type whose `body` describes UI declaratively; SwiftUI diffs the description and updates the render tree. `body` is built with `@ViewBuilder`, a result builder that turns a sequence of statements into a single composed view (and handles `if`/`switch`/`ForEach`).

```swift
struct Badge: View {                  // since iOS 13
    let count: Int
    var body: some View {             // @ViewBuilder is implicit on `body`
        if count > 0 {
            Text("\(count)").font(.caption).padding(6).background(.red, in: .circle)
        }
    }
}
```

- Keep views small and value-typed. Identity (position in the tree + explicit `id`) determines what SwiftUI animates and what state it preserves — restructuring the tree silently resets `@State`.
- `@ViewBuilder` caps a builder at ~10 children before type-checking slows; group with `Group` or extract subviews. **iOS 27 (pre-GA)** exposes `ContentBuilder`, a `ViewBuilder` variant that cuts type-check time for deeply nested containers and works at any deployment target when built with Xcode 27.

## How layout resolves

Layout is a three-pass negotiation, top-down then bottom-up. Internalize this and most "why is my view the wrong size" questions answer themselves:

1. **Parent proposes a size** (`ProposedViewSize`, since iOS 16) to the child.
2. **Child reports the size it wants** via `sizeThatFits(_:)` — it may ignore the proposal (e.g. `Image` takes its intrinsic size; `Text` wraps to the proposal's width).
3. **Parent places the child** at a point.

`ProposedViewSize` has three probe values that built-in views answer specially: `.zero` (minimum size), `.infinity` (maximum/greedy size), and `.unspecified` (ideal/intrinsic size). `proposal.replacingUnspecifiedDimensions()` resolves an unspecified probe to a concrete `CGSize`. Modifiers like `.frame`, `.padding`, and `.layoutPriority` work by intercepting the proposal a parent passes down.

## Stacks, Grid & the Layout protocol

| API | Since | Use for |
|---|---|---|
| `HStack`/`VStack`/`ZStack` | iOS 13 | Linear stacking; load all children eagerly. |
| `LazyVStack`/`LazyHStack` | iOS 14 | Long scrollable runs — children built on demand. |
| `Grid`/`GridRow` | iOS 16 | Aligned 2-D table where columns line up across rows (measures everything; not lazy). |
| `LazyVGrid`/`LazyHGrid` | iOS 14 | Scrollable grid with `GridItem` column specs; lazy. |
| `Layout` protocol | iOS 16 | Arrangements no built-in container expresses (radial, flow, masonry). |

Use `Grid` when cells must align into columns; use `LazyVGrid` for large, scrolling, independently-sized grids. For a fully custom arrangement, conform a type to `Layout` — it then composes exactly like a stack:

```swift
struct RadialLayout: Layout {                                    // since iOS 16
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let radius = min(bounds.width, bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for (i, sub) in subviews.enumerated() {
            let a = .pi * 2 / Double(subviews.count) * Double(i)
            sub.place(at: CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius),
                      anchor: .center, proposal: .unspecified)
        }
    }
}
// RadialLayout { ForEach(items) { ItemView($0) } }
```

Probe each child with `subviews[i].sizeThatFits(.unspecified)`. Conform the layout to `Animatable` and animate a stored property (e.g. an angle offset) to get a layout that animates between arrangements. Use `cache` to avoid recomputing across the two passes.

## Adaptive layout: ViewThatFits & containerRelativeFrame

- **`ViewThatFits(in:)`** (iOS 16) renders the first child subtree that fits the proposed space — the declarative replacement for manual size measurement when degrading a layout (e.g. a wide label that collapses to an icon on a narrow screen). Constrain the probed axis with `in:`.
- **`containerRelativeFrame(_:count:span:spacing:alignment:)`** (iOS 17) sizes a view relative to its nearest **scroll/window container**, not its immediate parent — the idiomatic way to build N-per-page carousels without `GeometryReader`. `.containerRelativeFrame(.horizontal)` makes a card exactly one container width; `count:span:` carves the container into a grid of pages.
- **`safeAreaInset(edge:alignment:spacing:content:)`** (iOS 15) places a bar that insets the safe area so scrollable content doesn't slide under it. **iOS 26** adds `safeAreaBar(edge:alignment:spacing:content:)`, the glass-aware companion that participates correctly in the Liquid Glass scroll-edge system — prefer it for floating bars on iOS 26 (see `liquid-glass.md`).

## Lists & ScrollView (the modern stack)

The declarative scroll stack (iOS 17–18) replaced years of `GeometryReader` + `PreferenceKey` hacks. The whole stack hinges on one rule: **`scrollTargetLayout()` on the lazy stack** is required for both snapping and position tracking.

| API | Since | Purpose |
|---|---|---|
| `scrollTargetBehavior(_:)` | iOS 17 | `.viewAligned` (snap to marked views) or `.paging` (page-sized snapping). |
| `scrollTargetLayout()` | iOS 17 | Marks the lazy stack whose children are snap targets / position ids. |
| `scrollPosition(id:)` | iOS 17 | Two-way binding to the id of the top-most/current view. |
| `scrollPosition(_:)` | iOS 18 | Takes a `ScrollPosition` binding for programmatic scroll-to (edge, id, offset). |
| `scrollTransition(_:axis:transition:)` | iOS 17 | Animate each item as it enters/exits the visible region. |
| `contentMargins(_:_:for:)` | iOS 17 | Inset content separately from scroll indicators. |
| `onScrollGeometryChange(for:of:action:)` | iOS 18 | Observe scroll offset/size/content without `GeometryReader`. |
| `onScrollVisibilityChange(threshold:_:)` | iOS 18 | Fire when an item crosses a visibility fraction. |
| `scrollEdgeEffectStyle(_:for:)` | iOS 26 | Blur transition under floating glass bars (see `liquid-glass.md`). |

A snapping carousel that tracks the current card and fades off-screen cards:

```swift
@State private var current: Item.ID?

ScrollView(.horizontal) {
    LazyHStack(spacing: 16) {
        ForEach(items) { item in
            CardView(item)
                .containerRelativeFrame(.horizontal)
                .scrollTransition { content, phase in           // phase: .topLeading / .identity / .bottomTrailing
                    content
                        .opacity(phase.isIdentity ? 1 : 0.4)
                        .scaleEffect(phase.isIdentity ? 1 : 0.92)
                }
        }
    }
    .scrollTargetLayout()                                       // REQUIRED — without it nothing snaps
}
.scrollTargetBehavior(.viewAligned)                             // or .paging for full-width pages
.scrollPosition(id: $current)
```

For `List`, prefer the `selection:`/`@Observable` data model and `.swipeActions` on rows. **iOS 26** brings incremental List update scheduling and a new SwiftUI Performance instrument in Xcode 26 (see `performance-and-shipping.md`). **iOS 27 (pre-GA)** lifts two long-standing limits: `.swipeActions` works on rows in any container (`LazyVStack`/`LazyVGrid`/custom `Layout`) once the scroll view has `.swipeActionsContainer()`, and universal drag-to-reorder arrives via `.reorderable()` on a `ForEach` plus `.reorderContainer(for:)` on the parent — both beta, names may change.

## Custom containers (Group/ForEach subviews)

**iOS 18** lets a container read its own child subviews as a `Subview` collection — so you can build sectioned or decorated layouts from inline view literals without a backing data array:

```swift
struct CardStack<Content: View>: View {                         // iOS 18
    @ViewBuilder var content: Content
    var body: some View {
        VStack {
            Group(subviews: content) { subviews in              // introspect children
                ForEach(subviews) { sub in
                    sub.padding().background(.thinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
    }
}
// CardStack { Text("One"); Text("Two"); Image(systemName: "star") }
```

`ForEach(subviews:content:)` is the same idea in `ForEach` form. This is the idiomatic replacement for the old "pass an array of `AnyView`" pattern.

## Animation

The animation surface, from simplest to most powerful:

- **`withAnimation(_:_:)`** (iOS 13) wraps a state mutation so dependent views animate. **`.animation(_:value:)`** (iOS 15) implicitly animates whenever a specific value changes. The single-argument, value-less `.animation(_:)` is **deprecated** (it animates every change in the subtree) — always scope to a value.
- **`phaseAnimator(_:trigger:content:animation:)`** (iOS 17) walks a view through discrete phases — ideal for a pulse, shake, or attention loop:

```swift
icon
    .phaseAnimator([1.0, 1.3, 1.0], trigger: pulseCount) { view, scale in
        view.scaleEffect(scale)
    } animation: { _ in .spring(duration: 0.3) }
```

- **`keyframeAnimator(initialValue:trigger:content:keyframes:)`** (iOS 17) drives several properties on independent timelines via `KeyframeTrack`s — reach for it when scale, rotation, and offset each need their own curve. `phaseAnimator` is for one shared sequence; `keyframeAnimator` is for parallel tracks.
- **Hero transitions.** `matchedGeometryEffect(id:in:)` (iOS 14) animates a view moving between two positions **within one rendered hierarchy**. For a hero that spans a navigation push or sheet presentation, use the **zoom transition** (iOS 18): `.matchedTransitionSource(id:in:)` on the source plus `.navigationTransition(.zoom(sourceID:in:))` on the destination, sharing one `@Namespace`.

```swift
@Namespace private var ns
// Source cell:
Thumbnail(item).matchedTransitionSource(id: item.id, in: ns)
// Destination:
DetailView(item).navigationTransition(.zoom(sourceID: item.id, in: ns))
```

- **Custom shapes.** Conform a `Shape` to `Animatable` and SwiftUI interpolates its `animatableData`. **iOS 26** adds the `@Animatable` macro, which synthesizes `animatableData` from a type's stored properties automatically; mark non-animating stored props with `@AnimatableIgnored`. This replaces hand-written `var animatableData`.
- **iOS 27 (pre-GA):** `CrossFadeNavigationTransition` via `.navigationTransition(.crossFade)` (also usable on sheet/`fullScreenCover` content), and `AnyNavigationTransition` to choose a transition at runtime. Beta; verify before shipping.

`visualEffect(_:)` (iOS 17) reads a view's resolved geometry (`GeometryProxy`) to drive effects (parallax, scaling by scroll position) **without** a `GeometryReader` wrapper that would disturb layout.

## SF Symbols 7 (iOS 26)

SF Symbols 7 ships with iOS 26. In SwiftUI, drive animation with `symbolEffect(_:options:value:)` (iOS 17). New in 7:

- **Draw On/Off:** `.symbolEffect(.drawOn, isActive:)` and `.symbolEffect(.drawOff, isActive:)` stroke a layered symbol in/out (whole-symbol, by-layer, or individually).
- **Variable-value draw mode:** `symbolVariableValueMode(_:)` with `SymbolVariableValueMode` (e.g. `.draw`) animates a variable-value symbol by drawing.
- Upgraded **Magic Replace** (`.contentTransition(.symbolEffect)`) and automatic gradient rendering via `.symbolColorRenderingMode`.

```swift
Image(systemName: "bell")
    .symbolEffect(.drawOn, isActive: isRinging)   // iOS 26; needs a layered/variable symbol
```

Draw animations require a **layered or variable** symbol — a flat custom symbol won't animate by-layer. **SF Symbols 8 is iOS 27 (pre-GA)** — do not rely on it for shipping apps.

## Visual effects: meshGradient & TextRenderer

- **`MeshGradient(width:height:points:colors:)`** (iOS 18) renders a 2-D grid of color control points for organic, multi-stop gradients — animate the `points` array for living backgrounds.
- **`TextRenderer`** (iOS 18) customizes how an entire `Text` tree is drawn via `draw(layout:in:)`, walking `Text.Layout` → lines → runs → glyphs. Attach with `.textRenderer(_:)`. Conform the renderer to `Animatable` (animate a `time` property) for per-glyph motion; pair with a custom `Transition` for per-glyph insert/remove.

```swift
struct WaveRenderer: TextRenderer, Animatable {                 // iOS 18
    var time: Double
    var animatableData: Double { get { time } set { time = newValue } }
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            for (i, run) in line.enumerated() {
                var c = ctx
                c.translateBy(x: 0, y: sin(time + Double(i)) * 4)
                c.draw(run)
            }
        }
    }
}
// Text("Hello").textRenderer(WaveRenderer(time: t))
```

`Transition` (iOS 17) defines a custom in/out effect via `body(content:phase:)` over `TransitionPhase` — the building block for bespoke `.transition(...)` insert/remove animations.

## Pitfalls

- **`scrollTargetBehavior(.viewAligned)` and `scrollPosition(id:)` silently do nothing** without `scrollTargetLayout()` on the lazy stack inside the `ScrollView`. This is the #1 "snapping doesn't work" cause.
- **`containerRelativeFrame` measures the nearest scroll/window container, not the immediate parent.** Nesting scroll views changes what it resolves to — a card inside a nested `ScrollView` sizes to the inner one.
- **`matchedGeometryEffect` only works within a single rendered hierarchy.** Across a navigation push or presentation you must use `.navigationTransition(.zoom)` + `.matchedTransitionSource`, not `matchedGeometryEffect`.
- **Forgetting to share one `@Namespace`** between source and destination breaks both `matchedGeometryEffect` and the zoom transition — you get an abrupt cut with no animation and no error.
- **The value-less `.animation(_:)` is deprecated** (since iOS 15) and animates every change in the subtree; use `.animation(_:value:)` or `withAnimation`.
- **`onScrollVisibilityChange` fires on a threshold fraction**, not at full visibility — assuming `1.0` by default gives wrong timing. Set `threshold:` explicitly.
- **SF Symbols Draw needs a layered/variable symbol** — a flat custom symbol won't animate by-layer or draw-on.
- **iOS 26-only APIs** (`@Animatable`, Draw effects, `safeAreaBar`, glass/scroll-edge modifiers) fail to compile or crash on older OSes — gate with `if #available(iOS 26, *)` and provide a fallback.
- **iOS 27 pre-GA `@State` becomes a lazy-init macro** (back-ported to iOS 17+). One source-break: setting a `@State` default value in the declaration **and** reassigning it in `init` now errors ("used before initialized") — drop the default.
- **Restructuring the view tree resets `@State`.** Identity is positional; if you wrap a view in a new conditional or container, its state is recreated. Use stable `.id(...)` when you mean to preserve or intentionally reset.

## Primary sources

- Composing custom layouts with SwiftUI — https://developer.apple.com/documentation/swiftui/composing-custom-layouts-with-swiftui
- ScrollTargetBehavior — https://developer.apple.com/documentation/swiftui/scrolltargetbehavior
- scrollTransition(_:axis:transition:) — https://developer.apple.com/documentation/SwiftUI/View/scrollTransition(_:axis:transition:)
- NavigationTransition — https://developer.apple.com/documentation/swiftui/navigationtransition
- keyframeAnimator — https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:)
- Create custom visual effects with SwiftUI (WWDC24 — meshGradient, TextRenderer, visualEffect) — https://developer.apple.com/videos/play/wwdc2024/10151/
- What's new in SF Symbols 7 (WWDC25) — https://developer.apple.com/videos/play/wwdc2025/337/
- What's new in SwiftUI (WWDC25 / iOS 26) — https://wwdcnotes.com/documentation/wwdc25-256-whats-new-in-swiftui/
- WWDC26 SwiftUI guide (iOS 27 pre-GA) — https://developer.apple.com/wwdc26/guides/swiftui/
