import Foundation
import SwiftData

/// Another reader in the club. "You" isn't stored here; that's AppStorage.
@Model
final class ClubMember {
    var name: String
    var colorHex: String
    var booksRead: Int
    var status: String          // e.g. "Middlemarch · p. 200"
    var isHost: Bool
    var joinedAt: Date
    /// Their profile id in Supabase.
    var remoteID: UUID?
    /// Their chosen silhouette (index into SilhouetteKind), or -1 if they haven't picked one.
    var silhouette: Int = -1

    init(name: String, colorHex: String, booksRead: Int, status: String, isHost: Bool = false, joinedAt: Date = .now) {
        self.name = name
        self.colorHex = colorHex
        self.booksRead = booksRead
        self.status = status
        self.isHost = isHost
        self.joinedAt = joinedAt
    }

    var initial: String { String(name.prefix(1)) }

    var silhouetteKind: SilhouetteKind? { SilhouetteKind(rawValue: silhouette) }
}

/// One line in the club's reading history.
@Model
final class LedgerEntry {
    var month: Date
    var title: String
    var author: String
    var clubRating: Double
    var myRating: Int?
    var spineHex: String
    /// The past meetup this line comes from.
    var remoteID: UUID?

    init(month: Date, title: String, author: String, clubRating: Double, myRating: Int? = nil, spineHex: String) {
        self.month = month
        self.title = title
        self.author = author
        self.clubRating = clubRating
        self.myRating = myRating
        self.spineHex = spineHex
    }
}

/// A book a member passed to you.
@Model
final class Recommendation {
    var fromName: String
    var title: String
    var author: String
    var reason: String
    var spineHex: String
    var pageCount: Int
    var isAdded: Bool

    init(fromName: String, title: String, author: String, reason: String, spineHex: String, pageCount: Int, isAdded: Bool = false) {
        self.fromName = fromName
        self.title = title
        self.author = author
        self.reason = reason
        self.spineHex = spineHex
        self.pageCount = pageCount
        self.isAdded = isAdded
    }
}

/// A candidate for next month's pick.
@Model
final class PickOption {
    var title: String
    var author: String
    var votes: Int              // votes from everyone else
    var isMyVote: Bool
    /// Row id in Supabase `pick_options`, and the catalog book it points at.
    var remoteID: UUID?
    var catalogID: UUID?

    init(title: String, author: String, votes: Int, isMyVote: Bool = false) {
        self.title = title
        self.author = author
        self.votes = votes
        self.isMyVote = isMyVote
    }

    var total: Int { votes + (isMyVote ? 1 : 0) }
}
