import Foundation
import SwiftUI
import SwiftData

enum ShelfFilter: String, CaseIterable, Identifiable {
    case all, favourites, clubPicks
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .favourites: "★ Favourites"
        case .clubPicks: "Club picks"
        }
    }

    func matches(_ book: Book) -> Bool {
        switch self {
        case .all: true
        case .favourites: book.isFavourite
        case .clubPicks: book.isClubPick
        }
    }
}

struct ShelvesView: View {
    @Environment(TearCoordinator.self) private var tear
    @AppStorage(AppKeys.clubName) private var clubName = "Tuesday Night Readers"
    @Query(sort: \Book.addedAt) private var books: [Book]

    @State private var filter: ShelfFilter = .all
    @State private var selected: Book?
    @State private var path: [Book] = []
    @State private var showingAdd = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        HStack(spacing: 8) {
                            ForEach(ShelfFilter.allCases) { option in
                                Chip(title: option.title, isOn: option == filter) { filter = option }
                            }
                        }
                        ForEach(ShelfKind.allCases) { kind in
                            ShelfRow(kind: kind, books: books(on: kind), selected: $selected)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 130)      // room for the slip
                }

                if let selected {
                    BookSlip(book: selected, onOpen: { open(selected) })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .paperBackground()
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: selected?.id)
            .animation(.easeInOut(duration: 0.2), value: filter)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showingAdd) {
                AddBookView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel(clubName, color: Theme.Colors.oxblood)
                Text("My shelves")
                    .font(Theme.Fonts.display(46))
                    .foregroundStyle(Theme.Colors.ink)
            }
            Spacer()
            CircleIconButton(systemName: "plus", label: "Add a book") { showingAdd = true }
                .padding(.bottom, 6)
        }
    }

    private func books(on kind: ShelfKind) -> [Book] {
        books.filter { $0.shelf == kind && filter.matches($0) }
    }

    private func open(_ book: Book) {
        tear.run {
            selected = nil
            path.append(book)
        }
    }
}

#Preview {
    ShelvesView()
        .environment(TearCoordinator())
        .modelContainer(SampleData.previewContainer)
}
