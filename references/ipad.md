# iPad: windowing, multitasking, input & adaptivity

iPadOS 26 replaced the old base multitasking model (full-screen / Split View / Slide Over) with true overlapping, resizable windows — so your app can be **any size at any time**. The engineering job is rarely a rewrite; it's making layout, state, and input survive arbitrary window geometry. If you already use standard containers (`NavigationSplitView`/`NavigationStack` + `Toolbar`) and respect the safe area, the system adapts you for free; your work is to verify, not rebuild.

**Contents**
- [The iPadOS 26 windowing model](#the-ipados-26-windowing-model)
- [Adaptivity: size classes & NavigationSplitView](#adaptivity-size-classes--navigationsplitview)
- [Multi-window & per-window state](#multi-window--per-window-state)
- [The menu bar (SwiftUI commands)](#the-menu-bar-swiftui-commands)
- [Window Controls & custom chrome](#window-controls--custom-chrome)
- [Minimum size & reacting to resize (UIKit)](#minimum-size--reacting-to-resize-uikit)
- [Pointer & trackpad](#pointer--trackpad)
- [Hardware keyboard](#hardware-keyboard)
- [Apple Pencil & hover](#apple-pencil--hover)
- [Drag and drop (Transferable)](#drag-and-drop-transferable)
- [Mac Catalyst & Designed for iPad](#mac-catalyst--designed-for-ipad)
- [iPadOS 27 (pre-GA)](#ipados-27-pre-ga)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## The iPadOS 26 windowing model

What shipped in iPadOS 26: every multitasking-capable app gets a bottom-right **resize handle**, macOS-style **Window Controls** (close/minimize/resize/tile) at the toolbar's leading edge, **Window Tiling** (flick to arrange), **Exposé**, and a customizable **Menu Bar** (swipe down from the top or move the pointer to the top edge). Window size and position are **persisted** — reopen and the window returns to where the user left it.

Key framing: **Stage Manager was not removed.** It remains an optional layer for grouping windows into stages and driving external displays; the new windowing replaced the *base* multitasking model, not Stage Manager. Don't tell users to "turn on Stage Manager" to get windows — they have windows by default now.

For most apps **no code change is required for compatibility**: as the window resizes, the system repositions standard toolbar items and inserts Window Controls automatically. The real implication is that the assumptions below (size classes, `NavigationSplitView` adaptivity, per-window state, minimum sizes) now matter far more because width changes constantly.

## Adaptivity: size classes & NavigationSplitView

Use `NavigationSplitView` (iOS 16+) as the app shell and let **it** decide which columns are visible — in iPadOS 26 it auto shows/hides columns based on live window width and collapses toward `NavigationStack` behavior in compact widths with no code from you. `NavigationView` is deprecated (since iOS 16); never use it.

```swift
struct RootView: View {
  @State private var columns: NavigationSplitViewVisibility = .automatic
  @State private var selectedFolder: Folder?
  @State private var selectedItem: Item?

  var body: some View {
    NavigationSplitView(columnVisibility: $columns) {
      SidebarView(selection: $selectedFolder)
    } content: {
      ItemListView(folder: selectedFolder, selection: $selectedItem)
    } detail: {
      DetailView(item: selectedItem)
    }
  }
}
```

The deprecated-thinking trap: **branching whole layouts on `horizontalSizeClass`.** Because a window can be any width at any time, the size class (`.compact`/`.regular`, read via `@Environment(\.horizontalSizeClass)`, iOS 13+) now flips frequently during a single resize gesture. Reserve size class for genuine *compact fallbacks* (e.g. swap a side-by-side row for a stacked one); let `NavigationSplitView` own the multi-column adaptivity. See `swiftui-views.md` for layout containers.

## Multi-window & per-window state

`WindowGroup` (iOS 16+) supports multiple windows on iPad. Open them programmatically with `@Environment(\.openWindow)` (iOS 16+) / `@Environment(\.dismissWindow)` (iOS 17+) keyed by scene `id` or a presented value.

```swift
@main struct MyApp: App {
  var body: some Scene {
    WindowGroup(id: "editor", for: Document.ID.self) { $docID in
      EditorView(documentID: docID)   // fresh @State per window
    }
  }
}

struct OpenButton: View {
  @Environment(\.openWindow) private var openWindow
  let id: Document.ID
  var body: some View {
    Button("Open in New Window") { openWindow(id: "editor", value: id) }
  }
}
```

**Each window gets its own `@State`/`@StateObject` storage.** Anything two windows must agree on (the document, selection, undo stack) belongs in a model layer — an `@Observable` model in the environment (the modern idiom, not `ObservableObject`) or SwiftData — or the windows silently desync. See `state-observation.md` and `data-persistence.md`.

## The menu bar (SwiftUI commands)

iPadOS 26 extends the menu bar to all iPads. You author it with the **same** `commands(content:)` scene modifier and `CommandMenu`/`CommandGroup` you'd use on macOS — there is no separate iPad-only menu API. These also populate the Cmd-hold **shortcut discoverability HUD**.

```swift
WindowGroup { ContentView() }
  .commands {
    CommandMenu("Insert") {
      Button("Image…") { /* … */ }
        .keyboardShortcut("i", modifiers: [.command, .shift])
      Button("Table") { /* … */ }
    }
    CommandGroup(replacing: .help) {
      Button("MyApp Help") { /* … */ }
    }
  }
```

`CommandMenu` adds a top-level app menu; `CommandGroup` inserts into or replaces a system menu via `CommandGroupPlacement` (e.g. `.newItem`, `.textEditing`, `.help`). HIG rule: **never hide menu items dynamically** — keep them static and *disable* (`.disabled(...)`) when unavailable, ordered by frequency and grouped into sections. (UIKit equivalent: `UIMenuBuilder`.)

## Window Controls & custom chrome

Standard `NavigationStack`/`NavigationSplitView` + `Toolbar` dodges the leading-edge Window Controls automatically. **Custom title bars / custom toolbar chrome can collide with them.**

- SwiftUI: `containerCornerOffset(_:sizeToFit:)` (iPadOS 26) offsets a custom view clear of the corner controls; `sizeToFit: true` also subtracts the controls' width from available space.
- UIKit: query the new `UIView.LayoutRegion` (iPadOS 26) via `layoutGuide(for:)` (Auto Layout) or `edgeInsets(for:)` / `directionalEdgeInsets(for:)` (frame-based) to inset around the corner-adaptation margins.

> Verify in Xcode 26: `containerCornerOffset(_:sizeToFit:)` and `UIView.LayoutRegion` were corroborated from WWDC sessions and strong secondary coverage, but the canonical reference pages were thin at research time — confirm exact signatures on-device.

You can also control the controls' style via `UIWindowSceneDelegate.preferredWindowingControlStyle(for:)` returning a `UIWindowScene.WindowingControlStyle` (iPadOS 26): `.automatic` (system decides), `.unified` (new iPadOS 26 inline behavior), or `.minimal` (legacy/compat — controls sit in the top safe area, useful to opt a custom title bar out of inline controls).

## Minimum size & reacting to resize (UIKit)

Adopt the **UIScene lifecycle now** (`UISceneDelegate`/`UIWindowSceneDelegate`) — it is becoming mandatory in the next major release, and an app-delegate-only app won't get full windowing control. Declare a preferred minimum content size at connect time via `UISceneSizeRestrictions` so resizing can't break core functionality, and defer expensive relayout until interactive resize ends (`isInteractivelyResizing`).

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options: UIScene.ConnectionOptions) {
  guard let ws = scene as? UIWindowScene else { return }
  ws.sizeRestrictions?.minimumSize = CGSize(width: 480, height: 400)
}

func windowScene(_ ws: UIWindowScene,
                 didUpdateEffectiveGeometry previous: UIWindowScene.Geometry) {
  if !ws.effectiveGeometry.isInteractivelyResizing { rebuildExpensiveLayout() }
}
```

Programmatic window resizing uses `UIWindowScene.requestGeometryUpdate(_:errorHandler:)` (iPadOS 16+, refined in 26) with a `UIWindowSceneGeometryPreferences`. Per HIG, resize adaptations must be **non-destructive** — when the window grows back, the layout should return to its prior state.

## Pointer & trackpad

iPadOS 26 ships a new **1:1 precise pointer**: it no longer magnetizes / rubber-bands onto controls, and a Liquid Glass highlight materializes on hover. Re-test any app that leaned on the old snapping feel or custom hit-target assumptions.

- `pointerStyle(_:)` sets the cursor over a view using `PointerStyle` — built-ins include `.default`, `.rectSelection`, `.link`, `.grabIdle`/`.grabActive`, `.zoomIn`/`.zoomOut`, `.frameResize(position:directions:)`, `.columnResize(directions:)`, `.rowResize(directions:)`, plus custom `.image(_:hotSpot:)` / `.shape(_:eoFill:size:)`. `pointerVisibility(_:)` shows/hides the cursor.
- `onContinuousHover(coordinateSpace:perform:)` (iPadOS 16+) reports a `HoverPhase` with the exact pointer location.
- `hoverEffect(_:)` (iPadOS 13.4+): `.automatic` / `.highlight` / `.lift` morph effects on pointer-over.

```swift
Canvas { ctx, size in /* … */ }
  .pointerStyle(tool == .marquee ? .rectSelection : .default)
  .onContinuousHover { phase in
    switch phase {
    case .active(let p): hoverPoint = p
    case .ended:         hoverPoint = nil
    }
  }
  .hoverEffect(.highlight)
```

> Availability caveat: the SwiftUI reference annotates `PointerStyle` / `pointerStyle(_:)` as macOS 15+/visionOS 2+ only, yet it is used on iPadOS. The iPadOS line is missing from primary docs — wrap in `#available` / verify on-device rather than trusting the header.

## Hardware keyboard

- `keyboardShortcut(_:modifiers:)` (iOS 14+) assigns Cmd-key shortcuts to buttons/commands; they surface in the discoverability HUD and the menu bar.
- `focusable(_:)` (iOS 17+ on iPad) opts a view into hardware-keyboard focus; pair with `@FocusState` to move focus with Tab/arrow keys.
- App-wide commands belong in `.commands { … }` (above) so they appear in the menu bar, not just as hidden hotkeys.

## Apple Pencil & hover

- `PencilHoverPose` (iPadOS 18+, still current) describes a Pencil hovering above a view: location, z-distance, azimuth, altitude, roll. `PKToolPicker` (PencilKit; custom tools iPadOS 18+) uses the pose to position itself.
- `onPencilSqueeze` (iPadOS 17.5+) exposes squeeze phase + hover position; UIKit's `UIPencilInteraction` delivers double-tap/squeeze and hover pose. For ink/markup surfaces use PencilKit (`PKCanvasView`, `PKToolPicker`) — see `frameworks.md`.

## Drag and drop (Transferable)

Use the SwiftUI-native stack — `Transferable` + `draggable(_:)` + `dropDestination(for:action:isTargeted:)` (all iOS 16+) — over the older `UIDragInteraction`/`UIDropInteraction`. Conforming your model to `Transferable` with a real `UTType` makes it work for in-app reordering, drops across separate windows, and drops into other apps (Notes, Contacts).

```swift
struct Photo: Transferable, Codable {
  let id: UUID
  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: .photo)
  }
}

Thumbnail(photo)
  .draggable(photo)

AlbumGrid()
  .dropDestination(for: Photo.self) { photos, location in
    model.add(photos); return true
  }
```

## Mac Catalyst & Designed for iPad

On Apple silicon Macs, an unmodified iPad build runs as a **"Designed for iPad"** app, scaled to ~77% (which can look soft). For a crisp, Mac-native result — native controls, windowing, menus, keyboard shortcuts — use **Mac Catalyst** with "Optimize for Mac." Catalyst remains supported in the 26 cycle. Choose Catalyst when the Mac is a first-class target; rely on the Designed-for-iPad build only as a low-effort bonus.

## iPadOS 27 (pre-GA)

WWDC 2026; developer beta, ships fall 2026 — **all provisional, may change before GA.** iPadOS 27 is a *refinement* release, not a new windowing paradigm:

- Faster window gestures (close/switch/drag) and faster cursor-driven context menus; CPU scheduler extended to all supported iPads.
- App name shown in the status bar; tapping/hovering it is a quicker entry point to the menu bar.
- iPhone apps on iPad can be resized larger.
- Stage Manager refinements (freer resizing, better keyboard-shortcut support) reported by hands-on coverage — **secondary source, not yet in Apple docs.**

No API migration is forced by 27 today; keep targeting the iPadOS 26 SDK and adopt the scene lifecycle regardless.

## Pitfalls

- **Don't branch whole navigation layouts on `horizontalSizeClass`.** Windows are any width at any time, so the size class flips mid-gesture. Let `NavigationSplitView` own column adaptivity; use size class only for true compact fallbacks.
- **Window `@State` is per-window.** A second window gets fresh state; shared truth must live in an environment `@Observable` model or SwiftData, or windows desync.
- **Custom title bars/toolbars collide with the corner Window Controls.** Standard `NavigationStack`/`SplitView` + `Toolbar` is handled automatically; custom chrome needs `containerCornerOffset(_:sizeToFit:)` (SwiftUI) or `UIView.LayoutRegion` insets (UIKit).
- **The 1:1 pointer no longer magnetizes.** Apps relying on the old snapping or custom hit-target tricks should re-test hover and tap targets.
- **`PointerStyle` availability is under-documented for iPadOS** — gate with `#available` / verify on-device instead of trusting the header.
- **Never hide menu-bar items dynamically.** Keep them static and disable when unavailable (HIG).
- **App-delegate-only lifecycle won't survive.** The UIScene lifecycle is becoming mandatory and is required for `preferredWindowingControlStyle` and other windowing control — migrate now.
- **Designed-for-iPad on Mac scales to ~77%** (blurry). Use Mac Catalyst with "Optimize for Mac" for a crisp Mac build.
- **Don't leave `UIDesignRequiresCompatibility = YES` on unintentionally** — it (or building against an older SDK) keeps legacy controls but opts you out of the new Liquid Glass / unified controls.
- **Resize must be non-destructive.** Per HIG, shrinking then growing a window should restore the original layout — don't drop user state on resize.

## Primary sources

- Apple Newsroom — iPadOS 26 new features: https://www.apple.com/newsroom/2025/06/ipados-26-introduces-powerful-new-features-that-push-ipad-even-further/
- WWDC25 Session 208 — Elevate the design of your iPad app: https://developer.apple.com/videos/play/wwdc2025/208/
- WWDC25 Session 282 — Make your UIKit app more flexible: https://developer.apple.com/videos/play/wwdc2025/282/
- SwiftUI — Building and customizing the menu bar: https://developer.apple.com/documentation/SwiftUI/Building-and-customizing-the-menu-bar-with-SwiftUI
- SwiftUI — Adopting drag and drop: https://developer.apple.com/documentation/SwiftUI/Adopting-drag-and-drop-using-SwiftUI
- UIKit — requestGeometryUpdate(_:errorHandler:): https://developer.apple.com/documentation/uikit/uiwindowscene/requestgeometryupdate(_:errorhandler:)
- UIKit — Adopting hover support for Apple Pencil: https://developer.apple.com/documentation/UIKit/adopting-hover-support-for-apple-pencil
- UIKit — Mac Catalyst: https://developer.apple.com/documentation/uikit/mac-catalyst
