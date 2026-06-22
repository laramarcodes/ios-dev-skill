# DOMAIN: SwiftUI App & Scene structure, navigation (NavigationStack/SplitView, TabView, windows, deep linking, state restoration) — iPhone & iPad, iOS 26 shipping / iOS 27 pre-GA

## Orientation
 SwiftUI app structure is a single `@main` struct conforming to `App`, returning one or more `Scene`s (almost always a `WindowGroup`, plus `DocumentGroup`, `Settings`, `MenuBarExtra` as needed). Navigation has fully migrated to value-based, data-driven APIs: `NavigationStack` (with `navigationDestination(for:)` and an optional `NavigationPath`/typed array binding) for hierarchical flows, and `NavigationSplitView` (2- or 3-column) for iPad/Mac multi-column UIs that auto-collapse to a stack on compact iPhone widths. The legacy `NavigationView` and `NavigationLink(destination:isActive:)`/`(_:tag:selection:)` are deprecated and must not be used in new code. Tabs use the iOS 18+ value-based `Tab`/`TabView(selection:)` builder API with `.tabViewStyle(.sidebarAdaptable)` and `TabSection` for iPad sidebars. iOS 26's headline change is the Liquid Glass redesign: a floating glass tab bar that can minimize on scroll (`tabBarMinimizeBehavior`), a dedicated search tab via `Tab(role: .search)`, and a `tabViewBottomAccessory` slot (e.g. a mini player). iOS 27 (pre-GA, WWDC 2026) layers on richer navigation transitions (`CrossFadeNavigationTransition`, `AnyNavigationTransition`), new toolbar overflow/visibility-priority controls, foldable-aware adaptive scene APIs, and `@State` becoming a macro with lazy one-time initialization. Deep linking is `onOpenURL`; cross-window control is the `openWindow`/`dismissWindow` environment actions; lightweight per-scene UI state restores via `@SceneStorage`.

