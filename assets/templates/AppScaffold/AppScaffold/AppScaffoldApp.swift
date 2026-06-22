import SwiftUI
import SwiftData

@main
struct AppScaffoldApp: App {
    /// The SwiftData container. Created once and shared with the whole scene via
    /// `.modelContainer(_:)`, which also injects a `ModelContext` into the
    /// environment for every view to read with `@Environment(\.modelContext)`.
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Item.self)
        } catch {
            // A failure here means the on-disk store is unreadable/incompatible.
            // Crashing loudly in development is correct; a shipping app would
            // surface a recovery path instead.
            fatalError("Could not create ModelContainer: \(error)")
        }
        Item.seedIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
