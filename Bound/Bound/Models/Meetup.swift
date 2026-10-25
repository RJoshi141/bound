import Foundation
import SwiftData

@Model
final class Meetup {
    var number: Int
    var date: Date
    var place: String
    var address: String
    var bookTitle: String
    var bookAuthor: String
    var spineHex: String
    var readUpTo: String
    var rsvpRaw: String
    var bringing: String
    var goingCount: Int         // others going, not counting you
    var maybeCount: Int

    enum RSVP: String, CaseIterable, Identifiable {
        case going, maybe, notGoing
        var id: String { rawValue }
        var title: String {
            switch self {
            case .going: "Going"
            case .maybe: "Maybe"
            case .notGoing: "Can't"
            }
        }

        /// Fill when selected.
        var hex: String {
            switch self {
            case .going: "2F4A35"      // forest
            case .maybe: "B4572A"      // rust orange
            case .notGoing: "8A2C22"   // oxblood red
            }
        }
    }

    init(
        number: Int,
        date: Date,
        place: String,
        address: String = "",
        bookTitle: String,
        bookAuthor: String = "",
        spineHex: String = Theme.Spine.oxblood,
        readUpTo: String,
        rsvp: RSVP = .maybe,
        bringing: String = "",
        goingCount: Int = 0,
        maybeCount: Int = 0
    ) {
        self.number = number
        self.date = date
        self.place = place
        self.address = address
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.spineHex = spineHex
        self.readUpTo = readUpTo
        self.rsvpRaw = rsvp.rawValue
        self.bringing = bringing
        self.goingCount = goingCount
        self.maybeCount = maybeCount
    }

    var rsvp: RSVP {
        get { RSVP(rawValue: rsvpRaw) ?? .maybe }
        set { rsvpRaw = newValue.rawValue }
    }
}
