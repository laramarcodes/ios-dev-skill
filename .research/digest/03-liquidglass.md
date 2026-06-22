# DOMAIN: Liquid Glass design system (SwiftUI adoption) — iOS 26 / iPadOS 26, with iOS 27 (pre-GA) refinements

## Orientation
 Liquid Glass is the headline iOS 26 redesign: a single dynamic "material" — combining the optical properties of glass (lensing/refraction, specular highlights, adaptive light/dark) with liquid fluidity — that the system applies to the *navigation layer* floating above your content. The single most important mental model: glass belongs to controls and chrome (tab bars, toolbars, nav bars, buttons, sliders, sheets), NOT to the content layer, and you must never stack glass on glass. The biggest win is that it's mostly free: standard SwiftUI components (TabView, NavigationStack/NavigationSplitView, .toolbar, sheets, Button, Slider, Menu) automatically pick up Liquid Glass the moment you build against the iOS 26 SDK in Xcode 26 — no code changes. For custom views you opt in with the glassEffect(_:in:) modifier, group related glass in a GlassEffectContainer, and morph elements with glassEffectID + a Namespace. There are exactly two variants — .regular (the default, adaptive, use almost always) and .clear (more transparent, only over bright media-rich content). A temporary escape hatch, the UIDesignRequiresCompatibility Info.plist key, opts the whole app out for one release cycle, but it's deprecated and goes away with iOS 27, where Liquid Glass becomes mandatory and gains a user-facing system transparency slider your tints respond to automatically.

## Key facts
- [iOS 26|high] Liquid Glass is a new dynamic material introduced across all Apple platforms (iOS/iPadOS/macOS Tahoe/watchOS/tvOS/visionOS 26) that combines the optical properties of glass with fluidity; standard SwiftUI/UIKit/AppKit controls and navigation elements pick up its appearance and behavior automatically.
- [iOS 26|high] You adopt Liquid Glass by simply building your app in the latest Xcode (26) — standard app structures (TabView, NavigationSplitView, .toolbar, sheets) restyle automatically. Most enhancements apply with no code changes.
- [iOS 26|high] There are exactly two glass variants: Glass.regular (default — adaptive, legible over any content, works at any size) and Glass.clear (permanently more transparent, NOT adaptive, needs a dimming layer; only use over media-rich content with bold/bright foreground). Never mix variants.
- [iOS 26|high] glassEffect(_:in:) defaults to the .regular variant inside a Capsule shape (DefaultGlassEffectShape). Apply it AFTER other appearance-affecting modifiers.
- [iOS 26|high] Glass cannot sample (refract) other glass — this is why GlassEffectContainer exists: it groups multiple glass shapes into one for correct sampling, blending/morphing, and best rendering performance. Limit total on-screen glass effects and containers; too many degrade performance.
- [iOS 26|high] Liquid Glass is best reserved for the navigation layer floating above content; keep content (e.g. table views/lists) in the content layer. Always avoid glass on glass. Use tinting selectively to highlight primary actions — if everything is tinted, nothing stands out.
- [iOS 26|high] Accessibility settings adjust Liquid Glass automatically when you use the standard material: Reduce Transparency makes it frostier/more opaque, Increase Contrast makes elements predominantly black/white with a contrasting border, Reduce Motion disables elastic/dynamic effects.
- [iOS 26 (temporary)|high] Set Info.plist key UIDesignRequiresCompatibility = YES to opt the entire app out of the Liquid Glass redesign and keep the iOS 18-style appearance. It is app-wide (not per-screen), available only temporarily, and is deprecated/removed with iOS 27 / Xcode 27.
- [iOS 26|high] iPhone tab bars float and can minimize on scroll via .tabBarMinimizeBehavior(.onScrollDown); attach persistent controls (e.g. a now-playing bar) above it with .tabViewBottomAccessory{} and read \.tabViewBottomAccessoryPlacement to adapt compact vs full layout.
- [iOS 26|high] backgroundExtensionEffect() extends an image/content beyond the safe area with a mirrored+blurred fill (edge-to-edge look); scrollEdgeEffectStyle(_:for:) tunes the blur/fade where content scrolls under bars (.automatic/.soft/.hard).
- [iOS 26|high] Concentricity: use a rounded rectangle with corner radius .containerConcentric (RoundedRectangle / .rect(corner: .containerConcentric)) so custom control corners stay concentric with their container and the device's rounded display corners across screen sizes.
- [iOS 27 (pre-GA, may change)|medium] iOS 27 (announced WWDC 2026, June 8 2026, developer beta): Liquid Glass gets a second iteration with updated design tokens/material guidelines; a user-facing system transparency slider (clear↔opaque) in Settings that your glass tints respond to automatically; Liquid Glass becomes effectively mandatory (compatibility opt-out removed).

