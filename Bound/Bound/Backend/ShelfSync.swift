import Foundation
import SwiftData
import Supabase

/// Keeps your shelves (SwiftData `Book`) in step with Supabase `user_books` + `books`,
/// and club notes (`Note`) in step with `notes`, live over Realtime.
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
    private var notesChannel: RealtimeChannelV2?
    private var notesListener: Task<Void, Never>?
    private var notesPullWaiting = false

    private var clubID: UUID? { UUID(uuidString: UserDefaults.standard.string(forKey: AppKeys.clubID) ?? "") }
    private var memberName: String { UserDefaults.standard.string(forKey: AppKeys.memberName) ?? "" }

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
        await subscribeToNotes()
    }

    func stop() {
        listener?.cancel()
        notesListener?.cancel()
        if let channel = notesChannel {
            notesChannel = nil
            Task { await supabase.removeChannel(channel) }
        }
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
                .select("id, shelf, current_page, is_favourite, spine_hex, added_at, book:books(id, title, author, year, page_count, open_library_key)")
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
            book.catalogID = row.book.id
            if let key = row.book.openLibraryKey, !key.hasPrefix("local:") { book.openLibraryKey = key }
            book.syncedFingerprint = book.syncFingerprint
        }

        knownRemote = remoteIDs
        try? context.save()
        defaults.set(userID.uuidString, forKey: Self.syncedUserKey)
        lastError = nil

        // books added here before they were ever pushed
        await pushChanges()
        await pullNotes()
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
                        let catalogID = try await CatalogService.bookID(title: snapshot.title, author: snapshot.author,
                                                                       year: snapshot.year, pageCount: snapshot.pageCount,
                                                                       openLibraryKey: snapshot.openLibraryKey)
                        let saved: IDRow = try await supabase.from("user_books")
                            .upsert(snapshot.insert(userID: userID, bookID: catalogID), onConflict: "user_id,book_id")
                            .select("id")
                            .single()
                            .execute()
                            .value
                        knownRemote.insert(saved.id)
                        if !book.isDeleted {
                            book.remoteID = saved.id
                            book.catalogID = catalogID
                        }
                    }
                    if !book.isDeleted { book.syncedFingerprint = snapshot.fingerprint }
                } catch {
                    report(error, "push \(snapshot.title)")
                }
            }
            await pushNotes(userID: userID)
            try? context.save()
        } while pushAgain

        // a Realtime ping came in mid-push; pull now that our ids are saved
        if notesPullWaiting {
            notesPullWaiting = false
            await pullNotes()
        }
    }

    // MARK: notes

    /// Club notes for every book on your shelves. Yours and your clubmates'.
    func pullNotes() async {
        guard let context, let clubID else { return }
        // pulling mid-push could duplicate a note we're still posting
        if isPushing { notesPullWaiting = true; return }

        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        var byCatalog: [UUID: Book] = [:]
        for book in books { if let id = book.catalogID { byCatalog[id] = book } }
        guard !byCatalog.isEmpty else { return }

        let rows: [RemoteNote]
        do {
            rows = try await supabase.from("notes")
                .select("id, book_id, author_id, body, rating, page, contains_spoilers, discuss_at_meetup, created_at, author:profiles(display_name)")
                .eq("club_id", value: clubID)
                .in("book_id", values: byCatalog.keys.map(\.uuidString))
                .execute()
                .value
        } catch {
            report(error, "pull notes")
            return
        }
        if isPushing { notesPullWaiting = true; return }

        let localNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        var byRemoteID: [UUID: Note] = [:]
        for note in localNotes {
            guard let id = note.remoteID else { continue }
            if byRemoteID[id] != nil { context.delete(note) } else { byRemoteID[id] = note }
        }

        let remoteIDs = Set(rows.map(\.id))
        // deleted by their author
        for (id, note) in byRemoteID where !remoteIDs.contains(id) {
            if let catalog = note.book?.catalogID, byCatalog[catalog] != nil { context.delete(note) }
        }

        let me = userID
        for row in rows {
            guard let book = byCatalog[row.bookID] else { continue }
            let note: Note
            if let existing = byRemoteID[row.id] {
                note = existing
            } else {
                note = Note(authorName: "", text: row.body, page: row.page)
                note.remoteID = row.id
                context.insert(note)
            }
            let name = row.author?.displayName ?? ""
            note.authorName = row.authorID == me ? (memberName.isEmpty ? name : memberName) : (name.isEmpty ? "A member" : name)
            note.authorID = row.authorID
            note.text = row.body
            note.rating = row.rating
            note.page = row.page
            note.containsSpoilers = row.containsSpoilers
            note.discussAtMeetup = row.discussAtMeetup
            note.createdAt = row.createdAt
            if note.book !== book { note.book = book }
        }
        try? context.save()
    }

    /// Posts notes written here that aren't on the server yet.
    private func pushNotes(userID: UUID) async {
        guard let context, let clubID else { return }
        let notes = (try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.remoteID == nil }))) ?? []
        for note in notes {
            guard let bookID = note.book?.catalogID else { continue }     // its book hasn't synced yet
            let write = NoteWrite(clubID: clubID, bookID: bookID, authorID: userID, body: note.text, rating: note.rating,
                                  page: note.page, containsSpoilers: note.containsSpoilers,
                                  discussAtMeetup: note.discussAtMeetup, createdAt: note.createdAt)
            do {
                let saved: IDRow = try await supabase.from("notes").insert(write).select("id").single().execute().value
                if !note.isDeleted {
                    note.remoteID = saved.id
                    note.authorID = userID
                }
            } catch {
                report(error, "post note")
            }
        }
    }

    /// Your edit to a note. Not posted yet? It just goes up with the new text later.
    func updateNote(_ note: Note, text: String, rating: Int?, page: Int, containsSpoilers: Bool, discussAtMeetup: Bool) async throws {
        if let remoteID = note.remoteID {
            try await supabase.from("notes")
                .update(NotePatch(body: text, rating: rating, page: page,
                                  containsSpoilers: containsSpoilers, discussAtMeetup: discussAtMeetup))
                .eq("id", value: remoteID)
                .execute()
        }
        guard !note.isDeleted else { return }
        note.text = text
        note.rating = rating
        note.page = page
        note.containsSpoilers = containsSpoilers
        note.discussAtMeetup = discussAtMeetup
        try? context?.save()
    }

    /// Removes your note for everyone. If the server can't be reached it stays, so it never quietly comes back.
    func deleteNote(_ note: Note) async throws {
        if let remoteID = note.remoteID {
            try await supabase.from("notes").delete().eq("id", value: remoteID).execute()
        }
        guard !note.isDeleted, let context = note.modelContext else { return }
        context.delete(note)
        try? context.save()
    }

    /// Live: a clubmate posts a note → we pull notes.
    private func subscribeToNotes() async {
        guard let clubID else { return }
        notesListener?.cancel()
        if let old = notesChannel { await supabase.removeChannel(old) }

        let channel = supabase.channel("notes-\(clubID.uuidString)")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "notes",
                                             filter: "club_id=eq.\(clubID.uuidString)")
        await channel.subscribe()
        notesChannel = channel
        notesListener = Task { [weak self] in
            for await _ in changes { await self?.pullNotes() }
        }
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
    let openLibraryKey: String?

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
        openLibraryKey = book.openLibraryKey
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
    let openLibraryKey: String?

    enum CodingKeys: String, CodingKey {
        case id, title, author, year
        case pageCount = "page_count"
        case openLibraryKey = "open_library_key"
    }
}

