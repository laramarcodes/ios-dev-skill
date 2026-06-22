# On-device Apple Intelligence developer APIs

Apple exposes AI to apps across several layers of effort. The headline is **Foundation Models** (iOS 26): direct Swift access to the same on-device ~3B-param LLM that powers Apple Intelligence — free, offline, private. Above it sit features that "just work" in standard views (Writing Tools, Genmoji, Translation) and dedicated framework surfaces (Image Playground, Visual Intelligence, Speech). The recurring discipline: **gate everything behind an availability check** — most of these features exist only on Apple Intelligence-capable devices, and shipping without a fallback ships a broken feature.

**Contents**
- [What runs where](#what-runs-where)
- [Foundation Models: availability gate](#foundation-models-availability-gate)
- [Sessions, instructions, prompts](#sessions-instructions-prompts)
- [Guided generation (@Generable / @Guide)](#guided-generation-generable--guide)
- [Streaming partial results](#streaming-partial-results)
- [Tool calling](#tool-calling)
- [Token budgeting](#token-budgeting)
- [Writing Tools](#writing-tools)
- [Genmoji](#genmoji)
- [Image Playground](#image-playground)
- [Visual Intelligence](#visual-intelligence)
- [Speech transcription](#speech-transcription)
- [Translation](#translation)
- [iOS 27 preview (pre-GA)](#ios-27-preview-pre-ga)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## What runs where

| Surface | Framework | Since | Needs Apple Intelligence device? | Notes |
|---|---|---|---|---|
| On-device LLM | FoundationModels | iOS 26 | Yes — gate it | ~3B params, 8,192-token context |
| Writing Tools | (built into text views) | iOS 18.1 | Yes for the feature; views still work without | Free in standard text views |
| Genmoji insertion | (NSAdaptiveImageGlyph) | iOS 18.2 | Yes to create; display works anywhere | Not a generation API |
| Image Playground | ImagePlayground | iOS 18.1 | Yes | System sheet or UIKit VC |
| Visual Intelligence | VisualIntelligence + AppIntents | iOS 26 | Yes | Camera/screenshot → your AppEntity |
| On-device speech-to-text | Speech (SpeechAnalyzer) | iOS 26 | No (broad device support) | Powers Notes/Voice Memos |
| Translation | Translation | iOS 18 | No | On-device shared models |

The Foundation Models model is small: great for **summarize, extract, classify, tag, rewrite, and short structured generation** — not a world-knowledge chatbot, calculator, or long-reasoning engine. For agentic LLM work involving Claude/Anthropic models you bring yourself, see `concurrency-and-networking.md` for keychain/auth patterns; never embed API keys.

## Foundation Models: availability gate

`SystemLanguageModel.default` is the base on-device model (iOS 26+). Only iPhone 15 Pro and later, M-series iPad/Mac, and supported visionOS qualify — with Apple Intelligence enabled, in supported regions/languages. **Always switch on `.availability` before constructing a session or showing AI UI**, and provide a non-AI fallback.

```swift
import FoundationModels

let model = SystemLanguageModel.default
switch model.availability {
case .available:
    showAIFeature()
case .unavailable(.deviceNotEligible):
    hideFeature()                       // old hardware — no AI
case .unavailable(.appleIntelligenceNotEnabled):
    promptUserToEnableInSettings()
case .unavailable(.modelNotReady):
    retryLater()                        // assets still downloading
case .unavailable(let other):
    fallbackToNonAIPath(other)          // open default — handle it
}
```

There is also a convenience `model.isAvailable: Bool`. `SystemLanguageModel` is `@Observable` and `Sendable`, so you can drive SwiftUI from it directly. A specialized variant is available via `init(useCase:guardrails:)` — e.g. `SystemLanguageModel(useCase: .contentTagging)` for tagging-tuned output.

## Sessions, instructions, prompts

A `LanguageModelSession` is **stateful** — it holds a `Transcript` of the conversation. `Instructions` set the system role; `Prompt` carries the turn. Generate with `respond(to:)`, stream with `streamResponse(to:)`.

```swift
let session = LanguageModelSession(
    instructions: "You are a concise note summarizer. Reply in one sentence."
)
let response = try await session.respond(to: "Summarize: \(longNote)")
print(response.content)   // String
// session.transcript now contains this exchange; the next call has context.
```

Create a fresh session when you want a clean slate; reuse one to keep history (which also consumes context budget).

## Guided generation (@Generable / @Guide)

When you need **structured output** (extraction, forms, classification), annotate a Swift type with `@Generable` and constrain fields with `@Guide`. The framework guarantees the model's output decodes into your type — far more reliable than parsing free text. Keep schemas tight; large schemas eat the small context window.

```swift
@Generable
struct Recipe {
    @Guide(description: "A short, appetizing title")
    let title: String

    @Guide(description: "Ingredient lines", .count(3...12))
    let ingredients: [String]

    @Guide(description: "Difficulty 1–5", .range(1...5))
    let difficulty: Int
}

let session = LanguageModelSession()
let recipe = try await session.respond(
    to: "Invent a quick pasta recipe.",
    generating: Recipe.self
).content                               // a fully-typed Recipe
```

`@Guide` accepts a natural-language description plus programmatic constraints: `.range(_)`, `.count(_)`, regex/`pattern`, and enumerated values. This is the idiomatic way to get reliable JSON-shaped data out of the model — do **not** prompt for "return JSON" and hand-parse.

## Streaming partial results

`streamResponse(to:)` yields **snapshots** (`PartiallyGenerated` versions of your type), not token deltas — bind each straight to SwiftUI state for low perceived latency. Optionals fill in over time as fields resolve.

```swift
@State private var draft: Recipe.PartiallyGenerated?

func generate(_ prompt: String) async throws {
    let session = LanguageModelSession(instructions: "You are a chef.")
    for try await partial in session.streamResponse(to: prompt, generating: Recipe.self) {
        draft = partial                 // UI updates as fields arrive
    }
}
```

## Tool calling

Conform a type to `Tool` to let the model call into your app mid-generation for live data or actions. The `Arguments` struct **must itself be `@Generable`** (or it won't compile). The model decides when to invoke; results feed back into the transcript automatically. Keep tools focused and well-described.

```swift
struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "Get current weather for a city."

    @Generable struct Arguments {
        @Guide(description: "City name") let city: String
    }

    func call(arguments: Arguments) async throws -> some PromptRepresentable {
        let temp = try await WeatherService.temp(for: arguments.city)
        return "It is \(temp)°C in \(arguments.city)."
    }
}

let session = LanguageModelSession(
    tools: [WeatherTool()],
    instructions: "Help with weather questions."
)
let answer = try await session.respond(to: "Should I bring a coat in Oslo?")
```

## Token budgeting

The on-device context window is **8,192 tokens** (iOS 26). Long documents or fat schemas overflow it — chunk inputs and trim schemas. iOS 26.4 (Feb 2026) added measurement APIs:

| API | Purpose | Since |
|---|---|---|
| `SystemLanguageModel.tokenCount(for:)` | Count tokens in instructions/prompt/transcript | iOS 26.4 |
| `contextSize` | Max token window | iOS 26.4 |

Note the on-device model is **versioned with the OS** (26.0–26.3 vs 26.4, again in 27). Re-test prompts after OS updates — output quality and guardrail behavior shift between versions. Wrap `respond`/`streamResponse` in `try`/`catch`: guardrails can block benign content; show a fallback, never raw errors.

## Writing Tools

Rewrite / proofread / summarize / make-a-list work **automatically** in any standard text view — SwiftUI `Text`/`TextField`/`TextEditor`, `UITextView`, `NSTextView`, `WKWebView` (iOS 18.1+). Do **not** build a custom rewrite UI. Customize only when you must:

```swift
TextEditor(text: $body)
    .writingToolsBehavior(.automatic)          // .limited or .disabled to restrict
    .writingToolsAllowedInputOptions([.plainText])  // or .richText / .table
```

UIKit equivalent: the `writingToolsBehavior` property taking `UIWritingToolsBehavior`, plus `UIWritingToolsResultOptions`.

## Genmoji

Genmoji are **not a generation API you call** — they're inserted by the user via the emoji keyboard and live inline in attributed text as `NSAdaptiveImageGlyph` (iOS 18.2+). Standard text views support them for free. For a **custom** text view, adopt `NSAdaptiveImageGlyph` and set `supportsAdaptiveImageGlyph = true`. To persist them, archive the attributed string (e.g. RTFD) so the glyph survives round-trips — a plain `String` drops it.

## Image Playground

Present the system image generator. **Use the sheet (or UIKit VC) as the entry point** — `ImageCreator` (the headless programmatic generator) is **deprecated 18.4 → 27.0; do not teach it as the way in.**

```swift
.imagePlaygroundSheet(
    isPresented: $showGenerator,
    concept: "a cozy reading nook",        // or concepts:/sourceImage:/sourceImageURL:
    onCompletion: { url in importImage(url) },
    onCancellation: { }
)
```

UIKit: `ImagePlaygroundViewController` (ImagePlayground framework, iOS 18.1+). Assets may download on first use — handle the not-ready state.

## Visual Intelligence

Let users find **your app's content** by pointing the camera or selecting on a screenshot (iOS 26). Model content as an `AppEntity`, implement an `IntentValueQuery` (App Intents) that receives a `SemanticContentDescriptor` and returns matches. Use Vision's `GenerateImageFeaturePrintRequest` with precomputed feature prints + distance thresholds to keep similarity fast and on-device. Also covered in `system-integration.md`.

```swift
struct LandmarkQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [LandmarkEntity] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }
        // run GenerateImageFeaturePrintRequest, compare to precomputed prints
        return matchingLandmarks
    }
}
```

Results render via App Intents snippets / `SnippetView`.

## Speech transcription

`SpeechAnalyzer` + `SpeechTranscriber` (iOS 26, also macOS/visionOS) is the **new fully on-device** speech-to-text API powering Notes, Voice Memos, Journal, and FaceTime Live Captions. `SpeechAnalyzer` manages the session; `SpeechTranscriber` is the general-purpose module tuned for long-form, far-field, and low-latency live transcription. This supersedes older `SFSpeechRecognizer` flows for new code. Ensure the model asset is downloaded, then consume async results.

```swift
import Speech

let transcriber = SpeechTranscriber(locale: .current, /* options */ )
let analyzer = SpeechAnalyzer(modules: [transcriber])
// feed audio to analyzer; iterate transcriber results as an async sequence
```

## Translation

System UI is `.translationPresentation(isPresented:text:)` (a popover, iOS 18+). For inline/batch translation, drive a `TranslationSession` with `.translationTask`. Models are shared and on-device; first use of a language may prompt a download.

```swift
struct ContentView: View {
    @State private var config: TranslationSession.Configuration?
    var body: some View {
        MyText()
            .translationTask(config) { session in
                let result = try? await session.translate("Bonjour")
                // result?.targetText
            }
    }
}
```

SwiftUI-first; host in UIKit/AppKit via `UIHostingController`.

## iOS 27 preview (pre-GA)

WWDC 2026 announced a major expansion shipping fall 2026. **All of the following is developer beta — names may change, and none of it exists on iOS 26 devices.** Do not generate this as shipping code unless the user is explicitly targeting the iOS 27 SDK.

- **Vision input**: the rebuilt on-device model accepts image attachments via `Attachment(...)` (from `UIImage`/`NSImage`/`CGImage`/`CIImage`/`CVPixelBuffer`/URL) inside a prompt builder. Larger images cost more tokens.
- **`LanguageModel` protocol**: abstracts the backing model. `SystemLanguageModel` and `PrivateCloudComputeLanguageModel` conform; `CoreAILanguageModel`/`MLXLanguageModel` run other local models; Anthropic and Google ship Swift packages for their server models — same `LanguageModelSession` API downstream.
- **`PrivateCloudComputeLanguageModel`**: Apple server model, **32K context + reasoning**, no auth/API-key setup, private, free under usage thresholds; needs an entitlement. Pass `contextOptions: ContextOptions(reasoningLevel: .light /* or .deep */)` on `respond(...)`. Enables Foundation Models on watchOS 27.
- **`LanguageModelSession.DynamicProfile`**: declarative, SwiftUI-builder-style agentic primitive — a `body` returning `Profile { Instructions { … }; tools }` with `.model(...)`/`.reasoningLevel(...)` modifiers; resolves to one active profile at a time within a session.
- **Built-in tools**: `OCRTool`, `BarcodeReaderTool` (Vision-backed), plus a Spotlight-powered on-device RAG search tool. `GenerationOptions.ToolCallingMode` controls interaction.
- **Token accounting**: response `usage` exposes `input.totalTokenCount`, `input.cachedTokenCount`, `output.totalTokenCount`, `output.reasoningTokenCount`.
- **Refined errors**: `LanguageModelError`, `SystemLanguageModel.Error`, `LanguageModelSession.Error`. Plus an **Evaluations** Swift framework, a macOS `fm` CLI, and a Python SDK (`apple_fm_sdk`).

Private Cloud Compute is Apple's privacy guarantee for any server-side Apple Intelligence — prompts are never stored, run on verifiable Apple-silicon servers. Bringing a **third-party** server model instead means your own OAuth + Keychain token storage and per-token billing.

## Pitfalls

- **No availability check = broken feature for most users.** Foundation Models exists only on Apple Intelligence hardware with the feature enabled, in supported regions. Gate every use; provide a non-AI fallback.
- **Small context (8,192 tokens, iOS 26).** Long documents and big `@Generable` schemas overflow it. Chunk inputs; keep schemas tight; budget with `tokenCount(for:)`/`contextSize` (iOS 26.4+).
- **It's a ~3B small model.** Weak at world knowledge, precise arithmetic, and long reasoning. Use it for language tasks, not as a chatbot or calculator.
- **The model version changes with the OS.** Re-test and version your prompts across OS updates; guardrail false-positive behavior shifts too.
- **Guardrails block benign content.** Catch generation errors and degrade gracefully; never surface raw errors.
- **`@Generable` Tool `Arguments` must themselves be `@Generable`** — otherwise tool calling won't compile.
- **Don't build custom rewrite/translate UI.** Standard text views get Writing Tools / Genmoji / Translation free; customize only via the dedicated modifiers.
- **`ImageCreator` is deprecated (18.4→27.0).** Use `imagePlaygroundSheet` / `ImagePlaygroundViewController` as the entry point.
- **Genmoji isn't a generation call** — it's user insertion of `NSAdaptiveImageGlyph`; archive attributed strings (RTFD) to persist glyphs.
- **Translation / Image Playground assets download on first use.** Handle the not-ready/downloading state; don't assume instant availability.
- **iOS 27 APIs are pre-GA.** `Attachment`, `PrivateCloudComputeLanguageModel`, `DynamicProfile`, `OCRTool`/`BarcodeReaderTool`, `usage`, `ToolCallingMode` — names may change; absent on iOS 26. Verify against the shipping SDK before relying on them.

## Primary sources

- Foundation Models — https://developer.apple.com/documentation/foundationmodels/
- SystemLanguageModel — https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- Foundation Models updates — https://developer.apple.com/documentation/updates/foundationmodels
- Expanding generation with tool calling — https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
- What's new in the Foundation Models framework (WWDC26) — https://developer.apple.com/videos/play/wwdc2026/241/
- Visual Intelligence — https://developer.apple.com/documentation/VisualIntelligence/
- SpeechAnalyzer — https://developer.apple.com/documentation/speech/speechanalyzer
- TranslationSession — https://developer.apple.com/documentation/translation/translationsession
- What's New — Apple Intelligence — https://developer.apple.com/apple-intelligence/whats-new/
