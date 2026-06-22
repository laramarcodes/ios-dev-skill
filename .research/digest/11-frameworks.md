# DOMAIN: High-value system frameworks survey for native SwiftUI iPhone/iPad apps (iOS 26 shipping; iOS 27 pre-GA) — routing index of MapKit, Swift Charts, PhotosUI, AVKit/AVFoundation, Core Location, HealthKit, EventKit, Contacts, MessageUI, PencilKit, TipKit, WeatherKit, Translation, Vision/Core ML/Create ML, Speech, Foundation gems, and FoundationModels.

## Orientation
 This domain is a routing index of Apple's high-value system frameworks an app builder reaches for, each version-qualified for iOS 26 (current shipping, released Sept 2025; Apple unified version numbers to the year+1 scheme so there is no iOS 19-25 — iOS 18 was followed by iOS 26) with iOS 27 freshly announced at WWDC 2026 and in developer beta (pre-GA). The dominant modern pattern across all of these is: prefer the first-party SwiftUI entry point where one exists (Map, VideoPlayer, PhotosPicker, Chart, TipView, LookAroundPreview, ContactAccessButton, translationPresentation), fall back to UIViewRepresentable/UIViewControllerRepresentable only where Apple still ships no SwiftUI view (PencilKit's PKCanvasView, MessageUI's MFMailComposeViewController, ContactsUI's CNContactPickerViewController). The second theme is async/await + AsyncSequence replacing delegate/callback APIs (CLLocationUpdate.liveUpdates, Vision's RequestHandler.perform, SpeechAnalyzer modules, WeatherKit's async WeatherService). Permission-gated frameworks (Core Location, HealthKit, EventKit, Contacts, Photos, camera/mic) require Info.plist usage-description keys or the build silently crashes. The headline iOS 26 additions are the FoundationModels on-device LLM framework, Swift Charts 3D (Chart3D), and the SpeechAnalyzer speech-to-text framework. For each card below, treat the SwiftUI entry point and key type names as copy-into-skill-accurate, and the availability as the floor OS that introduced the modern API.

