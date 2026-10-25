import SwiftUI

/// The paper slip that slides up when you lift a spine.
struct BookSlip: View {
    @Bindable var book: Book

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: book.spineHex))
                .frame(width: 28, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.shelf.title)
                    .font(Theme.Fonts.mono(10))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.oxblood)
                Text(book.title)
                    .font(Theme.Fonts.display(26))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                Text("\(book.author) · \(meta)")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                book.isFavourite.toggle()
            } label: {
                Image(systemName: book.isFavourite ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.oxblood)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Theme.Colors.oxblood, lineWidth: 1.5))
            }
            .accessibilityLabel(book.isFavourite ? "Remove from favourites" : "Add to favourites")
        }
        .padding(14)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.line))
        .shadow(color: Theme.Colors.ink.opacity(0.25), radius: 18, y: 12)
    }

    private var meta: String {
        switch book.shelf {
        case .reading: "p. \(book.currentPage) of \(book.pageCount)"
        case .finished: "Finished"
        case .toRead: "\(book.pageCount) pages"
        }
    }
}
