# High-value system frameworks survey

A routing index of the Apple frameworks an iOS/iPadOS app reaches for, each with its **modern entry point**, key types, and the OS floor that introduced the current API. This is a "which framework, which type, which version" map — not a deep dive. Three patterns recur: prefer the first-party **SwiftUI view** where one exists; prefer **async/await + AsyncSequence** over delegate/callback APIs; and remember permission-gated frameworks **crash on launch** without their `Info.plist` usage strings (see `system-integration.md`).

**Contents**
- [Maps & location](#maps--location)
- [Media: photos, video, capture](#media-photos-video-capture)
- [Data viz: Swift Charts](#data-viz-swift-charts)
- [Health, calendar, contacts](#health-calendar-contacts)
- [Drawing, tips, weather](#drawing-tips-weather)
- [Intelligence: Vision, Translation, Speech, Foundation Models](#intelligence-vision-translation-speech-foundation-models)
- [Foundation gems](#foundation-gems)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

A note on version numbers: Apple jumped from **iOS 18 (2024)** to **iOS 26 (2025)** to align with the calendar year. There is no iOS 19–25 — citing one is a tell of stale data. iOS 26 is the current shipping release; iOS 27 (WWDC 2026) is in developer beta (pre-GA).

## Maps & location

**MapKit for SwiftUI** — the modern entry point is the `Map { }` content-builder, not the old `Map(coordinateRegion:)` (iOS 14–16, deprecated) and not a `UIViewRepresentable` over `MKMapView` (only for advanced cases). See `swiftui-views.md`.

| API | Purpose | Since |
|---|---|---|
| `Map(position:selection:) { }` | Map container; `MapContentBuilder` body | iOS 17 |
| `Marker` | System balloon pin with label/`systemImage` | iOS 17 |
| `Annotation` | Custom SwiftUI view at a coordinate | iOS 17 |
| `MapPolyline` / `MapCircle` / `MapPolygon` | Overlays; style with `.stroke()` | iOS 17 |
| `MapCameraPosition` | `.region`/`.rect`/`.item`/`.userLocation`/`.automatic` | iOS 17 |
| `UserAnnotation`, `MapUserLocationButton`, `MapCompass` | User dot + map controls | iOS 17 |
| `LookAroundPreview` | Look Around imagery from an `MKLookAroundScene` | iOS 17 |

```swift
@State private var camera: MapCameraPosition = .automatic
Map(position: $camera, selection: $selected) {
    Marker("Home", coordinate: home)
    Annotation("Cafe", coordinate: cafe) { Image(systemName: "cup.and.saucer.fill") }
    MapPolyline(coordinates: route).stroke(.blue, lineWidth: 4)
    UserAnnotation()
}
.mapControls { MapUserLocationButton(); MapCompass() }
.mapStyle(.standard(elevation: .realistic))
```

**Core Location** — the delegate-based `CLLocationManager.startUpdatingLocation` is legacy. The modern idiom is the `CLLocationUpdate.liveUpdates()` AsyncSequence (iOS 17+). Iterating it implicitly holds a `CLServiceSession` (iOS 18+), so most manual authorization plumbing is deletable. Use `CLMonitor` (iOS 17+) for geofence/beacon events. Still requires `NSLocationWhenInUseUsageDescription` in `Info.plist`.

```swift
for try await update in CLLocationUpdate.liveUpdates() {
    guard let loc = update.location else { continue }
    coordinate = loc.coordinate
    if update.authorizationDenied { break }
}
```

Start this from a view's `.task`, not at app init — iterating before the app has an active scene can crash.

## Media: photos, video, capture

**PhotosUI** — `PhotosPicker` (iOS 16+) is the SwiftUI entry point and needs **no** `Info.plist` permission (it runs out-of-process). Bind to one `PhotosPickerItem` or `[PhotosPickerItem]` (with `maxSelectionCount`); filter with `matching:` (`.images`/`.videos`/`.any(of:)`). Load picked bytes with `loadTransferable(type:)` against the `Transferable` protocol.

```swift
@State private var item: PhotosPickerItem?
@State private var image: Image?
PhotosPicker("Pick", selection: $item, matching: .images)
    .onChange(of: item) { _, newItem in
        Task { image = try? await newItem?.loadTransferable(type: Image.self) }
    }
```

`loadTransferable` is async and can return `nil` for unsupported types — handle it, never force-unwrap.

**AVKit / AVFoundation** — `VideoPlayer(player:)` (iOS 14+) is the SwiftUI playback view; add controls overlays with the `videoOverlay:` builder. For full system chrome without SwiftUI use `AVPlayerViewController`. **Capture** still centers on `AVCaptureSession` + `AVCaptureDeviceInput`/`AVCaptureVideoDataOutput`, hosted in SwiftUI by wrapping `AVCaptureVideoPreviewLayer` in a `UIViewRepresentable`; requires `NSCameraUsageDescription` (and `NSMicrophoneUsageDescription` for audio).

```swift
VideoPlayer(player: player) {
    Text("Live").padding(6).background(.thinMaterial).clipShape(Capsule())
}
```

## Data viz: Swift Charts

**Swift Charts** — `Chart { }` (iOS 16+) with marks `BarMark`, `LineMark`, `PointMark`, `AreaMark`, `RuleMark`, `RectangleMark`, `SectorMark` (pie/donut). iOS 26 adds a full **3D** API: `Chart3D` with `SurfacePlot` (3D extension of `LinePlot` for mathematical surfaces) and Z-axis-capable marks, plus `.chart3DCameraProjection` and built-in rotation gestures. 3D is iOS 26+ only — gate it.

```swift
Chart(sales) { BarMark(x: .value("Month", $0.month), y: .value("Total", $0.total)) }

if #available(iOS 26, *) {        // iOS 26+ only
    Chart3D(points) {
        PointMark(x: .value("X", $0.x), y: .value("Y", $0.y), z: .value("Z", $0.z))
    }
    .chart3DCameraProjection(.perspective)
}
```

## Health, calendar, contacts

These have **no SwiftUI view** (except `ContactAccessButton`) and are all permission-gated.

| Framework | Entry point | Auth / setup | Since |
|---|---|---|---|
| **HealthKit** | shared `HKHealthStore`; `requestAuthorization(toShare:read:)` async | HealthKit **capability** + `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` | iOS 8 (async iOS 15) |
| **EventKit** (Calendar/Reminders) | `EKEventStore` | `requestFullAccessToEvents()` / `requestWriteOnlyAccessToEvents()` / `requestFullAccessToReminders()`; `NSCalendarsFullAccessUsageDescription` / `NSRemindersFullAccessUsageDescription` | iOS 6 (granular iOS 17) |
| **Contacts** | `CNContactStore`; SwiftUI `ContactAccessButton`; `CNContactPickerViewController` | `NSContactsUsageDescription` (picker needs none) | iOS 9 (button iOS 18) |

HealthKit: query with the modern `HKStatisticsCollectionQueryDescriptor` + `result(for:)` async over the legacy `HKStatisticsQuery`. EventKit: `requestAccess(to:)` is deprecated — use the granular requests (iOS 17+). Contacts: `ContactAccessButton` (SwiftUI, iOS 18+) grants incremental access to specific contacts when the app has *limited* authorization; `CNContactPickerViewController` (via `UIViewControllerRepresentable`) gives a one-time snapshot without any authorization. Store your `HealthKitManager`/store wrappers as `@Observable` types, not `ObservableObject` (see `state-observation.md`).

## Drawing, tips, weather

**PencilKit** — no SwiftUI view: wrap `PKCanvasView` (a `UIScrollView` subclass) in `UIViewRepresentable`. `PKToolPicker` is the system palette; drawing data is a `PKDrawing`. Low-latency, pressure/tilt Apple Pencil input. iOS 13+.

**TipKit** — define a tip by conforming to the `Tip` protocol (`title`/`message` + optional `@Parameter` flags and `Event`/`#Rule` conditions). Call `Tips.configure([...])` once at launch. Display inline with `TipView(tip)` (preferred) or as a popover with `.popoverTip(tip)`. Donate events with `Event.donate()`. iOS 17+.

```swift
struct FavoriteTip: Tip {
    static let opened = Event(id: "opened")
    var title: Text { Text("Save favorites") }
    var message: Text? { Text("Tap the star to keep this handy.") }
    var rules: [Rule] { #Rule(Self.opened) { $0.donations.count >= 3 } }
}
// App launch: try? Tips.configure()
TipView(FavoriteTip())
```

**WeatherKit** — `WeatherService.shared`; `try await service.weather(for: CLLocation)` returns `CurrentWeather` / `DayWeather` / `HourWeather` / `WeatherAlert`. Requires the **WeatherKit capability** (App ID + entitlement) and **mandatory attribution** — display the Apple Weather mark and legal link from `service.attribution`, or App Review rejects you. Free tier 500k calls/month. iOS 16+.

```swift
let weather = try await WeatherService.shared.weather(for: location)
let now = weather.currentWeather          // .temperature, .condition, .symbolName
let attribution = try await WeatherService.shared.attribution   // must be displayed
```

## Intelligence: Vision, Translation, Speech, Foundation Models

**Vision** — gained a Swift-only async API in iOS 18 (carried into iOS 26): request *structs* (`RecognizeTextRequest`, `DetectHumanBodyPoseRequest`, …) with `try await request.perform(on:)` returning typed observations. Replaces the legacy `VN`-prefixed types (`VNRecognizeTextRequest` + `VNImageRequestHandler` + completion handlers). Wrap a Core ML model for image tasks via `CoreMLRequest` / `VNCoreMLModel`.

```swift
var request = RecognizeTextRequest()
request.recognitionLevel = .accurate
let observations = try await request.perform(on: imageData)
let text = observations.compactMap { $0.topCandidates(1).first?.string }
                       .joined(separator: "\n")
```

**Core ML / Create ML** — train with the `CreateML` framework (`MLImageClassifier`, `MLTextClassifier`, …) or the Create ML app, producing a `.mlpackage`/`.mlmodel` consumed at runtime via `MLModel` (or its auto-generated Swift class). Core ML since iOS 11.

**Translation** — simplest path is the `.translationPresentation(isPresented:text:)` modifier (system overlay, iOS 17.4+). For custom UI, use `TranslationSession` obtained via the `.translationTask(_:action:)` modifier with a `TranslationSession.Configuration(source:target:)`. iOS 26 broadens how the session is reachable (previously only via the modifier). On-device ML.

**Speech** — iOS 26 introduces `SpeechAnalyzer`, an on-device, AsyncSequence-based replacement for `SFSpeechRecognizer`, optimized for long-form audio. Modules: `SpeechTranscriber` (long-form), `DictationTranscriber` (short utterances), `SpeechDetector` (voice activity). `SFSpeechRecognizer` remains only where you need its custom-vocabulary support that the new API lacks. iOS 26+; gate with `#available`.

**Foundation Models** — new in iOS 26: Swift access to Apple's on-device `SystemLanguageModel` (the model powering Apple Intelligence; on-device-first, but can route to Private Cloud Compute). Free, private, mostly offline. Entry point `LanguageModelSession` (stateful transcript); call `respond(to:)` / `respond(to:generating:)` for a full reply, or `streamResponse(to:)` for an async stream of partial snapshots. The `@Generable` + `@Guide` macros constrain decoding into a type-safe Swift struct; tool-calling via the `Tool` protocol. Every type here is tagged **Beta** in the iOS 26 SDK even though iOS 26 is shipping. **Always branch on `SystemLanguageModel.default.availability` first** (`.available` vs `.unavailable(.deviceNotEligible/.appleIntelligenceNotEnabled/.modelNotReady)`) — the model is absent on older devices and when Apple Intelligence is off. See `apple-intelligence.md` for the full treatment.

```swift
@Generable struct Recipe {
    @Guide(description: "dish name") var title: String
    var steps: [String]
}
guard case .available = SystemLanguageModel.default.availability else { return }
let session = LanguageModelSession()
let recipe = try await session.respond(to: "Invent a pasta recipe", generating: Recipe.self).content
```

## Foundation gems

Modern value & formatting types that supersede older Foundation classes (see also `data-persistence.md`).

| API | Purpose | Since |
|---|---|---|
| `FormatStyle` protocol — `value.formatted(...)` | Replaces `Formatter`/`DateFormatter`/`NumberFormatter`; styles `.number`, `.currency`, `.percent`, `Date.FormatStyle`, `.relative`, `ListFormatStyle` | iOS 15 |
| `Measurement<UnitX>` + `Measurement.FormatStyle` | Physical quantities with units (`.converted(to:)`, `.formatted()`) | iOS 15 (style) |
| `Duration` | Time spans; `.units` / `.time` format styles | iOS 16 |
| `Transferable` | Powers `PhotosPicker` loading, `ShareLink`, drag/drop | iOS 16 |
| `ShareLink` (SwiftUI) | System share sheet over `Transferable`; prefer over `UIActivityViewController` | iOS 16 |

```swift
let price = 19.99.formatted(.currency(code: "USD"))            // "$19.99"
let when  = date.formatted(.relative(presentation: .named))    // "yesterday"
let dist  = Measurement(value: 5, unit: UnitLength.kilometers).formatted()
let span  = Duration.seconds(3725).formatted(.units(allowed: [.hours, .minutes]))
```

For email/SMS, **MessageUI** stays UIKit-only — `MFMailComposeViewController` / `MFMessageComposeViewController` via `UIViewControllerRepresentable`, gated with `canSendMail()` / `canSendText()`. Prefer `ShareLink` for simple sharing. (`swift-subprocess` is a Swift package for running external processes — macOS/server only, not applicable to sandboxed iOS apps.)

## Pitfalls

- **Missing `Info.plist` usage string = launch crash.** Location, Health, Calendar/Reminders, Contacts, Camera, Microphone, Photo library all require their `NS…UsageDescription` key. (The `PhotosPicker` itself is the exception — it needs none.) See `system-integration.md`.
- **WeatherKit and HealthKit need capabilities/entitlements** added in Signing & Capabilities — code alone won't work. WeatherKit also *mandates* visible Apple Weather attribution or App Review rejects.
- **Don't hallucinate SwiftUI views that don't exist.** PencilKit (`PKCanvasView`), MessageUI mail/message composers, and `CNContactPickerViewController` have **no** native SwiftUI view — wrap UIKit. There is no `PencilCanvas` or `MailView` type.
- **iOS 26+-only APIs:** `Chart3D`/`SurfacePlot`, Foundation Models, `SpeechAnalyzer`/`SpeechTranscriber`. Gate with `#available(iOS 26, *)`; never present them as available on iOS 17/18.
- **Foundation Models can be unavailable at runtime** even on iOS 26 (old device, Apple Intelligence off) — branch on `SystemLanguageModel.default.availability`, don't assume.
- **Mail/message composers fail on simulators and Apple-silicon Macs / Mac Catalyst** — always guard with `canSendMail()` / `canSendText()`.
- **`loadTransferable` is async and can return `nil`** — load inside a `Task`, handle the failure, never force-unwrap.
- **Don't start `CLLocationUpdate.liveUpdates()` at app init** — begin it from a view `.task` once a scene is active, and handle `authorizationDenied`.
- **Use the modern API, not the deprecated one:** `Map { }` (not `Map(coordinateRegion:)`), `RecognizeTextRequest` (not `VNRecognizeTextRequest`), granular EventKit access (not `requestAccess(to:)`), `value.formatted(...)` (not `DateFormatter`), `ShareLink` (not `UIActivityViewController`).
- **"iOS 19"–"iOS 25" do not exist.** The sequence is iOS 18 → iOS 26 → iOS 27 (beta).

## Primary sources

- MapKit for SwiftUI — https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui
- Chart3D — https://developer.apple.com/documentation/charts/chart3d
- Bringing Photos picker to your SwiftUI app — https://developer.apple.com/documentation/photokit/bringing-photos-picker-to-your-swiftui-app
- CLLocationUpdate.Updates — https://developer.apple.com/documentation/corelocation/cllocationupdate/updates
- Foundation Models — https://developer.apple.com/documentation/foundationmodels/
- SpeechAnalyzer — https://developer.apple.com/documentation/speech/speechanalyzer
- Vision (Swift async API) — https://developer.apple.com/documentation/vision
- TipKit — https://developer.apple.com/documentation/tipkit/
- WeatherKit + attribution — https://developer.apple.com/weatherkit/data-source-attribution/
- FormatStyle — https://developer.apple.com/documentation/foundation/formatstyle
