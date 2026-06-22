# DOMAIN: Data persistence on iOS (SwiftData, CloudKit, Core Data) — SwiftUI apps for iPhone & iPad

## Orientation
 SwiftData is the default persistence layer for new SwiftUI apps on iOS 26: declare models with the @Model macro, register a ModelContainer via the .modelContainer(for:) scene modifier, read with @Query in views, and write through a @Environment(\.modelContext) ModelContext. It is a Swift-native layer built on top of Core Data's storage engine, so the two interoperate but you rarely touch Core Data directly anymore. Reach for Core Data only for advanced features SwiftData still lacks (fine-grained fetched-results sectioning historically, abstract entities, derived/ordered attributes, complex NSPredicate, sophisticated CloudKit sharing). CloudKit sync comes in two flavors: automatic mirroring (SwiftData with a .cloudKit ModelConfiguration, or NSPersistentCloudKitContainer for Core Data) which imposes a strict model contract, or hands-on CKSyncEngine (iOS 17+) when you own your local store and want full control. iOS 26 (shipping) added @Model class inheritance, sortable persistent history, and refined indexing; iOS 27 (announced WWDC 2026, developer beta, pre-GA) adds sectioned @Query, enum/composite predicates, an @Attribute(.codable) escape hatch, and the ResultsObserver/HistoryObserver observation types for use outside SwiftUI. Concurrency is compiler-enforced: PersistentModel and ModelContext are non-Sendable, so background work goes through a @ModelActor.