## Key facts
- [since iOS 14, current in iOS 26|high] App entry point is a struct marked `@main` conforming to `App`, with a `var body: some Scene`. The primary scene is `WindowGroup`. Other scene types: `DocumentGroup`, `Settings` (macOS), `WindowGroup(id:)`, `Window` (single unique window), `MenuBarExtra`, `ImmersiveSpace` (visionOS).
- [since iOS 14, current in iOS 26|high] `@Environment(\.scenePhase)` exposes scene lifecycle as `ScenePhase` with cases `.active`, `.inactive`, `.background`; observe via `.onChange(of: scenePhase)` to save state when backgrounding.
- [since iOS 16 / 17|high] Multiple/secondary windows on iPad and Mac are opened via the `@Environment(\.openWindow)` action (`openWindow(id:)` or `openWindow(value:)`) and closed via `@Environment(\.dismissWindow)`. Requires a `WindowGroup(id:)` or `WindowGroup(for:)` declared in the scene body. On iPhone these are no-ops (single window).
- [since iOS 16, current in iOS 26|high] Modern hierarchical navigation is `NavigationStack`. It pushes views declared by `.navigationDestination(for: SomeType.self) { value in ... }`, and links are value-based: `NavigationLink("Title", value: someValue)`. Programmatic control via `NavigationStack(path: $path)` where path is `NavigationPath` (type-erased, heterogeneous) or a typed `[T]` array binding.
- [since iOS 16|high] `NavigationPath` is a type-erased stack of `Hashable` values supporting `append`, `removeLast`, `count`, and `isEmpty`; it is `Codable` when its elements are, enabling persistence. Use a typed `[Route]` binding instead when all destinations share one enum type.
- [since iOS 16, current in iOS 26|high] `NavigationSplitView` provides 2-column (sidebar+detail) and 3-column (sidebar+content+detail) layouts. Column visibility is driven by a `NavigationSplitViewVisibility` binding; preferred widths via `.navigationSplitViewColumnWidth(...)`; collapse/expand style via `.navigationSplitViewStyle(.balanced / .prominentDetail)`. On compact (iPhone) size classes it automatically collapses into a single `NavigationStack`-like pushed presentation.
- [since iOS 18, current in iOS 26|high] Value-based Tab API (iOS 18+): build tabs with `Tab("Label", systemImage: "icon", value: someTag) { Content() }` inside `TabView(selection: $selection)`. This replaces the older `.tag()` modifier pattern. Tabs can be grouped into a sidebar with `TabSection`.
- [since iOS 18, current in iOS 26|high] `.tabViewStyle(.sidebarAdaptable)` automatically shows a tab bar on compact iPhone and a sidebar on regular-width iPad/Mac, eliminating manual sidebar construction. Combine with `TabSection` for grouped sidebar entries and customization.
- [role:.search since iOS 18; Liquid Glass visual treatment new in iOS 26|high] Search tab: `Tab(role: .search) { ... }` renders a dedicated, visually separated search tab that transforms into a search field when selected under the iOS 26 Liquid Glass tab bar. SwiftUI positions it consistently across platforms.
- [new in iOS 26|high] iOS 26 Liquid Glass tab bar can minimize on scroll: `.tabBarMinimizeBehavior(_:)` on the `TabView`, taking a `TabBarMinimizeBehavior` value — `.automatic`, `.onScrollDown`, `.onScrollUp`, `.never`. The minimize effect only occurs under the new design (no-op on legacy/iOS 18 appearance).
- [new in iOS 26|high] `.tabViewBottomAccessory { AccessoryView() }` adds a floating accessory panel above the Liquid Glass tab bar (e.g. a mini music player). Read the accessory's collapsed/expanded placement via `@Environment(\.tabViewBottomAccessoryPlacement)`.
- [since iOS 14, current in iOS 26|high] Deep links: attach `.onOpenURL { url in ... }` to a scene/top-level view to handle custom URL schemes and Universal Links; multiple handlers can be installed and the most appropriate one responds. Drive navigation by mutating the `NavigationPath`/selection state the handler updates.
- [since iOS 14, current in iOS 26|high] Lightweight automatic state restoration uses `@SceneStorage("key") var x` — per-scene, persisted by the system across relaunches, for small UI state (selected tab, scroll target, draft text). Not for model data; pair with `Codable` `NavigationPath` persistence for restoring nav stacks.
- [since iOS 14, current in iOS 26|high] `DocumentGroup(newDocument:)` builds a document-based app scene around a `FileDocument` or `ReferenceFileDocument` (or `PackageDocument`), giving free document browser, open/save, rename, and iCloud integration on iPhone/iPad.
- [zoom since iOS 18; CrossFade/AnyNavigationTransition iOS 27 (pre-GA, may change)|medium] Navigation transitions: `NavigationTransition` protocol (iOS 18) with `.zoom(sourceID:in:)` matched-geometry zoom via `.matchedTransitionSource(id:in:)`. iOS 27 (pre-GA) adds `CrossFadeNavigationTransition` and `AnyNavigationTransition` (type-erased, for choosing a transition dynamically at runtime). Custom `NavigationTransition` conformances are still NOT supported as of iOS 27 beta.
- [ToolbarSpacer iOS 26; toolbarMinimizeBehavior/overflow iOS 27 (pre-GA, may change)|medium] iOS 27 (pre-GA) toolbar additions: `.toolbarMinimizeBehavior(_:)` auto-collapses the navigation bar on scroll; new `visibilityPriority`, `toolbarOverflowMenu`, and trailing-pinning controls govern how toolbar items collapse as the app resizes. `ToolbarSpacer` (iOS 26) groups items.
- [iOS 27 (pre-GA, may change)|low] iOS 27 (pre-GA): `@State` becomes a macro and classes stored in `@State` are initialized lazily exactly once per view lifetime; new adaptive-layout/scene APIs add foldable hinge-state detection, with fluid reflow (not letterboxing) as the expected default.

