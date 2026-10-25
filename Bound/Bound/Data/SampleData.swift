import Foundation
import SwiftData

/// Classics + a pretend club for first launch and previews. Local only until we add a backend.
enum SampleData {
    /// Seeds each kind separately, so older installs pick up new models too.
    static func seedIfNeeded(_ context: ModelContext) {
        if count(Book.self, in: context) == 0 { insertBooks(into: context) }
        if count(Meetup.self, in: context) == 0 { insertMeetup(into: context) }
        if count(ClubMember.self, in: context) == 0 { insertClub(into: context) }
    }

    static let previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: Book.self, Note.self, Meetup.self, ClubMember.self, LedgerEntry.self, Recommendation.self, PickOption.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        seedIfNeeded(container.mainContext)
        return container
    }()

    private static func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }

    private static func month(_ m: Int, _ y: Int = 2026, day: Int = 1, hour: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: day, hour: hour)) ?? .now
    }

    private static func insertBooks(into context: ModelContext) {
        typealias S = Theme.Spine
        let books: [Book] = [
            // To read
            Book(title: "Persuasion", author: "Jane Austen", year: 1817, pageCount: 249, isFavourite: true, isClubPick: true, spineHex: S.forest),
            Book(title: "Frankenstein", author: "Mary Shelley", year: 1818, pageCount: 280, isClubPick: true, spineHex: S.ink),
            Book(title: "Walden", author: "Henry David Thoreau", year: 1854, pageCount: 352, spineHex: S.sage),
            Book(title: "Dracula", author: "Bram Stoker", year: 1897, pageCount: 418, spineHex: S.oxblood),
            Book(title: "The Odyssey", author: "Homer", pageCount: 560, spineHex: S.mustard),
            Book(title: "Little Women", author: "Louisa May Alcott", year: 1868, pageCount: 449, spineHex: S.cream),
            Book(title: "North and South", author: "Elizabeth Gaskell", year: 1855, pageCount: 452, spineHex: S.navy),
            Book(title: "Emma", author: "Jane Austen", year: 1815, pageCount: 474, spineHex: S.rust),
            Book(title: "Villette", author: "Charlotte Brontë", year: 1853, pageCount: 573, spineHex: S.plum),
            // Reading now
            Book(title: "Middlemarch", author: "George Eliot", year: 1871, pageCount: 880, currentPage: 212, shelf: .reading, isFavourite: true, isClubPick: true, spineHex: S.oxblood),
            Book(title: "Jane Eyre", author: "Charlotte Brontë", year: 1847, pageCount: 532, currentPage: 40, shelf: .reading, spineHex: S.ink),
            // Finished
            Book(title: "Wuthering Heights", author: "Emily Brontë", year: 1847, pageCount: 416, currentPage: 416, shelf: .finished, isFavourite: true, spineHex: S.navy),
            Book(title: "Moby-Dick", author: "Herman Melville", year: 1851, pageCount: 635, currentPage: 635, shelf: .finished, isClubPick: true, spineHex: S.forest),
            Book(title: "Great Expectations", author: "Charles Dickens", year: 1861, pageCount: 505, currentPage: 505, shelf: .finished, spineHex: S.mustard),
            Book(title: "Anna Karenina", author: "Leo Tolstoy", year: 1878, pageCount: 864, currentPage: 864, shelf: .finished, isFavourite: true, isClubPick: true, spineHex: S.oxblood),
            Book(title: "Mrs Dalloway", author: "Virginia Woolf", year: 1925, pageCount: 194, currentPage: 194, shelf: .finished, isClubPick: true, spineHex: S.cream),
            Book(title: "The Age of Innocence", author: "Edith Wharton", year: 1920, pageCount: 365, currentPage: 365, shelf: .finished, spineHex: S.plum),
            Book(title: "Pride and Prejudice", author: "Jane Austen", year: 1813, pageCount: 432, currentPage: 432, shelf: .finished, isFavourite: true, spineHex: S.rust),
            Book(title: "Dubliners", author: "James Joyce", year: 1914, pageCount: 230, currentPage: 230, shelf: .finished, spineHex: S.ink),
        ]

        // Stagger addedAt so shelf order matches the list above.
        for (index, book) in books.enumerated() {
            book.addedAt = Date(timeIntervalSince1970: 1_790_000_000 + Double(index) * 60)
            context.insert(book)
        }

        guard let middlemarch = books.first(where: { $0.title == "Middlemarch" }) else { return }
        let notes = [
            Note(authorName: "Priya", text: "Dorothea is me at 19, choosing the wrong man for the right reasons.", rating: 4, page: 200),
            Note(authorName: "Lucia", text: "Team Mary Garth. Could do with fewer pages of Casaubon.", rating: 3, page: 150),
            Note(authorName: "Jonah", text: "The chapter epigraphs are doing so much work. Read them twice.", page: 96),
            Note(authorName: "Marcus", text: "Read it with a pencil. Nearly every page has a line worth underlining.", rating: 5, page: 880, discussAtMeetup: true),
            Note(authorName: "Amara", text: "That will. I did not see it coming and I'm still mad.", rating: 5, page: 520, containsSpoilers: true),
            Note(authorName: "Sam", text: "Lydgate's storyline is the one I keep thinking about.", rating: 4, page: 640),
        ]
        for note in notes {
            context.insert(note)
            note.book = middlemarch
        }
    }

    private static func insertMeetup(into context: ModelContext) {
        context.insert(Meetup(
            number: 23,
            date: month(11, day: 19, hour: 19),
            place: "Lucia's place",
            address: "24th St, Mission",
            bookTitle: "Middlemarch",
            bookAuthor: "George Eliot",
            spineHex: Theme.Spine.oxblood,
            readUpTo: "Books I–IV",
            rsvp: .going,
            bringing: "Marcus → snacks, Priya → wine",
            goingCount: 4,
            maybeCount: 2
        ))
    }

    private static func insertClub(into context: ModelContext) {
        typealias S = Theme.Spine
        let members = [
            ClubMember(name: "Lucia", colorHex: S.rust, booksRead: 19, status: "Middlemarch · p. 150", isHost: true),
            ClubMember(name: "Priya", colorHex: S.forest, booksRead: 31, status: "Middlemarch · p. 200"),
            ClubMember(name: "Marcus", colorHex: S.navy, booksRead: 48, status: "Finished Middlemarch"),
            ClubMember(name: "Amara", colorHex: S.plum, booksRead: 27, status: "Middlemarch · p. 520"),
            ClubMember(name: "Jonah", colorHex: S.olive, booksRead: 12, status: "Middlemarch · p. 96"),
            ClubMember(name: "Sam", colorHex: S.mustard, booksRead: 22, status: "Middlemarch · p. 640"),
        ]
        members.forEach { context.insert($0) }

        let ledger = [
            LedgerEntry(month: month(10), title: "Mrs Dalloway", author: "Virginia Woolf", clubRating: 3.9, myRating: 4, spineHex: S.cream),
            LedgerEntry(month: month(9), title: "Moby-Dick", author: "Herman Melville", clubRating: 3.4, myRating: 3, spineHex: S.forest),
            LedgerEntry(month: month(8), title: "Anna Karenina", author: "Leo Tolstoy", clubRating: 4.6, myRating: 5, spineHex: S.oxblood),
            LedgerEntry(month: month(7), title: "Pride and Prejudice", author: "Jane Austen", clubRating: 4.4, myRating: 5, spineHex: S.rust),
            LedgerEntry(month: month(6), title: "Great Expectations", author: "Charles Dickens", clubRating: 4.0, spineHex: S.mustard),
            LedgerEntry(month: month(5), title: "The Age of Innocence", author: "Edith Wharton", clubRating: 4.1, myRating: 4, spineHex: S.plum),
            LedgerEntry(month: month(4), title: "Dubliners", author: "James Joyce", clubRating: 3.6, myRating: 3, spineHex: S.ink),
            LedgerEntry(month: month(3), title: "Wuthering Heights", author: "Emily Brontë", clubRating: 4.2, myRating: 5, spineHex: S.navy),
        ]
        ledger.forEach { context.insert($0) }

        let recs = [
            Recommendation(fromName: "Priya", title: "Jane Eyre", author: "Charlotte Brontë", reason: "Because you loved Persuasion", spineHex: S.ink, pageCount: 532),
            Recommendation(fromName: "Marcus", title: "The Moonstone", author: "Wilkie Collins", reason: "\"A proper page-turner. Trust me.\"", spineHex: "3E5C4C", pageCount: 528),
            Recommendation(fromName: "Amara", title: "Silas Marner", author: "George Eliot", reason: "More Eliot, a quarter of the length", spineHex: S.cream, pageCount: 183),
        ]
        recs.forEach { context.insert($0) }

        let picks = [
            PickOption(title: "Persuasion", author: "Jane Austen", votes: 4),
            PickOption(title: "Frankenstein", author: "Mary Shelley", votes: 3),
            PickOption(title: "Walden", author: "Henry David Thoreau", votes: 1),
        ]
        picks.forEach { context.insert($0) }
    }
}