nonisolated struct RemoteNote: Decodable, Sendable {
    nonisolated struct Author: Decodable, Sendable {
        let displayName: String?
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }

    let id: UUID
    let bookID: UUID
    let authorID: UUID
    let body: String
    let rating: Int?
    let page: Int
    let containsSpoilers: Bool
    let discussAtMeetup: Bool
    let createdAt: Date
    let author: Author?

    enum CodingKeys: String, CodingKey {
        case id, body, rating, page, author
        case bookID = "book_id"
        case authorID = "author_id"
        case containsSpoilers = "contains_spoilers"
        case discussAtMeetup = "discuss_at_meetup"
        case createdAt = "created_at"
    }
}

nonisolated struct NotePatch: Encodable, Sendable {
    let body: String
    let rating: Int?
    let page: Int
    let containsSpoilers: Bool
    let discussAtMeetup: Bool

    enum CodingKeys: String, CodingKey {
        case body, rating, page
        case containsSpoilers = "contains_spoilers"
        case discussAtMeetup = "discuss_at_meetup"
    }

    // send rating as null when cleared, so taking stars away actually sticks
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(body, forKey: .body)
        try c.encode(rating, forKey: .rating)
        try c.encode(page, forKey: .page)
        try c.encode(containsSpoilers, forKey: .containsSpoilers)
        try c.encode(discussAtMeetup, forKey: .discussAtMeetup)
    }
}

nonisolated struct NoteWrite: Encodable, Sendable {
    let clubID: UUID
    let bookID: UUID
    let authorID: UUID
    let body: String
    let rating: Int?
    let page: Int
    let containsSpoilers: Bool
    let discussAtMeetup: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case body, rating, page
        case clubID = "club_id"
        case bookID = "book_id"
        case authorID = "author_id"
        case containsSpoilers = "contains_spoilers"
        case discussAtMeetup = "discuss_at_meetup"
        case createdAt = "created_at"
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
