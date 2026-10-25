import Foundation
import SwiftData

/// A club member's review. `page` is where they were when they wrote it,
/// which is what lets us fold notes that are ahead of you (spoiler-safe).
@Model
final class Note {
    var authorName: String
    var text: String
    var rating: Int?            // optional until the book is finished
    var page: Int
    var createdAt: Date
    var discussAtMeetup: Bool
    var containsSpoilers: Bool
    var book: Book?

    init(
        authorName: String,
        text: String,
        rating: Int? = nil,
        page: Int,
        createdAt: Date = .now,
        discussAtMeetup: Bool = false,
        containsSpoilers: Bool = false
    ) {
        self.authorName = authorName
        self.text = text
        self.rating = rating
        self.page = page
        self.createdAt = createdAt
        self.discussAtMeetup = discussAtMeetup
        self.containsSpoilers = containsSpoilers
    }
}
