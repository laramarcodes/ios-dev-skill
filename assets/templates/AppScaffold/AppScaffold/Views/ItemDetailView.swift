import SwiftUI

/// The detail column. `@Bindable` lets us write straight back to the SwiftData
/// model (e.g. toggling favorite) and have the change persist + propagate.
struct ItemDetailView: View {
    @Bindable var item: Item
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !item.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(item.notes)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
                }

                LabeledContent("Category") {
                    Label(item.category.title, systemImage: item.category.symbol)
                }
                LabeledContent("Created", value: item.createdAt, format: .dateTime.day().month().year())
            }
            .padding()
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { item.isFavorite.toggle() }
                } label: {
                    Label("Favorite", systemImage: item.isFavorite ? "star.fill" : "star")
                        .symbolEffect(.bounce, value: item.isFavorite)
                }
                .tint(.yellow)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ItemEditView(mode: .edit(item))
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: item.symbolName)
                .font(.system(size: 34))
                .foregroundStyle(item.category.tint)
                .frame(width: 76, height: 76)
                // Adopting Liquid Glass on a custom view: a tinted, circular glass badge.
                .glassEffect(.regular.tint(item.category.tint.opacity(0.25)), in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title2.bold())
                Label(item.category.title, systemImage: item.category.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: PreviewData.sampleItem)
    }
}