## Key facts
- [since iOS 17|high] SwiftData models are declared with the @Model macro; the container is created with .modelContainer(for: [Type.self]) as a Scene/View modifier, views read via @Query and write via @Environment(\.modelContext).
- [iOS 26|high] iOS 26 adds @Model class inheritance: a subclass like `@Model class BusinessTrip: Trip` inherits parent properties. All subclasses must be annotated @available(iOS 26, *) and every subclass must be listed in the ModelContainer's model list and in the VersionedSchema's models array.
- [iOS 26|high] With inheritance, a plain `@Query var trips: [Trip]` is a polymorphic 'deep' search returning Trip plus all subclasses; filter to a single subclass ('shallow') with a type-check predicate: #Predicate { $0 is BusinessTrip }.
- [iOS 26|high] Use inheritance only for genuine is-a hierarchies queried both deep and shallow; if models share a single property prefer protocol conformance, and if you only ever query leaf types, flatten the models instead.
- [iOS 26|medium] iOS 26 lets you fetch persistent history with a sortBy, optimizing history fetches via FetchHistoryDescriptor/ModelContext history APIs.
- [since iOS 18 (#Index), #Unique since iOS 17|high] Compound uniqueness and indexes use the macros #Unique<T>([\.a, \.b]) and #Index<T>([\.a], [\.b], [\.a, \.b]) declared inside the @Model body; single-property uniqueness uses @Attribute(.unique).
- [since iOS 17|high] Schema migration: define each schema as an enum conforming to VersionedSchema (with versionIdentifier: Schema.Version and a models array), then a SchemaMigrationPlan enum listing schemas and stages. Stages are MigrationStage.lightweight(fromVersion:toVersion:) or MigrationStage.custom(fromVersion:toVersion:willMigrate:didMigrate:).
- [since iOS 17 (.preserveValueOnDeletion iOS 17)|high] @Attribute(originalName:) renames a property without a destructive migration; @Attribute(.preserveValueOnDeletion) keeps tombstone values available in persistent history.
- [since iOS 17|high] Background SwiftData work uses a @ModelActor; the macro synthesizes a nonisolated modelContainer and a modelExecutor backed by DefaultSerialModelExecutor over a fresh ModelContext. PersistentModel and ModelContext are NOT Sendable and cannot cross actor boundaries — pass PersistentIdentifier (model.persistentModelID) instead and re-fetch.
- [iOS 18|high] Custom data stores (iOS 18) let SwiftData persist to any backend by conforming to three protocols: DataStoreConfiguration, DataStoreSnapshot, and DataStore.
- [since iOS 17|high] SwiftData+CloudKit automatic sync requires every property be optional or have a default value, every relationship be optional, and forbids @Attribute(.unique)/#Unique. Enable the iCloud + CloudKit capability, add a CloudKit container, add Background Modes > Remote notifications, and use a ModelConfiguration with cloudKitDatabase set.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA) adds sectioned queries: @Query(sort:, sectionBy: \.keyPath) groups results; access the underscored property's `.sections`, each section exposing `id` and a collection of models.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA) adds @Attribute(.codable) to persist Codable types SwiftData can't model natively (e.g. third-party types); contents are opaque so they can't be used in predicates or sort descriptors and don't trigger migration.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA) adds ResultsObserver<Model, Section> and HistoryObserver to observe fetch results / persistent history outside SwiftUI, paired with withContinuousObservation(options:) to react to changes; HistoryObserver(authors:modelContainer:) exposes an eventCounter.
- [iOS 27 (pre-GA)|medium] iOS 27 (pre-GA) adds native enum predicates and composite predicates in #Predicate, removing the prior workaround of persisting an enum's raw value separately to filter on it.
- [since iOS 17|high] CKSyncEngine (iOS 17+) is the modern direct-CloudKit path: you own local storage and persist a CKSyncEngine.State.Serialization, passing it plus a CKContainer database into CKSyncEngine.Configuration. It replaces hand-rolling CKDatabase change tokens.
- [since iOS 14 / iOS 16 (Transferable)|high] @AppStorage / @SceneStorage wrap UserDefaults for small key-value state; for documents use the DocumentGroup scene with FileDocument (or ReferenceFileDocument) and Transferable for drag/drop/share.

## Patterns

### Standard SwiftData app setup  — Any new local-first SwiftUI app.
Mark @Model classes final. @Query auto-updates the view on changes. context.insert/delete; saves are autosaved by default. Use a #Predicate or sort in @Query rather than filtering in Swift.
```swift
@Model final class Trip {
  var name: String
  var startDate: Date
  @Relationship(deleteRule: .cascade) var stops: [Stop] = []
  init(name: String, startDate: Date) { self.name = name; self.startDate = startDate }
}

@main struct TripsApp: App {
  var body: some Scene {
    WindowGroup { ContentView() }
      .modelContainer(for: Trip.self)
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

### Background writes with @ModelActor  — Importing/processing data off the main thread.
Never pass a model or ModelContext across the actor boundary — pass PersistentIdentifier and re-fetch (subscript self[id, as:]). The @ModelActor macro provides modelContainer, modelContext, and the executor.
```swift
@ModelActor actor DataImporter {
  func importTrips(_ payloads: [TripPayload]) throws {
    for p in payloads { modelContext.insert(Trip(name: p.name, startDate: p.date)) }
    try modelContext.save()
  }
  func name(for id: PersistentIdentifier) -> String? {
    self[id, as: Trip.self]?.name
  }
}
// caller:
let importer = DataImporter(modelContainer: context.container)
try await importer.importTrips(payloads)
```

### Versioned schema + migration plan  — Shipping a model change to existing users.
Lightweight handles additive changes (new optional props, new subclasses). Use .custom(willMigrate:didMigrate:) to dedupe or transform data. Use @Attribute(originalName:) to rename without data loss.
```swift
enum SchemaV2: VersionedSchema {
  static var versionIdentifier = Schema.Version(2, 0, 0)
  static var models: [any PersistentModel.Type] { [Trip.self] }
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

### SwiftData + CloudKit automatic sync  — Free cross-device sync, you don't need custom conflict handling.
Add iCloud(CloudKit) + Background Modes(Remote notifications) capabilities. Every property optional/defaulted, every relationship optional, NO #Unique/@Attribute(.unique), NO @Attribute(.allowsCloudEncryption conflicts), and inverse relationships are required. Test schema deploys to Production in the CloudKit console before App Store release.
```swift
// Model rule: optional or defaulted, no .unique
@Model final class Note {
  var title: String = ""
  var body: String = ""
  @Relationship(deleteRule: .cascade) var tags: [Tag]? = nil
}
let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.example.app"))
let container = try ModelContainer(for: Note.self, configurations: config)
```

### Direct CloudKit with CKSyncEngine  — You own the local store (e.g. custom format) and want full sync control / sharing.
Persist CKSyncEngine.State.Serialization from the stateUpdate event so sync resumes across launches. iOS 17+. This is the recommended replacement for manual CKDatabase + change tokens.
```swift
let config = CKSyncEngine.Configuration(
  database: CKContainer(identifier: id).privateCloudDatabase,
  stateSerialization: loadSavedState(),
  delegate: self)
let engine = CKSyncEngine(config)
// delegate handles .stateUpdate (persist serialization),
// .fetchedRecordZoneChanges, and nextRecordZoneChangeBatch(...)
```

### iOS 27 sectioned query (pre-GA)  — Grouping a list (e.g. by category) without manual bucketing.
iOS 27 only — gate with @available. Access sections through the underscored query property. Replaces hand-rolled Dictionary(grouping:).
```swift
@Query(sort: \Trip.startDate, sectionBy: \.destination) private var trips: [Trip]
var body: some View {
  List { ForEach(_trips.sections) { section in
    Section(section.id) { ForEach(section) { Text($0.name) } }
  } }
}
```

## Pitfalls
- SwiftData models and ModelContext are not Sendable; passing them between threads/actors is a compile error. Move PersistentIdentifier across boundaries and re-fetch.
- CloudKit automatic sync silently fails (or refuses to build the schema) if any property is non-optional without a default, any relationship is non-optional, or you use #Unique / @Attribute(.unique). Inverse relationships are also required.
- @Attribute(.unique) is incompatible with CloudKit — design around it (de-dupe in app logic or a custom merge) instead.
- Forgetting to add every @Model subclass to BOTH the .modelContainer(for:) list and the VersionedSchema.models array causes runtime crashes once inheritance is used (iOS 26).
- @Attribute(.codable) contents (iOS 27) are opaque: you cannot filter on them in #Predicate or sort by them, and changing the encoded type's shape does NOT trigger a migration — only use it for external/third-party types.
- Lightweight migration cannot do data transformation or de-duplication; attempting a non-additive change there fails — use MigrationStage.custom.
- Background insert via @ModelActor regressed in early iOS 18 betas; verify on current shipping iOS 26 and avoid relying on beta-only behavior.
- @Query lives in the view and re-runs on the main actor — heavy predicates/large datasets can hitch the UI; offload to a ModelActor + manual fetch, or rely on indexing via #Index.
- Mark @Model classes `final`; non-final non-inheriting models can cause unexpected behavior, and only opt into inheritance deliberately (iOS 26) because polymorphic queries fetch all subclasses.
- Always deploy the CloudKit schema from Development to Production in the CloudKit Console before shipping; the local model defines Development schema but production sync uses the deployed one.

## iOS 26 changes
- @Model class inheritance: subclasses inherit stored properties; polymorphic deep queries return all subclasses, shallow queries filter via `$0 is Subclass` in #Predicate. Requires @available(iOS 26, *) and listing all subclasses in container + VersionedSchema.
- Persistent history can be fetched with a sortBy, optimizing history queries.
- Refined indexing/uniqueness macros (#Index, #Unique) and migration ergonomics demonstrated for inheritance-aware schemas.

## iOS 27 preview (pre-GA)
- Sectioned queries via @Query(sectionBy: \.keyPath); access `.sections` on the underscored property, each section has `id` + model collection. | Developer beta, pre-GA; exact section API surface may change.
- @Attribute(.codable) to persist Codable types SwiftData can't model natively; contents opaque (no predicate/sort, no migration trigger). | Pre-GA escape hatch intended for external types only.
- ResultsObserver<Model, Section> and HistoryObserver(authors:modelContainer:) to observe fetches / persistent history outside SwiftUI, used with withContinuousObservation(options:); HistoryObserver exposes eventCounter. | Pre-GA; initializer/property names from session notes, verify against final docs.
- Native enum predicates and composite predicates in #Predicate. | Pre-GA; corroborated by secondary sources, trace to final Apple docs before shipping.

## Deprecations
- ObservableObject + @Published → @Observable macro (iOS 17+) for view models; SwiftData @Model already participates in Observation, so observe models directly.
- NSPersistentContainer / Core Data stack hand-rolling → ModelContainer/ModelContext (SwiftData) for new apps.
- Manual NSManagedObject subclasses and .xcdatamodeld for greenfield work → @Model Swift classes (SwiftData generates the schema).
- Manual CKDatabase fetch with server change tokens → CKSyncEngine (iOS 17+).
- Persisting enum raw values in a separate property to query them → native enum predicates in #Predicate (iOS 27, pre-GA).
- Hand-rolled Dictionary(grouping:) for list sections → @Query(sectionBy:) (iOS 27, pre-GA).
- NSFetchedResultsController → @Query (in views) or ResultsObserver (outside views, iOS 27 pre-GA).

## Uncertainties
- Exact API surface of iOS 27 ResultsObserver/HistoryObserver (generic parameters, full initializer signatures, whether withContinuousObservation is the final spelling) is from a JS-rendered WWDC26 session summary plus secondary blogs — verify against final developer.apple.com/documentation before copying into a skill.
- Whether iOS 27 composite predicates introduce new macro/operator syntax beyond existing #Predicate compound expressions is unconfirmed at the signature level.
- Precise iOS 26 history API type names (e.g. FetchHistoryDescriptor sortBy property) were not confirmed against primary docs in this pass.
- developer.apple.com/documentation/updates/swiftdata did not render its version table via WebFetch; the per-version change list there should be cross-checked.
- CloudKit + SwiftData support for @Model inheritance (whether polymorphic models sync correctly) was not confirmed and may be unsupported.

## Sources
- Apple — SwiftData framework reference: https://developer.apple.com/documentation/swiftdata
- WWDC25 291 — SwiftData: Dive into inheritance and schema migration: https://developer.apple.com/videos/play/wwdc2025/291/
- WWDC26 274 — What's new in SwiftData: https://developer.apple.com/videos/play/wwdc2026/274/
- Apple — CKSyncEngine reference: https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5
- Apple — CKSyncEngine.State.Serialization: https://developer.apple.com/documentation/cloudkit/cksyncengine/state/serialization
- Apple — sample-cloudkit-sync-engine: https://github.com/apple/sample-cloudkit-sync-engine
- WWDC24 10138 — Create a custom data store with SwiftData: https://developer.apple.com/videos/play/wwdc2024/10138/
- Hacking with Swift — How to sync SwiftData with iCloud: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud
- Fatbobman — Designing Models for CloudKit Sync (Core Data & SwiftData rules): https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/
- BrightDigit — Using ModelActor in SwiftData: https://brightdigit.com/tutorials/swiftdata-modelactor/
- arshtechpro (DEV) — WWDC25 SwiftData iOS 26 inheritance & migration: https://dev.to/arshtechpro/wwdc-2025-swiftdata-ios-26-class-inheritance-migration-issues-30bh
- What's New in SwiftData for iOS 27 (swiftuisnippets): https://swiftuisnippets.wordpress.com/2026/06/16/whats-new-in-swiftdata-for-ios-27/
- SwiftData in iOS 27: Observation and History (Blake Crosley): https://blakecrosley.com/blog/swiftdata-ios-27-observation-history
- Use Your Loaf — SwiftData Background Tasks: https://useyourloaf.com/blog/swiftdata-background-tasks/
- Michael Tsai — SwiftData and Core Data at WWDC25: https://mjtsai.com/blog/2025/06/19/swiftdata-and-core-data-at-wwdc25/