## Key facts
- [iOS 26|high] iOS version numbering jumped from iOS 18 (2024) to iOS 26 (2025) — Apple aligned all OS version numbers to the following calendar year. iOS 26 is the current shipping release (since Sept 2025); iOS 27 was announced at WWDC 2026 (June 2026) and is in developer beta (pre-GA).
- [iOS 26|high] Swift Charts gained a full 3D API in iOS 26: Chart3D container with SurfacePlot (3D extension of LinePlot for mathematical surfaces), plus PointMark/RuleMark/RectangleMark extended to a Z axis. Modifiers include .chart3DCameraProjection. Built-in rotation gestures. Also macOS 26 / visionOS 26.
- [iOS 26|high] FoundationModels is a new iOS 26 framework giving Swift API access to Apple's on-device ~3B-parameter LLM. Entry point: LanguageModelSession; call respond(to:) for text. @Generable + @Guide macros enable constrained decoding into type-safe Swift structs. Tool-calling via the Tool protocol. Free, on-device, private, offline.
- [iOS 26|high] SpeechAnalyzer (Speech framework) is a new iOS 26 on-device replacement for SFSpeechRecognizer, built around long-form audio. Modules: SpeechTranscriber (long-form), DictationTranscriber (short-utterance), SpeechDetector (voice activity). AsyncSequence-based; reportedly ~2x faster than Whisper Large V3 Turbo. SFSpeechRecognizer is legacy but retains custom-vocabulary support the new API lacks.
- [since iOS 17|high] MapKit for SwiftUI: the modern entry point is Map { } (iOS 17+). Content builders: Marker (system pin with label), Annotation (custom view), MapCircle, MapPolyline (.stroke()), MapPolygon, UserAnnotation. Camera via MapCameraPosition (.region/.rect/.item/.userLocation/.automatic) bound through position:. LookAroundPreview shows Look Around imagery from an MKLookAroundScene.
- [since iOS 17|high] The old SwiftUI Map(coordinateRegion:) initializer (iOS 14–16) is deprecated; the new Map { content } builder API (iOS 17+) with MapContentBuilder is the current idiom. Likewise MKMapView/UIViewRepresentable is now only needed for advanced cases.
- [since iOS 16|high] PhotosUI: PhotosPicker is the SwiftUI entry point (iOS 16+). Bind selection to PhotosPickerItem (single) or [PhotosPickerItem] (multiple, via maxSelectionCount); filter with matching: .images/.videos/.any(of:). Load picked data with item.loadTransferable(type:) against the Transferable protocol (e.g. Image.self or Data.self).
- [since iOS 17 (CLServiceSession iOS 18)|high] Core Location modern API: CLLocationManager.startUpdatingLocation/delegate is legacy. The current async idiom is the CLLocationUpdate.liveUpdates() AsyncSequence (iOS 17+) and CLMonitor for region/beacon condition events. CLServiceSession (iOS 18+) declares authorization goals; iterating liveUpdates implicitly holds a session, so much manual authorization code can be deleted.
- [since iOS 18|high] Vision framework gained a Swift-only async API in iOS 18 that carries forward in iOS 26: request objects like RecognizeTextRequest, DetectHumanBodyPoseRequest, etc., with try await request.perform(on: imageData) returning typed observations — replacing the older VNRequest/VNImageRequestHandler + completion-handler pattern (VN-prefixed types).
- [ContactAccessButton since iOS 18|high] Contacts: ContactAccessButton (SwiftUI, iOS 18+) grants incremental access to specific contacts when the app has limited authorization, styled with standard SwiftUI modifiers; CNContactPickerViewController (ContactsUI, via UIViewControllerRepresentable) gives a one-time snapshot without requiring authorization. Backing store is CNContactStore.
- [since iOS 17.4/18; expanded iOS 26|medium] Translation framework: simplest path is the .translationPresentation(isPresented:text:) SwiftUI modifier (system overlay). For custom UI use TranslationSession (on-device ML) — obtained via the .translationTask(_:action:) modifier with a TranslationSession.Configuration(source:target:). On OS below iOS 26 TranslationSession was only reachable through the SwiftUI modifier; iOS 26 broadens access.
- [since iOS 17|high] TipKit: define a tip by conforming to the Tip protocol with title/message and optional @Parameter flags and Event rules (donate via Event.donate()); display inline with TipView(tip) (preferred) or as a popover with .popoverTip(tip). Configure once at launch with Tips.configure([.displayFrequency(...), .datastoreLocation(...)]). Introduced iOS 17.
- [VideoPlayer since iOS 14|high] AVKit: VideoPlayer(player: AVPlayer) is the SwiftUI entry point for playback (iOS 14+); customize overlays with the videoOverlay: builder. For full system controls without SwiftUI use AVPlayerViewController. Capture (AVFoundation) still centers on AVCaptureSession with AVCaptureDeviceInput/AVCaptureVideoDataOutput, hosted in SwiftUI via UIViewRepresentable over AVCaptureVideoPreviewLayer.
- [since iOS 8 (async since iOS 15)|high] HealthKit has no SwiftUI view; entry point is a single shared HKHealthStore. Request access with try await store.requestAuthorization(toShare:read:). Query with HKStatisticsQuery/HKSampleQuery or modern HKStatisticsCollectionQueryDescriptor/result(for:) async. Requires HealthKit capability + NSHealthShareUsageDescription / NSHealthUpdateUsageDescription Info.plist keys.
- [granular access since iOS 17|high] EventKit: EKEventStore is the entry point for Calendar + Reminders. iOS 17+ split authorization into requestFullAccessToEvents()/requestWriteOnlyAccessToEvents()/requestFullAccessToReminders() (the old requestAccess(to:) is deprecated). Needs NSCalendarsFullAccessUsageDescription / NSRemindersFullAccessUsageDescription. EventKitUI provides EKEventEditViewController / EKEventViewController.
- [since iOS 13|high] PencilKit has no native SwiftUI view: wrap PKCanvasView (a UIScrollView subclass) in UIViewRepresentable. PKToolPicker provides the system tool palette; drawing data is a PKDrawing. Provides low-latency, pressure/tilt-sensitive Apple Pencil input.
- [since iOS 16|high] WeatherKit: entry point WeatherService.shared; fetch async with try await service.weather(for: CLLocation) returning CurrentWeather/DayWeather/HourWeather/WeatherAlert. Requires the WeatherKit capability (App ID + entitlement) and mandatory attribution (Apple Weather trademark + legal link), fetched via service.attribution. Free tier 500k calls/month. iOS 16+.
- [ShareLink since iOS 16|high] MessageUI: MFMailComposeViewController (email w/ attachments) and MFMessageComposeViewController (SMS) remain UIKit-only — bridge via UIViewControllerRepresentable, and gate on MFMailComposeViewController.canSendMail(). For simple sharing prefer SwiftUI ShareLink (iOS 16+, Transferable). Mail compose does not work on Apple-silicon Macs / Mac Catalyst.
- [FormatStyle since iOS 15, Duration since iOS 16|high] Foundation modern formatting/value gems: the FormatStyle protocol (value.formatted(...)) supersedes legacy Formatter classes — Date.FormatStyle, .number, .currency, .percent, Measurement.FormatStyle, ListFormatStyle, .relative. Measurement<UnitX> + Duration (with .units/.time format styles) cover physical quantities and time spans. swift-foundation is the open-source cross-platform Foundation rewrite.
- [package (Swift 6 era)|medium] Subprocess: a new Swift-forward async API for running external processes (replacing Foundation Process for new code), distributed via the swift-subprocess package (swiftlang) rather than baked into the iOS SDK; primarily relevant on macOS/server, not sandboxed iOS apps.
- [since iOS 11 / macOS 10.13|high] Create ML is the model-training counterpart to Core ML: train on-device/Mac with the CreateML framework (MLImageClassifier, MLTextClassifier, etc.) or the Create ML app, producing a .mlmodel/.mlpackage consumed at runtime via Core ML (MLModel, or auto-generated Swift class). Vision wraps Core ML models for image tasks via a CoreMLRequest / VNCoreMLModel.