## APIs
- `App` (protocol; iOS 14+) — @main entry; body returns some Scene.
- `Scene` (protocol; iOS 14+) — 
- `WindowGroup` (struct (Scene); iOS 14+) — WindowGroup(id:) / WindowGroup(for:) for multi-window.
- `DocumentGroup` (struct (Scene); iOS 14+) — FileDocument / ReferenceFileDocument.
- `ScenePhase` (enum; iOS 14+) — .active/.inactive/.background via @Environment(\.scenePhase).
- `openWindow` (EnvironmentValue action; iOS 16+) — @Environment(\.openWindow); pair dismissWindow.
- `dismissWindow` (EnvironmentValue action; iOS 17+) — 
- `NavigationStack` (struct (View); iOS 16+) — NavigationStack(path:) with NavigationPath or [T] binding.
- `NavigationPath` (struct; iOS 16+) — Type-erased Hashable stack; Codable when elements are.
- `navigationDestination(for:destination:)` (modifier; iOS 16+) — Also navigationDestination(isPresented:) and (item:).
- `NavigationLink` (struct (View); value init iOS 16+) — NavigationLink(_:value:); destination:/isActive:/tag:selection: deprecated.
- `NavigationSplitView` (struct (View); iOS 16+) — 2- and 3-column; columnVisibility: NavigationSplitViewVisibility.
- `NavigationSplitViewVisibility` (enum; iOS 16+) — .all/.doubleColumn/.detailOnly/.automatic.
- `navigationSplitViewStyle` (modifier; iOS 16+) — .balanced / .prominentDetail / .automatic.
- `TabView(selection:)` (struct (View); iOS 14+ (value Tab builder iOS 18+)) — 
- `Tab` (struct; iOS 18+) — Tab(_:systemImage:value:){}; Tab(role: .search).
- `TabRole` (struct; iOS 18+) — .search.
- `TabSection` (struct; iOS 18+) — Grouped sidebar section.
- `tabViewStyle` (modifier; iOS 18+ for .sidebarAdaptable) — .sidebarAdaptable / .tabBarOnly / .page.
- `tabBarMinimizeBehavior` (modifier; iOS 26) — TabBarMinimizeBehavior: .automatic/.onScrollDown/.onScrollUp/.never.
- `tabViewBottomAccessory` (modifier; iOS 26) — Floating accessory; tabViewBottomAccessoryPlacement env value.
- `onOpenURL(perform:)` (modifier; iOS 14+) — Deep links / Universal Links.
- `SceneStorage` (property wrapper; iOS 14+) — @SceneStorage per-scene UI state restoration.
- `NavigationTransition` (protocol; iOS 18+) — .zoom(sourceID:in:) + matchedTransitionSource(id:in:).
- `CrossFadeNavigationTransition` (struct; iOS 27 (pre-GA)) — Built-in cross-fade; may change.
- `AnyNavigationTransition` (struct; iOS 27 (pre-GA)) — Type-erased; runtime transition choice.
- `toolbarMinimizeBehavior` (modifier; iOS 27 (pre-GA)) — Auto-collapse nav bar on scroll.
- `ToolbarSpacer` (struct; iOS 26) — Group/space toolbar items.
- `Observable` (macro; iOS 17+) — @Observable Router replaces ObservableObject for nav state.

## Patterns

### App entry, scene, scenePhase save-on-background  — Every app's root.
One WindowGroup is the norm. Use scenePhase, not UIApplication notifications, for lifecycle in SwiftUI.
```swift
@main
struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup { RootView() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background { saveState() }
            }
    }
}
```

### Path-based NavigationStack with value destinations  — Hierarchical drill-down where you need programmatic push/pop and deep-link control.
Destination is keyed by the value's TYPE. Pushing appends a value; popping is router.path.removeLast(). Prefer a typed [Route] enum array binding when all routes share one type — it is easier to inspect/persist than NavigationPath.
```swift
@Observable final class Router { var path = NavigationPath() }

struct ContentView: View {
    @State private var router = Router()
    var body: some View {
        NavigationStack(path: $router.path) {
            List(items) { item in
                NavigationLink(item.name, value: item)   // value-based
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetail(item: item)
            }
        }
    }
}
```

### Adaptive tabs that become an iPad sidebar with a search tab  — 5+ destinations; want a tab bar on iPhone and a sidebar on iPad automatically.
.sidebarAdaptable gives the iPad sidebar for free. Tab(role:.search) gets the dedicated iOS 26 glass search tab. tabBarMinimizeBehavior only animates under Liquid Glass.
```swift
TabView(selection: $selection) {
    Tab("Home", systemImage: "house", value: .home) { HomeView() }
    Tab("Library", systemImage: "books.vertical", value: .library) { LibraryView() }
    TabSection("Collections") {
        Tab("Recent", systemImage: "clock", value: .recent) { RecentView() }
    }
    Tab(role: .search) { SearchView() }
}
.tabViewStyle(.sidebarAdaptable)
.tabBarMinimizeBehavior(.onScrollDown)
```

