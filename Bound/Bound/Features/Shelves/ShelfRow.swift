import Foundation
import SwiftUI

struct ShelfRow: View {
    let kind: ShelfKind
    let books: [Book]
    @Binding var selected: Book?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(kind.title)
                    .font(Theme.Fonts.displayItalic(26))
                    .foregroundStyle(Theme.Colors.ink)
                Spacer()
                Text("\(books.count) books")
                    .font(Theme.Fonts.mono(11))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.inkMuted)
            }

            // spines + plank as one unit, no gap, so the books stand on the wood
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(books) { book in
                            SpineView(book: book, isLifted: selected?.id == book.id) {
                                selected = (selected?.id == book.id) ? nil : book
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 156, alignment: .bottom)   // pin spines to the bottom edge; top is lift headroom
                }
                .frame(height: 156)
            .overlay {
                if books.isEmpty {
                    Text("Nothing here yet")
                        .font(Theme.Fonts.mono(11))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.inkMuted)
                }
            }

                OakPlank()
            }
        }
    }
}