## APIs
- `glassEffect(_:in:)` (modifier; iOS 26+) — func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View. Core entry point for custom glass.
- `Glass` (struct; iOS 26+) — The material config value. .regular (default) and .clear variants; chainable: .regular.tint(.orange).interactive().
- `Glass.regular` (property; iOS 26+) — Adaptive default variant — legible over any content, any size.
- `Glass.clear` (property; iOS 26+) — Permanently transparent, non-adaptive; only over bright media-rich content, needs dimming layer.
- `Glass.tint(_:)` (modifier; iOS 26+) — Returns a tinted Glass; tones map to content brightness. Use selectively for prominence.
- `Glass.interactive(_:)` (modifier; iOS 26+) — func interactive(_ isEnabled: Bool = true) -> Glass. Adds touch/pointer reactions (scale, shimmer, glow) to custom glass — same feel as .glass buttons.
- `GlassEffectContainer` (struct; iOS 26+) — GlassEffectContainer(spacing:content:). Groups glass for correct sampling, shape blending, morphing, and performance. Larger spacing → shapes merge sooner.
- `glassEffectID(_:in:)` (modifier; iOS 26+) — func glassEffectID(_ id: (some Hashable & Sendable)?, in namespace: Namespace.ID) -> some View. Identity for morph transitions inside a container; only affects content during hierarchy transitions/animations.
- `glassEffectUnion(id:namespace:)` (modifier; iOS 26+) — func glassEffectUnion(id: (some Hashable & Sendable)?, namespace: Namespace.ID) -> some View. Merges several views into ONE glass capsule at rest (same shape+effect+id). Useful for dynamic/outside-stack views.
- `glassEffectTransition(_:)` (modifier; iOS 26+) — func glassEffectTransition(_ transition: GlassEffectTransition) -> some View. Chooses add/remove transition style for glass in a container.
- `GlassEffectTransition` (struct; iOS 26+) — Cases: .matchedGeometry (default, morphs nearby shapes), .materialize (simpler fade-in/out for distant shapes, pair with withAnimation), .identity.
- `DefaultGlassEffectShape` (struct; iOS 26+) — The default capsule shape used by glassEffect when no shape is given.
- `buttonStyle(.glass)` (modifier; iOS 26+) — GlassButtonStyle — standard glass button border artwork.
- `buttonStyle(.glassProminent)` (modifier; iOS 26+) — GlassProminentButtonStyle — prominent/filled glass button for primary actions.
- `tabBarMinimizeBehavior(_:)` (modifier; iOS 26+) — Floating iPhone tab bar collapse behavior, e.g. .onScrollDown / .onScrollUp / .automatic / .never.
- `tabViewBottomAccessory(_:)` (modifier; iOS 26+) — Persistent accessory view above the tab bar that adapts to its collapse state.
- `tabViewBottomAccessoryPlacement` (property; iOS 26+) — Environment value (\.tabViewBottomAccessoryPlacement); .inline vs expanded so the accessory can adapt layout.
- `Tab(role: .search)` (type; iOS 26+) — Dedicated search tab role; system places it appropriately in the floating tab bar.
- `backgroundExtensionEffect()` (modifier; iOS 26+) — Extends content beyond safe area with mirrored/blurred fill for edge-to-edge layouts under glass chrome.
- `scrollEdgeEffectStyle(_:for:)` (modifier; iOS 26+) — Tunes the scroll-edge blur/fade under bars; styles .automatic/.soft/.hard, edges via .top/.bottom etc.
- `containerConcentric` (modifier; iOS 26+) — Corner style for RoundedRectangle/.rect(corner:) so custom controls stay concentric with their container and device corners.
- `ToolbarSpacer` (struct; iOS 26+) — ToolbarSpacer(.fixed|.flexible, placement:) — visually groups toolbar items into separate glass capsules.
- `sharedBackgroundVisibility(_:)` (modifier; iOS 26+) — .sharedBackgroundVisibility(.hidden) on a ToolbarItem removes it from the shared glass background (own capsule).
- `DefaultToolbarItem` (struct; iOS 26+) — e.g. DefaultToolbarItem(kind: .search, placement: .bottomBar) — system-provided toolbar items.
- `searchToolbarBehavior(_:)` (modifier; iOS 26+) — .searchToolbarBehavior(.minimize) collapses the search field into a toolbar glass button.
- `navigationTransition(.zoom(sourceID:in:))` (modifier; iOS 18+ (used heavily with new design)) — Pairs with matchedTransitionSource(id:in:) for zoom morph from a glass control into a sheet/detail.
- `UIDesignRequiresCompatibility` (macro; iOS 26 only (deprecated for iOS 27)) — Info.plist Boolean key (YES) to opt the whole app out of Liquid Glass. App-wide, temporary, removed in Xcode 27.

