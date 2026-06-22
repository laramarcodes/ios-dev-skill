# DOMAIN: iPad windowing, multitasking & input (SwiftUI/UIKit) — iPadOS 26 (shipping) / iPadOS 27 (pre-GA)

## Orientation
 iPadOS 26 replaced the old base multitasking model (full-screen / Split View / Slide Over) with a true overlapping-windows system: every multitasking-capable app gets a bottom-right resize handle, traffic-light Window Controls in the toolbar leading edge, window tiling (flick to arrange), Exposé, and a swipe-down/cursor-to-top Menu Bar. Stage Manager still exists as an optional layer for grouping windows into stages; it is no longer the only path to windows. For most SwiftUI/UIKit apps that already respect the safe area and use standard containers (NavigationSplitView/NavigationStack + toolbar, or UISplitViewController/UINavigationController), the system adapts automatically — you mostly verify responsive layout across arbitrary sizes rather than rebuild. The biggest engineering implication is that your app can now be any size at any time, so size classes, NavigationSplitView column adaptivity, per-window @State, and minimum-size declarations (UISceneSizeRestrictions) matter more than ever. iPadOS 27 (WWDC 2026, pre-GA) is a refinement release: faster window gestures, app name in the status bar as a quicker menu-bar entry point, resizable iPhone apps, and CPU-scheduler/perf work — no new windowing paradigm. The UIScene lifecycle is becoming mandatory, so adopt scene-based lifecycle now.

