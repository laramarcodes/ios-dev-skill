# DOMAIN: Apple HIG, design craft (Liquid Glass era) & accessibility for iOS/iPadOS SwiftUI

## Orientation
 iOS 26 (shipping, the current release as of June 2026) introduced Liquid Glass — a system-wide "dynamic material" forming a distinct functional layer for controls and navigation that floats above content, with optical glass + fluidity. The single biggest practical truth: if you use standard SwiftUI components (NavigationStack, TabView, .toolbar, Button, List, sheets) and rebuild against the iOS 26 SDK, your app adopts the new look automatically — the design work is mostly about REMOVING custom backgrounds/effects that now fight the system, not adding glass everywhere. Apply glassEffect to custom views sparingly and only on the most important functional elements. Design craft in this era is governed by the updated Human Interface Guidelines: SF Pro typeface + named Dynamic Type text styles, semantic system colors that auto-adapt to dark mode / Increase Contrast, SF Symbols with four rendering modes, layered Liquid Glass app icons authored in Icon Composer, 44pt minimum hit targets, and concentric rounded shapes. Accessibility is a first-class craft, not an afterthought: Dynamic Type support, VoiceOver labels/values/traits/rotors, the Reduce Motion / Reduce Transparency / Increase Contrast / Differentiate Without Color environment values, and automated Xcode accessibility audits (performAccessibilityAudit). iOS 27 / Xcode 27 were announced at WWDC 2026 (week of June 8) and are in developer beta (pre-GA) — they refine Liquid Glass, add SF Symbols 8, AI-assisted localization, and SwiftUI toolbar/document APIs, but treat all iOS 27 facts as subject to change.

