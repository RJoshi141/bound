import Foundation
import SwiftData

@Model
final class Meetup {
    var number: Int
    var date: Date
    var place: String
    var bookTitle: String
    var readUpTo: String
    var rsvpRaw: String

    enum RSVP: String, CaseIterable {
        case going, maybe, notGoing
    }

    init(number: Int, date: Date, place: String, bookTitle: String, readUpTo: String, rsvp: RSVP = .maybe) {
        self.number = number
        self.date = date
        self.place = place
        self.bookTitle = bookTitle
        self.readUpTo = readUpTo
        self.rsvpRaw = rsvp.rawValue
    }

    var rsvp: RSVP {
        get { RSVP(rawValue: rsvpRaw) ?? .maybe }
        set { rsvpRaw = newValue.rawValue }
    }
}
