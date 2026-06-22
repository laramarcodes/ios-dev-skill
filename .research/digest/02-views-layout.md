# DOMAIN: SwiftUI — Views, layout system & animation (iPhone & iPad), iOS 26 shipping / iOS 27 pre-GA

## Orientation
 SwiftUI's view layer is built from value-type `View` structs composed via `@ViewBuilder`; the layout engine is a three-pass negotiation (parent proposes a size, child reports `sizeThatFits`, parent places it) that you can fully customize via the `Layout` protocol. On iOS 26 the headline shift is Liquid Glass: stock controls adopt it for free, and you opt custom views in with `.glassEffect(_:in:)`, `GlassEffectContainer`, `glassEffectID`, plus the new `.scrollEdgeEffectStyle` / `.backgroundExtensionEffect` that make content flow under floating glass bars. Modern idioms have largely settled: `NavigationStack`/`NavigationSplitView` over `NavigationView`, `@Observable` over `ObservableObject`, the declarative scroll stack (`scrollTargetBehavior`, `scrollPosition`, `scrollTransition`, `contentMargins`, `onScrollGeometryChange`) over `GeometryReader` hacks, and the `@Animatable` macro (iOS 26) over hand-written `animatableData`. Animation spans implicit `.animation(value:)`, multi-step `phaseAnimator`/`keyframeAnimator`, SF Symbols 7 effects (`.symbolEffect`, new Draw On/Off), `matchedGeometryEffect`, zoom `NavigationTransition`, custom `Transition`, `visualEffect`, `meshGradient`, and `TextRenderer`. iOS 27 (pre-GA, announced WWDC 2026) is incremental: it removes long-standing limits (swipe actions and reordering on any container, `CrossFadeNavigationTransition`, toolbar overflow/priority controls, `@State` becoming a lazy-init macro) rather than redesigning the framework. Always version-qualify: most of the rich scroll/animation surface is iOS 17–18, Liquid Glass and `@Animatable` are iOS 26, and the WWDC 2026 items below are pre-release and may change before GA.