## Key facts
- [iOS 26|high] Liquid Glass is a system-wide dynamic material introduced in iOS 26 that combines the optical properties of glass with fluidity, forming a distinct functional layer for controls and navigation that floats above the content layer. Standard SwiftUI/UIKit/AppKit components adopt it automatically when you rebuild against the latest SDK.
- [iOS 26|high] To adopt Liquid Glass on custom views, use the SwiftUI modifier glassEffect(_:in:); combine multiple glass shapes inside a GlassEffectContainer for correct morphing and rendering performance. UIKit equivalent is UIGlassEffect; AppKit is NSGlassEffectView.
- [iOS 26|high] Liquid Glass button styles: SwiftUI .buttonStyle(.glass) and .glassProminent (PrimitiveButtonStyle.glass / .glassProminent). UIKit: UIButton.Configuration.glass(), .prominentGlass(), .clearGlass(), .prominentClearGlass(). 'Avoid overusing Liquid Glass effects' — limit to the most important functional elements.
- [iOS 26|high] Liquid Glass automatically adapts to accessibility settings: Reduced Transparency makes it frostier/more opaque, Increased Contrast makes elements predominantly black or white with contrasting borders, and Reduced Motion decreases effect intensity. These adaptations are automatic ONLY for standard system components — you must test custom elements, colors, and animations against each setting.
- [iOS 26|high] You can ship against the latest SDK while keeping the pre-Liquid-Glass appearance by adding the UIDesignRequiresCompatibility key to the Info.plist — an opt-out escape hatch, not a long-term strategy.
- [iOS 26|high] Minimum tap/hit target on iOS & iPadOS is 44x44 pt (default), with an absolute minimum control size of 28x28 pt. Add ~12 pt padding around bezeled elements and ~24 pt around bezel-less elements to avoid mis-taps.
- [iOS 26|high] iOS/iPadOS default body text size is 17 pt; the recommended minimum text size is 11 pt. SF Pro is the system font; New York (NY) is the system serif. SF Pro Rounded and a monospaced variant are also available.
- [iOS 26|high] WCAG AA color-contrast minimums Apple's Accessibility Inspector enforces: 4.5:1 for text up to 17pt, 3:1 for text 18pt+, and 3:1 for any bold text. Check contrast in BOTH light and dark appearances.
- [iOS 26|high] App icons in iOS 26 are layered Liquid Glass icons authored in Icon Composer (single layered .icon file). The system applies reflection, refraction, shadow, blur, and highlights automatically; you supply foreground/middle/background layers. iOS/iPadOS/macOS offer default (light), dark, clear, and tinted appearance variants. Icon Composer ships with Xcode 26 / requires recent macOS.
- [iOS 26 (SF Symbols 8 = iOS 27, pre-GA)|high] SF Symbols has four rendering modes set via .symbolRenderingMode(_:): .monochrome, .hierarchical, .palette, and .multicolor. All support Variable Color (the Image(_:variableValue:) initializer). Symbols scale automatically with Dynamic Type. SF Symbols 8 (7,000+ symbols) was announced at WWDC 2026.
- [iOS 26|high] Section headers in lists/tables/forms now use title-style capitalization automatically (no longer all-caps). Update header strings to title case to match. Use the .grouped form style for automatic layout metrics.
- [iOS 26|high] For custom toolbars/bars over scrolling content, register views for the scroll edge effect with safeAreaBar(edge:alignment:spacing:content:) (SwiftUI) or UIScrollEdgeElementContainerInteraction (UIKit). System bars get it for free.
- [iOS 26|high] Use concentric rounded shapes to nest controls in their containers: ConcentricRectangle and Shape.rect(corners:isUniform:) in SwiftUI; UICornerConfiguration in UIKit. Hardware corner radius informs control curvature.
- [iOS 26|high] Mark the search tab with Tab(role: .search) (SwiftUI) / UISearchTab (UIKit) so the system places it at the trailing end. Adapt tab bars to sidebars with .tabViewStyle(.sidebarAdaptable). Minimize the tab bar on scroll with .tabBarMinimizeBehavior(.onScrollDown).
- [iOS 26|high] Always provide an accessibility label for every icon-only control via .accessibilityLabel(_:) — even when no text is shown — so VoiceOver and Voice Control users get the information. This is explicitly required by the toolbar/icon guidance.
- [since iOS 17 / Xcode 15|high] performAccessibilityAudit (XCUIApplication.performAccessibilityAudit(for:_:)) runs the same checks as Accessibility Inspector inside a UI test and auto-fails on issues with no manual assertions; filter false positives via the issue handler closure. Audit types include contrast, dynamic type, hit-region, element detection, and trait conflicts.
- [since Xcode 15|high] String Catalogs (.xcstrings) are the modern localization container (introduced Xcode 15, superseding .strings/.stringsdict). Any string literal in SwiftUI is automatically localizable and extracted to Localizable.xcstrings. Plurals are handled with 'Vary by Plural' in the catalog editor; AttributedString is fully localizable via localized: initializers.
- [iOS 26|high] VoiceOver rotor support: SwiftUI uses AccessibilityRotorEntry / .accessibilityRotor(_:); UIKit uses UIAccessibilityCustomRotor; AppKit uses NSAccessibilityCustomRotor. Group related elements so VoiceOver reads them together (.accessibilityElement(children: .combine) or shouldGroupAccessibilityChildren).
- [iOS 26|high] Key accessibility environment values to branch on: @Environment(\.accessibilityReduceMotion), \.accessibilityReduceTransparency, \.colorSchemeContrast (.standard vs .increased), \.accessibilityDifferentiateWithoutColor, and \.accessibilityVoiceOverEnabled.
- [iOS 27 (pre-GA, subject to change)|medium] iOS 27 / Xcode 27 (announced WWDC 2026, pre-GA): SF Symbols 8, a new SwiftUI Document API, expanded toolbar controls (visibilityPriority, toolbarOverflowMenu, topBarPinnedTrailing), drag-to-reorder/swipe in any container, ~2x faster nested-layout resize, AI-assisted app translation in Xcode, and HIG updates for Design Principles, Siri, and Snippets.

## Patterns

### Apply Liquid Glass to a custom view (sparingly, in a container)  — You have a genuinely custom control or floating accent that should read as the system material — not for every button (standard buttons already get it).
glassEffect(_:in:) defaults to a Capsule shape; pass an explicit shape (.circle, .rect(cornerRadius:)). Use .regular for most cases. Always wrap multiple glass shapes in GlassEffectContainer for correct morphing + performance. Do NOT stack glass on glass.
```swift
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        Image(systemName: "heart.fill")
            .padding(12)
            .glassEffect(.regular, in: .circle)
        Image(systemName: "star.fill")
            .padding(12)
            .glassEffect(.regular.interactive(), in: .circle)
    }
}
```

### Liquid Glass buttons without custom code  — You want a primary/secondary action to read as Liquid Glass.
Prefer these over hand-rolled glass. Be judicious with .tint on glass controls so content shines through and legibility holds.
```swift
Button("Save") { save() }
    .buttonStyle(.glassProminent)   // prominent / tinted action

Button("Cancel") { dismiss() }
    .buttonStyle(.glass)            // standard glass
```