## Key facts
- [iPadOS 26|high] iPadOS 26 introduces an entirely new windowing system: fluidly resizable, overlapping windows; a bottom-right resize handle on every multitasking app; macOS-style Window Controls (close/minimize/resize/tile); Window Tiling (flick to arrange); and Exposé to see all open windows.
- [iPadOS 26|high] Window size/position is persisted: a previously resized app reopens at the exact same size and position.
- [iPadOS 26|high] A new Menu Bar comes to all iPads (extended beyond what existed before): revealed by swiping down from the top or moving the pointer to the top edge; includes search; developers customize it via SwiftUI commands / UIKit UIMenuBuilder.
- [iPadOS 26|high] Stage Manager is NOT removed — it remains an optional way to group windows into distinct stages and works alongside the new windowing system and external displays. The new windowing replaced the *base* multitasking model, not Stage Manager.
- [iPadOS 26|high] iPadOS 26 ships a new precise pointer that tracks 1:1 (no longer magnetizes/rubber-bands to controls) and a 'Liquid Glass' highlight that materializes on buttons during hover. Test apps for unexpected pointer interactions.
- [iPadOS 26|high] Apps that already respect the safe area and use standard controls (NavigationStack/NavigationSplitView + Toolbar, or UINavigationController/UISplitViewController) get the new Window Controls handled automatically — the system repositions toolbar items as the window resizes. No code change strictly required for compatibility.
- [iPadOS 26|high] Window Control behavior is configurable via UIWindowSceneDelegate.preferredWindowingControlStyle(for:) returning a UIWindowScene.WindowingControlStyle: .automatic (system decides), .minimal (legacy/compat behavior — controls sit in top safe area), or .unified (new iPadOS 26 inline behavior).
- [iPadOS 26|high] Legacy apps built before the iPadOS 26 SDK (or with Info.plist UIDesignRequiresCompatibility = YES) run in compatibility mode: Window Controls are inserted into the top safe area and contribute to top safe-area inset, so safe-area-respecting layouts need no changes.
- [iPadOS 26|medium] For custom (non-standard) title bars/controls in SwiftUI, the new modifier containerCornerOffset(_:sizeToFit:) offsets a view to dodge the Window Controls; with sizeToFit:true SwiftUI also subtracts the controls' width from available space.
- [iPadOS 26|medium] UIKit gains UIView.LayoutRegion describing regions including safe area and corner/margin layout; retrieve layout via UIView.layoutGuide(for:) (UILayoutGuide for Auto Layout) or edgeInsets(for:) / directionalEdgeInsets(for:) for frame-based layout — used to dodge the new corner-adaptation margins from Window Controls.
- [iPadOS 26|high] UISceneSizeRestrictions lets a scene express a preferred minimum content size so resizing can't break core functionality; set it when the scene is about to connect (scene willConnectTo).
- [iPadOS 26 → required next release|high] The UIScene lifecycle (UISceneDelegate / UIWindowSceneDelegate) is becoming mandatory in the next major release — apps still on the app-delegate-only lifecycle must migrate. Adopting container view controllers (UISplitViewController, UITabBarController) is the recommended path to flexibility.
- [shipping (refined iPadOS 26)|high] Programmatic window resizing uses UIWindowScene.requestGeometryUpdate(_:errorHandler:) with a UIWindowSceneGeometryPreferences; observe results via UIWindowSceneDelegate didUpdateEffectiveGeometry, and check windowScene geometry's isInteractivelyResizing to defer expensive work until interactive resize ends.
- [iPadOS 26|high] iPadOS 26 adds computationally-intensive Background Tasks (leveraging Apple silicon) surfaced with Live Activities so users can see/control long-running work — relevant to multi-window/pro workflows.
- [iPadOS 26 (commands API since macOS/iPadOS earlier; extended to all iPads)|high] SwiftUI Menu Bar is built with the commands(content:) scene modifier plus CommandMenu (top-level app-specific menus) and CommandGroup (insert/replace into system menus via CommandGroupPlacement). On iPadOS these populate the menu bar and the Cmd-key shortcut discoverability HUD.
- [iPadOS 26|high] NavigationSplitView automatically shows/hides columns based on available window space in iPadOS 26; with the new flexible windowing it collapses toward NavigationStack behavior in compact widths without code changes.
- [used on iPadOS (header lists macOS 15+/visionOS 2+)|medium] SwiftUI PointerStyle (struct) + .pointerStyle(_:) and .pointerVisibility(_:) control cursor appearance/visibility; built-in styles include .default, .horizontalText, .verticalText, .rectSelection, .grabIdle, .grabActive, .link, .zoomIn, .zoomOut, plus .frameResize(position:directions:), .columnResize(directions:), .rowResize(directions:), and custom .image(_:hotSpot:) / .shape(_:eoFill:size:).
- [since iPadOS 18, still current|high] PencilHoverPose (SwiftUI) describes an Apple Pencil hovering above a view's bounds (location + z-distance, azimuth, altitude, roll). UIPencilInteraction delivers hover pose with double-tap/squeeze; SwiftUI .onPencilSqueeze exposes phase + hover position; PKToolPicker uses pose to position itself.
- [iPadOS 27 (pre-GA)|medium] iPhone apps running on iPadOS 27 can be resized larger; app name appears in the status bar and tapping/hovering it is a faster way to reach the menu bar; window close/switch/drag gestures are quicker and the CPU scheduler is extended to all supported iPads. (pre-GA, may change)
- [iOS/iPadOS 26 cycle|medium] On Apple silicon Macs, unmodified iPhone/iPad apps run natively ('Designed for iPad', UI scaled ~77%); Mac Catalyst with 'Optimize for Mac' gives Mac-native controls/windowing/menus/keyboard shortcuts. Catalyst remains supported in the 26 cycle.

