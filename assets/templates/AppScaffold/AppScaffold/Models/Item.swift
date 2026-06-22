import Foundation
import SwiftData

/// The app's one persisted model.
///
/// `@Model` (SwiftData) makes this class persistable *and* observable — SwiftUI
/// re-renders only the views that read a property that actually changed. Mark
/// model classes `final` for performance.
@Model
final class Item {
    var title: String
    var notes: String
    /// Name of the SF Symbol shown for this item.
    var symbolName: String
    /// `ItemCategory.rawValue`. Stored as a `String` so it's usable inside an iOS 26
    /// `#Predicate` (see `ItemCategory` for why). Read/write the typed value via
    /// the `category` computed property below.
    var categoryID: String
    var isFavorite: Bool
    var createdAt: Date

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryID) ?? .personal }
        set { categoryID = newValue.rawValue }
    }

    init(
        title: String,
        notes: String = "",
        symbolName: String = "star",
        category: ItemCategory = .personal,
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.title = title
        self.notes = notes
        self.symbolName = symbolName
        self.categoryID = category.rawValue
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }
}

extension Item {
    /// Seed a fresh store with a few example items so the app isn't empty on
    /// first launch. Runs once (only when the store has no items).
    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Item>())) ?? 0
        guard existing == 0 else { return }
        for item in sampleItems() { context.insert(item) }
    }

    static func sampleItems() -> [Item] {
        [
            Item(title: "Welcome to AppScaffold", notes: "Tap Edit to change this item, or + to add your own.",
                 symbolName: "hand.wave", category: .personal, isFavorite: true),
            Item(title: "Ship the v1 build", notes: "Archive in Xcode and upload to TestFlight.",
                 symbolName: "shippingbox", category: .work),
            Item(title: "A SwiftUI app for measuring tides", notes: "Could use WeatherKit + Swift Charts.",
                 symbolName: "lightbulb", category: .ideas),
            Item(title: "Standing desk", notes: "The one with the walnut top.",
                 symbolName: "gift", category: .wishlist),
        ]
    }
}
