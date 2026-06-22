# Widgets, App Intents, Live Activities & Controls

App Intents is the central nervous system for system integration on modern iOS: build an action once and it powers Siri, Spotlight, Shortcuts, interactive widgets, Control Center controls, Live Activity buttons, and Apple Intelligence. Everything else here (WidgetKit, ActivityKit, AlarmKit, Visual Intelligence) plugs into that one layer.

**Contents**
- [The App Intents layer (start here)](#the-app-intents-layer-start-here)
- [Entities, queries & Spotlight](#entities-queries--spotlight)
- [WidgetKit](#widgetkit)
- [Interactive widgets](#interactive-widgets)
- [Accented / tinted rendering](#accented--tinted-rendering)
- [Push & relevance updates](#push--relevance-updates)
- [Control Center controls (iOS 18)](#control-center-controls-ios-18)
- [Live Activities & Dynamic Island](#live-activities--dynamic-island)
- [AlarmKit (iOS 26)](#alarmkit-ios-26)
- [Siri, snippets & Visual Intelligence](#siri-snippets--visual-intelligence)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## The App Intents layer (start here)

An `AppIntent` (since iOS 16) is a `struct` with a static `title`, `@Parameter` inputs, and an `async perform()` returning `some IntentResult`. The same intent backs Siri, Spotlight, Shortcuts, widget buttons, controls, and Live Activities — write the action once, surface it everywhere. This is the modern idiom; the deprecated path is SiriKit `.intentdefinition` custom intents (see deprecations below).

Register up to **10** App Shortcuts per app via a single `AppShortcutsProvider`. Shortcuts appear in Shortcuts, Spotlight, and Siri **without the user opening the app**. Phrases must include `\(.applicationName)` or they won't register.

```swift
struct LogCoffeeIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Coffee"
    @Parameter(title: "Cups") var cups: Int
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Tracker.shared.log(cups: cups)
        return .result(dialog: "Logged \(cups) cups")
    }
}

struct CoffeeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogCoffeeIntent(),
            phrases: ["Log coffee in \(.applicationName)"],
            shortTitle: "Log Coffee", systemImageName: "cup.and.saucer")
    }
}
```

Keep `perform()` fast and side-effecting. Return `ProvidesDialog` for spoken/written replies or `ShowsSnippetView` (iOS 26) for rich UI. New iOS 26 capabilities on the intent layer:

| API | Purpose | Since |
|---|---|---|
| `UndoableIntent` | Registers undo with the system `undoManager` | iOS 26 |
| `supportedModes` / `IntentModes` | Declare `.background` / `.foreground(.dynamic)`; `continueInForeground()` escalates mid-run | iOS 26 |
| `TargetContentProvidingIntent` + `.onAppIntentExecution(_:)` | Move navigation out of the intent into the view layer | iOS 26 |
| `@ComputedProperty` / `@DeferredProperty` | Derived (no storage) / async-lazy entity properties | iOS 26 |
| `@UnionValue` | A query that returns more than one entity type | iOS 26 |
| `AppIntentsPackage` | Ship App Intents from a Swift Package (`includedPackages`) | iOS 26 |

## Entities, queries & Spotlight

An `AppEntity` (the noun your intents act on) needs an `id`, a `displayRepresentation`, and a `defaultQuery`. Pick the query protocol by lookup shape:

| Protocol | Use | Since |
|---|---|---|
| `EntityQuery` | `suggestedEntities()` — default suggestions | iOS 16 |
| `EnumerableEntityQuery` | `allEntities()` — small bounded sets | iOS 16 |
| `EntityStringQuery` | `entities(matching:)` — free-text search | iOS 16 |
| `EntityPropertyQuery` | Find-by-property (Shortcuts "Find" actions) | iOS 16 |

Adopt `IndexedEntity` (since iOS 18) on your entity to make it searchable in **Spotlight** with auto-generated Find actions — this supersedes hand-rolled `CSSearchableItem`/`CSSearchableIndex` (CoreSpotlight, still valid). On macOS Tahoe, intents with a complete `parameterSummary` surface as Spotlight Quick Actions.

## WidgetKit

A widget is **archived SwiftUI driven by a timeline**: your view code runs only at archive time, in a separate process — there is no live `@State`, no timers, no closures executing on screen. The system renders snapshots from `TimelineEntry` values you supply and reloads per a `TimelineReloadPolicy`.

- Non-configurable widget → `StaticConfiguration` (since iOS 14).
- User-configurable widget → `AppIntentConfiguration` with a `WidgetConfigurationIntent` (since iOS 17). This replaced the old SiriKit `IntentConfiguration` / `INIntent` path — use the App Intent form for anything new.
- Families: `systemSmall/Medium/Large/ExtraLarge`, `accessoryCircular/Rectangular/Inline` (Lock Screen / StandBy). `systemExtraLargePortrait` is **iOS/iPadOS/macOS 27 (pre-GA)** — visionOS-only at GA.

```swift
struct ScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Scores", provider: Provider()) { entry in
            ScoreView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
```

## Interactive widgets

Since iOS 17, the **only** way to act from a widget is `Button(intent:)` or `Toggle(intent:)` backed by an `AppIntent`. The intent runs in the background in the widget's process; WidgetKit then reloads the timeline to reflect new state. No tap closures, no direct mutation.

```swift
struct ToggleTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Timer"
    func perform() async throws -> some IntentResult {
        Timers.shared.toggle()
        return .result()
    }
}

struct TimerWidgetView: View {
    let entry: Entry
    var body: some View {
        Button(intent: ToggleTimerIntent()) {
            Image(systemName: entry.isRunning ? "pause.fill" : "play.fill")
        }
    }
}
```

## Accented / tinted rendering

The Home Screen can recolor widgets (tinted/Liquid Glass since iOS 26; accented Lock Screen since iOS 18). Read `@Environment(\.widgetRenderingMode)` — `.fullColor`, `.accented`, or `.vibrant` — and design so the widget reads in a single tint. For images, control behavior explicitly with `.widgetAccentedRenderingMode(_:)`: `.fullColor`, `.accented`, `.desaturated`, or `.accentedDesaturated`. Hardcoded colors and opaque backgrounds break under tinted/clear glass — assume accented rendering from the start.

## Push & relevance updates

**Push-based widget updates (iOS 26)** refresh a widget from your server without the app running. Conform to `WidgetPushHandler`, attach via `.pushHandler(_:)`, and send an APNS background push with topic `{bundleId}.push-type.widgets` and body `{"aps":{"content-changed":true}}`. Requires the Push Notification entitlement **on the widget extension**; refreshes are system-budgeted like timeline reloads.

```swift
struct ScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Scores", provider: Provider()) { ScoreView(entry: $0) }
            .pushHandler(ScorePushHandler.self)
    }
}

struct ScorePushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ info: WidgetPushInfo, widgets: [WidgetInfo]) {
        Task { await API.register(token: info.token) }
    }
}
```

**watchOS relevance widgets (watchOS 26)**: use `RelevanceConfiguration` with a `RelevanceEntriesProvider` returning `WidgetRelevance([WidgetRelevanceAttribute])` keyed on date interval / location / routine. You supply **one entry per configuration** (not a full timeline); the system surfaces the widget contextually in the Smart Stack.

## Control Center controls (iOS 18)

A control is **not** a widget — it uses `ControlWidgetConfiguration` (no `TimelineProvider`) and lives in the widget extension. Conform to `ControlWidget`; pick `StaticControlConfiguration` or `AppIntentControlConfiguration` (user-configurable). Templates are `ControlWidgetButton` and `ControlWidgetToggle`. Toggle state flows through a `SetValueIntent`, not a SwiftUI binding. Controls appear in Control Center, the Lock Screen, and the Action button.

```swift
struct FlashlightControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.app.flashlight") {
            ControlWidgetToggle("Flashlight", isOn: Flashlight.isOn,
                action: SetFlashlightIntent()) { isOn in
                Image(systemName: isOn ? "flashlight.on.fill" : "flashlight.off.fill")
            }
        }
    }
}
```

## Live Activities & Dynamic Island

ActivityKit (since iOS 16.1; push since 16.2) shows ongoing, glanceable state — delivery, timer, live score — on the Lock Screen and in the Dynamic Island. Define `ActivityAttributes` with a nested `ContentState` (`Codable & Hashable`). In the widget extension, declare an `ActivityConfiguration` with a Lock Screen view and a `DynamicIsland { }` builder (expanded regions + `compactLeading`/`compactTrailing`/`minimal`).

```swift
struct DeliveryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable { var stage: Stage; var eta: Date }
    var orderID: String
}

struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { ctx in
            LockScreenView(ctx: ctx)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(ctx.state.stage.label) }
                DynamicIslandExpandedRegion(.trailing) { Text(ctx.state.eta, style: .timer) }
            } compactLeading: { Image(systemName: "shippingbox") }
              compactTrailing: { Text(ctx.state.eta, style: .timer) }
              minimal: { Image(systemName: "shippingbox") }
        }
    }
}
```

Lifecycle: `Activity.request(attributes:content:pushType:)` to start, `activity.update(_:)` locally, `activity.end(_:)` to finish. Remote updates use APNS **push-type `liveactivity`** with an ActivityKit-issued token (different from widget push). Buttons inside activity views use `LiveActivityIntent` (an `AppIntent` variant) with `Button(intent:)`/`Toggle(intent:)`.

iOS 26 extends Live Activities to the Mac menu bar (from a paired iPhone) and CarPlay via `.supplementalActivityFamilies([.small])` + `@Environment(\.activityFamily)`. **iOS 27 (pre-GA)** adds native forwarding to Apple Watch Smart Stack and landscape Dynamic Island — gate with `#available` and treat `@Environment(\.isDynamicIslandLimitedInWidth)` as provisional.

## AlarmKit (iOS 26)

AlarmKit is the supported way to build **real alarms and countdown timers** with proper wake UX — it replaces hacking alarms out of `UNUserNotification`. `AlarmManager` handles authorization and scheduling; `AlarmConfiguration` + `AlarmPresentation` define behavior and appearance; `AlarmAttributes` is generic over your `AlarmMetadata`. Countdowns drive a Live Activity (Lock Screen / Dynamic Island / StandBy); button actions use `LiveActivityIntent`, and `Alarm.CountdownDuration` sets pre/post-alert durations. You **must** request authorization via `AlarmManager` and provide a Live Activity, or there is no visible alarm.

## Siri, snippets & Visual Intelligence

For Siri and Apple Intelligence, bind your types to predefined **app intent domains** (mail, photos, books, browser, camera, etc.) with `@AssistantIntent(schema:)` / `@AssistantEntity(schema:)` / `@AssistantEnum(schema:)`. These assistant schemas shipped in iOS 18.2; iOS 26 generalized the pattern to `@AppIntent(schema:)` with **new domains**. Schemas enforce a fixed parameter/return shape at compile time — you can't freely add required parameters.

**Interactive snippets (iOS 26)**: a `SnippetIntent`'s `perform()` returns `some IntentResult & ShowsSnippetView` via `.result(view:)`. Snippets can embed `Button(intent:)`/`Toggle(intent:)`; call `MySnippetIntent.reload()` after a mutation to re-render, and `requestConfirmation(actionName:snippetIntent:)` for confirmation flows.

```swift
struct FavoriteSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Favorite"
    @Parameter var item: ItemEntity
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let fav = await Store.isFavorite(item)
        return .result(view: SnippetView(item: item, isFavorite: fav))
    }
}
```

**Visual Intelligence (iOS 26)**: to appear in camera/screenshot search, adopt `IntentValueQuery` whose `values(for: SemanticContentDescriptor)` returns matching `AppEntity` results, and expose a search intent via `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`. `SemanticContentDescriptor` carries the pixel buffer of the captured region.

## Pitfalls

- **Widget view code runs only at archive time, in another process** — no live closures, timers, or `@State` mutation. All interactivity goes through `Button(intent:)`/`Toggle(intent:)` plus a timeline reload.
- **Controls are not widgets.** `ControlWidget` uses `ControlWidgetConfiguration` (not `TimelineProvider`), must live in the widget extension, and toggle state needs a `SetValueIntent`, not a binding.
- **Two different APNS push-types.** Widget updates use `{bundleId}.push-type.widgets` (background); Live Activities use push-type `liveactivity` with an ActivityKit token. Don't cross them.
- **Live Activity `ContentState` must stay small** (APNS payload limits) and be `Codable & Hashable` — oversized state silently fails to update over push.
- **App Shortcuts cap at 10** and phrases must include `\(.applicationName)` or they won't register; changing parameter-bearing phrases requires `AppShortcutsProvider.updateAppShortcutParameters()`.
- **Spotlight Quick Actions on Mac** require a complete `parameterSummary` and a discoverable intent (not `isDiscoverable = false`), or the action won't surface.
- **Assistant/AppIntent schemas are rigid** — deviating from the schema's parameter/return shape fails to build.
- **Tinted rendering breaks hardcoded colors** — design widgets for `.accented` mode from the start (see `liquid-glass.md`).
- **AlarmKit needs both authorization and a Live Activity** — skip either and the alarm is invisible.
- **iOS 27 surfaces are pre-GA** — CarPlay/Mac-remote widgets, `systemExtraLargePortrait` on iOS, landscape Dynamic Island, and `@Environment(\.isDynamicIslandLimitedInWidth)` may change before GM. Gate with `#available`.
- **SiriKit custom intent domains are deprecated** (announced WWDC 2026; existing code compiles with Xcode 27 warnings). Migrate `.intentdefinition` intents → `AppIntent`, the same way you migrate `ObservableObject` → `@Observable` and `NavigationView` → `NavigationStack`. See `apple-intelligence.md` for the Foundation Models / Siri side, and `state-observation.md` for the observation idiom.

## Primary sources

- App Intents — https://developer.apple.com/documentation/appintents
- App intent domains — https://developer.apple.com/documentation/appintents/app-intent-domains
- Adding interactivity to widgets and Live Activities — https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
- ActivityKit — https://developer.apple.com/documentation/ActivityKit
- AlarmKit — https://developer.apple.com/documentation/AlarmKit
- WidgetKit foundations — WWDC26 (Session 277) — https://developer.apple.com/videos/play/wwdc2026/277/
- Explore new advances in App Intents — WWDC25 (Session 275) — https://developer.apple.com/videos/play/wwdc2025/275/
- Extend your app's controls across the system — WWDC24 (Session 10157) — https://developer.apple.com/videos/play/wwdc2024/10157/