## APIs
- `Map` (struct (SwiftUI); iOS 17+) — Map(position:selection:) { MapContentBuilder } — modern entry point; replaces Map(coordinateRegion:).
- `Marker` (struct (MapContent); iOS 17+) — System balloon pin with label/systemImage.
- `Annotation` (struct (MapContent); iOS 17+) — Custom SwiftUI view at a coordinate.
- `MapPolyline` (struct (MapContent); iOS 17+) — Route line; style with .stroke(). Siblings: MapCircle, MapPolygon.
- `MapCameraPosition` (struct; iOS 17+) — .region/.rect/.item/.userLocation/.automatic; bound via Map(position:).
- `LookAroundPreview` (struct (SwiftUI); iOS 17+) — Look Around imagery from an MKLookAroundScene; init(initialScene:) or init(scene:).
- `Chart` (struct (SwiftUI); iOS 16+) — Swift Charts container; marks BarMark/LineMark/PointMark/AreaMark/RuleMark/RectangleMark/SectorMark.
- `Chart3D` (struct (SwiftUI); iOS 26+) — 3D charts container; with SurfacePlot and Z-axis marks; .chart3DCameraProjection.
- `SurfacePlot` (struct (ChartContent); iOS 26+) — 3D extension of LinePlot for mathematical surfaces.
- `PhotosPicker` (struct (SwiftUI, PhotosUI); iOS 16+) — selection: PhotosPickerItem or [PhotosPickerItem]; matching: PHPickerFilter.
- `PhotosPickerItem` (struct; iOS 16+) — loadTransferable(type:) against Transferable.
- `Transferable` (protocol; iOS 16+) — Powers PhotosPicker loading, ShareLink, drag/drop.
- `CLLocationUpdate` (struct; iOS 17+) — liveUpdates() returns an AsyncSequence of location updates.
- `CLServiceSession` (class; iOS 18+) — Declares authorization goals; implicitly held while iterating liveUpdates.
- `CLMonitor` (actor; iOS 17+) — AsyncSequence of region/beacon condition events.
- `LanguageModelSession` (class (FoundationModels); iOS 26+) — respond(to:) / respond(to:generating:); stateful transcript.
- `@Generable` (macro; iOS 26+) — Constrained-decode model output into a typed Swift struct; pair with @Guide.
- `SystemLanguageModel` (struct (FoundationModels); iOS 26+) — .default.availability — branch on this before using the model.
- `SpeechAnalyzer` (class (Speech); iOS 26+) — Coordinates analysis modules; replaces SFSpeechRecognizer.
- `SpeechTranscriber` (class (Speech); iOS 26+) — Long-form on-device transcription module; AsyncSequence results.
- `RecognizeTextRequest` (struct (Vision); iOS 18+) — Swift-only OCR; perform(on:) async — replaces VNRecognizeTextRequest.
- `DetectHumanBodyPoseRequest` (struct (Vision); iOS 18+) — detectsHands → HumanBodyPoseObservation.
- `Tip` (protocol (TipKit); iOS 17+) — title/message/rules; Event + #Rule for conditional display.
- `TipView` (struct (SwiftUI); iOS 17+) — Inline tip display (preferred); also .popoverTip(_:).
- `WeatherService` (class (WeatherKit); iOS 16+) — .shared; weather(for: CLLocation) async; .attribution required.
- `HKHealthStore` (class (HealthKit); iOS 8+ (async iOS 15+)) — requestAuthorization(toShare:read:); needs capability + plist keys.
- `EKEventStore` (class (EventKit); iOS 6+ (granular access iOS 17+)) — requestFullAccessToEvents()/requestFullAccessToReminders().
- `ContactAccessButton` (struct (SwiftUI, ContactsUI); iOS 18+) — Incremental contact access under limited authorization.
- `CNContactPickerViewController` (class (ContactsUI); iOS 9+) — One-time contact snapshot; bridge via UIViewControllerRepresentable.
- `MFMailComposeViewController` (class (MessageUI); iOS 3+) — Email w/ attachments; gate with canSendMail(); UIKit-only.
- `VideoPlayer` (struct (SwiftUI, AVKit); iOS 14+) — VideoPlayer(player:) with optional videoOverlay:.
- `AVCaptureSession` (class (AVFoundation); iOS 4+) — Capture hub; host AVCaptureVideoPreviewLayer via UIViewRepresentable.
- `PKCanvasView` (class (PencilKit); iOS 13+) — No SwiftUI view; wrap in UIViewRepresentable; PKToolPicker + PKDrawing.
- `translationPresentation(isPresented:text:)` (view modifier (Translation); iOS 17.4+) — System translation overlay; custom UI uses TranslationSession.
- `TranslationSession` (class (Translation); iOS 18+ (broadened iOS 26)) — On-device translation; obtained via .translationTask with Configuration.
- `FormatStyle` (protocol (Foundation); iOS 15+) — value.formatted(...); supersedes Formatter classes.
- `Duration` (struct (Foundation); iOS 16+) — Time spans; .units / .time FormatStyles.
- `ShareLink` (struct (SwiftUI); iOS 16+) — System share sheet over Transferable; prefer over UIActivityViewController.
- `CreateML / MLImageClassifier` (framework / struct; iOS 11+ / macOS 10.13+) — Train models → .mlmodel/.mlpackage consumed by Core ML (MLModel).

