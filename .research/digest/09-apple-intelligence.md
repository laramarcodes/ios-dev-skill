# DOMAIN: Apple Intelligence developer APIs (Foundation Models, Writing Tools, Image Playground/Genmoji, Visual Intelligence, Speech, Translation)

## Orientation
 Apple Intelligence exposes several distinct developer surfaces, layered by effort. The headline framework is Foundation Models (new in iOS 26): a Swift-native API over the same on-device ~3B-param LLM that powers Apple Intelligence, with guided generation (@Generable/@Guide), snapshot streaming, and a Tool protocol for function calling. It runs fully on-device, free, offline, private — but only on Apple Intelligence-capable devices (iPhone 15 Pro and later, M-series iPad/Mac, etc.) with Apple Intelligence enabled, so you MUST gate every use behind SystemLanguageModel.availability. The model is small: short context (8,192 tokens on-device in iOS 26), best for summarization, classification, tagging, extraction and short structured generation — not a world-knowledge chatbot or math engine. WWDC26/iOS 27 (pre-GA) is a big expansion: a rebuilt on-device model with vision (image input), a new LanguageModel protocol abstraction letting you back a session with PrivateCloudComputeLanguageModel (32K context, reasoning) or third-party models (Anthropic/Google Swift packages), DynamicProfile for agentic mode-switching, built-in Vision (OCRTool/BarcodeReaderTool) and Spotlight RAG tools, an Evaluations framework, plus a Python SDK and `fm` CLI. Separately, many AI features need no LLM code at all: Writing Tools, Genmoji, and Translation 'just work' if you use standard text views, and Image Playground / Visual Intelligence are integrated via dedicated frameworks and App Intents. Always version-qualify: iOS 26 is shipping; iOS 27 / 'June 2026' items are developer-beta and subject to change.