### Two/three-column NavigationSplitView (auto-collapses on iPhone)  — iPad-first master/detail apps.
Selection bindings (not NavigationLink) drive split-view columns. It collapses to a single stack on compact width with no extra code. Use ContentUnavailableView for empty detail.
```swift
NavigationSplitView(columnVisibility: $visibility) {
    List(categories, selection: $selectedCategory) { Text($0.name).tag($0) }
} content: {
    List(items, selection: $selectedItem) { Text($0.title).tag($0) }
} detail: {
    if let selectedItem { ItemDetail(item: selectedItem) }
    else { ContentUnavailableView("Select an item", systemImage: "doc") }
}
.navigationSplitViewStyle(.balanced)
```

### Deep link / widget / App Intent navigation into a stack  — Opening from a URL, widget, or App Intent must land on a specific screen.
Centralize routing on a shared @Observable Router in the environment so onOpenURL, widgets, and App Intents all mutate the same path. Reset before appending to avoid stale stacks.
```swift
.onOpenURL { url in
    guard let route = Route(url: url) else { return }
    router.path = NavigationPath()      // reset
    router.path.append(route)           // then push target
}
```

### Floating bottom accessory (mini player) above the glass tab bar  — Persistent now-playing / status control across tabs on iOS 26.
New in iOS 26. Inside the accessory, read @Environment(\.tabViewBottomAccessoryPlacement) to adapt its layout when expanded vs inline.
```swift
TabView(selection: $selection) { /* tabs */ }
    .tabViewBottomAccessory { MiniPlayerView() }
```

### Secondary window on iPad/Mac  — Multi-window iPad apps.
Declare the WindowGroup(id:/for:) in the scene, then call openWindow. No-op on iPhone — gate multi-window features behind size class / idiom checks.
```swift
// Scene:
WindowGroup("Inspector", id: "inspector", for: Item.ID.self) { $id in
    InspectorView(itemID: id)
}
// In a view:
@Environment(\.openWindow) private var openWindow
Button("Open") { openWindow(id: "inspector", value: item.id) }
```

## Pitfalls
- Navigation identity is value-TYPE-keyed: `.navigationDestination(for: Item.self)` must be reachable in the view tree at push time. Declaring it inside a lazy/conditional branch (or below the pushed content) causes a runtime 'no destination found' warning and a failed push.
- Putting `.navigationDestination(for:)` inside a `ForEach`/`List` row instead of once on the stack content registers duplicate destinations — declare it ONCE on the stack's root content.
- `NavigationPath` only accepts `Hashable` values; mixing types is fine, but to persist it every element must also be `Codable` and you must use `NavigationPath(codable:)`/`.codable`. A single non-Codable element makes the whole path non-persistable.
- `NavigationSplitView` columns are driven by SELECTION bindings (List(selection:)), not `NavigationLink` — using NavigationLink inside a split view's sidebar fights the column model.
- `tabBarMinimizeBehavior` and `tabViewBottomAccessory` are no-ops if the app opts out of the new design / runs the legacy appearance; they only animate under Liquid Glass on iOS 26.
- `openWindow`/`dismissWindow` silently do nothing on iPhone (single-window). Don't build core flows assuming a second window exists; gate behind `UIDevice`/size-class/idiom checks.
- Value-based `Tab(value:)` selection type must exactly match the `TabView(selection:)` binding type, or selection silently won't update.
- Resetting navigation on deep link by appending without clearing leaves a stale stack; reset `path = NavigationPath()` (or empty the array) before appending the target.
- `@SceneStorage` is for small UI state only — it is per-scene and not a model store; large or shared data belongs in your model layer / SwiftData / persistence.
- Old `NavigationLink(isActive:)` / `(tag:selection:)` compile (deprecated) but interact badly with NavigationStack — never mix them with `.navigationDestination`.

## iOS 26 changes
- Liquid Glass floating tab bar; `.tabBarMinimizeBehavior(_:)` (.automatic/.onScrollDown/.onScrollUp/.never) to collapse the tab bar on scroll.
- `.tabViewBottomAccessory { ... }` floating accessory slot above the tab bar; placement via @Environment(\.tabViewBottomAccessoryPlacement).
- `Tab(role: .search)` renders the dedicated, visually separated glass search tab that morphs into a search field.
- `ToolbarSpacer` to group/space toolbar items; sheets are inset with Liquid Glass background and pull bottom edges in at smaller detents.