## Key facts
- [iOS 26|high] `scrollEdgeEffectStyle(_:for:)` configures the blur transition between scrolling content and floating glass controls (toolbars). Signature: `func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View`. Styles are `.automatic` (default), `.hard`, `.soft`. Companion: `scrollEdgeEffectHidden(_:for:)`.
- [iOS 26|high] Liquid Glass for custom views: `.glassEffect(_:in:isEnabled:)` applies a glass material in a given shape; wrap multiple glass shapes in `GlassEffectContainer` so they morph/blend (glass cannot sample other glass); `glassEffectID(_:in:)` + a `@Namespace` drives morph transitions; `GlassEffectTransition` and the `Glass` type configure appearance/tint.
- [iOS 26|high] `backgroundExtensionEffect()` mirrors and blurs a view's content into the safe-area margins on each edge, used to extend imagery edge-to-edge under Liquid Glass bars.
- [iOS 26|high] `@Animatable` macro auto-synthesizes the `animatableData` of a `Shape`/`Animatable` conformer from its stored properties; mark non-animating stored props with `@AnimatableIgnored`. Replaces hand-written `var animatableData`.
- [iOS 26|medium] `safeAreaBar(edge:alignment:spacing:content:)` is the new (iOS 26) sibling of `safeAreaInset` for placing a custom bar that participates correctly in the glass/scroll-edge system.
- [iOS 26|high] `ToolbarSpacer` is a new toolbar element (iOS 26) that inserts fixed/flexible spacing to visually separate groups of toolbar buttons; bordered-prominent toolbar items can be tinted with `.tint`.
- [since iOS 17|high] `ScrollTargetBehavior`: `.viewAligned` (snaps to views marked by `scrollTargetLayout()`; variants `viewAligned(anchor:)`, `viewAligned(limitBehavior:)`), `.paging` (`PagingScrollTargetBehavior`, page-sized snapping with custom deceleration). Applied via `scrollTargetBehavior(_:)`.
- [since iOS 17 (ScrollPosition binding iOS 18)|high] `scrollPosition(id:)` / `scrollPosition(_:)` (the latter taking a `ScrollPosition` binding, iOS 18) reads/sets which view is scrolled to; requires `scrollTargetLayout()` on the lazy stack. `scrollTransition(_:axis:transition:)` and `scrollTransition(topLeading:bottomTrailing:axis:transition:)` animate per-item as it enters/exits the visible region (phases `.identity`, `.topLeading`, `.bottomTrailing`).
- [iOS 18 (contentMargins iOS 17)|high] `onScrollGeometryChange(for:of:action:)` and `onScrollVisibilityChange(threshold:_:)` (iOS 18) replace GeometryReader/PreferenceKey hacks for observing scroll offset/size and item visibility. `contentMargins(_:_:for:)` insets content separately from scroll indicators.
- [since iOS 18|high] Custom-container introspection (iOS 18): `Group(subviews:transform:)` and `ForEach(subviews:content:)` let a container read its child subviews as a `Subview` collection to build sectioned/decorated layouts without a backing data array.
- [since iOS 16|high] `Layout` protocol custom layouts require `sizeThatFits(proposal:subviews:cache:)` and `placeSubviews(in:proposal:subviews:cache:)`; subviews are `LayoutSubviews`, sizes are negotiated via `ProposedViewSize` (.zero/.infinity/.unspecified probes). Conform a type to `Layout`, optionally `Animatable`, and use it like a stack.
- [since iOS 18|high] `meshGradient` (MeshGradient) renders a 2D grid of color control points for organic gradients: `MeshGradient(width:height:points:colors:)`.
- [since iOS 18|high] `TextRenderer` protocol customizes how `Text` is drawn for an entire text tree via `draw(layout:in:)`, exposing `Text.Layout` → lines → runs → glyphs; attach with `.textRenderer(_:)`. Pairs with custom `Transition` for per-glyph animations.
- [iOS 26 (SF Symbols 7)|medium] SF Symbols 7 (iOS 26) adds Draw animations: in SwiftUI use `.symbolEffect(.drawOn, isActive:)` / `.symbolEffect(.drawOff, isActive:)` with playback styles (whole-symbol, by-layer, individually); new variable-value draw mode via `symbolVariableValueMode(_:)` / `SymbolVariableValueMode`; improved Magic Replace and automatic gradient rendering (`.symbolColorRenderingMode`).
- [since iOS 18|high] Zoom navigation transition: `.navigationTransition(.zoom(sourceID:in:))` on the destination plus `.matchedTransitionSource(id:in:)` on the source produces the system continuous zoom (e.g. Photos). `matchedGeometryEffect(id:in:)` remains for in-place hero animations within a single view tree.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA, WWDC 2026): `CrossFadeNavigationTransition` accessed as `.navigationTransition(.crossFade)`, applicable directly to sheet / fullScreenCover content; `AnyNavigationTransition` type-eraser for runtime transition choice (`AnyNavigationTransition(.crossFade)` / `(.automatic)`). Prior to this only Automatic and Zoom transitions existed.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA): swipe actions on any scrollable container — `.swipeActions` on rows inside `LazyVStack`/`LazyVGrid`/custom `Layout` when the scroll view has `.swipeActionsContainer()`. Previously `.swipeActions` worked only inside `List`.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA): universal drag-to-reorder via `.reorderable()` on a `ForEach` + `.reorderContainer(for:)` on the parent, working on `List`, `LazyVGrid`, and custom layouts (and watchOS for the first time); applies a `ReorderDifference`.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA) toolbar control: `.visibilityPriority(.high)` keeps groups visible under pressure; `ToolbarOverflowMenu { }` forces items into the overflow; `ToolbarItem(placement: .topBarPinnedTrailing)` pins an item to the trailing edge; `.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)` collapses the nav bar on scroll.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA): `@State` becomes a macro with lazy initialization — an `@Observable` stored in `@State` is created once per view lifetime, not on every parent re-init; behavior back-ported to iOS 17+. `ContentBuilder` (an exposed `ViewBuilder` variant) cuts type-check time for nested containers and works at any deployment target when built with Xcode 27.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA): `Tab(role: .prominent)` visually elevates a tab (cart/create) out of the main tab row; iPhone apps become resizable (matters for iPhone Mirroring / running on iPad), testable via Live Preview resize handles in Xcode 27.
- [since iOS 17|high] `containerRelativeFrame(_:count:span:spacing:alignment:)` sizes a view relative to its scroll/window container — the idiomatic way to build carousels of N-per-page cells without GeometryReader.
- [since iOS 16|high] `ViewThatFits(in:)` picks the first child subtree that fits the proposed space (axis-constrainable), the declarative replacement for manual size measurement when degrading layouts on small screens.

