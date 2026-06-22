# AppScaffold — a polished, adaptive iOS/iPadOS SwiftUI starter

A small but real, **buildable** starting point for a native iPhone + iPad app,
using the current (iOS 26) stack. It is the template the `ios-dev` skill's
scaffold script copies and renames.

## What it demonstrates

- **Adaptive `NavigationSplitView`** — sidebar + list + detail on iPad, the same
  code collapsing to push-navigation on iPhone.
- **SwiftData persistence** — one `@Model` (`Item`), a shared `ModelContainer`,
  and a **dynamic `@Query`** whose predicate is rebuilt from the sidebar filter
  and the search field.
- **Observation + `@Bindable`** — editing model state and having SwiftUI react.
- **Liquid Glass adoption** — standard controls get it for free by building
  against the iOS 26 SDK; the detail badge and primary button adopt it
  explicitly with `.glassEffect(...)` and `.buttonStyle(.glassProminent)`.
- **`.searchable`, swipe actions, `ContentUnavailableView`, `.symbolEffect`** —
  the everyday polish.
- **A clean create/edit sheet** that edits local state and commits only on Save.
- **Swift 6.2 "Approachable Concurrency"** — the whole module is `@MainActor` by
  default, so the UI code needs no `Sendable` ceremony.
- **Swift Testing** — `@Test`/`#expect` unit tests against an in-memory store,
  including a parameterized test.

## Generate and open

This template is driven by [XcodeGen](https://github.com/yonyz/XcodeGen) — the
source of truth is `project.yml`, **not** the `.xcodeproj` (which is generated
and git-ignored).

```bash
# From the skill's scaffold script (renames the app for you):
python3 <skill>/scripts/new_ios_app.py "MyApp" --bundle-id com.you.myapp --dest ~/Developer/MyApp

# …or directly inside a copy of this template:
brew install xcodegen      # once
xcodegen generate
open AppScaffold.xcodeproj
```

Pick an **iPhone** or **iPad** simulator and press Run. Try it on both — the
layout adapts. Requires **Xcode 26+** with the **iOS 26 SDK**.

## Project layout

```
AppScaffold/
├── project.yml                     # XcodeGen spec (edit this, then re-generate)
├── AppScaffold/
│   ├── AppScaffoldApp.swift        # @main App + ModelContainer + seed
│   ├── Models/
│   │   ├── Item.swift              # @Model + sample data
│   │   └── Category.swift          # Category + SidebarFilter
│   ├── Navigation/
│   │   └── RootView.swift          # the adaptive NavigationSplitView
│   ├── Views/
│   │   ├── SidebarView.swift       # filter list (column 1)
│   │   ├── ItemListView.swift      # dynamic @Query list (column 2)
│   │   ├── ItemDetailView.swift    # detail (column 3)
│   │   └── ItemEditView.swift      # create/edit sheet + SymbolPicker
│   ├── DesignSystem/
│   │   └── PreviewData.swift       # in-memory container for #Preview (DEBUG only)
│   └── Assets.xcassets/            # AppIcon + AccentColor
└── AppScaffoldTests/
    └── AppScaffoldTests.swift      # Swift Testing suite
```

## Changing the minimum iOS version

`project.yml` sets the deployment target to `26.0` so the template can use Liquid
Glass freely. To support older devices, lower it (e.g. `18.0`) and wrap the
iOS 26-only calls (`.glassEffect`, `.buttonStyle(.glassProminent)`) in
`if #available(iOS 26, *)`. Remember: the **App Store still requires building
with the iOS 26 SDK** regardless of how low your deployment target is.