## APIs
- `WindowGroup` (struct (SwiftUI Scene); iOS 16+/iPadOS) — Multi-window scene; opens multiple windows on iPadOS/macOS. Add id:/presentation value for programmatic opening.
- `openWindow` (EnvironmentValues action (@Environment(\.openWindow)); iOS 16+) — Programmatically open a window by scene id or presented value.
- `dismissWindow` (EnvironmentValues action; iOS 17+) — Programmatically close a window/scene.
- `commands(content:)` (Scene modifier (SwiftUI); iPadOS (extended to all iPads in 26)) — Builds the iPad menu bar / macOS menu bar.
- `CommandMenu` (struct (Commands); iPadOS/macOS) — Top-level custom app menu.
- `CommandGroup` (struct (Commands); iPadOS/macOS) — Insert/replace items in system menus via CommandGroupPlacement.
- `CommandGroupPlacement` (struct; iPadOS/macOS) — Placement for CommandGroup (e.g. .newItem, .textEditing).
- `keyboardShortcut(_:modifiers:)` (View/command modifier; iOS 14+) — Assign Cmd-key shortcuts; surfaced in iPad shortcut discoverability HUD.
- `focusable(_:)` (View modifier; iOS 17+ on iPad) — Hardware-keyboard focus participation.
- `PointerStyle` (struct (SwiftUI); header: macOS 15+/visionOS 2+ (used on iPadOS — verify)) — Cursor styles: .default,.rectSelection,.link,.grabIdle/Active,.zoomIn/Out,.frameResize(...),.columnResize(...),.rowResize(...),.image(_:hotSpot:),.shape(_:eoFill:size:).
- `pointerStyle(_:)` (View modifier; macOS 15+/visionOS 2+ per header) — Set cursor over a view.
- `pointerVisibility(_:)` (View modifier; macOS 15+/visionOS 2+) — Show/hide the pointer over a view.
- `hoverEffect(_:)` (View modifier; iPadOS 13.4+) — HoverEffect: .automatic/.highlight/.lift for pointer-over-view morphing.
- `onContinuousHover(coordinateSpace:perform:)` (View modifier; iPadOS 16+) — Reports HoverPhase + exact pointer location within bounds.
- `draggable(_:)` (View modifier; iOS 16+) — Make a Transferable view draggable.
- `dropDestination(for:action:isTargeted:)` (View modifier; iOS 16+) — Receive dropped Transferable items + drop location.
- `Transferable` (protocol; iOS 16+) — Drag/drop + clipboard payloads; String/URL/Data/Image conform out of the box.
- `NavigationSplitView` (struct (SwiftUI); iOS 16+) — 2/3-column adaptive layout; auto column show/hide on window resize; collapses to stack in compact.
- `NavigationSplitViewVisibility` (struct; iOS 16+) — .all/.doubleColumn/.detailOnly/.automatic bound via columnVisibility:.
- `horizontalSizeClass / verticalSizeClass` (@Environment EnvironmentValues; iOS 13+) — .compact/.regular — drives adaptive layout; now varies live as windows resize.
- `UIWindowScene.WindowingControlStyle` (enum (UIKit); iPadOS 26) — .automatic/.minimal/.unified controlling iPadOS 26 Window Controls.
- `preferredWindowingControlStyle(for:)` (UIWindowSceneDelegate method; iPadOS 26) — Return desired WindowingControlStyle.
- `containerCornerOffset(_:sizeToFit:)` (View modifier (SwiftUI); iPadOS 26) — Offset custom title-bar views around corner Window Controls; sizeToFit subtracts controls' width.
- `UIView.LayoutRegion` (type (UIKit); iPadOS 26) — Describes regions (safe area, corner/margin layout) for the new controls.
- `layoutGuide(for:) / edgeInsets(for:) / directionalEdgeInsets(for:)` (UIView methods; iPadOS 26) — Resolve a LayoutRegion into UILayoutGuide / insets.
- `UISceneSizeRestrictions` (class (UIKit); iPadOS 26) — Declare preferred minimum scene content size; set at scene connect.
- `UIWindowScene.requestGeometryUpdate(_:errorHandler:)` (method; iPadOS 16+ (refined 26)) — Programmatic window geometry change via UIWindowSceneGeometryPreferences.
- `UIWindowSceneDelegate didUpdateEffectiveGeometry` (delegate method; iPadOS) — Observe effective geometry/resize changes; isInteractivelyResizing to defer work.
- `PencilHoverPose` (struct (SwiftUI); iPadOS 18+) — Apple Pencil hover location/distance/angles above a view.
- `onPencilSqueeze` (View modifier; iPadOS 17.5/18) — Pencil squeeze phase + hover position.
- `PKToolPicker` (class (PencilKit); iPadOS 14+ (custom tools 18+)) — Tool picker; supports custom tools (iPadOS 18+); positions from squeeze hover pose.
- `UIPencilInteraction` (class (UIKit); iPadOS 12.1+ (hover pose newer)) — Delivers double-tap/squeeze + Pencil hover pose.

