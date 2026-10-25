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
    @Query(sort: \Book.addedAt) private var books: [Book]
    @State private var filter: ShelfFilter = .all
    @State private var selected: Book?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    chips
                    ForEach(ShelfKind.allCases) { kind in
                        ShelfRow(kind: kind, books: books(on: kind), selected: $selected)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 130)      // room for the slip
            }

            if let selected {
                BookSlip(book: selected)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: selected?.id)
        .animation(.easeInOut(duration: 0.2), value: filter)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tuesday Night Readers")
                    .font(Theme.Fonts.mono(11))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.oxblood)
                Text("My shelves")
                    .font(Theme.Fonts.display(46))
                    .foregroundStyle(Theme.Colors.ink)
            }
            Spacer()
            Button {
                // TODO: Add a book flow
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Theme.Colors.ink, lineWidth: 1.5))
            }
            .accessibilityLabel("Add a book")
            .padding(.bottom, 6)
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(ShelfFilter.allCases) { option in
                let isOn = option == filter
                Button { filter = option } label: {
                    Text(option.title)
                        .font(Theme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(isOn ? Theme.Colors.paper : Theme.Colors.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(isOn ? Theme.Colors.ink : .clear, in: Capsule())
                        .overlay(Capsule().stroke(isOn ? Theme.Colors.ink : Theme.Colors.lineStrong, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func books(on kind: ShelfKind) -> [Book] {
        books.filter { $0.shelf == kind && filter.matches($0) }
    }
}

#Preview {
    NavigationStack { ShelvesView() }
        .modelContainer(SampleData.previewContainer)
}