## APIs
- `View` (protocol; since iOS 13) — Base protocol; value-type, `body` built with @ViewBuilder.
- `@ViewBuilder` (result builder; since iOS 13) — Composes view trees; iOS 27 adds exposed `ContentBuilder` variant for faster type-checking.
- `Layout` (protocol; since iOS 16) — sizeThatFits(proposal:subviews:cache:) + placeSubviews(in:proposal:subviews:cache:).
- `ProposedViewSize` (type; since iOS 16) — .zero/.infinity/.unspecified probes; replacingUnspecifiedDimensions().
- `ViewThatFits` (type; since iOS 16) — ViewThatFits(in:) picks first fitting subtree.
- `containerRelativeFrame(_:count:span:spacing:alignment:)` (modifier; since iOS 17) — Sizes relative to scroll/window container.
- `safeAreaInset(edge:alignment:spacing:content:)` (modifier; since iOS 15) — 
- `safeAreaBar(edge:alignment:spacing:content:)` (modifier; iOS 26) — Glass-aware bar companion to safeAreaInset.
- `Grid / GridRow` (type; since iOS 16) — 
- `LazyVGrid / LazyHGrid` (type; since iOS 14) — 
- `Group(subviews:transform:)` (initializer; since iOS 18) — Container introspection over child Subview collection.
- `ForEach(subviews:content:)` (initializer; since iOS 18) — 
- `scrollTargetBehavior(_:)` (modifier; since iOS 17) — 
- `ScrollTargetBehavior` (protocol; since iOS 17) — .viewAligned, .paging; PagingScrollTargetBehavior, ViewAlignedScrollTargetBehavior.
- `scrollTargetLayout()` (modifier; since iOS 17) — Required for viewAligned snapping and scrollPosition.
- `scrollPosition(id:)` (modifier; since iOS 17) — 
- `scrollPosition(_:)` (modifier; iOS 18) — Takes a ScrollPosition binding (programmatic scroll-to).
- `scrollTransition(_:axis:transition:)` (modifier; since iOS 17) — Phases .identity/.topLeading/.bottomTrailing.
- `contentMargins(_:_:for:)` (modifier; since iOS 17) — 
- `onScrollGeometryChange(for:of:action:)` (modifier; iOS 18) — 
- `onScrollVisibilityChange(threshold:_:)` (modifier; iOS 18) — 
- `scrollEdgeEffectStyle(_:for:)` (modifier; iOS 26) — ScrollEdgeEffectStyle: .automatic/.hard/.soft.
- `scrollEdgeEffectHidden(_:for:)` (modifier; iOS 26) — 
- `ScrollEdgeEffectStyle` (type; iOS 26) — 
- `glassEffect(_:in:isEnabled:)` (modifier; iOS 26) — 
- `GlassEffectContainer` (type; iOS 26) — 
- `glassEffectID(_:in:)` (modifier; iOS 26) — 
- `GlassEffectTransition` (type; iOS 26) — 
- `Glass` (type; iOS 26) — .regular, .interactive(), tintable.
- `backgroundExtensionEffect()` (modifier; iOS 26) — 
- `ToolbarSpacer` (type; iOS 26) — 
- `@Animatable` (macro; iOS 26) — With @AnimatableIgnored.
- `Animatable` (protocol; since iOS 13) — animatableData; VectorArithmetic.
- `animation(_:value:)` (modifier; since iOS 15) — 
- `withAnimation(_:_:)` (function; since iOS 13) — 
- `phaseAnimator(_:trigger:content:animation:)` (modifier; since iOS 17) — 
- `keyframeAnimator(initialValue:trigger:content:keyframes:)` (modifier; since iOS 17) — KeyframeTrack / KeyframeTimeline.
- `matchedGeometryEffect(id:in:)` (modifier; since iOS 14) — 
- `navigationTransition(_:)` (modifier; iOS 18) — .zoom(sourceID:in:); iOS 27 adds .crossFade.
- `matchedTransitionSource(id:in:)` (modifier; iOS 18) — 
- `NavigationTransition` (protocol; iOS 18) — ZoomNavigationTransition, AutomaticNavigationTransition; iOS 27 CrossFadeNavigationTransition, AnyNavigationTransition.
- `Transition` (protocol; since iOS 17) — Custom transitions via body(content:phase:); TransitionPhase.
- `visualEffect(_:)` (modifier; since iOS 17) — Geometry-driven effects without GeometryReader.
- `MeshGradient` (type; iOS 18) — MeshGradient(width:height:points:colors:).
- `TextRenderer` (protocol; iOS 18) — draw(layout:in:); Text.Layout; textRenderer(_:) modifier.
- `symbolEffect(_:options:value:)` (modifier; since iOS 17) — SF Symbols 7 adds .drawOn/.drawOff (iOS 26).
- `symbolVariableValueMode(_:)` (modifier; iOS 26) — SymbolVariableValueMode (e.g. .draw).
- `contentTransition(.symbolEffect)` (modifier; since iOS 17) — 
- `swipeActionsContainer()` (modifier; iOS 27 (pre-GA)) — 
- `reorderable()` (modifier; iOS 27 (pre-GA)) — With reorderContainer(for:) and ReorderDifference.
- `toolbarMinimizeBehavior(_:for:)` (modifier; iOS 27 (pre-GA)) — 
- `ToolbarOverflowMenu` (type; iOS 27 (pre-GA)) — 
- `visibilityPriority(_:)` (modifier; iOS 27 (pre-GA)) — Toolbar item-group priority.
- `ContentBuilder` (result builder; iOS 27 (pre-GA)) — Exposed ViewBuilder variant; faster type-checking, any deployment target.

