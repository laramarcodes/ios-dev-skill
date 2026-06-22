# Design craft (Liquid Glass era) & accessibility

How to make an iOS 26 app look and feel native — typography, color, SF Symbols, icons, hit targets — and how to treat accessibility as craft (VoiceOver, Dynamic Type, motion/contrast, audits) and localization as a default, not a bolt-on. The single most important truth: in the Liquid Glass era, native polish comes mostly from *removing* custom chrome so the system can render correctly, not from sprinkling glass everywhere.

**Contents**
- [Liquid Glass: adopt by subtraction](#liquid-glass-adopt-by-subtraction)
- [Layout, safe areas & hit targets](#layout-safe-areas--hit-targets)
- [Typography & Dynamic Type](#typography--dynamic-type)
- [Color, dark mode & materials](#color-dark-mode--materials)
- [SF Symbols](#sf-symbols)
- [App icon via Icon Composer](#app-icon-via-icon-composer)
- [VoiceOver as craft](#voiceover-as-craft)
- [Reduce Motion / Transparency / Increase Contrast](#reduce-motion--transparency--increase-contrast)
- [Accessibility audits](#accessibility-audits)
- [Localization](#localization)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

For the glass APIs themselves (`glassEffect`, `GlassEffectContainer`, button styles) see `liquid-glass.md`; for view composition see `swiftui-views.md`; for state/`@Observable` see `state-observation.md`.

## Liquid Glass: adopt by subtraction

iOS 26 (shipping) introduced **Liquid Glass** — a system-wide dynamic material that combines the optics of glass with fluidity, forming a distinct functional layer for controls and navigation that floats above the content layer. The why: when you build standard SwiftUI components (`NavigationStack`, `TabView`, `.toolbar`, `Button`, `List`, sheets) against the iOS 26 SDK, they adopt the new look **automatically**. Your job is mostly to stop fighting it.

- **Remove custom backgrounds** from navigation bars, tab bars, toolbars, split views, sheets, and popovers. They now clash with the glass layer and the scroll-edge effect.
- **Apply `glassEffect(_:in:)` sparingly** — only on genuinely custom, important functional elements, wrapped in a `GlassEffectContainer`. Prefer `.buttonStyle(.glass)` / `.glassProminent` over hand-rolled glass. Never stack glass on glass.
- **Opt-out escape hatch:** the `UIDesignRequiresCompatibility` Info.plist key keeps the pre-Liquid-Glass appearance while you build on the new SDK. Use it to buy time, not as a strategy.

Crucially: Liquid Glass adapts to accessibility settings (Reduce Transparency → frostier/opaque; Increase Contrast → near-black/white with bordered edges; Reduce Motion → less effect intensity) **automatically only for standard system components**. Custom glass, colors, and animations you must test yourself against each setting.

## Layout, safe areas & hit targets

- **Respect safe areas.** Let content flow edge-to-edge under bars but keep interactive/critical content inside the safe area. Use `.safeAreaPadding(_:)` and `.safeAreaInset(edge:)`. For a custom bar that should get the scroll-edge effect over scrolling content, register it with `safeAreaBar(edge:alignment:spacing:content:)` (iOS 26) — system bars get this for free.
- **Hit targets:** minimum **44×44 pt** tap target on iOS/iPadOS; absolute minimum control size 28×28 pt. Pad icon-only controls (~12 pt around bezeled, ~24 pt around bezel-less) so taps don't miss.
- **Concentric shapes (iOS 26):** nest controls in containers with `ConcentricRectangle` and `Shape.rect(corners:isUniform:)` so corner radii align with the container and hardware curvature. Don't hard-code corner radii — that blocks automatic adoption of the new rounder shapes.

```swift
ScrollView { content }
    .safeAreaBar(edge: .bottom) {
        Button("Continue") { advance() }
            .buttonStyle(.glassProminent)
            .padding()
    }
```

## Typography & Dynamic Type

**SF Pro** is the system sans; **New York (NY)** is the system serif; SF Pro Rounded and a monospaced variant exist too. Default body is 17 pt; recommended minimum text size is 11 pt.

The modern idiom is **named text styles**, never fixed point sizes — named styles get Dynamic Type scaling for free:

| Style | Use |
|---|---|
| `.largeTitle`, `.title`/`.title2`/`.title3` | Screen titles, section leads |
| `.headline`, `.subheadline` | Emphasis, secondary headings |
| `.body`, `.callout` | Primary reading text |
| `.footnote`, `.caption`/`.caption2` | Metadata, fine print |

For any hard-coded dimension that sits next to text (icon size, spacing, custom row height), use **`@ScaledMetric`** so it grows with the user's text size. Test at the largest accessibility sizes (AX1–AX5): let layouts reflow vertically, minimize truncation.

```swift
Text("Welcome").font(.largeTitle)        // free Dynamic Type
Text("Subtitle").font(.subheadline).foregroundStyle(.secondary)

@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24
Image(systemName: "bell").frame(width: iconSize, height: iconSize)
```

Emphasized Dynamic Type weights were added to the per-platform style specs (Dec 2025) — reach for `.fontWeight(_:)` on a named style rather than switching to a fixed font.

## Color, dark mode & materials

Use **semantic / system colors**, not hard-coded hex, for UI chrome. They ship accessible variants that adapt automatically to Dark Mode and Increase Contrast:

- Foreground hierarchy: `.primary`, `.secondary`, `.tertiary`, `.quaternary`.
- Backgrounds: `Color(.systemBackground)`, `Color(.systemGroupedBackground)`, etc.
- System palette: `.red`, `.blue`, … (or `Color(.systemRed)`), plus `.tint` / the app accent color.

If you must define a custom color, author **light + dark + an Increase-Contrast variant** in the asset catalog. Verify contrast in **both** appearances — Accessibility Inspector enforces WCAG AA: **4.5:1** for text ≤17 pt, **3:1** for text ≥18 pt and for any bold text.

```swift
Text("Title").foregroundStyle(.primary)
VStack { /* ... */ }
    .background(Color(.systemGroupedBackground))
    .tint(.accentColor)
```

**Materials** (`.ultraThinMaterial` … `.thickMaterial`) remain for legibility behind content, but in the Liquid Glass era prefer letting system bars/sheets supply their own material rather than layering your own blur.

## SF Symbols

SF Symbols scale with Dynamic Type automatically and have **four rendering modes** set via `.symbolRenderingMode(_:)`:

| Mode | Behavior |
|---|---|
| `.monochrome` | Single color (default) |
| `.hierarchical` | One color, multiple opacity levels for depth |
| `.palette` | Two or three explicit colors you supply |
| `.multicolor` | Symbol's own intrinsic colors |

All modes support **Variable Color** via `Image(_:variableValue:)` to show progress/intensity. **SF Symbols 7** ships with iOS 26 and introduced **Draw animations** (animate a symbol along its drawing path) alongside the existing `.symbolEffect(_:)` family (bounce, pulse, variableColor, replace).

```swift
Image(systemName: "wifi", variableValue: signalStrength)   // 0...1 fills bars
    .symbolRenderingMode(.hierarchical)
    .symbolEffect(.pulse)
```

> **SF Symbols 8 (iOS 27, pre-GA):** announced at WWDC 2026 with 7,000+ symbols and new effects. Ships fall 2026 — treat the symbol count and any new APIs as subject to change; don't depend on SF Symbols 8-only glyphs in a shipping iOS 26 app.

## App icon via Icon Composer

iOS 26 app icons are **layered Liquid Glass icons** authored in **Icon Composer** (a single layered `.icon` file, ships with Xcode 26). You supply foreground / middle / background layers; the system applies reflection, refraction, shadow, blur, and highlights. Provide the **default (light), dark, clear, and tinted** appearance variants so the icon looks right in every mode. Pre-iOS-26 single-image icons are deprecated for this layered model.

## VoiceOver as craft

Think in four properties, applied with the **modern standalone modifiers** (the old `.accessibility(label:)` family is deprecated):

- **Label** (`.accessibilityLabel`) — *what it is*. Required on every icon-only control even though no text shows.
- **Value** (`.accessibilityValue`) — *current state* (e.g. "70 percent").
- **Hint** (`.accessibilityHint`) — *what happens* on activation; use sparingly.
- **Traits** (`.accessibilityAddTraits`) — `.isButton`, `.isHeader`, `.isSelected`, etc.

Group composite cells into one swipe stop with `.accessibilityElement(children: .combine)`. Hide decorative images with `.accessibilityHidden(true)`. Add custom rotors with `.accessibilityRotor(_:)` / `AccessibilityRotorEntry` so users jump between like elements (headings, unread items).

```swift
Button(action: favorite) { Image(systemName: "star") }
    .accessibilityLabel("Add to favorites")

HStack { thumbnail; VStack { Text(name); Text(subtitle) } }
    .accessibilityElement(children: .combine)
    .accessibilityHint("Opens details")

Image("texture").accessibilityHidden(true)   // decorative
```

For a custom control, **swap in a known control's accessibility tree** with `accessibilityRepresentation(representation:)` — VoiceOver then gets correct label/value/adjustable behavior without you re-implementing it:

```swift
MyCustomSlider(value: $volume)
    .accessibilityRepresentation { Slider(value: $volume, in: 0...1) { Text("Volume") } }
```

## Reduce Motion / Transparency / Increase Contrast

Branch on these **environment values** for any custom visual (system components handle themselves):

| Environment value | Branch when… |
|---|---|
| `\.accessibilityReduceMotion` | You add custom animation — prefer a cross-fade over movement |
| `\.accessibilityReduceTransparency` | You rely on translucency — supply an opaque fallback |
| `\.colorSchemeContrast` (`.standard` / `.increased`) | Strengthen borders/contrast when `.increased` |
| `\.accessibilityDifferentiateWithoutColor` | State shown by color — also encode it as shape/icon |
| `\.accessibilityVoiceOverEnabled` | Adjust behavior when VoiceOver is active |

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.colorSchemeContrast) private var contrast

withAnimation(reduceMotion ? nil : .spring) { expand.toggle() }
let borderWidth = contrast == .increased ? 2.0 : 0.0
```

## Accessibility audits

`performAccessibilityAudit()` (XCUIApplication, since Xcode 15 / iOS 17) runs the same checks as Accessibility Inspector inside a UI test and **auto-fails** on issues — no manual assertions. Add one per screen. Filter false positives by passing an audit-type set and a handler that returns `false` for issues to ignore. Audit types cover contrast, Dynamic Type, hit-region size, element detection, and trait conflicts. Note `performAccessibilityAudit()` is an XCUITest API (part of XCTest), so the audit itself lives in a UI test target — there is no Swift Testing equivalent; write logic tests in Swift Testing and keep UI tests in XCUITest. See `testing-and-debugging.md`.

```swift
func testAccessibility() throws {
    let app = XCUIApplication()
    app.launch()
    try app.performAccessibilityAudit()   // auto-fails on issues
}
```

Audits don't replace manual VoiceOver use or the Accessibility Inspector (Xcode ▸ Open Developer Tool). Test on-device with VoiceOver before claiming an app is accessible. WWDC 2026 session 220 ("Refine accessibility for custom controls", pre-GA) signals continued investment here.

## Localization

**String Catalogs (`.xcstrings`)** are the modern container (since Xcode 15; `.strings`/`.stringsdict` are deprecated). Any string literal in SwiftUI is automatically localizable and extracted to `Localizable.xcstrings` — no manual `NSLocalizedString`.

- **Plurals:** use the catalog editor's **"Vary by Plural"**, or the inline `inflect` form. Never concatenate strings to build a plural or sentence — it breaks translation.
- **Styled text:** `AttributedString(localized:)` keeps Markdown/styling localizable.
- **RTL:** right-to-left layout flips automatically *only* if you use **leading/trailing** edges and alignments — never left/right.
- **Formatting:** use `.formatted()` / `FormatStyle` (dates, numbers, measurements, lists) so output is locale-correct.

```swift
Text("Welcome back")                          // auto-extracted to the catalog
Text("^[\(count) item](inflect: true)")       // or "Vary by Plural" in the editor
let note = AttributedString(localized: "**Bold** and _italic_")
Text(date, format: .dateTime.month().day())
```

> **Pre-GA:** Xcode 27 (fall 2026) previews **AI-assisted app translation** ("Translate your app using agents in Xcode"). Useful for first-pass drafts; treat as subject to change and still review translations.

## Pitfalls

- **Glass everywhere.** `glassEffect` on many custom controls looks subpar and distracts — Apple says use it sparingly, only on the most important functional elements, inside a `GlassEffectContainer`.
- **Custom bar backgrounds left in place.** Navigation/tab/toolbars, sheets, popovers, and split views now fight Liquid Glass and the scroll-edge effect. Remove your backgrounds; let the system render them.
- **Hard-coded font sizes or corner radii.** Breaks Dynamic Type and blocks the new rounder shapes/sizing on rebuild. Use named text styles + `@ScaledMetric` and `ConcentricRectangle`.
- **Icon-only button with no `.accessibilityLabel`.** Invisible to VoiceOver and Voice Control even though the glyph is "obvious" to you.
- **Color as the only signal** for error/success/selection — fails for color-blind users. Pair with shape/icon and honor `accessibilityDifferentiateWithoutColor`.
- **Animations that ignore `accessibilityReduceMotion`** — can cause nausea. Provide a cross-fade fallback.
- **Assuming custom views inherit Liquid Glass a11y adaptations.** Automatic only for standard components — test custom glass/colors/motion against Reduce Transparency / Increase Contrast / Reduce Motion yourself.
- **All-caps section headers.** iOS 26 uses title-style capitalization automatically; pre-uppercased strings now look wrong — write headers in title case.
- **Left/right instead of leading/trailing.** Breaks RTL localization silently.
- **Concatenating strings for plurals/sentences.** Breaks pluralization and translation — use "Vary by Plural" and full interpolated localized strings.
- **Checking contrast only in light mode.** Apple requires verifying minimums in both light and dark appearances.
- **Decorative images left visible to VoiceOver.** Adds noise — mark them `.accessibilityHidden(true)`.

## Primary sources

- Adopting Liquid Glass (Technology Overviews): https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- HIG — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- HIG — Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- HIG — Color: https://developer.apple.com/design/human-interface-guidelines/color
- SwiftUI accessibility modifiers: https://developer.apple.com/documentation/swiftui/view-accessibility
- Performing accessibility audits: https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app
- Localizing and varying text with a string catalog: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Creating your app icon using Icon Composer: https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer
