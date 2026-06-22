# DOMAIN: Widgets, App Intents, Live Activities, Controls (WidgetKit / AppIntents / ActivityKit / AlarmKit)

## Orientation
 App Intents is the central nervous system for system integration on modern iOS: a single AppIntent can power Siri, Spotlight, Shortcuts, interactive widgets, Control Center controls, Live Activity buttons, and Apple Intelligence. Build the intent layer once and surface it everywhere. WidgetKit widgets are a timeline-driven, archived-SwiftUI model (your view code runs only at archive time, in a separate process), made interactive in iOS 17 via Button(intent:)/Toggle(intent:) backed by AppIntent. iOS 18 added Control Center / Lock Screen / Action-button controls via ControlWidget, and iOS 26 (shipping now) adds push-based widget updates (WidgetPushHandler), watchOS relevance-based widgets (RelevanceConfiguration), interactive App Intent snippets (SnippetIntent), Visual Intelligence integration (IntentValueQuery + SemanticContentDescriptor), and AlarmKit. iOS 27 (WWDC26, developer beta, pre-GA) expands widgets to CarPlay and remote-on-Mac, adds the systemExtraLargePortrait family broadly, and brings Live Activities natively to Apple Watch, the Mac menu bar, and CarPlay with Dynamic Island landscape support. Critically, SiriKit's custom intent domains are formally deprecated as of WWDC26 — App Intents (plus @AssistantIntent assistant schemas) is the only path for new Siri/Apple-Intelligence features.

## Key facts
- [since iOS 16|high] AppIntent is the unifying protocol: a struct conforming to AppIntent with static title, @Parameter properties, and async perform() returning some IntentResult. The same intent backs Siri, Spotlight, Shortcuts, widgets, controls, and Live Activities.
- [since iOS 16|high] App Shortcuts are registered via AppShortcutsProvider (single static appShortcuts getter returning [AppShortcut]); max 10 per app, each wraps an AppIntent and needs phrases referencing \(.applicationName). They appear automatically in Shortcuts, Spotlight, and Siri without opening the app.
- [since iOS 17|high] Interactive widgets: use Button(intent:) and Toggle(intent:) (SwiftUI) backed by an AppIntent. The intent runs in the background in the widget's process; the widget then reloads its timeline to reflect new state.
- [since iOS 17|high] User-configurable widgets use AppIntentConfiguration with a WidgetConfigurationIntent (replaced the old SiriKit IntentConfiguration / .intentdefinition files). Non-configurable widgets use StaticConfiguration. Both take a TimelineProvider producing TimelineEntry values with a TimelineReloadPolicy.
- [since iOS 18|high] Control Center / Lock Screen / Action button controls: a struct conforming to ControlWidget, body returns a ControlWidgetConfiguration. Use StaticControlConfiguration or AppIntentControlConfiguration; templates are ControlWidgetButton and ControlWidgetToggle. Toggle state comes from a SetValueIntent / ControlValueProvider.
- [iOS 26|high] Push-based widget updates (iOS 26): conform to WidgetPushHandler, attach via .pushHandler(_:) on the WidgetConfiguration, send APNS background push with topic {bundleId}.push-type.widgets and body {"aps":{"content-changed":true}}. Requires Push Notification entitlement on the widget extension; system-budgeted like timeline reloads. Works across all WidgetKit platforms.
- [iOS 26 (Liquid Glass); base accented since iOS 18|high] Accented/tinted rendering: read @Environment(\.widgetRenderingMode); modes are .fullColor, .accented, .vibrant. For images use .widgetAccentedRenderingMode(_:) with .fullColor / .accented / .desaturated / .accentedDesaturated to control behavior in tinted/Liquid-Glass Home Screen presentations.
- [iOS 26 / watchOS 26|high] watchOS 26 relevance widgets: RelevanceConfiguration with a RelevanceEntriesProvider; return WidgetRelevance([WidgetRelevanceAttribute]) keyed on date interval / location / routine. One entry per configuration (not a full timeline); the system surfaces the widget only when relevant in the Smart Stack.
- [iOS 26|high] Interactive App Intent snippets (iOS 26): SnippetIntent protocol; perform() returns some IntentResult & ShowsSnippetView via .result(view:). Snippets can contain Button(intent:)/Toggle(intent:); call SomeSnippetIntent.reload() to refresh, and requestConfirmation(actionName:snippetIntent:) for confirmation flows.
- [iOS 26|high] Visual Intelligence / image search (iOS 26): adopt IntentValueQuery whose values(for: SemanticContentDescriptor) returns matching AppEntity results; expose a search intent via @AppIntent(schema: .visualIntelligence.semanticContentSearch). SemanticContentDescriptor carries the pixel buffer of the captured/selected region.
- [iOS 26|high] New App Intents property macros (iOS 26): @ComputedProperty (derive from source of truth, no storage) and @DeferredProperty (async lazy-load expensive values). New @UnionValue macro lets a query return multiple entity types.
- [iOS 26|high] UndoableIntent (iOS 26) registers undo with the system undoManager; supportedModes: IntentModes ([.background, .foreground(.dynamic)] etc.) plus continueInForeground() let an intent start in background and escalate to foreground. TargetContentProvidingIntent + the .onAppIntentExecution(_:) view modifier move navigation out of the intent into the view layer.
- [iOS 26|high] App Intents can now ship in Swift Packages / static libraries via the AppIntentsPackage protocol (includedPackages).
- [iOS 26 / macOS 26 (IndexedEntity since iOS 18)|high] Spotlight indexing via App Intents: adopt IndexedEntity on your AppEntity and associate properties with indexing keys; the system auto-generates Find actions and makes entities searchable. Legacy path is CSSearchableItem/CSSearchableIndex (CoreSpotlight). On macOS Tahoe, intents with full parameterSummary appear as Spotlight Quick Actions.
- [since iOS 16|high] Entity query protocols: EntityQuery (suggestedEntities()), EnumerableEntityQuery (allEntities() for small bounded sets), EntityStringQuery (entities(matching:) for search), EntityPropertyQuery (Find-by-property). AppEntity requires id, displayRepresentation, and a defaultQuery.
- [iOS 26 (schemas since iOS 18.2)|high] Assistant schemas for Siri/Apple Intelligence: macros @AssistantIntent(schema:), @AssistantEntity(schema:), @AssistantEnum(schema:) bind your types to predefined app-intent domains (mail, photos, books, browser, camera, etc.). This is the supported replacement for SiriKit custom intents.
- [announced WWDC26 (pre-GA)|medium] SiriKit custom intent domains are deprecated as of WWDC 2026 (June 2026); existing code compiles but emits Xcode 27 deprecation warnings. New Siri / Apple Intelligence features require App Intents. Migrate ObservableObject->@Observable, NavigationView->NavigationStack, .intentdefinition SiriKit intents -> AppIntent are the analogous modern idioms.
- [since iOS 16.1 (16.2 push)|high] Live Activities (ActivityKit): define ActivityAttributes with a nested ContentState (Codable & Hashable); the widget extension declares an ActivityConfiguration with a Lock Screen view and a DynamicIsland { } builder (expanded regions + compactLeading/compactTrailing/minimal). Start/update/end via Activity<Attributes>; remote updates via APNS push-type liveactivity with ActivityKit push tokens.
- [since iOS 17|high] Live Activity interactivity uses LiveActivityIntent (an AppIntent variant) wired to Button(intent:)/Toggle(intent:) inside the activity views.
- [iOS 26|high] AlarmKit (iOS 26): AlarmManager handles authorization + scheduling; AlarmConfiguration + AlarmPresentation define behavior/appearance; AlarmAttributes is generic over a custom AlarmMetadata type. Countdown timers drive a Live Activity (Lock Screen / Dynamic Island / StandBy); button actions use LiveActivityIntent and Alarm.CountdownDuration controls pre/post-alert durations. Replaces UNUserNotification-based alarms for real alarm UX.

## APIs
- `AppIntent` (protocol; iOS 16+) — Core action protocol: static title, @Parameter, async perform().
- `AppShortcutsProvider` (protocol; iOS 16+) — Static appShortcuts: [AppShortcut]; max 10.
- `AppShortcut` (struct; iOS 16+) — Binds intent+phrases+shortTitle+systemImageName.
- `AppEntity` (protocol; iOS 16+) — id, displayRepresentation, defaultQuery.
- `EntityQuery / EnumerableEntityQuery / EntityStringQuery / EntityPropertyQuery` (protocol; iOS 16+) — Entity lookup, enumeration, search, Find-by-property.
- `IntentValueQuery` (protocol; iOS 26) — Visual Intelligence: values(for: SemanticContentDescriptor).
- `SemanticContentDescriptor` (struct; iOS 26) — Carries pixelBuffer of captured/selected region.
- `SnippetIntent` (protocol; iOS 26) — Interactive snippet; returns IntentResult & ShowsSnippetView; .reload().
- `ShowsSnippetView` (protocol (result modifier); iOS 26) — Marks perform() result as carrying a snippet SwiftUI view.
- `UndoableIntent` (protocol; iOS 26) — Registers undo with system undoManager.
- `TargetContentProvidingIntent` (protocol; iOS 26) — Moves navigation to the view via .onAppIntentExecution(_:).
- `IntentModes / supportedModes` (OptionSet / static property; iOS 26) — .background, .foreground(.immediate/.dynamic/.deferred); continueInForeground().
- `@ComputedProperty / @DeferredProperty / @UnionValue` (macro; iOS 26) — Derived, async-lazy, and multi-type entity properties.
- `AppIntentsPackage` (protocol; iOS 26) — Ship App Intents from Swift Packages (includedPackages).
- `@AssistantIntent / @AssistantEntity / @AssistantEnum (schema:)` (macro; iOS 18.2+ / iOS 26) — Bind types to App Intent domains for Siri/Apple Intelligence.
- `IndexedEntity` (protocol; iOS 18+) — Spotlight indexing of AppEntity; auto Find actions.
- `CSSearchableItem / CSSearchableIndex` (class; iOS 9+ (CoreSpotlight)) — Legacy Spotlight indexing path.
- `WidgetConfigurationIntent` (protocol; iOS 17+) — App-Intent-based widget configuration (replaces INIntent).
- `AppIntentConfiguration / StaticConfiguration` (struct; iOS 17+ / iOS 14+) — Configurable vs non-configurable WidgetConfiguration.
- `TimelineProvider / AppIntentTimelineProvider / TimelineEntry / TimelineReloadPolicy` (protocol / struct; iOS 14+ / 17+) — Timeline model for widget refresh.
- `WidgetPushHandler / WidgetPushInfo` (protocol / struct; iOS 26) — Push-based widget updates via .pushHandler(_:).
- `widgetAccentedRenderingMode(_:)` (view modifier; iOS 18+ (Liquid Glass tuning iOS 26)) — .fullColor/.accented/.desaturated/.accentedDesaturated.
- `WidgetRenderingMode (\.widgetRenderingMode)` (enum / environment; iOS 16+) — .fullColor/.accented/.vibrant.
- `RelevanceConfiguration / RelevanceEntriesProvider / WidgetRelevance / WidgetRelevanceAttribute` (struct / protocol; iOS 26 / watchOS 26) — Contextual relevance widgets (Smart Stack).
- `systemExtraLargePortrait (WidgetFamily)` (enum case; visionOS 26; iOS/iPadOS/macOS 27 (pre-GA)) — New large portrait widget family.
- `supportedMountingStyles(_:) / widgetTexture(_:) / \.levelOfDetail` (view modifier / environment; visionOS 26) — visionOS widget mounting, texture, distance LOD.
- `ControlWidget` (protocol; iOS 18+) — Control Center / Lock Screen / Action button control.
- `StaticControlConfiguration / AppIntentControlConfiguration / ControlWidgetConfiguration` (struct / protocol; iOS 18+) — Control body configuration.
- `ControlWidgetButton / ControlWidgetToggle` (struct; iOS 18+) — Control templates; toggle uses SetValueIntent/ControlValueProvider.
- `SetValueIntent` (protocol; iOS 18+) — Backs toggle controls with on/off state.
- `ActivityAttributes (+ ContentState)` (protocol; iOS 16.1+) — Static + dynamic Live Activity data model.
- `ActivityConfiguration` (struct; iOS 16.1+) — Lock Screen view + dynamicIsland builder.
- `DynamicIsland / DynamicIslandExpandedRegion` (struct; iOS 16.1+) — Expanded leading/trailing/center/bottom + compact/minimal.
- `Activity<Attributes>` (class; iOS 16.1+) — request / update / end; pushType for APNS.
- `LiveActivityIntent` (protocol; iOS 17+) — App Intent variant for Live Activity / AlarmKit buttons.
- `supplementalActivityFamilies(_:) / ActivityFamily (\.activityFamily)` (view modifier / enum; iOS 26) — .small family for Watch/CarPlay Live Activities.
- `isDynamicIslandLimitedInWidth` (environment value; iOS 27 (pre-GA)) — Adapt compact/minimal views in Dynamic Island landscape.
- `AlarmManager / AlarmConfiguration / AlarmPresentation / AlarmAttributes / AlarmMetadata / Alarm.CountdownDuration` (class / struct / protocol; iOS 26) — AlarmKit: real alarms & countdown timers with Live Activity.
- `Button(intent:) / Toggle(intent:)` (SwiftUI initializer; iOS 17+) — Interactive widgets, Live Activities, snippets.