## iOS 27 preview (pre-GA)
- `CrossFadeNavigationTransition` — built-in cross-fade transition (no source view required). | Pre-GA WWDC 2026 beta; API may change before release.
- `AnyNavigationTransition` — type-erased wrapper to pick a navigation transition dynamically at runtime. Custom NavigationTransition conformances still unsupported. | Pre-GA; custom conformance still not allowed as of beta.
- `.toolbarMinimizeBehavior(_:)` auto-collapses the nav bar on scroll; new `visibilityPriority`, `toolbarOverflowMenu`, trailing-pin controls for adaptive toolbars. | Pre-GA WWDC 2026 beta.
- Adaptive scene/layout APIs for foldables (hinge-state detection, fluid reflow over letterboxing); `swipeActionsContainer()` extends swipe actions beyond List to LazyVStack/LazyVGrid/custom Layout. | Pre-GA; foldable hardware/behavior speculative.
- `@State` becomes a macro; classes in @State are lazily initialized once per view lifetime. | Pre-GA; low confidence, verify against final docs.

## Deprecations
- `NavigationView` is deprecated — use `NavigationStack` (single column) or `NavigationSplitView` (multi-column).
- `NavigationLink(destination:isActive:)` and `NavigationLink(_:tag:selection:)` are deprecated — use value-based `NavigationLink(_:value:)` + `.navigationDestination(for:)`, or `.navigationDestination(isPresented:)` for a single boolean-driven push.
- `StackNavigationViewStyle`/`.navigationViewStyle(...)` no longer needed — `NavigationStack` is always a stack.
- ObservableObject + @StateObject/@ObservedObject for routers superseded by the @Observable macro + @State/@Bindable (still works, but @Observable is the modern idiom for a Router).
- Manual UISceneDelegate state restoration superseded by @SceneStorage and Codable NavigationPath persistence in SwiftUI-lifecycle apps.

## Uncertainties
- Exact final names/signatures of iOS 27 toolbar APIs (`visibilityPriority`, `toolbarOverflowMenu`, trailing-pin modifier) are from secondary WWDC 2026 recaps, not yet confirmed against developer.apple.com reference — treat as pre-GA and verify.
- The `@State`-as-macro / lazy-once class init claim for iOS 27 is from a single secondary source (low confidence); confirm against Apple's final SwiftUI release notes.
- Could not load the Apple `migrating-to-new-navigation-types` page body directly (WebFetch returned no content); deprecation specifics are corroborated from Apple session video + multiple secondary sources but exact deprecation availability strings were not read verbatim.
- `swipeActionsContainer()` and foldable adaptive-scene specifics are pre-GA WWDC 2026 material and may be renamed or cut before iOS 27 GA.
- Whether `.never` is a documented case of `TabBarMinimizeBehavior` (vs only .automatic/.onScrollDown/.onScrollUp) should be confirmed against the framework header.

## Sources
- Apple: Migrating to new navigation types: https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types
- WWDC25 256 — What's new in SwiftUI: https://developer.apple.com/videos/play/wwdc2025/256/
- WWDC25 323 — Build a SwiftUI app with the new design: https://developer.apple.com/videos/play/wwdc2025/323/
- WWDC26 SwiftUI guide (Apple Developer): https://developer.apple.com/wwdc26/guides/swiftui/
- Donny Wals — Exploring tab bars on iOS 26 with Liquid Glass: https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/
- Swift with Majid — Glassifying tabs in SwiftUI: https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/
- Nil Coalescing — SwiftUI Search Enhancements in iOS and iPadOS 26: https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/
- Nil Coalescing — Navigation transition updates in SwiftUI on iOS 27: https://nilcoalescing.com/blog/SwiftUINavigationTransitionUpdatesIniOS27/
- Create with Swift — Making the tab bar collapse while scrolling: https://www.createwithswift.com/making-the-tab-bar-collapse-while-scrolling/
- DEV — WWDC26 What's New in SwiftUI: A Developer's Breakdown: https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333
- Appcircle — WWDC26 What's New in SwiftUI: https://appcircle.io/blog/wwdc26-whats-new-in-swiftui
- Swift with Majid — Deep linking in SwiftUI: https://swiftwithmajid.com/2024/04/09/deep-linking-for-local-notifications-in-swiftui/