## Patterns

### Adaptive 3-column layout that survives arbitrary window sizes  — Primary iPad app shell; must collapse gracefully as the window resizes.
Let SwiftUI auto show/hide columns; don't hard-code widths. Avoid branching whole layouts on horizontalSizeClass alone in iPadOS 26 — windows can be any width, so prefer NavigationSplitView's built-in adaptivity and use size class only for genuine compact fallbacks.
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

### Multi-window + per-window state with programmatic open  — Document/inspector apps where each document opens its own window.
Each WindowGroup window gets fresh @State/@StateObject storage — keep shared truth in a model layer (e.g. @Observable model in the environment or SwiftData) so windows stay in sync.
```swift
@main struct MyApp: App {
  var body: some Scene {
    WindowGroup(id: "editor", for: Document.ID.self) { $docID in
      EditorView(documentID: docID) // independent @State per window
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

### iPad menu bar via SwiftUI commands  — Pro iPad app wanting discoverable commands + keyboard shortcuts in the new menu bar.
Keep menu contents static (never hide items — disable instead), order by frequency, group into sections, assign SF Symbols + shortcuts. Shortcuts also appear in the Cmd-hold discoverability HUD.
```swift
WindowGroup { ContentView() }
  .commands {
    CommandMenu("Insert") {
      Button("Image…") { /* … */ }.keyboardShortcut("i", modifiers: [.command, .shift])
      Button("Table")  { /* … */ }
    }
    CommandGroup(replacing: .help) {
      Button("MyApp Help") { /* … */ }
    }
  }
```

### Transferable drag-and-drop between windows/apps  — Reorder, or move data across Split View / separate windows.
Conform your model to Transferable for both in-app reordering and cross-app drops (e.g. into Notes/Contacts). Provide a meaningful TransferRepresentation/UTType so other apps can accept it.
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

### Custom pointer + precise hover tracking  — Canvas/drawing/pro tools that want cursor affordances and hover feedback.
Use built-in PointerStyle cases (.rectSelection, .grabIdle/.grabActive, .frameResize) before custom shapes. Verify behavior on iPadOS 26's 1:1 pointer — it no longer snaps to controls, so don't rely on magnetism.
```swift
Canvas { ctx, size in /* … */ }
  .pointerStyle(tool == .marquee ? .rectSelection : .default)
  .onContinuousHover { phase in
    switch phase {
    case .active(let p): hoverPoint = p
    case .ended:        hoverPoint = nil
    }
  }
  .hoverEffect(.highlight)
```

### Declare a minimum window size and react to resize (UIKit)  — App breaks below a certain size, or you need to throttle expensive relayout during interactive resize.
Adopt the UIScene lifecycle now (becoming mandatory). Set sizeRestrictions at connect time; defer costly work until isInteractivelyResizing is false. To opt a custom title bar out of the new corner controls, return .minimal from preferredWindowingControlStyle(for:).
```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
  guard let ws = scene as? UIWindowScene else { return }
  ws.sizeRestrictions?.minimumSize = CGSize(width: 480, height: 400)
}

