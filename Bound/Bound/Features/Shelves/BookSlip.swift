import Foundation
import SwiftUI

/// The paper slip that slides up when you lift a spine.
struct BookSlip: View {
    @Bindable var book: Book
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SpineSwatch(hex: book.spineHex, width: 28, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                MonoLabel(book.shelf.title, color: Theme.Colors.oxblood, size: 10)
                Text(book.title)
                    .font(Theme.Fonts.display(26))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                Text("\(book.author) · \(book.shelfMeta)")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            IconButton(
                systemName: book.isFavourite ? "heart.fill" : "heart",
                label: book.isFavourite ? "Remove from favourites" : "Add to favourites",
                color: Theme.Colors.oxblood,
                bordered: false
            ) { book.isFavourite.toggle() }

            Button("Open", action: onOpen)
                .buttonStyle(SmallButtonStyle(filled: true))
        }
        .padding(14)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.line))
        .shadow(color: Theme.Colors.inkFixed.opacity(0.4), radius: 18, y: 12)
        .environment(\.colorScheme, .light)
    }
}

extension Book {
    var shelfMeta: String {
        switch shelf {
        case .reading: "p. \(currentPage) of \(pageCount)"
        case .finished: "Finished"
        case .toRead: "\(pageCount) pages"
        }
    }
}
