# DOMAIN: Swift 6 concurrency & networking (strict concurrency, Approachable Concurrency, async/await, actors, URLSession) for native SwiftUI iPhone/iPad apps

## Orientation
 As of June 2026, the shipping toolchain is Xcode 26 / Swift 6.2 (iOS 26), with Xcode 27 / Swift 6.3 freshly in developer beta at WWDC 2026 (pre-GA). The single most important shift since "raw" Swift 6 is "Approachable Concurrency" (Swift 6.2): a new app target in Xcode 26 ships with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor and the SWIFT_APPROACHABLE_CONCURRENCY umbrella ON, so all your code is implicitly @MainActor unless you say otherwise. This makes single-threaded app code "just work" with no Sendable ceremony; you opt INTO concurrency explicitly with @concurrent (offload to a background thread) or actors (protect shared mutable state). The mental model is progressive disclosure: stay on the main actor for UI and view models, push only genuinely expensive work (@concurrent) or shared mutable state (actor) off-main. Networking is URLSession's async methods (data(for:), bytes(for:), download) feeding Codable decoding; Combine is legacy and only appears where a specific API still vends a Publisher. The compiler enforces data-race safety at compile time via Sendable and actor isolation — most migration pain is teaching it which state is isolated where.

## Key facts
- [iOS 26 / Swift 6.2|high] A new app target created in Xcode 26 defaults to main-actor isolation: build setting 'Default Actor Isolation' (SWIFT_DEFAULT_ACTOR_ISOLATION) = MainActor for new projects, = nonisolated for existing ones. The compiler implicitly writes @MainActor on every type/function in the module that has no explicit isolation.
- [iOS 26 / Swift 6.2|high] 'Approachable Concurrency' is an umbrella build setting (SWIFT_APPROACHABLE_CONCURRENCY) that turns on a suite of upcoming-feature flags: DisableOutwardActorInference (SE-0401), GlobalActorIsolatedTypesUsability (SE-0434), InferIsolatedConformances (SE-0470), InferSendableFromCaptures (SE-0418), and NonisolatedNonsendingByDefault (SE-0461). Apple recommends enabling it for all projects.
- [iOS 26 / Swift 6.2|high] SE-0461 (implemented in Swift 6.2) changes what a plain 'nonisolated async' function does. With NonisolatedNonsendingByDefault enabled, nonisolated async functions run on the CALLER's actor/executor (inherit isolation) instead of hopping to the global concurrent executor. This means you can pass non-Sendable values into them without errors.
- [iOS 26 / Swift 6.2|high] nonisolated(nonsending) is the explicit spelling for 'run on the caller's executor, do not start a new isolation context.' @concurrent is the opposite: it forces an async function to always switch OFF the current actor onto the global concurrent executor (background thread), and its arguments/results must be Sendable. @concurrent functions are implicitly nonisolated.
- [iOS 26 / Swift 6.2|high] Recommended pattern for offloading CPU-heavy work (JSON decoding, image processing) in a main-actor-by-default app: mark just that one function @concurrent rather than offloading whole pipelines. 'nonisolated' (without nonsending) is recommended for general-purpose library code that should run wherever it is called from.
- [since iOS 15 / Swift 5.5|high] Actors serialize access to shared mutable state ('only one task touches the data at a time') and are implicitly Sendable, so actor references can be freely shared across isolation boundaries. Use an actor (not @MainActor) for non-UI shared state like a connection cache or in-memory store.
- [since iOS 15|high] URLSession async APIs: data(from:)/data(for:) await the full response body; bytes(from:)/bytes(for:) return URLSession.AsyncBytes (an AsyncSequence) for incremental/streaming consumption with helpers like .lines; download(for:) for files; all async methods accept an optional task-specific delegate argument.
- [iOS 26 / Swift 6|high] Under Swift 6 strict concurrency, networking/service classes must be Sendable or isolated. Simplest options: make the service an actor, or annotate it @MainActor; models decoded with Codable should be Sendable (value types usually are automatically).
- [since iOS 17 / Swift 5.9|high] AsyncStream.makeStream(of:bufferingPolicy:) (SE-0388, Swift 5.9+) returns the stream and its continuation together — the modern way to bridge delegate/callback APIs (e.g. download progress) into an AsyncSequence. Cancelling the consumer does NOT cancel the producer; clean up producer work in the continuation's onTermination handler.
- [iOS 26 / Swift 6|high] Strict concurrency checking has three levels controlled by SWIFT_STRICT_CONCURRENCY: minimal, targeted, complete. Swift 6 language mode = complete enforcement (data-race safety is a compile error, not a warning). Recommended migration: ground on Swift 5.10 with complete checking shipping as warnings, then move global mutable state to actors/@MainActor before flipping to the Swift 6 language mode.
- [iOS 26|medium] Modern alternative to Combine: @Observable macro (Observation framework) for state + async/await and AsyncSequence/AsyncStream for streams of values. Combine still surfaces where APIs vend Publishers (some system frameworks, NotificationCenter.publisher, Timer.publish) but is no longer the default reactive layer.

## APIs
- `@MainActor` (global actor attribute; iOS 15+) — In Xcode 26 new app targets, implicitly applied to all code via Default Actor Isolation = MainActor.
- `actor` (declaration keyword; iOS 15+) — Serializes access to mutable state; implicitly Sendable.
- `nonisolated` (isolation modifier; iOS 15+) — Detaches code from actor isolation; runs wherever called. Recommended for library code.
- `nonisolated(nonsending)` (isolation modifier; Swift 6.2 (iOS 26)) — Async fn runs on caller's executor without starting a new isolation context; non-Sendable args OK. SE-0461.
- `@concurrent` (function attribute; Swift 6.2 (iOS 26)) — Forces async fn onto the global concurrent executor (background); args/results must be Sendable. SE-0461.
- `Sendable` (protocol; iOS 15+) — Marks types safe to cross isolation boundaries.
- `@Sendable` (closure attribute; iOS 15+) — 
- `async / await` (keywords; iOS 15+) — 
- `async let` (structured concurrency binding; iOS 15+) — Concurrent child tasks awaited at use site.
- `withTaskGroup(of:)/withThrowingTaskGroup(of:)` (function; iOS 15+) — Dynamic structured concurrency; children implicitly awaited at closure exit.
- `Task { }` (unstructured task; iOS 15+) — Inherits actor isolation + task-locals of the creating context.
- `Task.detached` (static function; iOS 15+) — Does NOT inherit isolation/task-locals; use sparingly.
- `Task.checkCancellation() / Task.isCancelled` (cancellation API; iOS 15+) — Cooperative cancellation; tasks must check.
- `@TaskLocal` (property wrapper; iOS 15+) — Task-scoped values propagated to child tasks via $value.withValue { }.
- `withCheckedContinuation / withCheckedThrowingContinuation` (function; iOS 15+) — Bridge single-shot callback APIs into async; resume exactly once.
- `AsyncStream / AsyncThrowingStream` (type; iOS 15+) — 
- `AsyncStream.makeStream(of:bufferingPolicy:)` (static factory; iOS 17+ / Swift 5.9) — SE-0388; returns (stream, continuation).
- `AsyncSequence` (protocol; iOS 15+) — 
- `URLSession.data(for:) / data(from:)` (async method; iOS 15+) — Returns (Data, URLResponse).
- `URLSession.bytes(for:) / bytes(from:)` (async method; iOS 15+) — Returns (URLSession.AsyncBytes, URLResponse).
- `URLSession.AsyncBytes` (type (AsyncSequence); iOS 15+) — .lines helper for streaming text.
- `URLSession.download(for:)` (async method; iOS 15+) — 
- `URLSessionConfiguration.background(withIdentifier:)` (factory; iOS 15+) — Out-of-process transfers; uses delegate, not async return.
- `@Observable` (macro (Observation); iOS 17+) — Replaces ObservableObject; modern reactive state, used with async/await instead of Combine.
- `Codable / JSONDecoder` (protocol / decoder; iOS 15+) — Decode network payloads; offload large decodes with @concurrent.
- `SWIFT_DEFAULT_ACTOR_ISOLATION` (build setting; Xcode 26) — MainActor (new app targets) | nonisolated.
- `SWIFT_APPROACHABLE_CONCURRENCY` (build setting; Xcode 26) — Umbrella ON for new targets; enables SE-0401/0434/0470/0418/0461.
- `SWIFT_STRICT_CONCURRENCY` (build setting; Xcode 14+) — minimal | targeted | complete.

## Patterns

### Main-actor-by-default app: offload only the expensive part  — New Xcode 26 app target (MainActor default). A view model fetches and decodes; only decode is CPU-heavy.
UI state stays on the main actor with zero Sendable ceremony. Mark just the heavy function @concurrent. Post must be Sendable (a struct of Sendable fields is automatically).
```swift
@Observable
final class FeedModel { // implicitly @MainActor
    var posts: [Post] = []
    func load() async throws {
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        posts = try await decode(data) // hops back to main automatically
    }
    @concurrent
    private func decode(_ data: Data) async throws -> [Post] {
        try JSONDecoder().decode([Post].self, from: data) // runs off-main
    }
}
```