func windowScene(_ ws: UIWindowScene, didUpdateEffectiveGeometry previous: UIWindowScene.Geometry) {
  if !ws.effectiveGeometry.isInteractivelyResizing { rebuildExpensiveLayout() }
}
```

## Pitfalls
- Don't branch entire navigation layouts on horizontalSizeClass — in iPadOS 26 a window can be any width at any time, so size class flips frequently. Prefer NavigationSplitView's built-in column adaptivity; use size class only for true compact fallbacks.
- Window @State is per-window: opening a second WindowGroup window gives fresh @State/@StateObject. Shared data must live in a model layer (environment @Observable, SwiftData, or a store), or windows desync.
- Custom (non-standard) title bars/toolbars can collide with the new corner Window Controls. Standard NavigationStack/SplitView + Toolbar is handled automatically; custom chrome needs containerCornerOffset(_:sizeToFit:) (SwiftUI) or UIView.LayoutRegion insets (UIKit).
- The iPadOS 26 pointer no longer magnetizes/rubber-bands to controls (1:1 tracking). Apps that relied on the old snapping feel or built custom hit-target assumptions should re-test hover and tap targets.
- PointerStyle/pointerStyle(_:) is documented in the SwiftUI reference as macOS 15+/visionOS 2+ only; it is used on iPadOS but availability annotations are inconsistent — wrap in #available / verify on-device rather than trusting the header.
- Menu bar items should never be hidden dynamically — keep them static and disable when unavailable; users expect persistent, predictable menus (HIG).
- The UIScene lifecycle is becoming mandatory; apps still using only UIApplicationDelegate (no scene delegate / no Application Scene Manifest) will need migration and won't get full windowing control (e.g. preferredWindowingControlStyle).
- 'Designed for iPad' apps on Apple silicon Macs scale the whole UI to ~77%, causing blurriness; for a crisp Mac experience use Mac Catalyst with 'Optimize for Mac' rather than relying on the unmodified iPad build.
- Setting UIDesignRequiresCompatibility = YES (or building with an older SDK) keeps legacy window-control behavior but opts you out of the new Liquid Glass / unified controls — don't leave it on unintentionally.
- Don't make destructive layout changes on resize. Per HIG, window-size adaptations should be non-destructive and revert to the starting state when the window grows back.

## iOS 26 changes
- Overlapping resizable windows become the base multitasking model on iPad (replacing the old Split View/Slide Over base); resize handle on every multitasking app, Window Controls, Window Tiling, Exposé.
- Menu Bar extended to all iPads; developer-customizable via SwiftUI commands / UIKit menu builder.
- New 1:1 precise pointer with Liquid Glass hover highlight; old magnetizing/rubber-banding behavior removed.
- New WindowingControlStyle (.automatic/.minimal/.unified) via preferredWindowingControlStyle(for:) and UIDesignRequiresCompatibility compat path.
- New SwiftUI containerCornerOffset(_:sizeToFit:) and UIKit UIView.LayoutRegion / layoutGuide(for:) / edgeInsets(for:) to lay out around corner Window Controls.
- UISceneSizeRestrictions for minimum scene size; UIScene lifecycle on track to become mandatory.
- NavigationSplitView auto shows/hides columns based on live window size.
- Computationally-intensive Background Tasks surfaced via Live Activities.

## iOS 27 preview (pre-GA)
- Faster window gestures (close/switch/drag), faster cursor-driven context menus, CPU scheduler extended to all supported iPads. | Pre-GA developer beta; perf claims and details may change before GA.
- App name shown in status bar; tap/hover it as a quicker entry to the menu bar. | Pre-GA; UI behavior may change.
- iPhone apps on iPad can be resized larger. | Pre-GA.
- Refinements to Stage Manager (more intuitive, better keyboard-shortcut support, freer resizing) reported by hands-on coverage. | Secondary source / pre-GA; not yet confirmed in Apple docs.

## Deprecations
- Base iPad multitasking (full-screen-only + the old Split View / Slide Over model) is superseded by the new overlapping windowing system in iPadOS 26 (Stage Manager retained as optional).
- NavigationView → NavigationStack / NavigationSplitView (NavigationView deprecated since iOS 16; essential for adaptive multi-column iPad layout).
- App-delegate-only lifecycle → UIScene lifecycle (UISceneDelegate/UIWindowSceneDelegate), which is becoming mandatory in the next major release.
- Old magnetizing/rubber-banding iPad pointer behavior → new 1:1 precise pointer with Liquid Glass hover highlight (iPadOS 26).
- UIDragInteraction/UIDropInteraction (UIKit, still valid) → Transferable + draggable/dropDestination for SwiftUI-native drag and drop.
- ObservableObject/@StateObject still work but @Observable (Observation) is the modern idiom for the shared models that back multi-window apps.

## Uncertainties
- Exact platform availability of SwiftUI PointerStyle / pointerStyle(_:) on iPadOS: Apple's reference header lists only macOS 15+/visionOS 2+, yet it is demonstrably used on iPadOS. Could not find an iPadOS-qualified availability line in primary docs — verify on-device / in Xcode 26.
- containerCornerOffset(_:sizeToFit:) and UIView.LayoutRegion details came from a strong secondary source (JuniperPhoton) corroborating WWDC sessions; the canonical Apple reference pages for these were thin/empty at fetch time — confirm exact signatures in Xcode 26 docs.
- Whether iPadOS 26 adds a dedicated NEW SwiftUI/UIKit API specifically to author the Menu Bar beyond existing commands/CommandMenu/UIMenuBuilder, or simply extends the existing commands system to all iPads — sources indicate the latter, but I could not fully confirm there isn't an additional iPad-specific menu API.
- iPadOS 27 windowing/Stage Manager refinement details are from pre-GA hands-on/secondary coverage (MacRumors, AppleInsider), not yet from Apple developer docs/sessions — treat as provisional.
- Did not deeply verify external-display specifics (resolution/extended-vs-mirrored APIs, UIScreen/UISceneDelegate behavior) for iPadOS 26 beyond Apple's statement that the new windowing 'works with an external display'.
- Exact set of CommandGroupPlacement cases and any iPadOS-26-new placements were not enumerated from primary docs in this pass.

## Sources
- Apple Newsroom — iPadOS 26 introduces powerful new features: https://www.apple.com/newsroom/2025/06/ipados-26-introduces-powerful-new-features-that-push-ipad-even-further/
- WWDC25 Session 208 — Elevate the design of your iPad app: https://developer.apple.com/videos/play/wwdc2025/208/
- WWDC25 Session 282 — Make your UIKit app more flexible: https://developer.apple.com/videos/play/wwdc2025/282/
- WWDC25 Session 256 — What's new in SwiftUI: https://developer.apple.com/videos/play/wwdc2025/256/
- Adopting the New Window Controls in iPadOS 26 (JuniperPhoton): https://juniperphoton.substack.com/p/adopting-the-new-window-controls
- SwiftUI — Building and customizing the menu bar with SwiftUI: https://developer.apple.com/documentation/SwiftUI/Building-and-customizing-the-menu-bar-with-SwiftUI
- SwiftUI PointerStyle (reference): https://developer.apple.com/documentation/swiftui/pointerstyle
- SwiftUI pointerStyle(_:) (reference): https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)
- SwiftUI onContinuousHover(coordinateSpace:perform:): https://developer.apple.com/documentation/swiftui/view/oncontinuoushover(coordinatespace:perform:)
- SwiftUI — Adopting drag and drop using SwiftUI: https://developer.apple.com/documentation/SwiftUI/Adopting-drag-and-drop-using-SwiftUI
- SwiftUI NavigationSplitView (reference): https://developer.apple.com/documentation/SwiftUI/NavigationSplitView
- UIKit — UIWindowScene.requestGeometryUpdate(_:errorHandler:): https://developer.apple.com/documentation/uikit/uiwindowscene/requestgeometryupdate(_:errorhandler:)
- SwiftUI PencilHoverPose (reference): https://developer.apple.com/documentation/swiftui/pencilhoverpose
- UIKit — Adopting hover support for Apple Pencil: https://developer.apple.com/documentation/UIKit/adopting-hover-support-for-apple-pencil
- UIKit — Mac Catalyst: https://developer.apple.com/documentation/uikit/mac-catalyst
- MacRumors — iPadOS 27 Hands-On: Everything New for iPad: https://www.macrumors.com/2026/06/17/ipados-27-hands-on/
- AppleInsider — Liquid Glass customization & better Apple Intelligence arrive with iPadOS 27: https://appleinsider.com/articles/26/06/08/liquid-glass-customization-better-apple-intelligence-arrive-with-ipados-27
