import Foundation
import SwiftUI

/// One book on the shelf. Width follows page count, height varies for rhythm.
struct SpineView: View {
    let book: Book
    let isLifted: Bool
    let action: () -> Void

    private let shape = UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)

    var body: some View {
        let size = book.spineSize
        let titleColor = Color.isLight(hex: book.spineHex) ? Theme.Colors.ink : Theme.Colors.paper

        Button(action: action) {
            ZStack {
                shape.fill(Color(hex: book.spineHex))

                // shade on the right edge so spines read as rounded bindings
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(.black.opacity(0.18)).frame(width: 3)
                }

                // gilt bands top + bottom, star for favourites
                VStack(spacing: 0) {
                    giltBand
                    Spacer()
                    if book.isFavourite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(Theme.Colors.gilt)
                            .padding(.bottom, 4)
                    }
                    giltBand
                }
                .padding(.vertical, 6)

                // title runs top-to-bottom like a real spine
                Text(book.title)
                    .font(Theme.Fonts.display(14))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .frame(width: size.height - 36)
                    .rotationEffect(.degrees(90))
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
        }
        .buttonStyle(.plain)
        .offset(y: isLifted ? -22 : 0)
        .shadow(color: .black.opacity(isLifted ? 0.28 : 0), radius: 8, y: 6)
        .accessibilityLabel("\(book.title) by \(book.author)")
        .accessibilityAddTraits(isLifted ? .isSelected : [])
    }

    private var giltBand: some View {
        Rectangle()
            .fill(Theme.Colors.gilt)
            .frame(height: 1.5)
            .padding(.horizontal, 2)
    }
}

extension Book {
    /// Thicker books get wider spines. Height comes from a stable hash of the title
    /// (String.hashValue changes every launch, so we roll our own).
    var spineSize: CGSize {
        let width = min(max(Double(pageCount) / 20, 18), 46)
        let seed = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        let height = 98 + Double(seed % 27)
        return CGSize(width: width, height: height)
    }
}