### Support Dynamic Type correctly  — Always. Every piece of text should scale with the user's preferred size.
Use the named text styles (.largeTitle, .title/.title2/.title3, .headline, .subheadline, .body, .callout, .footnote, .caption/.caption2) instead of fixed point sizes. Use @ScaledMetric for any hard-coded dimension that sits next to text. Test at the largest accessibility sizes (AX1–AX5); keep truncation to a minimum and let layouts reflow vertically.
```swift
Text("Welcome")
    .font(.largeTitle)        // named text style = free Dynamic Type

// Scale custom metrics (spacing, image sizes) with the text
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24
Image(systemName: "bell")
    .frame(width: iconSize, height: iconSize)
```

### Semantic colors that auto-adapt to dark mode and Increase Contrast  — Any foreground/background color — avoid hard-coded hex for UI chrome.
System-defined colors (.primary/.secondary/.tertiary/.quaternary, Color(.systemBackground), .systemGroupedBackground, .systemRed, etc.) ship accessible variants that adapt automatically to Dark Mode and Increase Contrast. If you must use a custom color, define light + dark + an increased-contrast variant in the asset catalog.
```swift
Text("Title").foregroundStyle(.primary)
Text("Subtitle").foregroundStyle(.secondary)
VStack { /* ... */ }
    .background(Color(.systemGroupedBackground))
    .tint(.accentColor)
```

### VoiceOver: label, value, traits, and grouping  — Custom controls, composite cells, icon-only buttons, and meaningful images.
Label = what it is; Value = current state; Hint = what happens (used sparingly); Traits via .accessibilityAddTraits(.isButton/.isHeader/.isSelected). Use .accessibilityElement(children: .combine) to merge a cell into one swipe stop. Hide purely decorative images.
```swift
// Icon-only button
Button(action: favorite) { Image(systemName: "star") }
    .accessibilityLabel("Add to favorites")

// Composite cell read as one element
HStack { thumbnail; VStack { Text(name); Text(subtitle) } }
    .accessibilityElement(children: .combine)
    .accessibilityHint("Opens details")

// Decorative image — hide it
Image("texture").accessibilityHidden(true)
```

### Replace a complex custom control's a11y with a known one  — You built a custom slider/gauge and want VoiceOver's adjustable behavior for free.
accessibilityRepresentation(representation:) swaps the accessibility tree for a standard control so VoiceOver applies the correct label/value/adjustable actions without you re-implementing them.
```swift
MyCustomSlider(value: $volume)
    .accessibilityRepresentation {
        Slider(value: $volume, in: 0...1) { Text("Volume") }
    }
```

### Honor Reduce Motion / Increase Contrast  — Whenever you add custom animation or contrast-sensitive visuals.
Branch animations on accessibilityReduceMotion (prefer cross-fades over motion); strengthen borders/contrast when colorSchemeContrast == .increased; check accessibilityReduceTransparency before relying on translucency; pair color with shape/icon when accessibilityDifferentiateWithoutColor is on.
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.colorSchemeContrast) private var contrast

withAnimation(reduceMotion ? nil : .spring) { expand.toggle() }
let border = contrast == .increased ? 2.0 : 0.0
```

### Automated accessibility audit in a UI test  — CI / regression — catch contrast, hit-size, dynamic-type, and missing-label issues automatically.
Add per-screen. Filter known false positives by passing an audit-type set and a handler that returns false to ignore specific issues. Complement with the Accessibility Inspector (Xcode > Open Developer Tool) and on-device VoiceOver testing — audits don't replace manual VoiceOver use.
```swift
func testAccessibility() throws {
    let app = XCUIApplication()
    app.launch()
    try app.performAccessibilityAudit()   // auto-fails on issues
}
```

### Localizable strings + plurals via String Catalog  — All user-facing text.
SwiftUI string literals are localizable for free. Use the catalog editor's 'Vary by Plural' for count-dependent strings (don't concatenate). AttributedString(localized:) keeps markdown/styling localizable. Right-to-left layout flips automatically when you use leading/trailing (never left/right).
```swift
Text("Welcome back")                 // auto-extracted to Localizable.xcstrings
Text("^[\\(count) item](inflect: true)") // or use 'Vary by Plural' in the catalog