### Actor for shared mutable state (not UI)  — A cache/connection store shared across tasks that is not the UI.
Use an actor (not @MainActor) so cache access serializes off the main thread. The actor reference is Sendable and shareable.
```swift
actor ImageCache {
    private var store: [URL: Data] = [:]
    func image(for url: URL) async throws -> Data {
        if let cached = store[url] { return cached }
        let (data, _) = try await URLSession.shared.data(from: url)
        store[url] = data
        return data
    }
}
```

### Concurrent fan-out with async let / TaskGroup  — Fetch several independent resources at once.
async let for a fixed number of children; TaskGroup when the count is dynamic. Both are structured: children are awaited before the scope returns and cancel together.
```swift
// fixed set
async let user = api.user(id)
async let posts = api.posts(for: id)
let profile = try await Profile(user: user, posts: posts)

// dynamic set
try await withThrowingTaskGroup(of: Post.self) { group in
    for id in ids { group.addTask { try await api.post(id) } }
    var result: [Post] = []
    for try await p in group { result.append(p) }
    return result
}
```

### Streaming download progress via AsyncStream.makeStream  — Bridge URLSession delegate progress callbacks into async/await.
Cancelling the consumer does not cancel the producer — wire cleanup in onTermination. makeStream avoids the older nested-closure capture dance.
```swift
let (stream, continuation) = AsyncStream<Double>.makeStream()
continuation.onTermination = { _ in downloadTask.cancel() }
// in delegate: continuation.yield(progress); continuation.finish() on completion
for await progress in stream { updateBar(progress) }
```

### Bridge a single-shot callback API  — Wrapping a legacy completion-handler API in async.
Resume the continuation exactly once on every path — resuming twice traps, never resuming leaks the task forever. Prefer the checked variants in development.
```swift
func currentLocation() async throws -> CLLocation {
    try await withCheckedThrowingContinuation { cont in
        manager.requestLocation { result in
            switch result {
            case .success(let loc): cont.resume(returning: loc)
            case .failure(let e):   cont.resume(throwing: e)
            }
        }
    }
}
```

### Simple typed retry with backoff and cancellation  — Transient network failures.
Honor cancellation between attempts (checkCancellation / Task.sleep throws on cancel). Keep op non-Sendable-friendly by running on the caller's isolation.
```swift
func withRetry<T: Sendable>(_ attempts: Int = 3, _ op: () async throws -> T) async throws -> T {
    for attempt in 1...attempts {
        do { return try await op() }
        catch {
            try Task.checkCancellation()
            if attempt == attempts { throw error }
            try await Task.sleep(for: .seconds(pow(2, Double(attempt - 1))))
        }
    }
    fatalError("unreachable")
}
```

## Pitfalls
- Assuming a plain 'nonisolated async func' runs in the background. With Approachable Concurrency (SE-0461) it now runs on the CALLER's executor — to actually offload work you must use @concurrent.
- Reaching for Task.detached to 'get off the main thread.' It drops actor isolation AND task-local values and breaks structured cancellation. Prefer @concurrent or an actor; use detached only when you truly need no inherited context.
- Forgetting that cancelling an AsyncStream consumer does not cancel the producer — leaking the underlying network/download task. Always set continuation.onTermination.
- Resuming a continuation zero or multiple times. Two resumes trap at runtime; zero resumes hangs the awaiting task forever. Use withChecked* in dev to catch misuse.
- Slapping @MainActor on everything to silence Swift 6 errors — this serializes genuinely parallel work onto the main thread and hurts responsiveness. Isolate UI state to main; move shared non-UI state into actors.
- Making a class Sendable with @unchecked Sendable to dodge errors without real synchronization — reintroduces the exact data races the compiler was preventing.
- Enabling all Approachable Concurrency upcoming-feature flags at once on a large existing project. Apple/Donny Wals recommend migrating feature-by-feature with the migration tooling to avoid surprise isolation changes.
- Expecting an @concurrent function to accept non-Sendable arguments — it switches isolation domains, so all arguments and the return type must be Sendable.
- Treating Combine as the default for new async data flows. Use @Observable + async/await/AsyncStream; Combine is now legacy and mainly appears where a framework still vends a Publisher.
- Using URLSession.shared.data on a background URLSessionConfiguration and expecting the async return — background sessions deliver results via delegate after the app may be suspended, not via the async data(for:) return value.

