import SwiftUI

/// The app's spine: a three-ish-column `NavigationSplitView` that adapts itself.
///
/// On iPad (regular width) it shows a sidebar of filters, a content list, and a
/// detail pane side-by-side. On iPhone (compact width) the *same code* collapses
/// into a single push-navigation stack — no conditional layout required. This
/// adaptive behavior is the main reason to reach for `NavigationSplitView`.
struct RootView: View {
    // On iOS, `List(selection:)` needs an OPTIONAL binding (nil = nothing
    // selected), so the sidebar selection is `SidebarFilter?`. We default the
    // content list to `.all` whenever it's nil.
    @State private var selectedFilter: SidebarFilter? = .all
    @State private var selectedItem: Item?
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var activeFilter: SidebarFilter { selectedFilter ?? .all }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedFilter)
        } content: {
            // Re-creating ItemListView when the filter or `searchText` changes
            // re-evaluates its `@Query` with a fresh predicate.
            ItemListView(filter: activeFilter, searchText: searchText, selection: $selectedItem)
                .navigationTitle(activeFilter.title)
                .searchable(text: $searchText, prompt: "Search items")
        } detail: {
            NavigationStack {
                if let selectedItem {
                    ItemDetailView(item: selectedItem)
                } else {
                    ContentUnavailableView(
                        "No Item Selected",
                        systemImage: "sidebar.right",
                        description: Text("Choose an item from the list to see its details.")
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        // Clearing the selection when the filter changes avoids showing a detail
        // for an item that's no longer in the visible list.
        .onChange(of: selectedFilter) { selectedItem = nil }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