let msg = AttributedString(localized: "**Bold** and _italic_")
```

## Pitfalls
- Applying glassEffect to many custom controls — Apple explicitly says use it sparingly and only on the most important functional elements; overuse distracts from content and looks subpar.
- Leaving custom backgrounds on navigation bars, tab bars, toolbars, split views, sheets, and popovers — these now fight Liquid Glass and the scroll edge effect. Remove them and let the system render the background.
- Hard-coding control layout metrics (sizes, corner radii) — this prevents automatic adoption of the new rounder shapes and sizing when rebuilding against the iOS 26 SDK.
- Using fixed point font sizes instead of named text styles — breaks Dynamic Type. Also forgetting @ScaledMetric for spacing/image sizes that sit beside text, so layouts don't scale proportionally.
- Icon-only buttons without .accessibilityLabel — invisible to VoiceOver/Voice Control. Required even though no text is shown.
- Relying on color alone to convey state (error/success) — fails for color-blind users; pair with shape/icon and honor accessibilityDifferentiateWithoutColor.
- Custom animations that ignore accessibilityReduceMotion — can cause dizziness/nausea; provide a cross-fade fallback.
- All-caps section headers — iOS 26 uses title-style capitalization; pre-formatted ALL-CAPS strings now look wrong.
- Assuming Liquid Glass accessibility adaptations apply to custom views — they're automatic ONLY for standard components; you must test custom elements against Reduce Transparency / Increase Contrast / Reduce Motion yourself.
- Using left/right edges/alignment instead of leading/trailing — breaks right-to-left (RTL) localization.
- Concatenating strings to build plurals or sentences — breaks translation and pluralization; use String Catalog 'Vary by Plural' and full localized strings with interpolation.
- Checking contrast only in light mode — Apple requires verifying minimum contrast in both light and dark appearances.
- Decorative images left visible to VoiceOver — adds noise; mark them .accessibilityHidden(true).

## iOS 26 changes
- Liquid Glass material introduced system-wide; standard components adopt it automatically on rebuild against the iOS 26 SDK.
- New SwiftUI APIs: glassEffect(_:in:), GlassEffectContainer, .buttonStyle(.glass/.glassProminent), backgroundExtensionEffect(), scroll edge effect via safeAreaBar(...), ConcentricRectangle, Tab(role: .search), .tabViewStyle(.sidebarAdaptable), .tabBarMinimizeBehavior(_:), ToolbarSpacer.
- Layered Liquid Glass app icons authored in Icon Composer with default/dark/clear/tinted appearance variants; system applies reflection/refraction/shadow/blur/highlights.
- Lists/tables/forms get larger row height + padding and increased section corner radius; section headers switch to title-style capitalization.
- New VoiceOver HIG page (March 2025) and split-out Dynamic Type guidance; Accessibility Nutrition Labels added to App Store Connect.
- Emphasized weights added to Dynamic Type style specifications for each platform (Dec 2025).
- UIDesignRequiresCompatibility Info.plist key added as an opt-out to retain pre-Liquid-Glass appearance while building on the new SDK.

## iOS 27 preview (pre-GA)
- SF Symbols 8 (7,000+ symbols). | Announced WWDC 2026; symbol count and new effects subject to change before GA.
- SwiftUI: new Document API, toolbar controls (visibilityPriority, toolbarOverflowMenu, topBarPinnedTrailing), drag-to-reorder/swipe in any container, ~2x faster nested layout resize, auto-caching AsyncImage. | Developer beta / pre-GA; APIs and names may change.
- AI-assisted app translation in Xcode 27 ('Translate your app using agents in Xcode'); Xcode 27 bundles on-device specialists for SwiftUI, accessibility, sizing, testing, performance. | Pre-GA; availability may vary by region/language.
- HIG updates for Design Principles, Siri, and Snippets; platform design refinements for consistency/readability/accessibility. | Stated as subject to change; some capabilities not available in all regions/languages.
- WWDC 2026 session 'Refine accessibility for custom controls' (session 220) — continued investment in custom-control accessibility. | Session content reflects pre-GA SDKs.

## Deprecations
- Flat/translucent-blur material chrome of iOS 18 and earlier → replaced by the Liquid Glass functional layer in iOS 26.
- Pre-iOS-26 single-image / single-layer app icons → replaced by layered Liquid Glass icons authored in Icon Composer (default/dark/clear/tinted variants).
- All-caps list/table/form section headers → now title-style capitalization automatically.
- Custom hand-built glass/blur backgrounds on bars, sheets, popovers → remove; rely on system Liquid Glass + scroll edge effect.
- Legacy .strings and .stringsdict files → superseded by String Catalogs (.xcstrings) since Xcode 15.
- .accessibility(label:) and the old .accessibility(...) modifier family → use the modern standalone modifiers .accessibilityLabel/.accessibilityValue/.accessibilityHint/.accessibilityAddTraits.
- Manual XCTest assertions for a11y issues → performAccessibilityAudit auto-detects and fails.

## Uncertainties
- Exact Liquid Glass variant API names: docs confirm a 'regular' variant (Glass.regular) and UIKit clearGlass()/prominentClearGlass(), strongly implying a 'clear' variant, but I did not fetch the SwiftUI Glass type reference to confirm the exact spelling of a '.clear' case and the .interactive()/.tint() modifier signatures — verify against the SwiftUI Glass / glassEffect reference before copying into a skill.
- Icon Composer's exact minimum macOS/Xcode version: one secondary source said 'macOS Tahoe 26.4+'; Apple's own page says 'latest version of Xcode' — treat the precise version number as unverified.
- iOS 27 / Xcode 27 details are from WWDC 2026 guide pages and session titles (pre-GA); specific API names like visibilityPriority/toolbarOverflowMenu/topBarPinnedTrailing come from a secondary summary of the SwiftUI guide and should be reconfirmed against the SwiftUI updates doc once stabilized.
- I did not separately fetch the full Color and Typography HIG pages' Specifications tables (exact tracking/leading values per text style); the named text styles and 17pt/11pt minimums are confirmed, but per-style point sizes were not individually captured.
- The precise set of XCUIAccessibilityAuditType cases (e.g. .contrast, .dynamicType, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait) was not enumerated from the reference page — confirm exact enum names before use.

## Sources
- Adopting Liquid Glass — Technology Overviews (primary, most API-dense): https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- Liquid Glass — Technology Overviews landing: https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass
- HIG: Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- HIG: VoiceOver: https://developer.apple.com/design/human-interface-guidelines/voiceover
- HIG: Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- HIG: Color: https://developer.apple.com/design/human-interface-guidelines/color
- HIG: Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- SymbolRenderingMode (SwiftUI reference): https://developer.apple.com/documentation/swiftui/symbolrenderingmode
- SwiftUI accessibility modifiers (View-Accessibility): https://developer.apple.com/documentation/swiftui/view-accessibility
- accessibilityRepresentation(representation:): https://developer.apple.com/documentation/swiftui/view/accessibilityrepresentation(representation:)
- colorSchemeContrast environment value: https://developer.apple.com/documentation/swiftui/environmentvalues/colorschemecontrast
- accessibilityReduceMotion environment value: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion
- accessibilityReduceTransparency environment value: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency
- Performing accessibility audits for your app: https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app
- performAccessibilityAudit(for:_:) reference: https://developer.apple.com/documentation/xctest/xcuiapplication/4191487-performaccessibilityaudit
- Accessibility Inspector: https://developer.apple.com/documentation/accessibility/accessibility-inspector
- Localizing and varying text with a string catalog: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Creating your app icon using Icon Composer: https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer
- Icon Composer: https://developer.apple.com/icon-composer/
- Landmarks: Building an app with Liquid Glass (sample code): https://developer.apple.com/documentation/SwiftUI/Landmarks-Building-an-app-with-Liquid-Glass
- WWDC25 219 — Meet Liquid Glass: https://developer.apple.com/videos/play/wwdc2025/219/
- WWDC25 323 — Build a SwiftUI app with the new design: https://developer.apple.com/videos/play/wwdc2025/323/
- WWDC25 356 — Get to know the new design system: https://developer.apple.com/videos/play/wwdc2025/356/
- WWDC25 220/361 — Create icons with Icon Composer: https://developer.apple.com/videos/play/wwdc2025/361/
- WWDC25 316 — Principles of inclusive app design: https://developer.apple.com/videos/play/wwdc2025/316/
- WWDC25 224 — Evaluate your app for Accessibility Nutrition Labels: https://developer.apple.com/videos/play/wwdc2025/224/
- WWDC23 10035 — Perform accessibility audits for your app: https://developer.apple.com/videos/play/wwdc2023/10035/
- WWDC26 269 — What's new in SwiftUI (pre-GA): https://developer.apple.com/videos/play/wwdc2026/269/
- WWDC26 220 — Refine accessibility for custom controls (pre-GA): https://developer.apple.com/videos/play/wwdc2026/220/
- WWDC26 Design guide (pre-GA): https://developer.apple.com/wwdc26/guides/design/
- WWDC26 SwiftUI guide (pre-GA): https://developer.apple.com/wwdc26/guides/swiftui/
