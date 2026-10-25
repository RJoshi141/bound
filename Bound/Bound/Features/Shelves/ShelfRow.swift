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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(books) { book in
                        SpineView(book: book, isLifted: selected?.id == book.id) {
                            selected = (selected?.id == book.id) ? nil : book
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 28)          // headroom so a lifted spine isn't clipped
            }
            .frame(height: 156, alignment: .bottom)
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
