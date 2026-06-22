# App & scene structure, navigation

How a SwiftUI iOS/iPadOS app is wired together — the `@main App`, its `Scene`s, and the data-driven navigation containers (`NavigationStack`, `NavigationSplitView`, value-based `Tab`). Getting these shapes right is what makes deep links, multi-window, and iPad layouts "just work"; getting them wrong produces silent failed pushes and selections that won't update.

**Contents**
- [App and Scene skeleton](#app-and-scene-skeleton)
- [Scene phase & lifecycle](#scene-phase--lifecycle)
- [Multi-window (iPad/Mac)](#multi-window-ipadmac)
- [NavigationStack & value destinations](#navigationstack--value-destinations)
- [NavigationSplitView (2/3 column)](#navigationsplitview-23-column)
- [Tabs: value-based Tab API + sidebarAdaptable](#tabs-value-based-tab-api--sidebaradaptable)
- [iOS 26 tab bar: minimize & bottom accessory](#ios-26-tab-bar-minimize--bottom-accessory)
- [Deep linking & routing](#deep-linking--routing)
- [State restoration with SceneStorage](#state-restoration-with-scenestorage)
- [Navigation transitions](#navigation-transitions)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## App and Scene skeleton

Every SwiftUI-lifecycle app is one struct marked `@main` conforming to `App`, returning a `Scene` tree. The default scene is `WindowGroup`; most iPhone apps need exactly one. Other scene types: `WindowGroup(id:)`/`WindowGroup(for:)` (secondary windows), `Window` (single unique window), `DocumentGroup` (file-based apps — free document browser, open/save, iCloud), `Settings` (macOS), `MenuBarExtra` (macOS).

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { RootView() }      // iOS 14+
    }
}
```

There is no `AppDelegate`/`SceneDelegate` in this model unless you opt in via `@UIApplicationDelegateAdaptor`. Use SwiftUI's `@Environment(\.scenePhase)` for lifecycle, not `UIApplication` notifications.

## Scene phase & lifecycle

`@Environment(\.scenePhase)` (iOS 14+) exposes a `ScenePhase` with cases `.active`, `.inactive`, `.background`. Observe transitions with the two-parameter `onChange(of:)` (the only non-deprecated form since iOS 17) to persist state when backgrounding.

```swift
@Environment(\.scenePhase) private var scenePhase
// ...
WindowGroup { RootView() }
    .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .background { saveState() }
    }
```

## Multi-window (iPad/Mac)

Secondary windows are an iPad/Mac feature — on iPhone these calls are **no-ops** (single window). Declare a `WindowGroup(id:)` or `WindowGroup(for:)` in the scene body, then drive it with the `@Environment(\.openWindow)` action (iOS 16+) and `@Environment(\.dismissWindow)` (iOS 17+).

```swift
// In the Scene tree:
WindowGroup("Inspector", id: "inspector", for: Item.ID.self) { $id in
    InspectorView(itemID: id)
}

// In a view:
@Environment(\.openWindow) private var openWindow
Button("Open") { openWindow(id: "inspector", value: item.id) }
```

Gate any feature that *depends* on a second window behind an idiom/size-class check — don't build a core flow that assumes one exists.

## NavigationStack & value destinations

`NavigationStack` (iOS 16+) is the modern hierarchical container; `NavigationView` is **deprecated** — never use it in new code. Pushes are value-based and keyed by the value's **type**: `NavigationLink(_:value:)` appends a value, and a single `.navigationDestination(for: T.self)` declared on the stack's root content maps that type to a destination view.

Programmatic control comes from `NavigationStack(path:)`. The path is either a `NavigationPath` (type-erased, heterogeneous, `Codable` when its elements are) or a typed `[Route]` array binding. Prefer a typed enum array when all destinations share one type — it's far easier to inspect and persist. Centralize it on an `@Observable` router (the modern idiom — not `ObservableObject`).

```swift
@Observable final class Router { var path = NavigationPath() }

struct ContentView: View {
    @State private var router = Router()
    var body: some View {
        NavigationStack(path: $router.path) {
            List(items) { item in
                NavigationLink(item.name, value: item)        // value-based push
            }
            .navigationDestination(for: Item.self) { item in  // declared ONCE, on root content
                ItemDetail(item: item)
            }
        }
    }
}
```

For a single boolean-driven push, use `.navigationDestination(isPresented:)`; for an optional value, `.navigationDestination(item:)`. The deprecated `NavigationLink(destination:isActive:)` and `(_:tag:selection:)` still compile but interact badly with `NavigationStack` — never mix them with `.navigationDestination`.

## NavigationSplitView (2/3 column)

`NavigationSplitView` (iOS 16+) gives 2-column (sidebar + detail) or 3-column (sidebar + content + detail) layouts for iPad/Mac, and **auto-collapses to a single pushed stack on compact (iPhone) widths** with no extra code. Columns are driven by **selection bindings** (`List(selection:)`), not `NavigationLink`. Control visibility with a `NavigationSplitViewVisibility` binding (`.all`/`.doubleColumn`/`.detailOnly`/`.automatic`) and overall behavior with `.navigationSplitViewStyle(.balanced / .prominentDetail / .automatic)`.

On iOS, `List(selection:)` requires an **optional** binding — `Binding<SelectionValue?>` (nil = nothing selected). The non-optional single-selection initializer (`init(selection: Binding<SelectionValue>, …)`) is marked *unavailable in iOS* and fails to compile. So a sidebar that selects a non-optional enum still needs `@State private var selection: Filter?` (optional), defaulting the content to a fallback when it's nil.

```swift
NavigationSplitView(columnVisibility: $visibility) {
    List(categories, selection: $selectedCategory) { Text($0.name).tag($0) }
} content: {
    List(items, selection: $selectedItem) { Text($0.title).tag($0) }
} detail: {
    if let selectedItem { ItemDetail(item: selectedItem) }
    else { ContentUnavailableView("Select an item", systemImage: "doc") }  // empty-detail idiom
}
.navigationSplitViewStyle(.balanced)
```

## Tabs: value-based Tab API + sidebarAdaptable

Use the value-based `Tab` builder (iOS 18+) inside `TabView(selection:)` — this replaces the old `.tag()` pattern. Each `Tab("Label", systemImage:, value:)` carries a selection value whose type must **exactly match** the `selection` binding's type, or selection silently won't update. Group tabs with `TabSection`.

`.tabViewStyle(.sidebarAdaptable)` (iOS 18+) shows a tab bar on compact iPhone and an automatic sidebar on regular-width iPad/Mac — no manual sidebar to build. `Tab(role: .search)` (iOS 18+) renders a dedicated search tab that, under iOS 26 Liquid Glass, visually separates and morphs into a search field when selected.

```swift
TabView(selection: $selection) {
    Tab("Home", systemImage: "house", value: Screen.home) { HomeView() }
    Tab("Library", systemImage: "books.vertical", value: Screen.library) { LibraryView() }
    TabSection("Collections") {
        Tab("Recent", systemImage: "clock", value: Screen.recent) { RecentView() }
    }
    Tab(role: .search) { SearchView() }
}
.tabViewStyle(.sidebarAdaptable)
```

See `liquid-glass.md` for the visual treatment and `swiftui-views.md` for search field wiring (`.searchable`).

## iOS 26 tab bar: minimize & bottom accessory

iOS 26's Liquid Glass tab bar floats and can collapse on scroll. `.tabBarMinimizeBehavior(_:)` (iOS 26) takes a `TabBarMinimizeBehavior` — `.automatic`, `.onScrollDown`, `.onScrollUp`, `.never`. `.tabViewBottomAccessory { ... }` (iOS 26) adds a floating panel above the tab bar — the canonical use is a mini player. Inside the accessory, read `@Environment(\.tabViewBottomAccessoryPlacement)` to adapt its layout when inline vs expanded.

```swift
TabView(selection: $selection) { /* tabs */ }
    .tabBarMinimizeBehavior(.onScrollDown)   // iOS 26 — no-op on legacy appearance
    .tabViewBottomAccessory { MiniPlayerView() }   // iOS 26
```

Both modifiers are **no-ops** under the legacy (non-Liquid-Glass) appearance; they only animate on iOS 26's new design.

## Deep linking & routing

Attach `.onOpenURL { url in ... }` (iOS 14+) to handle custom URL schemes and Universal Links. Drive navigation by mutating the shared router's path or the tab selection. Put the same `@Observable` router in the environment so deep links, widgets, and App Intents (see `system-integration.md`) all funnel into one place.

```swift
.onOpenURL { url in
    guard let route = Route(url: url) else { return }
    router.path = NavigationPath()   // reset to avoid a stale stack
    router.path.append(route)        // then push the target
}
```

Reset before appending — appending onto a non-empty path leaves the previous stack underneath the deep-linked screen.

## State restoration with SceneStorage

`@SceneStorage("key")` (iOS 14+) persists **small** per-scene UI state — selected tab, scroll target, draft text — across relaunches automatically. It is not a model store; large or shared data belongs in SwiftData / your persistence layer (see `data-persistence.md`). To restore a full navigation stack, persist a `Codable` `NavigationPath` yourself (`NavigationPath(codable:)` / `.codable`) alongside it.

```swift
@SceneStorage("selectedTab") private var selectedTab: Screen = .home
```

## Navigation transitions

The zoom transition (iOS 18+) pairs `.matchedTransitionSource(id:in:)` on the source with `.navigationTransition(.zoom(sourceID:in:))` on the destination for a matched-geometry zoom into detail.

**iOS 27 (pre-GA, WWDC 2026 — ships fall 2026, API may change):** `CrossFadeNavigationTransition` adds a built-in cross-fade with no source view required, and `AnyNavigationTransition` type-erases a transition so you can choose one at runtime. Custom `NavigationTransition` conformances remain **unsupported** as of the iOS 27 beta. Also pre-GA: `.toolbarMinimizeBehavior(_:)` to auto-collapse the nav bar on scroll, plus new toolbar overflow / `visibilityPriority` / trailing-pin controls for adaptive toolbars — names from WWDC recaps, verify against final docs. (`ToolbarSpacer`, for grouping toolbar items, is shipping in iOS 26.)

## Pitfalls

- **Destination must be in the tree at push time.** `.navigationDestination(for: Item.self)` declared inside a lazy/conditional branch (or below the pushed content) yields a runtime "no destination found" warning and a failed push. Declare it once, on the stack's root content.
- **Don't put `.navigationDestination(for:)` inside a `ForEach`/`List` row.** That registers duplicate destinations. One per type, on the stack content.
- **`NavigationPath` persistence is all-or-nothing.** Every element must be `Codable` (and you must use the `codable` initializer) — a single non-Codable element makes the whole path non-persistable.
- **Split-view columns are selection-driven.** Using `NavigationLink` inside a `NavigationSplitView` sidebar fights the column model; use `List(selection:)` bindings instead.
- **`List(selection:)` needs an OPTIONAL binding on iOS.** Passing a non-optional `Binding<T>` resolves to the iOS-unavailable initializer and fails to compile (`'init(selection:content:)' is unavailable in iOS`). Make the selection state `T?`.
- **iOS 26 tab-bar modifiers silently do nothing on legacy appearance.** `.tabBarMinimizeBehavior` / `.tabViewBottomAccessory` require Liquid Glass.
- **`openWindow`/`dismissWindow` are no-ops on iPhone.** Don't assume a second window; gate behind idiom/size-class checks.
- **Tab selection type must match exactly.** `Tab(value:)` and `TabView(selection:)` must share one type or selection won't update — and nothing warns you.
- **Deep link without reset leaves a stale stack.** Clear the path/selection before appending the target.
- **`@SceneStorage` is UI state only** — per-scene, small. Not for model data.
- **Don't reach for `NavigationView`, `StackNavigationViewStyle`, or `NavigationLink(isActive:)/(tag:selection:)`** — all deprecated. Use `NavigationStack`/`NavigationSplitView` + value destinations.

## Primary sources

- Migrating to new navigation types: https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types
- WWDC25 256 — What's new in SwiftUI: https://developer.apple.com/videos/play/wwdc2025/256/
- WWDC25 323 — Build a SwiftUI app with the new design: https://developer.apple.com/videos/play/wwdc2025/323/
- WWDC26 SwiftUI guide: https://developer.apple.com/wwdc26/guides/swiftui/
- Donny Wals — Tab bars on iOS 26 with Liquid Glass: https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/
- Nil Coalescing — Navigation transition updates in SwiftUI on iOS 27: https://nilcoalescing.com/blog/SwiftUINavigationTransitionUpdatesIniOS27/
