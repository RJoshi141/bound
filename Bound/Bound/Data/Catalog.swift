import Foundation

/// A search result: from Open Library, or from the small built-in list of classics shown before you type.
struct CatalogBook: Identifiable, Hashable {
    let title: String
    let author: String
    let year: Int?
    let pageCount: Int          // 0 when Open Library doesn't know
    var openLibraryKey: String? = nil
    var coverID: Int? = nil
    var id: String { openLibraryKey ?? title + author }

    var coverURL: URL? {
        coverID.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-S.jpg") }
    }
}

enum Catalog {
    static let all: [CatalogBook] = [
        .init(title: "Middlemarch", author: "George Eliot", year: 1871, pageCount: 880),
        .init(title: "Silas Marner", author: "George Eliot", year: 1861, pageCount: 183),
        .init(title: "The Mill on the Floss", author: "George Eliot", year: 1860, pageCount: 576),
        .init(title: "The Moonstone", author: "Wilkie Collins", year: 1868, pageCount: 528),
        .init(title: "The Woman in White", author: "Wilkie Collins", year: 1859, pageCount: 672),
        .init(title: "Sense and Sensibility", author: "Jane Austen", year: 1811, pageCount: 409),
        .init(title: "Northanger Abbey", author: "Jane Austen", year: 1817, pageCount: 251),
        .init(title: "Bleak House", author: "Charles Dickens", year: 1853, pageCount: 1017),
        .init(title: "A Tale of Two Cities", author: "Charles Dickens", year: 1859, pageCount: 489),
        .init(title: "Tess of the d'Urbervilles", author: "Thomas Hardy", year: 1891, pageCount: 518),
        .init(title: "Far from the Madding Crowd", author: "Thomas Hardy", year: 1874, pageCount: 433),
        .init(title: "The Picture of Dorian Gray", author: "Oscar Wilde", year: 1890, pageCount: 254),
        .init(title: "To the Lighthouse", author: "Virginia Woolf", year: 1927, pageCount: 209),
        .init(title: "Orlando", author: "Virginia Woolf", year: 1928, pageCount: 333),
        .init(title: "The House of Mirth", author: "Edith Wharton", year: 1905, pageCount: 329),
        .init(title: "War and Peace", author: "Leo Tolstoy", year: 1869, pageCount: 1225),
        .init(title: "Crime and Punishment", author: "Fyodor Dostoevsky", year: 1866, pageCount: 545),
        .init(title: "The Brothers Karamazov", author: "Fyodor Dostoevsky", year: 1880, pageCount: 796),
        .init(title: "Madame Bovary", author: "Gustave Flaubert", year: 1857, pageCount: 329),
        .init(title: "The Great Gatsby", author: "F. Scott Fitzgerald", year: 1925, pageCount: 180),
        .init(title: "Shirley", author: "Charlotte Brontë", year: 1849, pageCount: 624),
        .init(title: "Agnes Grey", author: "Anne Brontë", year: 1847, pageCount: 256),
        .init(title: "Cranford", author: "Elizabeth Gaskell", year: 1853, pageCount: 224),
        .init(title: "The Awakening", author: "Kate Chopin", year: 1899, pageCount: 195),
    ]

    static func search(_ query: String) -> [CatalogBook] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Array(all.prefix(8)) }
        return all.filter { $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q) }
    }

    /// Picks a spine colour so new books don't all look the same.
    static func spineHex(for title: String) -> String {
        let palette = [Theme.Spine.forest, Theme.Spine.oxblood, Theme.Spine.rust, Theme.Spine.mustard,
                       Theme.Spine.olive, Theme.Spine.plum, Theme.Spine.navy, Theme.Spine.ink, Theme.Spine.sage]
        let seed = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return palette[seed % palette.count]
    }
}
