import Foundation
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var owned: [Book]

    @State private var query = ""
    @State private var picked: CatalogBook?
    @State private var shelf: ShelfKind = .toRead
    @State private var favourite = false
    @FocusState private var searchFocused: Bool

    private var results: [CatalogBook] {
        let ownedTitles = Set(owned.map { $0.title.lowercased() })
        return Catalog.search(query).filter { !ownedTitles.contains($0.title.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(Theme.Fonts.letterpress(18))
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                Spacer()
                Text("Add a book").font(Theme.Fonts.body(17, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 56, height: 1)
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.inkMuted)
                    TextField("", text: $query, prompt: Text("Title, author or ISBN").foregroundStyle(Theme.Colors.inkMuted))
                        .font(Theme.Fonts.body(16))
                        .focused($searchFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Theme.Colors.paperDeep)

                IconButton(systemName: "barcode.viewfinder", label: "Scan a barcode") {
                    // TODO: VisionKit DataScannerViewController
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            HStack {
                MonoLabel(query.isEmpty ? "Suggested" : "\(results.count) results")
                Spacer()
            }
            .padding(.horizontal, 20)

            List(results) { book in
                Button {
                    searchFocused = false
                    picked = book
                } label: {
                    HStack(spacing: 14) {
                        SpineSwatch(hex: Catalog.spineHex(for: book.title), width: 30, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title).font(Theme.Fonts.body(16, weight: .semibold))
                            Text([book.author, book.year.map(String.init), "\(book.pageCount) pp"].compactMap { $0 }.joined(separator: " · "))
                                .font(Theme.Fonts.body(13))
                                .foregroundStyle(Theme.Colors.inkMuted)
                        }
                        Spacer()
                        Image(systemName: picked == book ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.Colors.forest)
                    }
                    .foregroundStyle(Theme.Colors.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.Colors.line)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .paperBackground()
        .environment(\.colorScheme, .light)     // sheets are paper
        .sheet(item: $picked) { book in
            addSheet(for: book)
        }
    }

    private func addSheet(for book: CatalogBook) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(Theme.Fonts.display(30))
                    Text(book.author).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.inkMuted)
                }
                Spacer()
                IconButton(
                    systemName: favourite ? "heart.fill" : "heart",
                    label: favourite ? "Remove from favourites" : "Add to favourites",
                    color: Theme.Colors.oxblood,
                    bordered: false
                ) { favourite.toggle() }
            }

            VStack(alignment: .leading, spacing: 0) {
                MonoLabel("Add to shelf").padding(.bottom, 6)
                ForEach(ShelfKind.allCases) { kind in
                    Button {
                        shelf = kind
                    } label: {
                        HStack {
                            Image(systemName: shelf == kind ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(Theme.Colors.forest)
                            Text(kind.title).font(Theme.Fonts.body(16))
                            Spacer()
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(shelf == kind ? .isSelected : [])
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
                }
            }

            Button("Add to shelf") { add(book) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(24)
        .presentationDetents([.height(420)])
        .presentationBackground(Theme.Colors.paper)
    }

    private func add(_ item: CatalogBook) {
        let book = Book(
            title: item.title,
            author: item.author,
            year: item.year,
            pageCount: item.pageCount,
            shelf: shelf,
            isFavourite: favourite,
            spineHex: Catalog.spineHex(for: item.title)
        )
        if shelf == .finished { book.currentPage = item.pageCount }
        context.insert(book)
        picked = nil
        dismiss()
    }
}

#Preview {
    AddBookView().modelContainer(SampleData.previewContainer)
}
