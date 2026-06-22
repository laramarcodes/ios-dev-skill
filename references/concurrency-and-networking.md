# Swift 6 concurrency & networking

How concurrency works in a modern iOS 26 app: main-actor-by-default code, explicit opt-in to background work, actors for shared state, and URLSession's async APIs feeding Codable. The big mental shift since "raw" Swift 6 is **Approachable Concurrency** — most of your code is implicitly `@MainActor`, and you offload deliberately rather than fighting `Sendable` everywhere.

**Contents**
- [The two build settings that change everything](#the-two-build-settings-that-change-everything)
- [The main-actor-by-default mental model](#the-main-actor-by-default-mental-model)
- [nonisolated vs nonisolated(nonsending) vs @concurrent (SE-0461)](#nonisolated-vs-nonisolatednonsending-vs-concurrent-se-0461)
- [Actors for shared mutable state](#actors-for-shared-mutable-state)
- [Structured concurrency: async let, TaskGroup, Task](#structured-concurrency-async-let-taskgroup-task)
- [Cancellation](#cancellation)
- [Bridging callbacks: continuations & AsyncStream](#bridging-callbacks-continuations--asyncstream)
- [Networking with URLSession](#networking-with-urlsession)
- [Strict concurrency levels](#strict-concurrency-levels)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## The two build settings that change everything

A new app target in **Xcode 26** (these settings shipped in Swift 6.2, Sept 2025, and persist in the current Swift 6.3.2 toolchain) turns two settings on by default. They are why modern iOS code "just works" without `Sendable` ceremony.

| Build setting | Default (new app target) | What it does |
|---|---|---|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | Compiler implicitly writes `@MainActor` on every type/function in the module that has no explicit isolation. (Existing projects default to `nonisolated`.) |
| `SWIFT_APPROACHABLE_CONCURRENCY` | ON | Umbrella flag turning on SE-0401, SE-0434, SE-0470, SE-0418, SE-0461 — together these cut almost all `Sendable`/isolation boilerplate. Apple recommends enabling it for **all** projects. |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | Data-race safety is a compile **error**, not a warning (Swift 6 language mode). |

Current shipping compiler is **Swift 6.3.2** in **Xcode 26.5 (GA, May 11 2026)** — you still build under the **Swift 6 language mode**; these settings and that language mode are unchanged since Swift 6.2 (Sept 2025). See `project-setup.md` for where these live in the project file. Xcode 27 / Swift 6.4 (WWDC 2026, **pre-GA developer beta**, ships fall 2026) is expected to refine diagnostics but has no confirmed concurrency API changes — do not rely on it for shipping apps.

## The main-actor-by-default mental model

With `MainActor` default isolation, **single-threaded UI code needs zero annotations**. Your views, `@Observable` view models, and most app logic are implicitly on the main actor — passing non-`Sendable` values between them is fine because nothing crosses an isolation boundary.

You opt **into** concurrency in exactly two situations:

- **Expensive work** (JSON decoding a large payload, image processing) → mark just that function `@concurrent` to run it on a background thread.
- **Shared mutable state that isn't UI** (a cache, an in-memory store) → put it in an `actor`.

The idiom is progressive disclosure: stay on main until you have a concrete reason not to, then offload the *narrowest* piece. Don't offload whole pipelines.

```swift
@Observable
final class FeedModel {            // implicitly @MainActor — no annotation needed
    var posts: [Post] = []
    var isLoading = false

    func load() async throws {
        isLoading = true
        defer { isLoading = false }
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        posts = try await decode(data)   // hops back to main automatically after await
    }

    @concurrent                    // runs OFF the main actor
    private func decode(_ data: Data) async throws -> [Post] {
        try JSONDecoder().decode([Post].self, from: data)
    }
}
```

`Post` must be `Sendable` so it can cross back from the `@concurrent` function — a `struct` of `Sendable` fields gets this automatically (SE-0418 infers it).

## nonisolated vs nonisolated(nonsending) vs @concurrent (SE-0461)

This is the single most important change to *understand*, because the old mental model is now wrong. **SE-0461** (Swift 6.2) changed what a plain `nonisolated async` function does.

| Spelling | Where async body runs | Args/results must be Sendable? | Use for |
|---|---|---|---|
| plain `nonisolated async` (with Approachable Concurrency) | the **caller's** executor/actor | no | general code that should run wherever called |
| `nonisolated(nonsending)` | caller's executor (explicit spelling of the above) | no | making caller-isolation intent explicit |
| `@concurrent` | the **global concurrent executor** (a background thread) — always switches off the current actor | **yes** | actually offloading expensive work |

Pre-SE-0461, a `nonisolated async` function hopped to the background. **Now it inherits the caller's isolation by default.** So if you write `nonisolated func decode(...) async` expecting it to run off-main, it won't — it runs wherever it was called. To genuinely offload, you must use `@concurrent`. A `@concurrent` function is implicitly `nonisolated`; because it changes isolation domains, every argument and the return type must be `Sendable`.

```swift
// Runs on the caller's actor — does NOT offload. Fine for cheap, isolation-agnostic work.
nonisolated func format(_ p: Post) async -> String { ... }

// Always runs off-main. All inputs/outputs must be Sendable.
@concurrent func resize(_ image: CGImage) async -> CGImage { ... }
```

## Actors for shared mutable state

An `actor` serializes access to its mutable state — only one task touches the data at a time — and is implicitly `Sendable`, so you can freely share an actor reference across isolation boundaries. Use an actor (not `@MainActor`) for non-UI shared state like a cache, so its access serializes **off** the main thread.

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

Reaching into an actor's state is `await`ed from outside (it may have to wait its turn). See `state-observation.md` for `@MainActor @Observable` view-model state, which is the UI counterpart to this.

## Structured concurrency: async let, TaskGroup, Task

**Structured** concurrency means child tasks are scoped — they're awaited before the enclosing scope returns and cancel together. Prefer it.

- `async let` — a **fixed** number of concurrent children, awaited at the use site.
- `withTaskGroup(of:)` / `withThrowingTaskGroup(of:)` — a **dynamic** number of children.

```swift
// fixed fan-out
async let user = api.user(id)
async let posts = api.posts(for: id)
let profile = try await Profile(user: user, posts: posts)   // both run concurrently

// dynamic fan-out
let posts = try await withThrowingTaskGroup(of: Post.self) { group in
    for id in ids { group.addTask { try await api.post(id) } }
    var result: [Post] = []
    for try await p in group { result.append(p) }
    return result
}
```

**Unstructured** tasks escape the current scope:

- `Task { }` — inherits the creating context's **actor isolation and task-locals**. This is what you use to kick off async work from a synchronous context (e.g. a SwiftUI button action), though prefer the `.task` view modifier which ties lifetime to the view (see `swiftui-views.md`).
- `Task.detached` — inherits **nothing**: no isolation, no task-locals, no structured cancellation. Almost always the wrong tool. Don't use it just to "get off the main thread" — use `@concurrent` or an actor instead.

`@TaskLocal` values propagate to child tasks via `$value.withValue { }` — useful for request IDs / logging context.

## Cancellation

Swift concurrency cancellation is **cooperative**: cancelling a task only sets a flag — the task must check it. `async let`/TaskGroup children cancel automatically when the scope unwinds or throws.

- `Task.isCancelled` — a Bool you can branch on.
- `try Task.checkCancellation()` — throws `CancellationError` if cancelled.
- `try await Task.sleep(for:)` — throws on cancellation, so sleeps are cancellation points for free.

```swift
func withRetry<T: Sendable>(
    _ attempts: Int = 3,
    _ op: () async throws -> T
) async throws -> T {
    for attempt in 1...attempts {
        do { return try await op() }
        catch {
            try Task.checkCancellation()           // bail immediately if cancelled
            if attempt == attempts { throw error }
            try await Task.sleep(for: .seconds(pow(2, Double(attempt - 1))))  // backoff
        }
    }
    fatalError("unreachable")
}
```

`op` is called on the caller's isolation, so it can use non-`Sendable` captures.

## Bridging callbacks: continuations & AsyncStream

**Single-shot callback → async:** wrap with `withCheckedContinuation` / `withCheckedThrowingContinuation` (iOS 15+). Resume **exactly once** on every path — resuming twice traps at runtime, never resuming hangs the awaiting task forever. The "checked" variants catch misuse in development.

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

**Stream of callbacks → AsyncSequence:** use `AsyncStream.makeStream(of:bufferingPolicy:)` (SE-0388, iOS 17+ / Swift 5.9) which returns the stream and its continuation as a pair — no nested-closure capture dance. Critically, **cancelling the consumer does not cancel the producer**; wire producer cleanup in `continuation.onTermination`.

```swift
let (stream, continuation) = AsyncStream<Double>.makeStream()
continuation.onTermination = { _ in downloadTask.cancel() }   // or you leak the task
// in the delegate: continuation.yield(progress); continuation.finish() on completion
for await progress in stream { updateBar(progress) }
```

## Networking with URLSession

URLSession's `async` methods are the default. All accept an optional task-specific delegate.

| API (iOS 15+) | Returns | Use for |
|---|---|---|
| `data(for:)` / `data(from:)` | `(Data, URLResponse)` | normal request — full body buffered |
| `bytes(for:)` / `bytes(from:)` | `(URLSession.AsyncBytes, URLResponse)` | streaming/incremental; `.lines` for line-delimited text (SSE, NDJSON) |
| `download(for:)` | `(URL, URLResponse)` | downloading to a file |
| `URLSessionConfiguration.background(withIdentifier:)` | — | out-of-process transfers; results arrive via **delegate**, not an async return |

```swift
struct UserClient {                       // make services Sendable or isolated under Swift 6
    let session = URLSession.shared

    func user(id: String) async throws -> User {
        let (data, response) = try await session.data(from: usersURL.appending(path: id))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(User.self, from: data)   // User: Codable & Sendable
    }
}
```

Streaming line-by-line:

```swift
let (bytes, _) = try await session.bytes(from: eventsURL)
for try await line in bytes.lines { handle(line) }
```

Under Swift 6 strict concurrency, a service class must be `Sendable` or isolated — simplest is a `struct`, an `actor`, or `@MainActor`. Decoded `Codable` models are usually `Sendable` automatically (value types). Background sessions (`URLSessionConfiguration.background`) deliver via delegate after the app may be suspended — do **not** call `data(for:)` on them and expect the async return.

**Combine is legacy.** Use `@Observable` + `async/await` + `AsyncStream` for new data flows. Combine only surfaces where a framework still vends a `Publisher` (`NotificationCenter.publisher`, `Timer.publish`). See `state-observation.md`.

## Strict concurrency levels

`SWIFT_STRICT_CONCURRENCY` has three levels: `minimal`, `targeted`, `complete`. **`complete` is the destination** (Swift 6 language mode) — not a stopping point at `minimal`/`targeted`. Recommended migration for an existing project: stay on the Swift 5 language mode with `complete` checking emitting **warnings**, move global mutable state into actors / `@MainActor`, then flip to the Swift 6 language mode. Enable Approachable Concurrency's upcoming-feature flags **feature-by-feature** on a large existing codebase rather than all at once.

## Pitfalls

- **Assuming a plain `nonisolated async func` runs in the background.** Since SE-0461 it runs on the **caller's** executor. To actually offload, use `@concurrent`.
- **Reaching for `Task.detached` to "get off the main thread."** It drops actor isolation *and* task-locals and breaks structured cancellation. Use `@concurrent` or an actor.
- **Forgetting `continuation.onTermination` on an `AsyncStream`.** Cancelling the consumer doesn't cancel the producer — you leak the underlying network/download task.
- **Resuming a continuation zero or multiple times.** Two resumes trap; zero resumes hangs the task forever. Use the `withChecked*` variants in development.
- **Slapping `@MainActor` on everything to silence Swift 6 errors.** This serializes genuinely parallel work onto the main thread and tanks responsiveness. Isolate UI state to main; move shared non-UI state into actors.
- **`@unchecked Sendable` to dodge errors** without real synchronization — reintroduces the exact data races the compiler was preventing.
- **Expecting a `@concurrent` function to accept non-`Sendable` arguments.** It changes isolation domains, so all args and the return type must be `Sendable`.
- **Enabling all Approachable Concurrency flags at once on a large project** — migrate feature-by-feature with the migration tooling to avoid surprise isolation changes.
- **Treating Combine as the default** for new async data flows. It's now legacy; reach for `@Observable` + `async/await`/`AsyncStream`.
- **Calling `data(for:)` on a background `URLSessionConfiguration`** and expecting the async return — background sessions deliver via delegate after suspension.
- **Using `DispatchQueue.global().async` for app-level concurrency.** Replaced by structured concurrency (`Task`, `async let`, TaskGroup, actors).

## Primary sources

- WWDC25 Session 268 — Embracing Swift concurrency: https://developer.apple.com/videos/play/wwdc2025/268/
- SE-0461 — Run nonisolated async functions on the caller's actor by default: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
- Approachable Concurrency in Swift 6.2 (SwiftLee): https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/
- What is @concurrent in Swift 6.2? (Donny Wals): https://www.donnywals.com/what-is-concurrent-in-swift-6-2/
- Swift 6 Concurrency Migration Guide — strategy (swift.org): https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/migrationstrategy/
- URLSession.AsyncBytes (Apple): https://developer.apple.com/documentation/foundation/urlsession/asyncbytes
- AsyncStream (Apple): https://developer.apple.com/documentation/swift/asyncstream
