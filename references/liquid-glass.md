# The Liquid Glass design system (SwiftUI adoption)

Liquid Glass is the iOS 26 redesign: a single dynamic material — glass optics (lensing, specular highlights, light/dark adaptation) plus liquid fluidity — that the system applies to the *navigation layer* floating above your content. The core mental model never changes: **glass is chrome, not content, and you never stack glass on glass.** Most of it is free the moment you build against the iOS 26 SDK; for custom views you opt in with a handful of modifiers below.

**Contents**
- [Automatic adoption vs explicit opt-in](#automatic-adoption-vs-explicit-opt-in)
- [The two variants (and tint, interactive)](#the-two-variants-and-tint-interactive)
- [Glass on custom views](#glass-on-custom-views)
- [Containers and morphing](#containers-and-morphing)
- [Buttons](#buttons)
- [Toolbars, tab bars, accessories](#toolbars-tab-bars-accessories)
- [Edge-to-edge content and concentric corners](#edge-to-edge-content-and-concentric-corners)
- [The temporary opt-out](#the-temporary-opt-out)
- [iOS 27 refinements (pre-GA)](#ios-27-refinements-pre-ga)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## Automatic adoption vs explicit opt-in

There are two ways Liquid Glass reaches your app, and knowing which is which prevents the most common over-engineering:

- **Automatic (free).** Standard SwiftUI components — `TabView`, `NavigationStack`/`NavigationSplitView`, `.toolbar`, sheets, `Button`, `Slider`, `Menu` — restyle to Liquid Glass automatically the moment you build with **Xcode 26 against the iOS 26 SDK** (shipping: Xcode 26.5, Swift 6.3.2). Building with the iOS 26 SDK is also a hard App Store upload requirement since Apr 28 2026, independent of your deployment target. No code changes. You do *not* rewrite your app to adopt the redesign; you mostly delete the workarounds you wrote for the old look (see Pitfalls).
- **Explicit (custom views only).** Bespoke controls, badges, floating panels — things that aren't a standard component — opt in with `glassEffect(_:in:)`, group with `GlassEffectContainer`, and morph with `glassEffectID` + a `Namespace`.

If you find yourself hand-rolling a glass tab bar or now-playing bar, stop — the standard `TabView` already does it. See `swiftui-views.md` for the standard component catalog and `app-structure.md` for navigation scaffolding.

## The two variants (and tint, interactive)

There are exactly **two** glass variants, modeled by the `Glass` struct (iOS 26+). Never mix them on screen.

| Variant | When | Behavior |
|---|---|---|
| `Glass.regular` | Almost always — the default | Adaptive; legible over any content, any size, light/dark |
| `Glass.clear` | Only over bright, media-rich content | Permanently more transparent, **not** adaptive; needs your own dimming layer or it goes illegible |

`Glass` is chainable. Two modifiers refine it:

- `.tint(_:)` — tones the glass; use **selectively** to highlight the single primary action. Tint everything and nothing stands out.
- `.interactive(_:)` (default `true`) — adds the touch/pointer reaction (scale, shimmer, glow) that `.glass` buttons have. Use on custom controls that respond to touch.

```swift
Glass.regular.tint(.orange).interactive()   // a tinted, reactive primary control
```

## Glass on custom views

`glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View` (iOS 26+) is the entry point. The default shape is a `Capsule` — right for small pills; switch to `.rect(cornerRadius:)` for larger surfaces. **Apply `glassEffect` after** layout and appearance modifiers (padding, frame), not before.

```swift
Label("Desert", systemImage: "sun.max.fill")
    .padding()
    .glassEffect()                       // .regular in a Capsule

Button("Get Started") { start() }
    .padding()
    .glassEffect(.regular.tint(.orange).interactive(),
                 in: .rect(cornerRadius: 16))
```

Why the ordering matters: `glassEffect` captures the view's resolved shape and content to compute lensing. Modifiers applied *after* it sit outside the glass and won't be refracted.

## Containers and morphing

**Glass cannot sample (refract) other glass.** That single hardware fact is why `GlassEffectContainer` exists: it groups multiple glass shapes into one unit for correct light sampling, shape blending, smooth morphing, and far better rendering performance. Whenever you have more than one glass element near each other, wrap them in a container.

`GlassEffectContainer(spacing:content:)` (iOS 26+) — `spacing` controls how close two shapes get before they visually merge into one. **Match the container spacing to the inner stack's spacing** or shapes merge at rest unexpectedly.

For appear/disappear morphing, each element gets a `glassEffectID(_:in:)` (iOS 26+) in a shared `Namespace`, and the state change must be wrapped in `withAnimation`:

```swift
@State private var isExpanded = false
@Namespace private var ns

GlassEffectContainer(spacing: 40) {
    HStack(spacing: 40) {
        Image(systemName: "scribble.variable")
            .frame(width: 80, height: 80)
            .glassEffect()
            .glassEffectID("pencil", in: ns)
        if isExpanded {
            Image(systemName: "eraser.fill")
                .frame(width: 80, height: 80)
                .glassEffect()
                .glassEffectID("eraser", in: ns)
        }
    }
}
Button("Toggle") { withAnimation { isExpanded.toggle() } }
    .buttonStyle(.glass)
```

Two related modifiers:

- `glassEffectUnion(id:namespace:)` (iOS 26+) — merges several views into **one** glass capsule *at rest* (same shape + effect + id). Useful for clusters that should read as a single surface, including views generated dynamically outside the main stack.
- `glassEffectTransition(_:)` (iOS 26+) — picks the add/remove transition. `GlassEffectTransition` cases: `.matchedGeometry` (default; morphs nearby shapes), `.materialize` (simpler fade for distant shapes — pair with `withAnimation`), `.identity`.

Keep the total count of glass effects and containers on screen modest — each one costs GPU work, and too many degrade performance noticeably.

## Buttons

Two glass button styles (iOS 26+):

- `.buttonStyle(.glass)` — standard glass button, the default border artwork.
- `.buttonStyle(.glassProminent)` — filled/prominent glass for the **primary** action.

```swift
Button("Save") { save() }.buttonStyle(.glassProminent)
Button("Cancel") { dismiss() }.buttonStyle(.glass)
```

## Toolbars, tab bars, accessories

These standard structures get Liquid Glass automatically, but a few modifiers let you shape the chrome.

**Toolbar grouping.** `ToolbarSpacer` (iOS 26+) breaks the shared glass background into separate capsules; `sharedBackgroundVisibility(.hidden)` (iOS 26+) on a `ToolbarItem` pulls it out into its own capsule.

```swift
.toolbar {
    ToolbarItem { ShareLink(item: url) }
    ToolbarSpacer(.fixed)
    ToolbarItem { FavoriteButton() }
    ToolbarItem { CollectionsButton() }
    ToolbarSpacer(.flexible)
    ToolbarItem { InspectorToggle() }
        .sharedBackgroundVisibility(.hidden)   // its own capsule
}
```

**Floating tab bar (iPhone).** The iOS 26 tab bar floats and can collapse on scroll. Use standard `TabView` + `Tab` so the system supplies styling, minimize behavior, and accessory placement — don't hand-roll it.

```swift
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab(role: .search) { SearchView() }        // dedicated search role; system places it
}
.tabBarMinimizeBehavior(.onScrollDown)         // .onScrollUp / .automatic / .never
.tabViewBottomAccessory {
    NowPlayingBar()   // read \.tabViewBottomAccessoryPlacement inside to adapt compact vs full
}
```

`\.tabViewBottomAccessoryPlacement` (environment, iOS 26+) tells the accessory whether it's `.inline` or expanded so it can adapt its own layout. For toolbar search collapse, `searchToolbarBehavior(.minimize)` (iOS 26+) folds a search field into a glass button; `DefaultToolbarItem(kind: .search, placement: .bottomBar)` provides a system search item. See `ipad.md` for `NavigationSplitView` toolbar behavior on larger screens.

## Edge-to-edge content and concentric corners

**Bleed content under the glass chrome.** `backgroundExtensionEffect()` (iOS 26+) extends an image/content beyond the safe area with a mirrored, blurred fill — the edge-to-edge look Apple uses behind floating bars. `scrollEdgeEffectStyle(_:for:)` (iOS 26+) tunes the blur/fade where content scrolls under bars: styles `.automatic` / `.soft` / `.hard`, edges via `.top` / `.bottom`.

**Concentric corners.** Never hardcode a corner radius on a control that sits inside a container or near the screen edge. Use `.rect(corner: .containerConcentric)` (iOS 26+) so the control's corners stay concentric with its container and the device's rounded display corners across every screen size.

```swift
Image("hero").resizable().scaledToFill()
    .backgroundExtensionEffect()

CustomControl()
    .background(.tint, in: .rect(corner: .containerConcentric))
```

## The temporary opt-out

`UIDesignRequiresCompatibility` — an `Info.plist` Boolean. Setting it `YES` opts the **entire app** (not a single screen) out of the Liquid Glass redesign and keeps the iOS 18-style appearance. It exists only as a short migration buffer: it's **deprecated and removed with iOS 27 / Xcode 27**, where Liquid Glass becomes mandatory. Use it to buy a release cycle, never as a permanent answer.

## iOS 27 refinements (pre-GA)

Everything in this section is **pre-GA** — announced at WWDC 2026 (June 8, 2026), developer beta only, shipping fall 2026. API names and behavior may change before GA; verify against `developer.apple.com` before relying on any of it. See `versions-and-sources.md` for the version timeline.

- **Second iteration of the material** — updated design tokens and material guidelines refining legibility and contrast.
- **User-facing transparency slider** in Settings (clear ↔ opaque). Your custom glass tints respond automatically — meaning you can **no longer assume a fixed opacity**. Design tints to stay legible across the whole slider range.
- **`appearsActive` environment value** (reported) — dim custom glass when a window/scene is inactive, matching how iPad windows dim when inactive.
- **Liquid Glass becomes effectively mandatory** — the `UIDesignRequiresCompatibility` opt-out is removed (or no-op'd; not yet confirmed in a primary Apple doc).

## Pitfalls

- **Glass on glass — the #1 mistake.** Glass can't sample other glass; nesting `glassEffect` inside glass chrome looks muddy and breaks the material. Put fills or vibrancy *on top of* glass, never more glass.
- **Glass in the content layer.** Don't make list rows or large content surfaces glass. Glass is the navigation/control layer only; content stays opaque so hierarchy reads.
- **Forgetting `GlassEffectContainer`** around multiple glass views — you lose correct light sampling, shape blending, and morphing, and you hurt performance.
- **Over-tinting.** Tinting every element kills hierarchy. Reserve `.tint` for the single primary action.
- **`.clear` where `.regular` belongs.** `.clear` is non-adaptive and can go illegible; only over bright, media-rich backgrounds with your own dimming layer.
- **Mismatched container spacing.** A `GlassEffectContainer` spacing larger than the inner stack's spacing makes shapes merge at rest unexpectedly.
- **`glassEffect` applied before layout modifiers.** It captures the resolved shape; padding/frame after it won't be refracted. Apply glass last.
- **Hardcoded corner radii** instead of `.containerConcentric` — controls won't stay concentric across device sizes.
- **Fighting the new look with leftovers** — stray `.toolbarBackground`, custom blur stacks, or `Material` backgrounds behind sheets and bars. Remove them; iOS 26 renders chrome backgrounds automatically.
- **Re-implementing accessibility.** Reduce Transparency (frostier), Increase Contrast (black/white with borders), and Reduce Motion (no elastic effects) are honored **automatically only if you use the standard material**. Hand-rolled blur gets none of it.
- **Treating `UIDesignRequiresCompatibility` as permanent** — it's app-wide, can't target one screen, and is gone in iOS 27.
- **Assuming a fixed opacity under iOS 27 (pre-GA)** — the user transparency slider moves it; don't rely on the opt-out surviving either.

## Primary sources

- Liquid Glass — Apple Technology Overviews: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Applying Liquid Glass to custom views — SwiftUI: https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- GlassEffectContainer — SwiftUI reference: https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- glassEffectUnion(id:namespace:) — SwiftUI reference: https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:)
- Meet Liquid Glass — WWDC25 session 219: https://developer.apple.com/videos/play/wwdc2025/219/
- Build a SwiftUI app with the new design — WWDC25 session 323: https://developer.apple.com/videos/play/wwdc2025/323/
- Materials — Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/materials
- Landmarks: Building an app with Liquid Glass — Apple sample code: https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass
