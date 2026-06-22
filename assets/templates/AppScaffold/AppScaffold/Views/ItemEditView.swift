import SwiftUI
import SwiftData

/// A modal form used for both creating and editing an item.
///
/// It edits *local* `@State` copies of the fields and only commits to SwiftData
/// on Save — so Cancel is free (no orphaned objects) and a half-finished edit
/// never touches the store. This is a clean pattern for create/edit sheets.
struct ItemEditView: View {
    enum Mode: Hashable {
        case create
        case edit(Item)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let mode: Mode

    @State private var title: String
    @State private var notes: String
    @State private var symbolName: String
    @State private var category: ItemCategory
    @State private var isFavorite: Bool

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _notes = State(initialValue: "")
            _symbolName = State(initialValue: "star")
            _category = State(initialValue: .personal)
            _isFavorite = State(initialValue: false)
        case .edit(let item):
            _title = State(initialValue: item.title)
            _notes = State(initialValue: item.notes)
            _symbolName = State(initialValue: item.symbolName)
            _category = State(initialValue: item.category)
            _isFavorite = State(initialValue: item.isFavorite)
        }
    }

    private var isCreate: Bool { mode == .create }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases) { category in
                            Label(category.title, systemImage: category.symbol).tag(category)
                        }
                    }
                    Toggle("Favorite", isOn: $isFavorite)
                }

                Section("Symbol") {
                    SymbolPicker(selection: $symbolName, tint: category.tint)
                }
            }
            .navigationTitle(isCreate ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .create:
            let item = Item(title: trimmed, notes: notes, symbolName: symbolName,
                            category: category, isFavorite: isFavorite)
            context.insert(item)
        case .edit(let item):
            item.title = trimmed
            item.notes = notes
            item.symbolName = symbolName
            item.category = category
            item.isFavorite = isFavorite
        }
        dismiss()
    }
}

/// A compact SF Symbol picker. Demonstrates a `LazyVGrid` of selectable,
/// animated symbols.
struct SymbolPicker: View {
    @Binding var selection: String
    var tint: Color = .accentColor

    private let symbols = [
        "star", "hand.wave", "shippingbox", "lightbulb", "gift", "flag",
        "heart", "bookmark", "bell", "paperplane", "leaf", "bolt",
    ]

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                let isSelected = symbol == selection
                Button {
                    withAnimation(.snappy) { selection = symbol }
                } label: {
                    Image(systemName: symbol)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(isSelected ? .white : Color.primary)
                        .background(isSelected ? tint : Color(.secondarySystemFill),
                                    in: .rect(cornerRadius: 12))
                        .symbolEffect(.bounce, value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Create") {
    ItemEditView(mode: .create)
        .modelContainer(PreviewData.container)
}
