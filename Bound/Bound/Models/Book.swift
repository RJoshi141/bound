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
    /// Row id in Supabase `user_books`; nil until the first push.
    var remoteID: UUID?
    /// Row id in the shared `books` catalog. Club notes hang off this.
    var catalogID: UUID?
    /// Open Library work key ("OL45804W"), when the book came from search.
    var openLibraryKey: String?
    /// What we last sent or received, so we only push real changes.
    var syncedFingerprint: String?

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

    /// The fields that sync. If this differs from `syncedFingerprint`, the book needs pushing.
    var syncFingerprint: String { "\(shelfRaw)|\(currentPage)|\(isFavourite)|\(spineHex)" }

    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return min(Double(currentPage) / Double(pageCount), 1)
    }
}
