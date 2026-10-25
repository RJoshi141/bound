import Foundation
import SwiftData

/// Classics for first launch and previews. Local only until we add a backend.
enum SampleData {
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Book>())) ?? 0
        guard count == 0 else { return }
        insertAll(into: context)
    }

    @MainActor
    static let previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: Book.self, Note.self, Meetup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        insertAll(into: container.mainContext)
        return container
    }()

    @MainActor
    private static func insertAll(into context: ModelContext) {
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

        if let middlemarch = books.first(where: { $0.title == "Middlemarch" }) {
            let notes = [
                Note(authorName: "Priya", text: "Dorothea is me at 19, choosing the wrong man for the right reasons.", rating: 4, page: 200),
                Note(authorName: "Lucia", text: "Team Mary Garth. Could do with fewer pages of Casaubon.", rating: 3, page: 150),
                Note(authorName: "Marcus", text: "Read it with a pencil. Nearly every page has a line worth underlining.", rating: 5, page: 880, discussAtMeetup: true),
            ]
            notes.forEach { note in
                context.insert(note)
                note.book = middlemarch
            }
        }

        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 19)) ?? .now
        context.insert(Meetup(number: 23, date: date, place: "Lucia's place", bookTitle: "Middlemarch", readUpTo: "Books I–IV", rsvp: .going))
    }
}
