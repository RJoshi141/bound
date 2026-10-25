import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var year: Int?
    var pageCount: Int
    var currentPage: Int
    var shelfRaw: String        // raw string keeps #Predicate queries simple
    var isFavourite: Bool
    var isClubPick: Bool
    var spineHex: String
    var addedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note] = []

    init(
        title: String,
        author: String,
        year: Int? = nil,
        pageCount: Int,
        currentPage: Int = 0,
        shelf: ShelfKind = .toRead,
        isFavourite: Bool = false,
        isClubPick: Bool = false,
        spineHex: String,
        addedAt: Date = .now
    ) {
        self.title = title
        self.author = author
        self.year = year
        self.pageCount = pageCount
        self.currentPage = currentPage
        self.shelfRaw = shelf.rawValue
        self.isFavourite = isFavourite
        self.isClubPick = isClubPick
        self.spineHex = spineHex
        self.addedAt = addedAt
    }

    var shelf: ShelfKind {
        get { ShelfKind(rawValue: shelfRaw) ?? .toRead }
        set { shelfRaw = newValue.rawValue }
    }

    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return min(Double(currentPage) / Double(pageCount), 1)
    }
}