## Patterns

### SwiftUI Map with markers, polyline, and camera position  — Any map-centric screen on iOS 17+
Bind camera via position:. Use Marker for default pins, Annotation for custom views. selection: enables tap-to-select of map content.
```swift
@State private var camera: MapCameraPosition = .automatic
Map(position: $camera, selection: $selectedItem) {
    Marker("Home", coordinate: home)
    Annotation("Cafe", coordinate: cafe) { Image(systemName: "cup.and.saucer.fill") }
    MapPolyline(coordinates: route).stroke(.blue, lineWidth: 4)
    UserAnnotation()
}
.mapControls { MapUserLocationButton(); MapCompass() }
.mapStyle(.standard(elevation: .realistic))
```

### PhotosPicker loading via Transferable  — Letting the user import images/videos from their library
For multi-select use selection: [PhotosPickerItem] with maxSelectionCount. No Info.plist permission needed — the picker runs out-of-process.
```swift
@State private var item: PhotosPickerItem?
@State private var image: Image?
PhotosPicker("Pick", selection: $item, matching: .images)
    .onChange(of: item) { _, newItem in
        Task { image = try? await newItem?.loadTransferable(type: Image.self) }
    }
```

### Core Location async live updates (no delegate)  — Streaming the user's location with modern concurrency
Iterating implicitly holds a CLServiceSession (iOS 18+). Still add NSLocationWhenInUseUsageDescription to Info.plist. Use CLMonitor for geofence/beacon events.
```swift
for try await update in CLLocationUpdate.liveUpdates() {
    guard let loc = update.location else { continue }
    self.coordinate = loc.coordinate
    if update.authorizationDenied { break }
}
```