## Patterns

### viewAligned snapping carousel with scrollPosition + scrollTransition  — Horizontal paged carousel that snaps to cards, tracks the current item, and fades/scales off-screen cards.
`scrollTargetLayout()` on the lazy stack is mandatory for both snapping and `scrollPosition`. Use `.paging` instead of `.viewAligned` for full-width page snapping.
```swift
@State private var current: Item.ID?

ScrollView(.horizontal) {
    LazyHStack(spacing: 16) {
        ForEach(items) { item in
            CardView(item)
                .containerRelativeFrame(.horizontal)
                .scrollTransition { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.4)
                        .scaleEffect(phase.isIdentity ? 1 : 0.92)
                }
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
.scrollPosition(id: $current)
```

### Custom Layout protocol (radial)  — Arrangement no built-in stack/grid can express; reusable like HStack.
Probe child sizes with `subviews[i].sizeThatFits(.unspecified)`. Conform the layout to `Animatable` to animate its parameters.
```swift
struct RadialLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = min(bounds.width, bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for (i, sub) in subviews.enumerated() {
            let angle = Angle.degrees(360 / Double(subviews.count) * Double(i)).radians
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            sub.place(at: pt, anchor: .center, proposal: .unspecified)
        }
    }
}
```

### Multi-step animation with phaseAnimator  — Looping/triggered sequence of discrete states (pulse, shake, attention-grabber).
Use `keyframeAnimator(initialValue:trigger:content:keyframes:)` instead when properties need independent timelines (KeyframeTrack per property).
```swift
icon
  .phaseAnimator([1.0, 1.3, 1.0], trigger: pulseCount) { view, scale in
      view.scaleEffect(scale)
  } animation: { _ in .spring(duration: 0.3) }
```

### Zoom navigation transition (hero)  — Tapping a thumbnail expands continuously into a detail screen (Photos-style).
`@Namespace var namespace` must be shared. Use `matchedGeometryEffect` only for hero moves within one view tree; use `.zoom` across navigation pushes/presentations.
```swift
// Source (e.g. in a grid cell)
Thumbnail(item)
    .matchedTransitionSource(id: item.id, in: namespace)

// Destination
DetailView(item)
    .navigationTransition(.zoom(sourceID: item.id, in: namespace))
```