## Patterns

### Glass on a custom view (regular, tinted, interactive)  — You have a bespoke control/badge that should read as a floating glass element.
Default capsule is right for small pills; switch to .rect(cornerRadius:) for larger surfaces. Apply glassEffect AFTER layout/appearance modifiers. Reserve tint for primary actions only.
```swift
Label("Desert", systemImage: "sun.max.fill")
    .padding()
    .glassEffect()                       // .regular in a Capsule

Button("Get Started") { start() }
    .padding()
    .glassEffect(.regular.tint(.orange).interactive(),
                 in: .rect(cornerRadius: 16))
```

### Container + morphing transition  — Multiple glass elements that should blend at rest and morph as they appear/disappear.
Match container spacing to the inner stack spacing to control when shapes merge. Each morphing element needs a glassEffectID in a shared Namespace, and the state change must be inside withAnimation.
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

### Floating tab bar that minimizes, with a now-playing accessory  — A media/browse app on iPhone that wants the iOS 26 floating tab bar.
Use standard TabView + Tab so the system supplies the glass styling, minimize behavior, and accessory placement for free. Don't hand-roll a glass bar.
```swift
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab(role: .search) { SearchView() }
}
.tabBarMinimizeBehavior(.onScrollDown)
.tabViewBottomAccessory {
    NowPlayingBar()   // read \.tabViewBottomAccessoryPlacement inside to adapt
}
```

### Grouped toolbar items in separate glass capsules  — You want logical groups of toolbar buttons separated visually.
ToolbarSpacer breaks the shared glass background into separate capsules; sharedBackgroundVisibility(.hidden) pulls a single item out of the shared background.
```swift
.toolbar {
    ToolbarItem { ShareLink(item: url) }
    ToolbarSpacer(.fixed)
    ToolbarItem { FavoriteButton() }
    ToolbarItem { CollectionsButton() }
    ToolbarSpacer(.flexible)
    ToolbarItem { InspectorToggle() }
        .sharedBackgroundVisibility(.hidden)  // its own capsule
}
```

### Edge-to-edge content under glass chrome + concentric custom control  — Hero imagery should bleed under bars, and custom controls should match device corners.
backgroundExtensionEffect gives the mirrored/blurred bleed Apple uses behind glass. containerConcentric keeps corner radii harmonious with the container and the screen's rounded corners — never hardcode a radius.
```swift
Image("hero").resizable().scaledToFill()
    .backgroundExtensionEffect()

CustomControl()
    .background(.tint, in: .rect(corner: .containerConcentric))
```

## Pitfalls
- Stacking glass on glass — the #1 mistake. Glass cannot sample other glass; nesting glassEffect inside glass chrome looks muddy and breaks the material. Put fills/vibrancy on top of glass instead, not more glass.
- Putting glass in the content layer (e.g. making list rows or large content surfaces glass). Glass is for the navigation/control layer only; content stays opaque so hierarchy reads clearly.
- Forgetting GlassEffectContainer around multiple glass views — you lose correct light sampling, shape blending, and morphing, and you hurt performance.
- Over-tinting. Tinting every glass element kills the hierarchy; reserve tint for the single primary action.
- Using .clear where you should use .regular. .clear is non-adaptive and can become illegible; it's only for bright, media-rich backgrounds with a dimming layer.
- Mismatched spacing: a GlassEffectContainer spacing larger than the inner HStack/VStack spacing makes shapes merge at rest unexpectedly.
- Hardcoding corner radii instead of .containerConcentric — controls won't stay concentric across device sizes.
- Manually fighting the new look with leftover .toolbarBackground / custom blur stacks / Material backgrounds behind sheets and bars — remove them; iOS 26 handles chrome backgrounds automatically.
- Treating UIDesignRequiresCompatibility as a permanent solution — it's app-wide, can't target one screen, and is removed in iOS 27. Use it only as a short migration buffer.
- Re-implementing accessibility yourself — Reduce Transparency / Increase Contrast / Reduce Motion are honored automatically only if you use the standard material; custom hand-rolled blur won't get them.
- Assuming you must rewrite the app. You mostly get the redesign free by building with Xcode 26; only custom UI needs glassEffect adoption.
- iOS 27 caveat (pre-GA): the user transparency slider means you cannot assume a fixed opacity; design tints to remain legible across the slider range, and don't rely on the compatibility opt-out surviving.