## iOS 26 changes
- Approachable Concurrency (Swift 6.2): new Xcode 26 app targets default to Main Actor isolation (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) plus the Approachable Concurrency umbrella ON.
- SE-0461: nonisolated async functions inherit the caller's isolation by default; new spellings nonisolated(nonsending) and @concurrent.
- SE-0470 Infer Isolated Conformances, SE-0434 Global-Actor Isolated Types Usability, SE-0418 Infer Sendable from Captures, SE-0401 Disable Outward Actor Inference — all bundled under Approachable Concurrency to cut Sendable/isolation boilerplate.

## iOS 27 preview (pre-GA)
- WWDC 2026 brings Xcode 27 / Swift 6.3 into developer beta; expect continued refinement of Approachable Concurrency ergonomics and diagnostics. | Pre-GA and unverified in this pass — I did not retrieve a WWDC 2026 session confirming specific Swift 6.3 concurrency API changes. Treat as a placeholder; verify against WWDC 2026 session pages and Swift 6.3 release notes before relying on it.

## Deprecations
- ObservableObject + @Published + @StateObject/@ObservedObject → replaced by @Observable macro (Observation, iOS 17+) for view-model state.
- Combine as the primary reactive layer → async/await + AsyncSequence/AsyncStream; Combine retained only for Publisher-vending APIs.
- URLSession completion-handler methods → async methods data(for:), bytes(for:), download(for:); wrap remaining callbacks with continuations.
- Pre-SE-0461 mental model that 'nonisolated async = background' → now caller-isolated by default; use @concurrent to offload.
- GCD / DispatchQueue.global().async for app-level concurrency → structured concurrency (Task, async let, TaskGroup, actors).
- Swift 6 'minimal/targeted' strict-concurrency as a destination → complete checking / Swift 6 language mode is the target, with Approachable Concurrency easing the path.

## Uncertainties
- I did not retrieve a specific WWDC 2026 / Xcode 27 / Swift 6.3 session confirming new concurrency or networking APIs; the iOS 27 preview entry is inferred from the announced timeline, not a primary source. Verify before use.
- Exact UI label vs. underlying build-setting identifier pairing (e.g. whether the Xcode 26 UI shows 'Approachable Concurrency' as one toggle mapping to SWIFT_APPROACHABLE_CONCURRENCY) is corroborated by secondary sources (avanderlee, Donny Wals) and the WWDC25 video, but I did not open the Xcode 26 build-settings reference page directly.
- Whether @Observable fully covers all former Combine use cases (debounce/throttle/combineLatest operators) — async/await + AsyncAlgorithms covers most, but some teams still reach for Combine operators; not exhaustively verified here.
- Default bufferingPolicy of AsyncStream.makeStream (unbounded) and its memory implications were not re-confirmed against the Apple docs page in this pass.

## Sources
- WWDC25 Session 268 — Embracing Swift concurrency: https://developer.apple.com/videos/play/wwdc2025/268/
- SE-0461: Run nonisolated async functions on the caller's actor by default: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
- Approachable Concurrency in Swift 6.2: A Clear Guide — SwiftLee: https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/
- Setting default actor isolation in Xcode 26 — Donny Wals: https://www.donnywals.com/setting-default-actor-isolation-in-xcode-26/
- What is @concurrent in Swift 6.2? — Donny Wals: https://www.donnywals.com/what-is-concurrent-in-swift-6-2/
- Should you opt-in to Swift 6.2's Main Actor isolation? — Donny Wals: https://www.donnywals.com/should-you-opt-in-to-swift-6-2s-main-actor-isolation/
- Swift 6 Concurrency Migration Guide — Migration Strategy (swift.org): https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/migrationstrategy/
- URLSession with async/await — SwiftLee: https://www.avanderlee.com/concurrency/urlsession-async-await-network-requests-in-swift/
- URLSession.AsyncBytes — Apple Developer Documentation: https://developer.apple.com/documentation/foundation/urlsession/asyncbytes
- AsyncStream — Apple Developer Documentation: https://developer.apple.com/documentation/swift/asyncstream
- Convenience AsyncStream.makeStream (SE-0388) — Hacking with Swift: https://www.hackingwithswift.com/swift/5.9/convenience-asyncthrowingstream-makestream
- Understanding AsyncStream and AsyncThrowingStream — Donny Wals: https://www.donnywals.com/understanding-swift-concurrencys-asyncstream/
- Swift 6: What's New and How to Migrate — SwiftLee: https://www.avanderlee.com/concurrency/swift-6-migrating-xcode-projects-packages/