### FoundationModels on-device LLM with structured output  — On-device generation / extraction / summarization on iOS 26+ (no network, free)
Check SystemLanguageModel.default.availability first (device/OS support, Apple Intelligence enabled). Session is stateful (multi-turn transcript). Use Tool protocol for tool-calling.
```swift
@Generable struct Recipe { @Guide(description: "dish name") var title: String; var steps: [String] }
let session = LanguageModelSession()
let recipe = try await session.respond(to: "Invent a pasta recipe", generating: Recipe.self).content
```

### Swift Charts 2D and 3D  — Data visualization; 3D when the shape of the data matters more than exact values (iOS 26)
Marks: BarMark, LineMark, PointMark, AreaMark, RuleMark, RectangleMark, SectorMark (pie/donut). 3D adds Chart3D + SurfacePlot and Z-axis marks.
```swift
Chart(sales) { BarMark(x: .value("Month", $0.month), y: .value("Total", $0.total)) }

// iOS 26 3D
Chart3D(points) { PointMark(x: .value("X", $0.x), y: .value("Y", $0.y), z: .value("Z", $0.z)) }
    .chart3DCameraProjection(.perspective)
```

### Vision async text recognition  — OCR / image analysis on iOS 18+
New Swift-only Vision API: request structs + perform(on:). Avoid the legacy VNRecognizeTextRequest/VNImageRequestHandler completion-handler pattern in new code.
```swift
var request = RecognizeTextRequest()
request.recognitionLevel = .accurate
let observations = try await request.perform(on: imageData)
let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
```

### TipKit inline tip with an event rule  — Feature discovery / onboarding nudges (iOS 17+)
Call Tips.configure() once at launch. Donate events with FavoriteTip.opened.donate(). Prefer TipView (inline) over .popoverTip to avoid obscuring UI.
```swift
struct FavoriteTip: Tip {
    static let opened = Event(id: "opened")
    var title: Text { Text("Save favorites") }
    var rules: [Rule] { #Rule(Self.opened) { $0.donations.count >= 3 } }
}
// App launch: try? Tips.configure()
TipView(FavoriteTip())
```

### WeatherKit async fetch with attribution  — Showing weather; requires WeatherKit capability + entitlement
Attribution is mandatory. CurrentWeather/DayWeather/HourWeather are the result types. Add the WeatherKit capability in Signing & Capabilities.
```swift
let weather = try await WeatherService.shared.weather(for: location)
let now = weather.currentWeather  // .temperature, .condition, .symbolName
let attribution = try await WeatherService.shared.attribution  // must display logo + legal link
```

### UIViewControllerRepresentable bridge for mail/contacts/pencil  — Frameworks with no SwiftUI view: MFMailComposeViewController, CNContactPickerViewController, PKCanvasView
Standard escape hatch. For email prefer ShareLink/mailto when no attachment is needed. For contacts prefer the SwiftUI ContactAccessButton (iOS 18+) where it fits.
```swift
struct MailView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MFMailComposeViewController { /* set delegate */ }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
}
// Gate: if MFMailComposeViewController.canSendMail() { showMail = true }
```

