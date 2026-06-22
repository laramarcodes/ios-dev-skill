#if DEBUG
import SwiftData

/// An in-memory SwiftData container preloaded with sample items, for Xcode
/// Previews. `#if DEBUG` keeps it out of release builds.
enum PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Item.self, configurations: config)
        for item in Item.sampleItems() {
            container.mainContext.insert(item)
        }
        return container
    }()

    /// A single sample item for previewing detail/edit screens.
    static var sampleItem: Item {
        Item.sampleItems().first!
    }
}
#endif
