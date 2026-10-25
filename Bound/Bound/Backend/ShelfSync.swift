import Foundation
import SwiftData
import Supabase

/// Keeps your shelves (SwiftData `Book`) in step with Supabase `user_books` + `books`.
///
/// - Pull on sign-in and whenever the app comes back to the front. The server wins.
/// - Push shortly after each local save, and when the app goes to the background.
///   Only books whose synced fields changed are sent.
/// - Books you remove locally are removed remotely on the next push.
@Observable
final class ShelfSync {
    static let shared = ShelfSync()

    private(set) var isSyncing = false
    private(set) var lastError: String?

    private var context: ModelContext?
    private var userID: UUID?
    /// Remote rows we know exist. A known id with no local book means it was removed here.
    private var knownRemote: Set<UUID> = []
    private var pushTask: Task<Void, Never>?
    private var listener: Task<Void, Never>?
    private var isPushing = false
    private var pushAgain = false

    private static let syncedUserKey = "shelfSyncedUserID"

    // MARK: lifecycle

    func start(context: ModelContext, userID: UUID) async {
        self.context = context
        self.userID = userID
        listener?.cancel()
        listener = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                self?.schedulePush()
            }
        }
        await pull()
    }

    func stop() {
        listener?.cancel()
        pushTask?.cancel()
        context = nil
        userID = nil
        knownRemote = []
    }

    private func schedulePush() {
        guard userID != nil else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await self?.push()
        }
    }

    // MARK: pull

    func pull() async {
        guard let context, let userID, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let defaults = UserDefaults.standard
        let firstSyncForUser = defaults.string(forKey: Self.syncedUserKey) != userID.uuidString

        // send anything still waiting first, so the pull doesn't overwrite it
        if !firstSyncForUser { await pushChanges() }

        let rows: [RemoteShelfRow]
        do {
            rows = try await supabase
                .from("user_books")
                .select("id, shelf, current_page, is_favourite, spine_hex, added_at, book:books(id, title, author, year, page_count)")
                .eq("user_id", value: userID)   // RLS also lets you read clubmates' shelves
                .execute()
                .value
        } catch {
            report(error, "pull")
            return
        }

        let local = (try? context.fetch(FetchDescriptor<Book>())) ?? []

        // A new account on this phone: the sample shelves (or someone else's) go.
        if firstSyncForUser {
            for book in local { context.delete(book) }
        }
        let kept = firstSyncForUser ? [] : local

        var byRemoteID: [UUID: Book] = [:]
        for book in kept { if let id = book.remoteID { byRemoteID[id] = book } }

        let remoteIDs = Set(rows.map(\.id))
        // removed on another device
        for (id, book) in byRemoteID where !remoteIDs.contains(id) { context.delete(book) }

        for row in rows {
            let book: Book
            if let existing = byRemoteID[row.id] {
                book = existing
            } else {
                book = Book(title: row.book.title, author: row.book.author, pageCount: row.book.pageCount, spineHex: row.spineHex)
                book.remoteID = row.id
                context.insert(book)
            }
            book.title = row.book.title
            book.author = row.book.author
            book.year = row.book.year
            book.pageCount = row.book.pageCount
            book.currentPage = row.currentPage
            book.shelf = ShelfKind(remoteValue: row.shelf) ?? .toRead
            book.isFavourite = row.isFavourite
            book.spineHex = row.spineHex
            book.addedAt = row.addedAt
            book.syncedFingerprint = book.syncFingerprint
        }

        knownRemote = remoteIDs
        try? context.save()
        defaults.set(userID.uuidString, forKey: Self.syncedUserKey)
        lastError = nil

        // books added here before they were ever pushed
        await pushChanges()
    }

    // MARK: push

    func push() async {
        guard !isSyncing else { pushAgain = true; return }
        await pushChanges()
    }

    private func pushChanges() async {
        guard let context, let userID else { return }
        if isPushing { pushAgain = true; return }
        isPushing = true
        defer { isPushing = false }

        repeat {
            pushAgain = false
            let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []

            // removals
            let localIDs = Set(books.compactMap(\.remoteID))
            for gone in knownRemote.subtracting(localIDs) {
                do {
                    try await supabase.from("user_books").delete().eq("id", value: gone).execute()
                    knownRemote.remove(gone)
                } catch { report(error, "delete") }
            }

            // additions and edits
            for book in books where book.syncFingerprint != book.syncedFingerprint {
                // read everything up front: the book could be deleted while we wait on the network
                let snapshot = BookSnapshot(book)
                do {
                    if let remoteID = snapshot.remoteID {
                        try await supabase.from("user_books")
                            .update(snapshot.patch)
                            .eq("id", value: remoteID)
                            .execute()
                    } else {
                        let catalogID = try await catalogBookID(for: snapshot)
                        let saved: IDRow = try await supabase.from("user_books")
                            .upsert(snapshot.insert(userID: userID, bookID: catalogID), onConflict: "user_id,book_id")
                            .select("id")
                            .single()
                            .execute()
                            .value
                        knownRemote.insert(saved.id)
                        if !book.isDeleted { book.remoteID = saved.id }
                    }
                    if !book.isDeleted { book.syncedFingerprint = snapshot.fingerprint }
                } catch {
                    report(error, "push \(snapshot.title)")
                }
            }
            try? context.save()
        } while pushAgain
    }

    /// The shared catalog row for this title. `books` has no update policy, so find-then-insert.
    private func catalogBookID(for book: BookSnapshot) async throws -> UUID {
        let key = book.catalogKey
        if let found = try await findCatalogBook(key: key) { return found }
        do {
            let inserted: IDRow = try await supabase.from("books")
                .insert(CatalogBookWrite(openLibraryKey: key, title: book.title, author: book.author, year: book.year, pageCount: book.pageCount))
                .select("id")
                .single()
                .execute()
                .value
            return inserted.id
        } catch {
            // someone else added it a moment ago
            if let found = try await findCatalogBook(key: key) { return found }
            throw error
        }
    }

    private func findCatalogBook(key: String) async throws -> UUID? {
        let rows: [IDRow] = try await supabase.from("books")
            .select("id")
            .eq("open_library_key", value: key)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    private func report(_ error: Error, _ step: String) {
        lastError = error.localizedDescription
        print("ShelfSync \(step) failed:", error)
    }
}

