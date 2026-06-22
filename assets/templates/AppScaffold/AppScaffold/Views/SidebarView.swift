import SwiftUI

/// The first column: a selectable list of filters. `List(selection:)` drives the
/// split view — selecting a row updates `selectedFilter`, which re-queries the
/// content list. (In a split view you bind selection; you do *not* use
/// `NavigationLink` here.)
struct SidebarView: View {
    // Optional because iOS `List(selection:)` requires `Binding<SelectionValue?>`.
    @Binding var selection: SidebarFilter?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("All Items", systemImage: "tray.full")
                    .tag(SidebarFilter.all)
                Label("Favorites", systemImage: "star")
                    .tag(SidebarFilter.favorites)
            }

            Section("Categories") {
                ForEach(ItemCategory.allCases) { category in
                    Label(category.title, systemImage: category.symbol)
                        .tag(SidebarFilter.category(category))
                }
            }
        }
        .navigationTitle("AppScaffold")
    }
}

#Preview {
    @Previewable @State var selection: SidebarFilter? = .all
    NavigationSplitView {
        SidebarView(selection: $selection)
    } detail: {
        Text("Detail")
    }
}
