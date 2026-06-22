import SwiftUI

/// A simple, Codable category for items.
///
/// `Item` stores the *raw value* (`categoryID: String`) rather than the enum
/// directly. On iOS 26, `#Predicate` can't yet filter on a Swift enum, so we
/// query against the raw `String`. (iOS 27 adds native enum predicates — once
/// you raise the deployment target you can store the enum directly and drop the
/// `categoryID` shim.)
enum ItemCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case personal
    case work
    case ideas
    case wishlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Personal"
        case .work:     "Work"
        case .ideas:    "Ideas"
        case .wishlist: "Wishlist"
        }
    }

    /// An SF Symbol that represents the category.
    var symbol: String {
        switch self {
        case .personal: "person.crop.circle"
        case .work:     "briefcase"
        case .ideas:    "lightbulb"
        case .wishlist: "gift"
        }
    }

    /// A semantic tint used for Liquid Glass accents and symbol coloring.
    var tint: Color {
        switch self {
        case .personal: .blue
        case .work:     .orange
        case .ideas:    .yellow
        case .wishlist: .pink
        }
    }
}

/// What the sidebar is currently filtering by. Drives the content list's
/// `@Query` predicate in `ItemListView`.
enum SidebarFilter: Hashable {
    case all
    case favorites
    case category(ItemCategory)

    /// Raw category value to match in a predicate, or `nil` to match every category.
    var categoryID: String? {
        switch self {
        case .category(let category): category.rawValue
        case .all, .favorites:        nil
        }
    }

    var onlyFavorites: Bool { self == .favorites }

    var title: String {
        switch self {
        case .all:                    "All Items"
        case .favorites:              "Favorites"
        case .category(let category): category.title
        }
    }

    var symbol: String {
        switch self {
        case .all:                    "tray.full"
        case .favorites:              "star"
        case .category(let category): category.symbol
        }
    }
}
