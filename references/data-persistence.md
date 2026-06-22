# Data persistence: SwiftData, CloudKit, Core Data

SwiftData is the default persistence layer for new SwiftUI apps on iOS 26 — declare models with `@Model`, register a `ModelContainer` on your scene, read with `@Query`, write through a `ModelContext`. It is a Swift-native layer over Core Data's storage engine, so the two interoperate but you rarely touch Core Data directly anymore. This file covers SwiftData modeling, concurrency, migration, and both flavors of CloudKit sync.

**Contents**
- [Standard SwiftData setup](#standard-swiftdata-setup)
- [Querying with @Query](#querying-with-query)
- [Modeling: attributes, uniqueness, indexes, inheritance](#modeling-attributes-uniqueness-indexes-inheritance)
- [Background work with @ModelActor](#background-work-with-modelactor)
- [Schema migration](#schema-migration)
- [SwiftData + CloudKit automatic sync](#swiftdata--cloudkit-automatic-sync)
- [Direct CloudKit with CKSyncEngine](#direct-cloudkit-with-cksyncengine)
- [When to reach for Core Data](#when-to-reach-for-core-data)
- [UserDefaults, files, documents](#userdefaults-files-documents)
- [iOS 27 preview (pre-GA)](#ios-27-preview-pre-ga)
- [Pitfalls](#pitfalls)
- [Primary sources](#primary-sources)

## Standard SwiftData setup

The whole stack is three pieces: `@Model` classes (since iOS 17), a `.modelContainer(for:)` scene modifier that creates the on-disk store, and views that read via `@Query` and write via the `\.modelContext` environment value. Saves are autosaved by default, so you rarely call `save()` on the main context.

```swift
@Model final class Trip {                       // mark models `final`
  var name: String
  var startDate: Date
  @Relationship(deleteRule: .cascade) var stops: [Stop] = []
  init(name: String, startDate: Date) { self.name = name; self.startDate = startDate }
}

@main struct TripsApp: App {
  var body: some Scene {
    WindowGroup { ContentView() }
      .modelContainer(for: Trip.self)            // creates/opens the store
  }
}

struct ContentView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: \Trip.startDate) private var trips: [Trip]
  var body: some View {
    List(trips) { Text($0.name) }
      .toolbar { Button("Add") { context.insert(Trip(name: "New", startDate: .now)) } }
  }
}
```

`@Model` participates in Observation, so SwiftUI re-renders when a model's properties change — you observe models directly, no `@Observable` view-model wrapper needed for the data itself. See `state-observation.md` for how this composes with view state.

## Querying with @Query

`@Query` re-runs and updates the view automatically on any change to matching models. Prefer a `#Predicate` and `sort:` inside the query over filtering/sorting the array in Swift — the predicate runs in the store, not in memory.

```swift
@Query(filter: #Predicate<Trip> { $0.startDate > .now }, sort: \.startDate)
private var upcoming: [Trip]
```

For a query that depends on runtime input (a search field, a selected category), build it in `init` and pass it to the underscored query property:

```swift
struct TripList: View {
  @Query private var trips: [Trip]
  init(search: String) {
    let p = #Predicate<Trip> { search.isEmpty || $0.name.localizedStandardContains(search) }
    _trips = Query(filter: p, sort: \.startDate)
  }
  var body: some View { List(trips) { Text($0.name) } }
}
```

`@Query` runs on the main actor inside the view, so heavy predicates over large datasets can hitch the UI — add `#Index` (below) or offload the fetch to a `@ModelActor`. `@Query` is the modern replacement for `NSFetchedResultsController`.

## Modeling: attributes, uniqueness, indexes, inheritance

| API | Purpose | Since |
|---|---|---|
| `@Attribute(.unique)` | Single-property uniqueness (upsert on conflict) | iOS 17 |
| `#Unique<T>([\.a, \.b])` | Compound uniqueness, declared in the `@Model` body | iOS 17 |
| `#Index<T>([\.a], [\.a, \.b])` | Speed up predicates/sorts on those keypaths | iOS 18 |
| `@Attribute(originalName:)` | Rename a property without a destructive migration | iOS 17 |
| `@Attribute(.preserveValueOnDeletion)` | Keep tombstone values in persistent history | iOS 17 |
| `@Relationship(deleteRule:inverse:)` | Cascade/nullify rules and inverse links | iOS 17 |

```swift
@Model final class Stop {
  #Unique<Stop>([\.trip, \.order])              // no two stops share trip+order
  #Index<Stop>([\.order])
  @Attribute(originalName: "label") var name: String
  var order: Int
  var trip: Trip?
}
```

**Model inheritance (iOS 26).** `@Model` subclasses inherit stored properties:

```swift
@available(iOS 26, *)
@Model final class BusinessTrip: Trip {
  var costCenter: String = ""
}
```

A plain `@Query var trips: [Trip]` is a *polymorphic "deep" search* — it returns `Trip` plus every subclass. To get only one subclass ("shallow"), filter with a type check: `#Predicate { $0 is BusinessTrip }`. Use inheritance only for genuine *is-a* hierarchies that you query both deep and shallow; if models merely share a property, prefer a protocol, and if you only ever query leaf types, flatten the models. Every subclass must be `@available(iOS 26, *)` and listed in **both** the `.modelContainer(for:)` list **and** the `VersionedSchema.models` array, or you crash at runtime.

## Background work with @ModelActor

`PersistentModel` and `ModelContext` are **not `Sendable`** — they cannot cross an actor or thread boundary; doing so is a compile error under Swift 6. Background imports/processing go through a `@ModelActor` (since iOS 17), whose macro synthesizes a `nonisolated modelContainer`, a `modelContext`, and a serial executor over a fresh context. Pass a `PersistentIdentifier` (`model.persistentModelID`) across the boundary and re-fetch on the other side.

```swift
@ModelActor actor DataImporter {
  func importTrips(_ payloads: [TripPayload]) throws {
    for p in payloads { modelContext.insert(Trip(name: p.name, startDate: p.date)) }
    try modelContext.save()                       // background context: save explicitly
  }
  func name(for id: PersistentIdentifier) -> String? {
    self[id, as: Trip.self]?.name                 // re-fetch via subscript
  }
}

// caller — hand it the container, never a model or context:
let importer = DataImporter(modelContainer: context.container)
try await importer.importTrips(payloads)
```

See `concurrency-and-networking.md` for the broader Swift 6.2 Approachable Concurrency rules this builds on.

## Schema migration

Define each schema version as an enum conforming to `VersionedSchema`, then a `SchemaMigrationPlan` listing the schemas and the stages between them (since iOS 17). Lightweight stages handle purely additive changes (new optional property, new subclass, new index). Use `.custom(willMigrate:didMigrate:)` for anything that transforms or de-duplicates data — lightweight cannot.

```swift
enum SchemaV2: VersionedSchema {
  static var versionIdentifier = Schema.Version(2, 0, 0)
  static var models: [any PersistentModel.Type] { [Trip.self, Stop.self] }
}
enum MigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
  static var stages: [MigrationStage] { [migrateV1toV2] }
  static let migrateV1toV2 = MigrationStage.lightweight(
    fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
}

let container = try ModelContainer(
  for: Schema(versionedSchema: SchemaV2.self), migrationPlan: MigrationPlan.self)
```

Renames don't need a migration stage at all — `@Attribute(originalName:)` maps the old column to the new property name in place.

## SwiftData + CloudKit automatic sync

The cheapest path to cross-device sync: a `ModelConfiguration` with `cloudKitDatabase` set mirrors your private store into CloudKit automatically, with no conflict-resolution code on your side. It imposes a **strict model contract**, and violating it makes the schema fail to build (silent no-sync), not raise a clear error.

Contract:
- **Every property** must be optional or have a default value.
- **Every relationship** must be optional, and **inverse relationships are required**.
- **No `@Attribute(.unique)` and no `#Unique`** — CloudKit can't enforce uniqueness. De-dupe in app logic instead.

```swift
@Model final class Note {
  var title: String = ""                          // defaulted
  var body: String = ""
  @Relationship(deleteRule: .cascade, inverse: \Tag.note) var tags: [Tag]? = nil  // optional
}
let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.example.app"))
// or .automatic to use the app's primary CloudKit container from its entitlements
let container = try ModelContainer(for: Note.self, configurations: config)
```

Project setup (see `project-setup.md` for capabilities): enable **iCloud → CloudKit**, add a CloudKit container, and enable **Background Modes → Remote notifications**. Before App Store release, open the **CloudKit Console and deploy the schema from Development to Production** — your model defines the Development schema, but production sync uses the deployed one, and forgetting this is the classic "works in debug, no sync in the shipped app" bug. Whether `@Model` inheritance syncs polymorphically is unconfirmed; avoid combining inheritance with CloudKit until verified against current Apple docs.

## Direct CloudKit with CKSyncEngine

When you own your local store (custom format, or you want full control over sharing/conflicts), use `CKSyncEngine` (since iOS 17) — the modern replacement for hand-rolling `CKDatabase` fetches with server change tokens. You persist a `CKSyncEngine.State.Serialization` from the `.stateUpdate` event so sync resumes across launches.

```swift
let config = CKSyncEngine.Configuration(
  database: CKContainer(identifier: id).privateCloudDatabase,
  stateSerialization: loadSavedState(),           // nil on first launch
  delegate: self)
let engine = CKSyncEngine(config)
// delegate handles: .stateUpdate (persist the new serialization),
// .fetchedRecordZoneChanges (apply remote), and supplies nextRecordZoneChangeBatch(...)
```

Apple's `sample-cloudkit-sync-engine` is the reference implementation. CloudKit's own schema-deploy-to-Production rule applies here too.

## When to reach for Core Data

SwiftData is the default; use Core Data (`NSPersistentContainer` / `NSPersistentCloudKitContainer`) only for what SwiftData still lacks: abstract entities, derived/ordered attributes, very complex `NSPredicate`/`NSExpression`, and sophisticated CloudKit *sharing* (`UICloudSharingController`). The two share a storage engine and can be mirrored onto the same store, so you can adopt SwiftData incrementally in a Core Data app. For greenfield work, don't hand-roll an `NSManagedObject` + `.xcdatamodeld` stack — use `@Model`.

## UserDefaults, files, documents

| Need | Use |
|---|---|
| A few small settings/flags | `@AppStorage("key")` (wraps UserDefaults), `@SceneStorage` for per-scene UI state |
| App-private structured data | SwiftData (above) |
| User-facing documents | `DocumentGroup` scene + `FileDocument` / `ReferenceFileDocument`, `Transferable` for share/drag |
| Large blobs / caches | Files in the app container; never store big binaries as model attributes |

`@AppStorage` is for lightweight key-value state only — don't push a data model through it. `Transferable` (since iOS 16) is the modern conformance for drag-drop, share sheets, and paste.

## iOS 27 preview (pre-GA)

These shipped in the WWDC 2026 developer beta and are **pre-GA** (final fall 2026). Gate with `@available` and verify signatures against final docs before shipping — names below are from session notes and may change.

- **Sectioned queries.** `@Query(sort:, sectionBy: \.keyPath)` groups results; read `.sections` on the underscored property, each section exposing `id` and a model collection. Replaces hand-rolled `Dictionary(grouping:)`.
  ```swift
  @available(iOS 27, *)
  @Query(sort: \Trip.startDate, sectionBy: \.destination) private var trips: [Trip]
  // body: ForEach(_trips.sections) { section in Section(section.id) { ForEach(section) { … } } }
  ```
- **`@Attribute(.codable)`.** Persists a `Codable` type SwiftData can't model natively (e.g. a third-party struct). Contents are **opaque** — not usable in predicates or sort descriptors, and changing the encoded shape does **not** trigger a migration. For external types only.
- **`ResultsObserver<Model, Section>` / `HistoryObserver`.** Observe fetch results or persistent history *outside* SwiftUI, paired with `withContinuousObservation(options:)`; `HistoryObserver(authors:modelContainer:)` exposes an `eventCounter`. The non-view equivalent of `@Query` / `NSFetchedResultsController`.
- **Native enum & composite predicates** in `#Predicate`, removing the old workaround of persisting an enum's raw value in a separate property just to filter on it.

iOS 26 (shipping) additions, for contrast: `@Model` class inheritance, persistent history fetchable with a `sortBy`, and refined `#Index`/`#Unique` ergonomics.

## Pitfalls

- **Non-Sendable models.** `PersistentModel`/`ModelContext` can't cross actor or thread boundaries (compile error). Move a `PersistentIdentifier` and re-fetch via a `@ModelActor`.
- **A `ModelContext` doesn't retain its `ModelContainer`.** Create a container in a function and return only `container.mainContext`, and the container can deallocate — the context then crashes on the next fetch/insert. Keep the container alive (store or return it) for as long as you use its contexts. Bites in test factories and helpers especially.
- **Naming a `@Model` with a collision-prone word.** Generic type names like `Category` (also `Task`, `Group`) compile until some file does `import Foundation`/`import SwiftUI`, after which the name is *ambiguous for type lookup*. Prefer a domain-qualified name (`ItemCategory`).
- **CloudKit silently won't sync** if any property is non-optional-without-default, any relationship is non-optional or missing its inverse, or you use `#Unique`/`@Attribute(.unique)`. There's often no error — just no sync.
- **`@Attribute(.unique)` is incompatible with CloudKit.** De-dupe in app logic or a custom merge instead of relying on the store.
- **Inheritance bookkeeping (iOS 26).** Every `@Model` subclass must appear in *both* the `.modelContainer(for:)` list and the `VersionedSchema.models` array, or you crash at runtime. A plain `@Query` of the parent fetches all subclasses — filter with `$0 is Subclass` if you wanted shallow.
- **Lightweight migration can't transform data.** New optional props and new subclasses are fine; renames go through `@Attribute(originalName:)`; de-dup or reshape needs `MigrationStage.custom`.
- **`@Attribute(.codable)` contents are opaque (iOS 27 pre-GA)** — no predicate, no sort, no migration trigger. Use only for external types.
- **`@Query` runs on the main actor.** Heavy predicates over large datasets hitch the UI — add `#Index` or fetch on a `@ModelActor`.
- **Forgetting to deploy the CloudKit schema to Production** before release means the shipped app syncs against an empty/old production schema. Deploy from the CloudKit Console first.
- **Don't store large binaries as model attributes** — keep blobs as files in the app container and reference them by path/URL.
- **Deprecated patterns to avoid:** `ObservableObject`/`@Published` → `@Observable` (and observe `@Model` directly); manual `NSManagedObject`/`.xcdatamodeld` → `@Model`; manual `CKDatabase` + change tokens → `CKSyncEngine`; `NSFetchedResultsController` → `@Query` (or `ResultsObserver`, iOS 27 pre-GA).

## Primary sources

- SwiftData framework reference — https://developer.apple.com/documentation/swiftdata
- WWDC25 291, SwiftData inheritance & schema migration — https://developer.apple.com/videos/play/wwdc2025/291/
- WWDC26 274, What's new in SwiftData — https://developer.apple.com/videos/play/wwdc2026/274/
- WWDC24 10138, Create a custom data store with SwiftData — https://developer.apple.com/videos/play/wwdc2024/10138/
- CKSyncEngine reference — https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5
- Apple sample: sample-cloudkit-sync-engine — https://github.com/apple/sample-cloudkit-sync-engine
- SwiftData CloudKit model rules (Fatbobman) — https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/