## iOS 26 changes
- Liquid Glass material introduced; standard SwiftUI controls, tab bars, toolbars, nav bars, sheets, sliders, menus restyle automatically when built with Xcode 26.
- New custom-glass APIs: glassEffect(_:in:), GlassEffectContainer, glassEffectID, glassEffectUnion, glassEffectTransition, Glass(.regular/.clear/.tint/.interactive), DefaultGlassEffectShape.
- New button styles .glass / .glassProminent; floating tab bar with tabBarMinimizeBehavior and tabViewBottomAccessory; ToolbarSpacer + sharedBackgroundVisibility for toolbar grouping.
- backgroundExtensionEffect, scrollEdgeEffectStyle, and concentric corners (.containerConcentric) for edge-to-edge content and hardware-harmonious controls.

## iOS 27 preview (pre-GA)
- Liquid Glass second iteration: updated design tokens and material guidelines refining legibility/contrast. | Developer beta, announced WWDC 2026; details may change before GA.
- User-facing system Liquid Glass transparency slider (clear↔opaque) in Settings; custom glass tints respond automatically. | Pre-GA; confirm exact behavior and any new API before relying on it.
- appearsActive environment value to dim custom glass when a window/scene is inactive (iPad windows dim when inactive). | Secondary source paraphrasing WWDC 2026; verify against Apple docs when published.
- Liquid Glass effectively mandatory in iOS 27 — the UIDesignRequiresCompatibility opt-out is removed. | Pre-GA expectation; confirm with Apple release notes at GA.

## Deprecations
- UIDesignRequiresCompatibility (Info.plist opt-out) is a temporary iOS 26 affordance, deprecated and removed with iOS 27 / Xcode 27 — Liquid Glass becomes mandatory.
- Old idiom: custom .toolbarBackground colors / Material blur stacks / manual backgrounds behind sheets and bars. New idiom: let standard components render their own Liquid Glass chrome; remove the custom backgrounds.
- Hardcoded corner radii on controls → replaced by concentric corners via .rect(corner: .containerConcentric).
- Hand-rolled floating bottom bars / now-playing bars → replaced by standard TabView + tabViewBottomAccessory and tabBarMinimizeBehavior.

## Uncertainties
- Exact iOS 27 / Xcode 27 Liquid Glass API names (any new modifiers beyond appearsActive) are not yet confirmed from primary Apple docs — current iOS 27 facts come from secondary WWDC 2026 coverage and Apple Newsroom, not framework reference pages.
- Whether UIDesignRequiresCompatibility is fully removed vs merely no-op'd in iOS 27 is reported by secondary sources; not yet verified in an Apple primary doc.
- The precise enum case spellings for scrollEdgeEffectStyle (.automatic/.soft/.hard) and tabBarMinimizeBehavior were taken from the WWDC25 session transcript/fetch and secondary corroboration rather than a fully rendered Apple reference page; worth a final cross-check against developer.apple.com before copying into a skill.
- Adopting Liquid Glass technology-overview page was JS-rendered and not fully captured; the automatic-vs-manual adoption split here is synthesized from the Liquid Glass overview page + WWDC25 session 323 migration guidance.

## Sources
- Liquid Glass — Apple Technology Overviews: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Applying Liquid Glass to custom views — SwiftUI (Apple Developer Documentation): https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- GlassEffectContainer — SwiftUI reference: https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- GlassEffectTransition — SwiftUI reference: https://developer.apple.com/documentation/swiftui/glasseffecttransition
- glassEffectUnion(id:namespace:) — SwiftUI reference: https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:)
- Meet Liquid Glass — WWDC25 session 219: https://developer.apple.com/videos/play/wwdc2025/219/
- Build a SwiftUI app with the new design — WWDC25 session 323: https://developer.apple.com/videos/play/wwdc2025/323/
- Get to know the new design system — WWDC25 session 356: https://developer.apple.com/videos/play/wwdc2025/356/
- Materials — Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/materials
- Adopting Liquid Glass — Apple Technology Overviews: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- Landmarks: Building an app with Liquid Glass — Apple sample code: https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass
- Opting your app out of the Liquid Glass redesign with Xcode 26 — Donny Wals: https://www.donnywals.com/opting-your-app-out-of-the-liquid-glass-redesign-with-xcode-26/
- WWDC26: What's New in SwiftUI — A Developer's Breakdown (iOS 27): https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333
- Apple Liquid Glass iOS 27: WWDC 2026 refinements (TechTimes): https://www.techtimes.com/articles/317975/20260608/apple-liquid-glass-ios-27-wwdc-2026-brings-refinements-developers-must-adopt-today.htm
- Apple finally brings the slider for Liquid Glass and many other changes (Neowin, iOS 27): https://www.neowin.net/news/apple-finally-brings-the-slider-for-liquid-glass-and-many-other-changes/
