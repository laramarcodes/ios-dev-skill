import SwiftUI
import SwiftData

/// The middle column: the filtered, searchable list of items.
///
/// The key technique here is the **dynamic `@Query`**: the query's predicate is
/// built in `init` from the current filter + search text. Because SwiftUI
/// re-creates this view when those inputs change, the database query re-runs with
/// the new predicate — filtering happens in SwiftData, not in Swift.
struct ItemListView: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [Item]
    @Binding var selection: Item?

    @State private var showingCreate = false

    init(filter: SidebarFilter, searchText: String, selection: Binding<Item?>) {
        _selection = selection

        // Capture plain values for the predicate (no enums/optionals — iOS 26
        // `#Predicate` works best with primitives).
        let matchAllCategories = filter.categoryID == nil
        let categoryID = filter.categoryID ?? ""
        let onlyFavorites = filter.onlyFavorites
        let search = searchText

        _items = Query(
            filter: #Predicate<Item> { item in
                (matchAllCategories || item.categoryID == categoryID)
                    && (!onlyFavorites || item.isFavorite)
                    && (search.isEmpty
                        || item.title.localizedStandardContains(search)
                        || item.notes.localizedStandardContains(search))
            },
            sort: [SortDescriptor(\Item.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(items) { item in
                ItemRow(item: item)
                    .tag(item)
                    .swipeActions(edge: .leading) {
                        Button {
                            item.isFavorite.toggle()
                        } label: {
                            Label(item.isFavorite ? "Unfavorite" : "Favorite",
                                  systemImage: item.isFavorite ? "star.slash" : "star")
                        }
                        .tint(.yellow)
                    }
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No Items", systemImage: "tray")
                } description: {
                    Text("Add your first item to get started.")
                } actions: {
                    Button {
                        showingCreate = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent) // Liquid Glass primary action (iOS 26+)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreate = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            ItemEditView(mode: .create)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            if item == selection { selection = nil }
            context.delete(item)
        }
    }
}

/// A single row. Reading `item.isFavorite`/`item.symbolName`/`item.title` here
/// means SwiftUI re-renders just this row when one of those values changes.
struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.title3)
                .foregroundStyle(item.category.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ItemListView(filter: .all, searchText: "", selection: .constant(nil))
    }
    .modelContainer(PreviewData.container)
}
