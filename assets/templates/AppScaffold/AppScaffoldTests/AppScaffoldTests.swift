import Testing
import Foundation   // for the #Predicate macro
import SwiftData
@testable import AppScaffold

/// Unit tests written with **Swift Testing** (the `@Test` / `#expect` framework,
/// GA since Xcode 16 and the default for new test targets). The suite is
/// `@MainActor` because SwiftData's `ModelContext` and `@Model` objects are
/// main-actor isolated under this project's default-actor-isolation setting.
@MainActor
struct AppScaffoldTests {

    /// A fresh, empty, in-memory store per test — fast and fully isolated.
    /// Return the *container* (not just its context): the context doesn't keep
    /// the container alive, so handing back only `mainContext` would let the
    /// container deallocate mid-test and crash. Each test holds the container.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Item.self, configurations: config)
    }

    @Test("A new item is not a favorite and defaults to Personal")
    func newItemDefaults() {
        let item = Item(title: "Test")
        #expect(item.isFavorite == false)
        #expect(item.category == .personal)
        #expect(item.categoryID == ItemCategory.personal.rawValue)
    }

    @Test("The category accessor round-trips through the stored raw value",
          arguments: ItemCategory.allCases)
    func categoryRoundTrips(_ category: ItemCategory) {
        let item = Item(title: "X", category: category)
        #expect(item.category == category)
        #expect(item.categoryID == category.rawValue)

        item.category = .work
        #expect(item.categoryID == ItemCategory.work.rawValue)
    }

    @Test("A favorites predicate matches only favorited items")
    func favoritesPredicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Item(title: "Kept", isFavorite: true))
        context.insert(Item(title: "Skipped", isFavorite: false))

        let favorites = try context.fetch(
            FetchDescriptor<Item>(predicate: #Predicate { $0.isFavorite })
        )
        #expect(favorites.count == 1)
        #expect(favorites.first?.title == "Kept")
    }

    @Test("Seeding inserts sample items once and is idempotent")
    func seedingIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        Item.seedIfNeeded(in: context)
        let afterFirst = try context.fetchCount(FetchDescriptor<Item>())
        #expect(afterFirst == Item.sampleItems().count)

        // Running again must not duplicate the seed data.
        Item.seedIfNeeded(in: context)
        let afterSecond = try context.fetchCount(FetchDescriptor<Item>())
        #expect(afterSecond == afterFirst)
    }
}