## Pitfalls
- Permission-gated frameworks crash on launch if the Info.plist usage-description key is missing: NSLocationWhenInUseUsageDescription, NSHealthShareUsageDescription/NSHealthUpdateUsageDescription, NSCalendarsFullAccessUsageDescription, NSContactsUsageDescription, NSCameraUsageDescription, NSMicrophoneUsageDescription, NSPhotoLibraryUsageDescription (the picker itself needs none).
- WeatherKit and HealthKit require capabilities/entitlements added in Signing & Capabilities — they won't work from code alone; WeatherKit also mandates visible Apple Weather attribution or App Review rejection.
- FoundationModels is unavailable on older devices and when Apple Intelligence is off — always branch on SystemLanguageModel.default.availability instead of assuming the model exists; it is iOS 26+ only.
- MFMailComposeViewController/MFMessageComposeViewController return nil-behavior or fail on simulators and Apple-silicon Macs; always guard with canSendMail()/canSendText().
- PhotosPicker, PencilKit's PKCanvasView, CNContactPickerViewController, MFMailComposeViewController have NO native SwiftUI view (PencilKit/mail/contact picker) — don't hallucinate a pure-SwiftUI 'PencilCanvas' or 'MailView' type; wrap UIKit.
- Chart3D, FoundationModels, SpeechAnalyzer, and Swift Charts 3D marks are iOS 26+ only — gate with #available and don't present them as available on iOS 17/18.
- Loading a PhotosPickerItem must be async (loadTransferable) and can return nil for unsupported types; do it in a Task and handle nil rather than force-unwrapping.
- Iterating CLLocationUpdate.liveUpdates() without an active app/session can crash if started too early; start it from a view task, not at app init, and handle authorizationDenied.
- 'iOS 19'–'iOS 25' do not exist — citing them is a tell of stale data; the sequence is iOS 18 (2024) → iOS 26 (2025) → iOS 27 (2026, beta).

## iOS 26 changes
- Swift Charts 3D: new Chart3D container, SurfacePlot, Z-axis PointMark/RuleMark/RectangleMark, .chart3DCameraProjection, built-in rotation gestures.
- FoundationModels framework: on-device LLM via LanguageModelSession, @Generable/@Guide macros for structured output, Tool protocol for tool-calling — free, private, offline.
- SpeechAnalyzer / SpeechTranscriber / DictationTranscriber / SpeechDetector: new on-device, AsyncSequence-based speech-to-text replacing SFSpeechRecognizer, optimized for long-form audio.
- MapKit advances showcased at WWDC25 ('Go further with MapKit') including richer LookAroundPreview usage and MapKit JS parity; LookAroundPreview drives Look Around imagery from MKLookAroundScene.
- Translation framework broadens TranslationSession access in iOS 26 (previously the session was only obtainable via the SwiftUI modifier on earlier OSes).
- System-wide 'Liquid Glass' redesign in iOS 26 affects default rendering of system framework UI (maps controls, video player chrome, pickers) — generally automatic but worth noting for visual polish.

## iOS 27 preview (pre-GA)
- iOS 27 / Xcode 27 announced at WWDC 2026 (week of June 8, 2026) and in developer beta; specific framework deltas for this survey were not confirmable from primary Apple sources at research time. | Pre-GA — APIs and availability may change before public release; do not hard-code iOS 27-only APIs in a shipping skill without re-verifying against released SDK.

## Deprecations
- SwiftUI Map(coordinateRegion:) (iOS 14–16) → Map { MapContentBuilder } with position: MapCameraPosition (iOS 17+).
- ObservableObject/@Published view models → @Observable macro (Observation framework, iOS 17+); affects how you store HealthKitManager/LocationManager etc.
- CLLocationManagerDelegate + startUpdatingLocation → CLLocationUpdate.liveUpdates() AsyncSequence and CLMonitor (iOS 17+); manual CLServiceSession requests largely deletable (iOS 18+).
- EventKit requestAccess(to:) → granular requestFullAccessToEvents()/requestWriteOnlyAccessToEvents()/requestFullAccessToReminders() (iOS 17+).
- Vision VNRecognizeTextRequest + VNImageRequestHandler completion handlers → Swift-only RecognizeTextRequest.perform(on:) async (iOS 18+).
- SFSpeechRecognizer → SpeechAnalyzer + SpeechTranscriber on-device modules (iOS 26); SFSpeechRecognizer remains for custom-vocabulary cases.
- Legacy Formatter / DateFormatter / NumberFormatter classes → FormatStyle protocol and value.formatted(...) (iOS 15+).
- UIActivityViewController in SwiftUI → ShareLink (iOS 16+, Transferable-based).

