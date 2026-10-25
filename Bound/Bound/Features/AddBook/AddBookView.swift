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
    @State private var pagesText = ""
    @State private var found: [CatalogBook] = Catalog.search("")
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var showScanner = false
    @FocusState private var searchFocused: Bool

    private var results: [CatalogBook] {
        let ownedKeys = Set(owned.compactMap(\.openLibraryKey))
        let ownedTitles = Set(owned.map { "\($0.title)|\($0.author)".lowercased() })
        return found.filter { book in
            if let key = book.openLibraryKey, ownedKeys.contains(key) { return false }
            return !ownedTitles.contains("\(book.title)|\(book.author)".lowercased())
        }
    }

    private var statusLabel: String {
        if query.trimmingCharacters(in: .whitespaces).isEmpty { return "Suggested" }
        if isSearching { return "Searching Open Library…" }
        if searchFailed { return "Couldn't reach Open Library" }
        return "\(results.count) results"
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
                    searchFocused = false
                    showScanner = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            HStack {
                MonoLabel(statusLabel)
                Spacer()
            }
            .padding(.horizontal, 20)

            List(results) { book in
                Button {
                    searchFocused = false
                    pagesText = book.pageCount > 0 ? String(book.pageCount) : ""
                    picked = book
                } label: {
                    HStack(spacing: 14) {
                        thumbnail(for: book)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title).font(Theme.Fonts.body(16, weight: .semibold))
                            Text([book.author, book.year.map(String.init), book.pageCount > 0 ? "\(book.pageCount) pp" : nil].compactMap { $0 }.joined(separator: " · "))
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
        .sheet(item: $picked) { book in
            addSheet(for: book)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScanSheet { isbn in query = isbn }
        }
        // debounced: wait for a pause in typing, then search
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            searchFailed = false
            guard q.count >= 2 else {
                isSearching = false
                found = Catalog.search("")
                return
            }
            isSearching = true
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                let books = try await OpenLibrary.search(q)
                guard !Task.isCancelled else { return }
                found = books
            } catch {
                guard !Task.isCancelled else { return }
                searchFailed = true
                found = Catalog.search(q)       // offline: fall back to the built-in list
            }
            isSearching = false
        }
    }

    /// Open Library cover when there is one, otherwise a cloth spine.
    @ViewBuilder
    private func thumbnail(for book: CatalogBook) -> some View {
        if let url = book.coverURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                SpineSwatch(hex: Catalog.spineHex(for: book.title), width: 38, height: 56)
            }
            .frame(width: 38, height: 56)
            .clipped()
            .overlay(Rectangle().stroke(Theme.Colors.line, lineWidth: 0.5))
        } else {
            SpineSwatch(hex: Catalog.spineHex(for: book.title), width: 38, height: 56)
        }
    }

    private var pages: Int { Int(pagesText) ?? 0 }

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

            HStack {
                MonoLabel("Pages")
                Spacer()
                TextField("", text: $pagesText, prompt: Text("e.g. 320").foregroundStyle(Theme.Colors.inkMuted))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(Theme.Fonts.body(16))
                    .frame(width: 100, height: 40)
                    .padding(.horizontal, 10)
                    .background(Theme.Colors.card)
                    .overlay(Rectangle().stroke(Theme.Colors.lineStrong, lineWidth: 1))
            }

            Button("Add to shelf") { add(book) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(pages <= 0)
                .opacity(pages > 0 ? 1 : 0.45)
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(24)
        .presentationDetents([.height(480)])
        .presentationBackground(Theme.Colors.paper)
    }

    private func add(_ item: CatalogBook) {
        let book = Book(
            title: item.title,
            author: item.author,
            year: item.year,
            pageCount: pages,
            shelf: shelf,
            isFavourite: favourite,
            spineHex: Catalog.spineHex(for: item.title)
        )
        book.openLibraryKey = item.openLibraryKey
        book.coverID = item.coverID
        if shelf == .finished { book.currentPage = pages }
        context.insert(book)
        picked = nil
        dismiss()
    }
}

#Preview {
    AddBookView().modelContainer(SampleData.previewContainer)
}