### Liquid Glass custom control (iOS 26)  — A custom floating control/toolbar that should read as glass and morph with siblings.
Always group glass shapes in a `GlassEffectContainer` (glass can't sample other glass). Gate with `if #available(iOS 26, *)` and provide a material fallback for iOS 25 and earlier.
```swift
GlassEffectContainer(spacing: 12) {
    HStack(spacing: 12) {
        ForEach(actions) { a in
            Button(action: a.run) { Label(a.title, systemImage: a.symbol) }
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID(a.id, in: namespace)
        }
    }
}
```

### Per-glyph text animation with TextRenderer  — Animated headline where each glyph appears/transforms independently.
`Text.Layout` yields lines → runs → glyphs; conform the renderer to `Animatable` (animate `time`) to drive it. Pair with a custom `Transition` for insert/remove.
```swift
struct WaveRenderer: TextRenderer {
    var time: Double
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

## Pitfalls
- `scrollTargetBehavior(.viewAligned)` and `scrollPosition(id:)` silently do nothing without `scrollTargetLayout()` on the lazy stack inside the ScrollView.
- Glass effects must live inside a `GlassEffectContainer` — applying `.glassEffect` to overlapping standalone views looks wrong because glass cannot sample other glass.
- Liquid Glass / `scrollEdgeEffectStyle` / `@Animatable` / SF Symbols Draw are iOS 26-only; calling them without `#available` guards fails to compile or crashes on older OSes.
- `matchedGeometryEffect` only works within a single rendered view hierarchy; for cross-navigation hero animation you need `.navigationTransition(.zoom)` + `.matchedTransitionSource`, not matchedGeometryEffect.
- Forgetting to share one `@Namespace` between source and destination breaks both matchedGeometryEffect and the zoom transition (no animation, abrupt cut).
- `containerRelativeFrame` measures the nearest scroll/window container, not the immediate parent — nesting scroll views changes what it resolves to.
- The value-less `.animation(_:)` modifier animates *every* change in the subtree and is deprecated; prefer `.animation(_:value:)` scoped to a specific value.
- iOS 27 pre-GA: setting a `@State` default value in the declaration AND reassigning in `init` now errors ('used before initialized') because `@State` is a macro — drop the default.
- `onScrollVisibilityChange` fires on a threshold fraction; assuming it fires at fully-visible (1.0) by default gives wrong timing — set `threshold:` explicitly.
- SF Symbols Draw animations require layered/variable symbols; a flat custom symbol won't animate by-layer.

## iOS 26 changes
- Liquid Glass design language: stock controls adopt it automatically; custom views opt in via `.glassEffect(_:in:isEnabled:)`, `GlassEffectContainer`, `glassEffectID`, `GlassEffectTransition`, the `Glass` config type.
- `scrollEdgeEffectStyle(_:for:)` (.automatic/.hard/.soft) and `scrollEdgeEffectHidden(_:for:)` control how content blurs under floating glass bars.
- `backgroundExtensionEffect()` mirrors+blurs content into safe-area margins for edge-to-edge imagery.
- `@Animatable` macro (+`@AnimatableIgnored`) auto-generates `animatableData`.
- `ToolbarSpacer` and tintable bordered-prominent toolbar items; bottom-aligned search via `searchable` outside `NavigationSplitView`; morphing search tab via `Tab(role: .search)`.
- `safeAreaBar(edge:alignment:spacing:content:)` glass-aware companion to `safeAreaInset`.
- SF Symbols 7: Draw On/Off `.symbolEffect`, variable-value draw mode (`symbolVariableValueMode`), upgraded Magic Replace, automatic gradients.
- List and scrolling performance improvements (incremental updates, better update scheduling) + new SwiftUI Performance instrument in Xcode 26.
- Rich text: `TextEditor` now binds to `AttributedString` (paragraph styles, attribute transforms, input constraints).

## iOS 27 preview (pre-GA)
- `CrossFadeNavigationTransition` via `.navigationTransition(.crossFade)`, usable on sheet/fullScreenCover content; `AnyNavigationTransition` runtime type-eraser. | Developer beta; API names may change before GA.
- `.swipeActions` on any container inside a ScrollView via `.swipeActionsContainer()` (LazyVStack/LazyVGrid/custom Layout). | Pre-GA.
- Universal reorder: `.reorderable()` on ForEach + `.reorderContainer(for:)`; works on List/LazyVGrid/custom layouts and watchOS. | Pre-GA; ReorderDifference application pattern still settling.
- Toolbar: `.visibilityPriority`, `ToolbarOverflowMenu`, `.topBarPinnedTrailing`, `.toolbarMinimizeBehavior(.onScrollDown, for:)`. | Pre-GA.
- `@State` becomes a lazy-init macro (back-ported to iOS 17+); `ContentBuilder` exposed for faster type-checking. | Pre-GA; one source-break: don't set a @State default value AND assign in init.
- `Tab(role: .prominent)`; iPhone apps become resizable (Live Preview resize handles in Xcode 27). | Pre-GA.
- Adaptive/foldable layout APIs for hinge-state detection and multi-configuration display handling (prep for foldable hardware). | Pre-GA; exact API names unverified against Apple docs.

## Deprecations
- NavigationView → NavigationStack / NavigationSplitView (NavigationView deprecated since iOS 16; do not use in new code).
- ObservableObject + @Published + @StateObject/@ObservedObject → @Observable macro + @State/@Bindable (modern idiom since iOS 17; @Observable avoids over-invalidation).
- Hand-written `var animatableData` on Shapes → `@Animatable` macro (iOS 26).
- GeometryReader + PreferenceKey for scroll offset/visibility → `onScrollGeometryChange` / `onScrollVisibilityChange` (iOS 18) and `scrollPosition` (iOS 17+).
- Manual size-measurement to swap layouts → `ViewThatFits` (iOS 16).
- UIRequiresFullScreen on iPad → deprecated in iOS 26; adopt fluid/resizable layout.
- .animation(_:) single-argument (value-less) form deprecated since iOS 15 → use `.animation(_:value:)` or `withAnimation`.
- ForEach over fixed Range for static content → still valid, but `Group(subviews:)`/`ForEach(subviews:)` (iOS 18) preferred for container introspection.

## Uncertainties
- Exact Apple API names/signatures for the iOS 27 toolbar (`visibilityPriority`, `ToolbarOverflowMenu`, `topBarPinnedTrailing`), `swipeActionsContainer`, `reorderable`/`reorderContainer`, `CrossFadeNavigationTransition`, and `ContentBuilder` come from beta write-ups (dev.to, nilcoalescing) and the WWDC26 guide, not yet confirmed against final developer.apple.com reference pages — treat as pre-GA and verify before shipping.
- The dev.to WWDC26 article repeatedly says Liquid Glass refinements land on '2027 OS releases' while elsewhere the release is called iOS 27 — naming/year mapping for the 2026-announced release should be double-checked against Apple Newsroom.
- SF Symbols 7 Draw modifier exact spelling (`.drawOn`/`.drawOff` vs platform-specific Draw On/Draw Off, and `symbolVariableValueMode`/`SymbolVariableValueMode`) is corroborated by secondary sources (9to5Mac, Medium) but I did not load the Apple SF Symbols reference page to confirm verbatim casing.
- Foldable/hinge-state adaptive layout APIs are mentioned only in a secondary roundup (lushbinary) with no concrete type names — existence is plausible but unverified.
- `safeAreaBar` appears in the scrollEdgeEffect 'See Also' list but I did not open its own reference page to confirm full signature/availability.

## Sources
- scrollEdgeEffectStyle(_:for:) — Apple Developer: https://developer.apple.com/documentation/SwiftUI/View/scrollEdgeEffectStyle(_:for:)
- GlassEffectContainer — Apple Developer: https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- Applying Liquid Glass to custom views — Apple Developer: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- backgroundExtensionEffect() — Apple Developer: https://developer.apple.com/documentation/SwiftUI/View/backgroundExtensionEffect()
- ScrollTargetBehavior — Apple Developer: https://developer.apple.com/documentation/swiftui/scrolltargetbehavior
- scrollTransition(_:axis:transition:) — Apple Developer: https://developer.apple.com/documentation/SwiftUI/View/scrollTransition(_:axis:transition:)
- contentMargins(_:for:) — Apple Developer: https://developer.apple.com/documentation/swiftui/view/contentmargins(_:for:)
- Composing custom layouts with SwiftUI — Apple Developer: https://developer.apple.com/documentation/swiftui/composing-custom-layouts-with-swiftui
- NavigationTransition — Apple Developer: https://developer.apple.com/documentation/swiftui/navigationtransition
- phaseAnimator(_:content:animation:) — Apple Developer: https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:content:animation:)
- keyframeAnimator — Apple Developer: https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:)
- Create custom visual effects with SwiftUI — WWDC24 (meshGradient, TextRenderer, visualEffect): https://developer.apple.com/videos/play/wwdc2024/10151/
- What's new in SwiftUI — WWDCNotes (WWDC25/iOS 26): https://wwdcnotes.com/documentation/wwdc25-256-whats-new-in-swiftui/
- Build a SwiftUI app with the new design — WWDC25: https://developer.apple.com/videos/play/wwdc2025/323/
- What's new in SF Symbols 7 — WWDC25: https://developer.apple.com/videos/play/wwdc2025/337/
- Apple releases SF Symbols 7 beta — 9to5Mac: https://9to5mac.com/2025/06/11/apple-releases-sf-symbols-7-beta/
- WWDC26 SwiftUI guide — Apple Developer: https://developer.apple.com/wwdc26/guides/swiftui/
- Navigation transition updates in SwiftUI on iOS 27 — Nil Coalescing: https://nilcoalescing.com/blog/SwiftUINavigationTransitionUpdatesIniOS27/
- WWDC26 What's New in SwiftUI: A Developer's Breakdown — dev.to (arshtechpro): https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333
- How to create a custom layout using the Layout protocol — Hacking with Swift: https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-custom-layout-using-the-layout-protocol