## Uncertainties
- Could not load the JS-rendered Apple doc pages (Chart3D, LookAroundPreview, SpeechAnalyzer) verbatim via WebFetch; exact initializer signatures and full availability strings are corroborated from WWDC session pages + multiple reputable secondary sources but not copied from the framework reference. Re-verify exact signatures in Xcode 26 Quick Help before finalizing the skill.
- Translation framework's precise iOS 26 change (how TranslationSession is obtainable outside the SwiftUI modifier) is asserted by secondary sources; the exact new API surface was not confirmed against Apple's reference.
- No iOS 27-specific framework changes for this domain were verifiable from primary Apple sources during research — treated as unknown rather than guessed.
- Subprocess: it is a Swift package (swift-subprocess), not part of the sandboxed iOS SDK; its applicability to iPhone/iPad apps is minimal — included only for completeness as a 'Foundation-adjacent gem.'
- MapItemDetail (requested in the brief) did not surface as a confirmed public type name; the verified iOS 26 map-detail surfaces are LookAroundPreview and selection-driven detail via MapFeature/selection — flagging the requested name as unconfirmed.

## Sources
- MapKit for SwiftUI — Apple Developer Documentation: https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui
- LookAroundPreview — Apple Developer Documentation: https://developer.apple.com/documentation/mapkit/lookaroundpreview
- Bring Swift Charts to the third dimension — WWDC25 session 313: https://developer.apple.com/videos/play/wwdc2025/313/
- Chart3D — Apple Developer Documentation: https://developer.apple.com/documentation/charts/chart3d
- Bringing Photos picker to your SwiftUI app — Apple Developer Documentation: https://developer.apple.com/documentation/photokit/bringing-photos-picker-to-your-swiftui-app
- CLLocationUpdate.Updates — Apple Developer Documentation: https://developer.apple.com/documentation/corelocation/cllocationupdate/updates
- What's new in location authorization — WWDC24 session 10212: https://developer.apple.com/videos/play/wwdc2024/10212/
- Deep dive into the Foundation Models framework — WWDC25 session 301: https://developer.apple.com/videos/play/wwdc2025/301/
- Foundation Models — Apple Developer Documentation: https://developer.apple.com/documentation/foundationmodels/
- SpeechAnalyzer — Apple Developer Documentation: https://developer.apple.com/documentation/speech/speechanalyzer
- Bringing advanced speech-to-text capabilities to your app — Apple Developer Documentation: https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app
- Discover Swift enhancements in the Vision framework — WWDC24 session 10163: https://developer.apple.com/videos/play/wwdc2024/10163/
- Vision — Apple Developer Documentation: https://developer.apple.com/documentation/vision
- Meet the Contact Access Button — WWDC24 session 10121: https://developer.apple.com/videos/play/wwdc2024/10121/
- TipKit — Apple Developer Documentation: https://developer.apple.com/documentation/tipkit/
- WeatherKit — Apple Developer Documentation: https://developer.apple.com/documentation/weatherkit/
- WeatherKit Data Source Attribution — Apple Developer: https://developer.apple.com/weatherkit/data-source-attribution/
- HKHealthStore — Apple Developer Documentation: https://developer.apple.com/documentation/healthkit/hkhealthstore
- EKEventStore — Apple Developer Documentation: https://developer.apple.com/documentation/eventkit/ekeventstore
- CNContactPickerViewController — Apple Developer Documentation: https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller
- MFMailComposeViewController — Apple Developer Documentation: https://developer.apple.com/documentation/messageui/mfmailcomposeviewcontroller
- PKCanvasView — Apple Developer Documentation: https://developer.apple.com/documentation/pencilkit/pkcanvasview
- Translation — Apple Developer Documentation: https://developer.apple.com/documentation/translation
- FormatStyle — Apple Developer Documentation: https://developer.apple.com/documentation/foundation/formatstyle
- Create ML — Apple Developer Documentation: https://developer.apple.com/documentation/createml
- swift-subprocess — swiftlang GitHub: https://github.com/swiftlang/swift-subprocess
- WWDC 2025 Swift Charts 3D guide (corroboration) — DEV Community: https://dev.to/arshtechpro/wwdc-2025-swift-charts-3d-a-complete-guide-to-3d-data-visualization-40nc
- SpeechAnalyzer guide (corroboration) — Anton Gubarenko: https://antongubarenko.substack.com/p/ios-26-speechanalyzer-guide