// MARK: - wire types

/// Plain copy of a book's values, safe to hold across awaits.
private struct BookSnapshot {
    let remoteID: UUID?
    let title: String
    let author: String
    let year: Int?
    let pageCount: Int
    let shelf: ShelfKind
    let currentPage: Int
    let isFavourite: Bool
    let spineHex: String
    let addedAt: Date
    let fingerprint: String

    init(_ book: Book) {
        remoteID = book.remoteID
        title = book.title
        author = book.author
        year = book.year
        pageCount = book.pageCount
        shelf = book.shelf
        currentPage = book.currentPage
        isFavourite = book.isFavourite
        spineHex = book.spineHex
        addedAt = book.addedAt
        fingerprint = book.syncFingerprint
    }

    /// Until Open Library search lands, catalog books are keyed by title + author.
    var catalogKey: String {
        "local:" + "\(title)|\(author)".lowercased().trimmingCharacters(in: .whitespaces)
    }

    var patch: UserBookPatch {
        UserBookPatch(shelf: shelf.remoteValue, currentPage: currentPage, isFavourite: isFavourite, spineHex: spineHex)
    }

    func insert(userID: UUID, bookID: UUID) -> UserBookInsert {
        UserBookInsert(userID: userID, bookID: bookID, shelf: shelf.remoteValue, currentPage: currentPage,
                       isFavourite: isFavourite, spineHex: spineHex, addedAt: addedAt)
    }
}

nonisolated struct IDRow: Decodable, Sendable {
    let id: UUID
}

nonisolated struct RemoteShelfRow: Decodable, Sendable {
    let id: UUID
    let shelf: String
    let currentPage: Int
    let isFavourite: Bool
    let spineHex: String
    let addedAt: Date
    let book: RemoteBook

    enum CodingKeys: String, CodingKey {
        case id, shelf, book
        case currentPage = "current_page"
        case isFavourite = "is_favourite"
        case spineHex = "spine_hex"
        case addedAt = "added_at"
    }
}

nonisolated struct RemoteBook: Decodable, Sendable {
    let id: UUID
    let title: String
    let author: String
    let year: Int?
    let pageCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, author, year
        case pageCount = "page_count"
    }
}

nonisolated struct CatalogBookWrite: Encodable, Sendable {
    let openLibraryKey: String
    let title: String
    let author: String
    let year: Int?
    let pageCount: Int

    enum CodingKeys: String, CodingKey {
        case title, author, year
        case openLibraryKey = "open_library_key"
        case pageCount = "page_count"
    }
}

nonisolated struct UserBookPatch: Encodable, Sendable {
    let shelf: String
    let currentPage: Int
    let isFavourite: Bool
    let spineHex: String

    enum CodingKeys: String, CodingKey {
        case shelf
        case currentPage = "current_page"
        case isFavourite = "is_favourite"
        case spineHex = "spine_hex"
    }
}

nonisolated struct UserBookInsert: Encodable, Sendable {
    let userID: UUID
    let bookID: UUID
    let shelf: String
    let currentPage: Int
    let isFavourite: Bool
    let spineHex: String
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case shelf
        case userID = "user_id"
        case bookID = "book_id"
        case currentPage = "current_page"
        case isFavourite = "is_favourite"
        case spineHex = "spine_hex"
        case addedAt = "added_at"
    }
}