## Key facts
- [iOS 26|high] Foundation Models framework gives direct Swift access to the on-device LLM powering Apple Intelligence; available across iOS, iPadOS, macOS, and visionOS 26+. It is free, runs on-device, works offline, and keeps data private.
- [iOS 26|high] SystemLanguageModel is the on-device model class (iOS 26.0+). Access the base model via SystemLanguageModel.default; access a specialized variant via init(useCase:guardrails:) with SystemLanguageModel.UseCase (e.g. .contentTagging). It is @Observable, Sendable, and (in iOS 27 beta) conforms to the new LanguageModel protocol.
- [iOS 26|high] Availability check: model.availability returns SystemLanguageModel.Availability — .available, or .unavailable(reason) where reasons are .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, plus an open default. There is also a convenience var isAvailable: Bool. Always gate UI on this before creating a session.
- [iOS 26|high] Core types: LanguageModelSession (stateful, holds a transcript), Instructions, Prompt, GenerationOptions, Transcript. Generate via try await session.respond(to:) (returns a Response) and stream via session.streamResponse(to:) returning partial snapshots.
- [iOS 26|high] Guided generation: annotate a Swift type with the @Generable macro and constrain fields with @Guide (natural-language descriptions plus programmatic constraints like ranges, counts, regex/pattern, enumerated values). The framework guarantees the model output decodes into your type. Streaming yields a PartiallyGenerated version of the type.
- [iOS 26|high] Tool calling: conform a type to the Tool protocol with a name/description, a @Generable Arguments struct, and func call(arguments:) async throws returning a value (ToolOutput / PromptRepresentable). Pass tools into LanguageModelSession(tools:instructions:); the model decides when to invoke them.
- [iOS 26|high] On-device context window is 8,192 tokens in iOS 26 (Xcode #Playground estimates against 4,096). The model is small (~3B params) — designed for summarization, extraction, classification, tagging, and short generation; not for broad world knowledge or precise math.
- [iOS 26.4|high] iOS 26.4 (Feb 2026) added token APIs: SystemLanguageModel.tokenCount(for:) to measure tokens in instructions/prompt/transcript, and the contextSize property for the max token window. It also shipped an updated on-device model (so there are 26.0–26.3 and 26.4 model versions — re-test prompts) and improved guardrails to reduce false positives.
- [iOS 27 (pre-GA)|high] iOS 27 / June 2026 (pre-GA): the on-device model is rebuilt and gains vision — add image attachments to a prompt via Attachment(...) from UIImage, NSImage, CGImage, Core Image, CoreVideo pixel buffers, or file URLs, at any size/aspect ratio (larger images cost more tokens).
- [iOS 27 (pre-GA)|high] iOS 27 / June 2026 (pre-GA): new LanguageModel protocol abstracts the backing model. SystemLanguageModel and PrivateCloudComputeLanguageModel conform; open-source CoreAILanguageModel and MLXLanguageModel run other local models; Anthropic and Google publish Swift packages for their server models. Same LanguageModelSession API downstream.
- [iOS 27 (pre-GA)|high] iOS 27 / June 2026 (pre-GA): PrivateCloudComputeLanguageModel offers a 32,000-token context and reasoning. Pass contextOptions: ContextOptions(reasoningLevel: .light/.deep) on respond(...). No account/auth/API-key setup; private; free for developers with under 2M first-time downloads, higher limits for iCloud+ users. Enables Foundation Models on watchOS 27.
- [iOS 27 (pre-GA)|high] iOS 27 / June 2026 (pre-GA): DynamicProfile (LanguageModelSession.DynamicProfile) is a declarative, SwiftUI-builder-style primitive for agentic apps — a struct with a body of some DynamicProfile returning Profile { Instructions {…}; tools } with .model(...) and .reasoningLevel(...) modifiers. A DynamicProfile resolves to one active Profile at a time; the framework handles transitions within one session.
- [iOS 27 (pre-GA)|high] iOS 27 / June 2026 (pre-GA): built-in system tools — OCRTool and BarcodeReaderTool (Vision-backed) for visual reasoning, plus a Spotlight-powered search tool for fully on-device RAG. GenerationOptions.ToolCallingMode controls tool interaction. Sessions/responses expose a usage property (input.totalTokenCount, input.cachedTokenCount, output.totalTokenCount, output.reasoningTokenCount).
- [iOS 27 (pre-GA)|high] iOS 27 / June 2026 (pre-GA): improved error types — LanguageModelError (any model), SystemLanguageModel.Error (on-device), LanguageModelSession.Error (session, not model). New Evaluations Swift framework to measure feature quality. macOS 27 `fm` CLI and a Python SDK (apple_fm_sdk, also released March 2026) expose the same model. The core framework and a Foundation Models framework utilities package are being open-sourced.
- [since iOS 18|high] Writing Tools (rewrite/proofread/summarize) work automatically in standard text views (SwiftUI Text/TextField/TextEditor, UITextView, NSTextView, WKWebView). Control behavior with SwiftUI .writingToolsBehavior(.automatic/.limited/.disabled) (UIKit: writingToolsBehavior with UIWritingToolsBehavior) and restrict input via writingToolsAllowedInputOptions / UIWritingToolsResultOptions.
- [since iOS 18|high] Genmoji appear inline in attributed text as NSAdaptiveImageGlyph. Standard text views support them automatically; custom text views adopt NSAdaptiveImageGlyph (UIKit/AppKit) and set supportsAdaptiveImageGlyph = true on the text view. Persist them by archiving the attributed string (e.g. RTFD) so the glyph survives round-trips.
- [since iOS 18.1|high] Image Playground: present the system generator via SwiftUI .imagePlaygroundSheet(isPresented:concept:/concepts:/sourceImage:/sourceImageURL:onCompletion:onCancellation:) or UIKit ImagePlaygroundViewController. ImageCreator generates images programmatically without UI. From the ImagePlayground framework (iOS 18.1+ / 26).
- [iOS 26|high] Visual Intelligence (iOS 26): let users find in-app content by pointing the camera or selecting on a screenshot. Implement a query conforming to IntentValueQuery (App Intents) that receives a SemanticContentDescriptor (with a CVPixelBuffer / labels) and returns your AppEntity results. Use Vision's GenerateImageFeaturePrintRequest with precomputed feature prints + distance thresholds for fast on-device image similarity; results render via App Intents snippets / SnippetView.
- [iOS 26|high] Speech: SpeechAnalyzer + SpeechTranscriber (iOS 26, also macOS/visionOS) is a new fully on-device speech-to-text API powering Notes, Voice Memos, Journal, and FaceTime Live Captions. SpeechAnalyzer manages the session; SpeechTranscriber is the general-purpose module tuned for long-form, far-field, and low-latency live transcription. Setup: configure SpeechTranscriber, ensure the model asset is downloaded, then handle async results.
- [since iOS 18|high] Translation framework: present system translation UI with SwiftUI .translationPresentation(isPresented:text:) (popover). For programmatic translation use .translationTask(...) with a TranslationSession (translate one or many strings via async/await using shared on-device models). SwiftUI-first; UIKit/AppKit hosts via UIHostingController. Framework available since iOS 18.
- [iOS 27 (pre-GA)|high] Private Cloud Compute is Apple's privacy guarantee for any server-side Apple Intelligence: prompts are never stored, run on Apple-silicon servers, and the build is independently verifiable. From iOS 27 developers can target it directly via PrivateCloudComputeLanguageModel; third-party server models you bring instead require your own auth (OAuth, store tokens in Keychain — never embed keys) and per-token billing.

## APIs
- `FoundationModels` (framework; iOS 26+) — On-device LLM access; import FoundationModels.
- `SystemLanguageModel` (class; iOS 26+) — Final class. .default singleton; init(useCase:guardrails:). @Observable, Sendable, conforms to LanguageModel (iOS 27).
- `SystemLanguageModel.Availability` (enum; iOS 26+) — Cases: .available, .unavailable(UnavailableReason). Reasons: .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady.
- `SystemLanguageModel.UseCase` (struct; iOS 26+) — Specialized variants, e.g. .general, .contentTagging.
- `SystemLanguageModel.Guardrails` (struct; iOS 26+) — Flags sensitive input/output content.
- `isAvailable` (property; iOS 26+) — Convenience Bool on SystemLanguageModel.
- `contextSize` (property; iOS 26.4+) — Max context window in tokens (8192 on-device in iOS 26).
- `tokenCount(for:)` (method; iOS 26.4+) — Token count for instructions/prompt/transcript.
- `supportedLanguages` (property; iOS 26+) — Set<Locale.Language>; also supportsLocale(_:).
- `LanguageModelSession` (class; iOS 26+) — Stateful session; init(model:tools:instructions:transcript:profile:). respond(to:), streamResponse(to:); .transcript; .usage (iOS 27).
- `Instructions` (struct; iOS 26+) — System/role instructions; builder syntax.
- `Prompt` (struct; iOS 26+) — Prompt content; PromptRepresentable / PromptBuilder.
- `Generable` (macro/protocol; iOS 26+) — @Generable macro marks a type the model can generate; yields a PartiallyGenerated form for streaming.
- `Guide` (macro; iOS 26+) — @Guide adds description + constraints (.range, .count, pattern, enumerated).
- `Tool` (protocol; iOS 26+) — name, description, @Generable Arguments, func call(arguments:) async throws.
- `GenerationOptions` (struct; iOS 26+) — temperature, maximumResponseTokens, sampling; ToolCallingMode nested (iOS 27).
- `Transcript` (struct; iOS 26+) — Full prompt/response history of a session.
- `LanguageModel` (protocol; iOS 27 (pre-GA)) — Model abstraction backing a session; SystemLanguageModel & PrivateCloudComputeLanguageModel conform.
- `PrivateCloudComputeLanguageModel` (class; iOS 27 (pre-GA)) — Apple server model, 32K context, reasoning; needs an entitlement.
- `ContextOptions` (struct; iOS 27 (pre-GA)) — reasoningLevel: .light/.deep, passed to respond(...).
- `Attachment` (struct; iOS 27 (pre-GA)) — Image attachment in a prompt builder; from UIImage/NSImage/CGImage/CIImage/CVPixelBuffer/URL.
- `LanguageModelSession.DynamicProfile` (protocol; iOS 27 (pre-GA)) — Declarative agentic profiles; body returns Profile with .model()/.reasoningLevel() modifiers.
- `OCRTool` (struct; iOS 27 (pre-GA)) — Vision-backed built-in tool; extracts structured text from images.
- `BarcodeReaderTool` (struct; iOS 27 (pre-GA)) — Vision-backed built-in tool; reads barcodes.
- `LanguageModelError` (enum; iOS 27 (pre-GA)) — Plus SystemLanguageModel.Error and LanguageModelSession.Error.
- `WritingToolsBehavior` (enum; since iOS 18) — SwiftUI .writingToolsBehavior(.automatic/.limited/.disabled); UIKit UIWritingToolsBehavior.
- `writingToolsAllowedInputOptions` (modifier; since iOS 18) — Restrict to plain/rich text/tables (UIWritingToolsResultOptions).
- `NSAdaptiveImageGlyph` (class; since iOS 18) — Inline Genmoji glyph in attributed text; set supportsAdaptiveImageGlyph on custom text views.
- `imagePlaygroundSheet(isPresented:concept:sourceImage:onCompletion:onCancellation:)` (modifier; since iOS 18.1) — SwiftUI presenter for Image Playground; concept/concepts/sourceImage/sourceImageURL variants.
- `ImagePlaygroundViewController` (class; since iOS 18.1) — UIKit Image Playground UI.
- `ImageCreator` (class; since iOS 18.1) — Programmatic image generation without UI.
- `IntentValueQuery` (protocol; iOS 26) — App Intents query feeding Visual Intelligence on-screen search; receives SemanticContentDescriptor.
- `SemanticContentDescriptor` (struct; iOS 26) — Carries pixelBuffer/labels for Visual Intelligence queries.
- `SpeechAnalyzer` (class; iOS 26) — Manages on-device speech analysis session.
- `SpeechTranscriber` (class; iOS 26) — General-purpose on-device speech-to-text module; long-form & low-latency live.
- `TranslationSession` (class; since iOS 18) — Programmatic translate(_:) async; via .translationTask.
- `translationPresentation(isPresented:text:...)` (modifier; since iOS 18) — SwiftUI system translation popover.
- `translationTask(source:target:action:)` (modifier; since iOS 18) — Drives a TranslationSession for inline translation.

## Patterns

### Availability gate before any Foundation Models use  — Always, before constructing a LanguageModelSession or showing AI UI.
Never assume the model exists. Only iPhone 15 Pro+/M-series with Apple Intelligence on, in supported regions/languages, return .available. Provide a non-AI fallback path.
```swift
let model = SystemLanguageModel.default
switch model.availability {
case .available:
    // proceed
case .unavailable(.deviceNotEligible):
    // hide feature / fallback
case .unavailable(.appleIntelligenceNotEnabled):
    // prompt user to enable Apple Intelligence in Settings
case .unavailable(.modelNotReady):
    // model still downloading; retry later
case .unavailable(let other):
    // generic fallback
}
```

### Guided generation into a typed struct with @Generable / @Guide  — You need structured output (extraction, classification, forms) rather than free text.
The @Generable macro + @Guide constraints make the model emit decodable, schema-valid output — far more reliable than parsing free text. Keep schemas small to fit the short context window.
```swift
@Generable
struct Recipe {
    @Guide(description: "A short, appetizing title")
    let title: String
    @Guide(description: "Ingredients", .count(3...12))
    let ingredients: [String]
    @Guide(.range(1...5))
    let difficulty: Int
}

let session = LanguageModelSession()
let recipe = try await session.respond(
    to: "Invent a quick pasta recipe.",
    generating: Recipe.self
).content
```

### Streaming partial results to the UI  — You want progressive/snapshot updates as the model generates (better perceived latency).
streamResponse yields PartiallyGenerated snapshots, not token deltas — bind them straight to SwiftUI state. The session stays stateful; the call is recorded in session.transcript.
```swift
let session = LanguageModelSession(instructions: "You are a concise assistant.")
for try await partial in session.streamResponse(to: prompt, generating: Recipe.self) {
    // partial is Recipe.PartiallyGenerated — optionals fill in over time
    self.draft = partial
}
```

### Tool calling with the Tool protocol  — The model needs live data or to perform an app action mid-generation.
Arguments must be @Generable. The model decides when to call; results feed back into the transcript automatically. Keep tools focused and well-described.
```swift
struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "Get current weather for a city."
    @Generable struct Arguments { let city: String }
    func call(arguments: Arguments) async throws -> some PromptRepresentable {
        let temp = try await WeatherService.temp(for: arguments.city)
        return "It is \(temp)°C in \(arguments.city)."
    }
}

let session = LanguageModelSession(
    tools: [WeatherTool()],
    instructions: "Help with weather questions.")
let answer = try await session.respond(to: "Should I bring a coat in Oslo?")
```

### Multimodal image prompt (iOS 27, pre-GA)  — Asking the on-device or PCC model about an image. iOS 27 beta only.
Image attachments accept UIImage/NSImage/CGImage/CIImage/CVPixelBuffer/URL at any size. Pre-GA — API names may change before iOS 27 GA.
```swift
let response = try await session.respond {
    "What animal is this?"
    Attachment(UIImage(named: "photo")!)
}
```

### DynamicProfile for agentic mode-switching (iOS 27, pre-GA)  — One session needs to switch instructions/tools/model between tasks while keeping history.
Resolves to one active Profile at a time; framework swaps context as state changes. Pre-GA.
```swift
struct CraftProfile: LanguageModelSession.DynamicProfile {
    let states: CraftProjectStates
    var body: some DynamicProfile {
        switch states.mode {
        case .analysis:
            Profile { Instructions { "Analyze the craft." }; RecordAnalysisTool() }
        case .brainstorm:
            Profile { Instructions { "Brainstorm ideas." }; BrainstormTool() }
                .model(states.privateCloudCompute)
                .reasoningLevel(.deep)
        }
    }
}
let session = LanguageModelSession(profile: CraftProfile(states: states))
```

### Programmatic translation with TranslationSession  — Translating strings inside your app without showing the system popover.
Use .translationPresentation(isPresented:text:) for the quick system popover; use .translationTask + TranslationSession for inline/batch. On-device shared models; may prompt to download a language.
```swift
struct ContentView: View {
    @State private var config: TranslationSession.Configuration?
    var body: some View {
        MyText()
            .translationTask(config) { session in
                let result = try? await session.translate("Bonjour")
                // use result.targetText
            }
    }
}
```

### Visual Intelligence on-screen content search (iOS 26)  — Letting users find your app's entities from the camera or a screenshot.
Model your content as an AppEntity, implement IntentValueQuery returning matches, and render with App Intents snippets. Vision feature prints keep similarity on-device and fast.
```swift
struct LandmarkQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [LandmarkEntity] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }
        // run Vision GenerateImageFeaturePrintRequest, compare to precomputed prints
        return matchingLandmarks
    }
}
```

## Pitfalls
- Foundation Models is NOT available on all devices — only Apple Intelligence-capable hardware (iPhone 15 Pro+, M-series iPad/Mac, supported visionOS) with Apple Intelligence enabled and in supported regions/languages. Skipping the availability check ships a broken feature to most users.
- The on-device context window is small (8,192 tokens in iOS 26). Long documents or large @Generable schemas overflow it — chunk inputs and keep schemas tight; use tokenCount(for:)/contextSize (iOS 26.4+) to budget.
- It is a ~3B-param small model: weak at broad world knowledge, precise arithmetic, and long reasoning. Use it for language tasks (summarize/extract/classify/rewrite/tag), not as a general chatbot or calculator.
- The on-device model changes across OS updates (26.0–26.3 vs 26.4, and again in 27). Re-test and version your prompts; guardrail behavior and false positives also shift between versions.
- Guardrails can block benign content; handle generation errors and provide a fallback. Don't surface raw errors to users.
- iOS 27 / June 2026 APIs (vision Attachment, PrivateCloudComputeLanguageModel, DynamicProfile, OCRTool/BarcodeReaderTool, usage, ToolCallingMode) are developer beta — exact names may change before GA; do not assume they exist on iOS 26 devices.
- Third-party server models brought via the LanguageModel protocol require your own OAuth + Keychain token storage and per-token billing — never embed API keys in the app binary. PCC avoids this but needs an entitlement.
- @Generable Tool Arguments must themselves be @Generable, or tool calling won't compile/work.
- Translation/Image Playground may need to download language or model assets on first use — handle the not-ready/downloading state, don't assume instant availability.

## iOS 26 changes
- Foundation Models framework introduced — on-device LLM with @Generable/@Guide guided generation, snapshot streaming, Tool protocol, SystemLanguageModel availability gating. 8,192-token on-device context.
- iOS 26.4: added SystemLanguageModel.tokenCount(for:) and contextSize; shipped an updated on-device model (26.0–26.3 vs 26.4 versions — re-test prompts); improved guardrails reducing false positives.
- Visual Intelligence framework + IntentValueQuery / SemanticContentDescriptor for on-screen & camera content search returning AppEntity results.
- Speech: SpeechAnalyzer + SpeechTranscriber on-device speech-to-text API (powers Notes, Voice Memos, FaceTime Live Captions).

## iOS 27 preview (pre-GA)
- Rebuilt on-device model with vision/image input (Attachment in prompt builder); better logic and tool calling. | Developer beta; API names (Attachment) may change before GA.
- LanguageModel protocol abstraction: back a session with PrivateCloudComputeLanguageModel (32K context, reasoning levels), CoreAILanguageModel, MLXLanguageModel, or Anthropic/Google Swift packages. | Pre-GA; PCC needs an entitlement; third-party models need your own auth + billing.
- DynamicProfile declarative agentic API, GenerationOptions.ToolCallingMode, built-in OCRTool/BarcodeReaderTool, Spotlight RAG search tool, response.usage token accounting, refined error types. | Developer beta, subject to change.
- Evaluations Swift framework, macOS 27 `fm` CLI, Python SDK (apple_fm_sdk), Foundation Models on watchOS 27 via PCC, and open-sourcing of the core framework + utilities package. | Announced WWDC26; some items shipped pre-WWDC (Python SDK March 2026).

## Deprecations
- Use SystemLanguageModel.availability gating instead of assuming Apple Intelligence is present — there is no try/run-and-hope path.
- Old way vs new for LLM tasks: prior to iOS 26 you shipped/hosted your own model or called a cloud API; iOS 26+ Foundation Models gives a free on-device model — prefer it for summarize/extract/classify/tag.
- Writing Tools/Genmoji/Translation: do NOT build custom rewrite/translate UI when standard text views (SwiftUI Text/TextEditor, UITextView, NSTextView, WKWebView) get these features for free; only customize via writingToolsBehavior when you must.
- ImageCreator is reported deprecated in favor of imagePlaygroundSheet / ImagePlaygroundViewController in newer docs — verify against current SDK before using ImageCreator (flagged as uncertain).

## Uncertainties
- Exact spelling of some iOS 27 pre-GA symbols (e.g. Attachment vs ImageAttachment, ContextOptions, usage sub-properties like cachedTokenCount/reasoningTokenCount) is taken from the WWDC26 session 241 transcript/code samples; verify against the shipping iOS 27 SDK headers before copying into a skill.
- Whether ImageCreator is formally deprecated vs merely 'prefer the sheet' is reported by a secondary summary; confirm on the ImagePlayground/ImageCreator reference page.
- Precise enum case spelling for SystemLanguageModel.Availability unavailable reasons beyond the three documented (.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady) — there is an open default case; confirm full list in headers.
- The 'June 2026' updates doc labels several items Beta; final iOS 27 GA naming/behavior (DynamicProfile modifiers, Profile builder, Evaluations framework types) may differ.
- Smart Reply: I did not find a dedicated public developer API surface beyond the system keyboard/Messages integration; it appears to be a system feature rather than a third-party-callable API — needs confirmation.
- Exact GenerationOptions field names (temperature/maximumResponseTokens/sampling) inferred from WWDC25 patterns; verify against the GenerationOptions reference.

## Sources
- Foundation Models | Apple Developer Documentation: https://developer.apple.com/documentation/foundationmodels/
- SystemLanguageModel | Apple Developer Documentation: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- Foundation Models updates | Apple Developer Documentation: https://developer.apple.com/documentation/updates/foundationmodels
- Meet the Foundation Models framework - WWDC25: https://developer.apple.com/videos/play/wwdc2025/286/
- Deep dive into the Foundation Models framework - WWDC25: https://developer.apple.com/videos/play/wwdc2025/301/
- Expanding generation with tool calling | Apple Developer Documentation: https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
- What's new in the Foundation Models framework - WWDC26: https://developer.apple.com/videos/play/wwdc2026/241/
- WritingToolsBehavior | Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/writingtoolsbehavior
- NSAdaptiveImageGlyph | Apple Developer Documentation: https://developer.apple.com/documentation/uikit/nsadaptiveimageglyph
- imagePlaygroundSheet(...) | Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/view/imageplaygroundsheet(ispresented:concept:sourceimage:oncompletion:oncancellation:)
- ImageCreator | Apple Developer Documentation: https://developer.apple.com/documentation/ImagePlayground/ImageCreator
- Visual Intelligence | Apple Developer Documentation: https://developer.apple.com/documentation/VisualIntelligence/
- IntentValueQuery | Apple Developer Documentation: https://developer.apple.com/documentation/AppIntents/IntentValueQuery
- SpeechAnalyzer | Apple Developer Documentation: https://developer.apple.com/documentation/speech/speechanalyzer
- SpeechTranscriber | Apple Developer Documentation: https://developer.apple.com/documentation/speech/speechtranscriber
- TranslationSession | Apple Developer Documentation: https://developer.apple.com/documentation/translation/translationsession
- translationPresentation(...) | Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/view/translationpresentation(ispresented:text:attachmentanchor:arrowedge:replacementaction:)
- Bring advanced speech-to-text to your app with SpeechAnalyzer - WWDC25: https://developer.apple.com/videos/play/wwdc2025/277/
- What's New - Apple Intelligence - Apple Developer: https://developer.apple.com/apple-intelligence/whats-new/