## Patterns

### Core AppIntent backing an App Shortcut  — Expose an app action to Siri, Spotlight, and Shortcuts.
One intent, many surfaces. Keep perform() side-effecting and fast; return ProvidesDialog/ShowsSnippetView for richer Siri/Spotlight results.
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

### Interactive widget button  — Toggle or mutate state directly from the Home Screen.
Button(intent:)/Toggle(intent:) only — no closures run in the widget process. The intent runs in the background, then WidgetKit reloads the timeline.
```swift
struct ToggleTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Timer"
    func perform() async throws -> some IntentResult { Timers.shared.toggle(); return .result() }
}

struct TimerWidgetView: View {
    let entry: Entry
    var body: some View {
        Button(intent: ToggleTimerIntent()) { Image(systemName: entry.isRunning ? "pause.fill" : "play.fill") }
    }
}
```

### Control Center control (iOS 18+)  — Add a toggle/button to Control Center, Lock Screen, or the Action button.
Toggle value flows through a SetValueIntent (SetFlashlightIntent: SetValueIntent). Use AppIntentControlConfiguration for user-configurable controls.
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

### Live Activity with Dynamic Island + interactivity  — Show ongoing, glanceable state (delivery, timer, game) with action buttons.
Start with Activity.request(attributes:content:pushType:). Update locally via activity.update(_:) or remotely via APNS liveactivity push. Adapt to @Environment(\.activityFamily) for Watch/CarPlay .small.
```swift
struct DeliveryActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable { var stage: Stage; var eta: Date }
    var orderID: String
}

struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { ctx in
            LockScreenView(ctx: ctx)            // Lock Screen / banner
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

### Push-based widget update (iOS 26)  — Server-driven widget data without opening the app.
Add the Push Notification entitlement to the widget extension; APNS topic is {bundleId}.push-type.widgets with {"aps":{"content-changed":true}}. System-budgeted.
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

### Interactive snippet intent (iOS 26)  — Rich, tappable result/confirmation UI from Siri or Spotlight.
Embed Button(intent:)/Toggle(intent:) in the snippet view; call FavoriteSnippetIntent.reload() after a mutation to re-render.
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

## Pitfalls
- Widget view code only runs at archive time in a separate process — no live closures, timers, or @State mutation; all interactivity must go through Button(intent:)/Toggle(intent:) and a timeline reload.
- Controls are NOT widgets: a ControlWidget uses ControlWidgetConfiguration (not TimelineProvider) and must live in the widget extension; toggle state needs a SetValueIntent, not a binding.
- Push widget updates and ActivityKit pushes use DIFFERENT APNS push-types: widgets use {bundleId}.push-type.widgets (background), Live Activities use push-type liveactivity with an ActivityKit-issued token — don't confuse them.
- Live Activity ContentState must stay small (APNS payload limits) and be Codable & Hashable; large state silently fails to update over push.
- App Shortcuts cap at 10 per app and phrases must include \(.applicationName) or they won't register; updating phrases requires AppShortcutsProvider.updateAppShortcutParameters().
- For Spotlight Quick Actions on Mac the intent must have a complete parameterSummary and must NOT be assistantOnly/isDiscoverable=false, or it won't surface.
- Assistant schema macros (@AssistantIntent(schema:)) enforce a fixed parameter/return shape at compile time — deviating from the schema fails to build; you can't freely add required parameters.
- widgetAccentedRenderingMode / tinted mode: hardcoded colors and opaque backgrounds break in Liquid Glass tinted/clear presentations — design for accented rendering from the start.
- AlarmKit requires explicit user authorization via AlarmManager and a Live Activity for countdown UI; skipping the authorization check or the Live Activity yields no visible alarm.
- iOS 27 widget surfaces (CarPlay, Mac-remote, extra-large portrait) and Dynamic Island landscape are pre-GA — gate with #available and treat API names as provisional until GM.

## iOS 26 changes
- Push-based widget timeline updates via WidgetPushHandler + .pushHandler(_:); APNS background push refreshes widgets without a foreground app.
- Liquid Glass accented/tinted widget rendering; .widgetAccentedRenderingMode(_:) and refined widgetRenderingMode handling for clear-glass/tinted Home Screen.
- watchOS relevance-based widgets: RelevanceConfiguration + RelevanceEntriesProvider returning WidgetRelevance (single entry per configuration, surfaced contextually).
- Interactive App Intent snippets: SnippetIntent, ShowsSnippetView, .reload(), requestConfirmation(actionName:snippetIntent:), requestChoice(between:).
- Visual Intelligence integration: IntentValueQuery + SemanticContentDescriptor + @AppIntent(schema: .visualIntelligence.semanticContentSearch) for camera/screenshot search.
- App Intents property macros @ComputedProperty / @DeferredProperty; @UnionValue for multi-type queries; UndoableIntent; supportedModes/IntentModes with continueInForeground(); TargetContentProvidingIntent + .onAppIntentExecution(_:).
- App Intents packaged in Swift Packages via AppIntentsPackage.
- AlarmKit framework: schedule real alarms / countdown timers with Lock Screen + Dynamic Island + StandBy Live Activity integration.
- Live Activities reach Mac menu bar (from paired iPhone), and CarPlay via .supplementalActivityFamilies([.small]) + @Environment(\.activityFamily).
- visionOS 26 widgets: .supportedMountingStyles([.elevated,.recessed]), .widgetTexture(.paper/.glass), @Environment(\.levelOfDetail), systemExtraLargePortrait family.
- Shortcuts/Spotlight: Use Model action (Apple Intelligence) accepts AppEntity/AttributedString; Spotlight-on-Mac Quick Actions from intents with complete parameterSummary; Mac automations (Folder/External Drive triggers).

## iOS 27 preview (pre-GA)
- systemExtraLargePortrait widget family becomes available broadly on iOS, iPadOS, and macOS 27 (was visionOS-only). | Developer beta, pre-GA; family name and availability may change.
- iOS widgets run on CarPlay and appear as remote (interactive) widgets on macOS. | Pre-GA.
- Live Activities natively forward to Apple Watch Smart Stack, macOS menu bar, and CarPlay Dashboard automatically; iPhone activity propagates with no extra code beyond family adaptation. | Pre-GA; exact propagation conditions may change.
- Dynamic Island visible in both portrait and landscape; new @Environment(\.isDynamicIslandLimitedInWidth) to adapt compact/minimal views to constrained width. | Pre-GA; environment key name unverified against shipping headers.
- .supplementalActivityFamilies([.small]) small activity family for Apple Watch / CarPlay adaptation, read via @Environment(\.activityFamily). | Carried from iOS 26; emphasized for new surfaces in iOS 27.
- SiriKit custom intent domains formally deprecated (announced June 2026); Xcode 27 emits deprecation warnings; App Intents is the sole path forward. | Deprecation timeline/removal window (~2-3 yrs) is unofficial.

## Deprecations
- SiriKit custom intent domains deprecated (WWDC 2026, June 2026); migrate to App Intents + assistant schemas. Existing SiriKit code compiles with Xcode 27 deprecation warnings.
- INIntent / .intentdefinition-based widget configuration (IntentConfiguration) superseded by AppIntentConfiguration + WidgetConfigurationIntent (since iOS 17).
- Legacy CoreSpotlight-only indexing (CSSearchableItem) superseded for entity content by IndexedEntity App Intents indexing (still valid, but App Intents path auto-generates Find actions).
- General modern-idiom shifts a widgets/intents skill should enforce: ObservableObject -> @Observable, NavigationView -> NavigationStack, XCTest -> Swift Testing.

## Uncertainties
- The exact spelling/availability of @Environment(\.isDynamicIslandLimitedInWidth) is from WWDC26 session transcript text, not yet confirmed against shipping iOS 27 headers (pre-GA).
- Whether systemExtraLargePortrait is the final family name across iOS/iPadOS/macOS 27 vs a variant; WWDC26 session and secondary sources agree but headers unverified.
- Exact WidgetPushHandler method signature (pushTokenDidChange(_:widgets:)) is from a session summary; confirm parameter labels against developer.apple.com/documentation/widgetkit before copying verbatim.
- Whether Live Activity propagation to Apple Watch / Mac menu bar / CarPlay in iOS 27 is fully automatic or requires opting in via supplementalActivityFamilies — session implies automatic but specifics may change pre-GA.
- SiriKit deprecation removal window (~2-3 years) is from secondary sources, not an official Apple-stated timeline.
- ControlValueProvider exact name/role for live control values (vs SetValueIntent) should be confirmed against current WidgetKit docs.
- Some App Intents macro examples (e.g. @DeferredProperty getter syntax) come from session transcripts; verify exact macro spelling in the iOS 26 SDK.

## Sources
- Explore new advances in App Intents — WWDC25 (Session 275): https://developer.apple.com/videos/play/wwdc2025/275/
- Get to know App Intents — WWDC25 (Session 244): https://developer.apple.com/videos/play/wwdc2025/244/
- Develop for Shortcuts and Spotlight with App Intents — WWDC25 (Session 260): https://developer.apple.com/videos/play/wwdc2025/260/
- What's new in widgets — WWDC25 (Session 278): https://developer.apple.com/videos/play/wwdc2025/278/
- WidgetKit foundations — WWDC26 (Session 277): https://developer.apple.com/videos/play/wwdc2026/277/
- Live Activities essentials — WWDC26 (Session 223): https://developer.apple.com/videos/play/wwdc2026/223/
- App Intents — Apple Developer Documentation: https://developer.apple.com/documentation/appintents
- App Shortcuts — Apple Developer Documentation: https://developer.apple.com/documentation/appintents/app-shortcuts
- App intent domains — Apple Developer Documentation: https://developer.apple.com/documentation/appintents/app-intent-domains
- Adding interactivity to widgets and Live Activities — Apple Developer Documentation: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
- ControlWidgetToggle — Apple Developer Documentation: https://developer.apple.com/documentation/widgetkit/controlwidgettoggle
- Adding refinements and configuration to controls — Apple Developer Documentation: https://developer.apple.com/documentation/widgetkit/adding-refinements-and-configuration-to-controls
- Extend your app's controls across the system — WWDC24 (Session 10157): https://developer.apple.com/videos/play/wwdc2024/10157/
- ActivityKit — Apple Developer Documentation: https://developer.apple.com/documentation/ActivityKit
- AlarmKit — Apple Developer Documentation: https://developer.apple.com/documentation/AlarmKit
- Scheduling an alarm with AlarmKit — Apple Developer Documentation: https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit
- AssistantIntent(schema:) — Apple Developer Documentation: https://developer.apple.com/documentation/appintents/assistantintent(schema:)
- Deprecated SiriKit Intent Domains — Apple Developer Support: https://developer.apple.com/support/deprecated-sirikit-intent-domains
- Associating your App Clip with your website — Apple Developer Documentation: https://developer.apple.com/documentation/appclip/associating-your-app-clip-with-your-website
