import Foundation
import SwiftData
import Supabase

/// The club side: members, meetups, RSVPs and next month's vote.
/// The server owns all of it, so we pull it into SwiftData and send each tap straight up.
@Observable
final class ClubSync {
    static let shared = ClubSync()

    private(set) var lastError: String?

    private var context: ModelContext?
    private var userID: UUID?
    private var clubID: UUID?
    private var channel: RealtimeChannelV2?
    private var listeners: [Task<Void, Never>] = []
    private var pullTask: Task<Void, Never>?
    private var isPulling = false
    private var pullAgain = false

    // MARK: lifecycle

    func start(context: ModelContext, userID: UUID) async {
        guard let clubID = UUID(uuidString: UserDefaults.standard.string(forKey: AppKeys.clubID) ?? "") else { return }
        self.context = context
        self.userID = userID
        self.clubID = clubID
        await pull()
        await subscribe(clubID: clubID)
    }

    func stop() {
        listeners.forEach { $0.cancel() }
        listeners = []
        if let channel {
            self.channel = nil
            Task { await supabase.removeChannel(channel) }
        }
        context = nil
        userID = nil
        clubID = nil
    }

    /// Lots of Realtime pings arrive together (a vote, then a re-vote). One pull covers them.
    private func schedulePull() {
        pullTask?.cancel()
        pullTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.pull()
        }
    }

    private func subscribe(clubID: UUID) async {
        listeners.forEach { $0.cancel() }
        if let old = channel { await supabase.removeChannel(old) }

        let filter = "club_id=eq.\(clubID.uuidString)"
        let channel = supabase.channel("club-\(clubID.uuidString)")
        let streams = [
            channel.postgresChange(AnyAction.self, schema: "public", table: "meetups", filter: filter),
            channel.postgresChange(AnyAction.self, schema: "public", table: "rsvps"),      // RLS keeps it to your club
            channel.postgresChange(AnyAction.self, schema: "public", table: "pick_options", filter: filter),
            channel.postgresChange(AnyAction.self, schema: "public", table: "pick_votes", filter: filter),
            channel.postgresChange(AnyAction.self, schema: "public", table: "club_members", filter: filter),
        ]
        await channel.subscribe()
        self.channel = channel
        listeners = streams.map { stream in
            Task { [weak self] in
                for await _ in stream { self?.schedulePull() }
            }
        }
    }

    // MARK: pull

    func pull() async {
        guard let context, let userID, let clubID else { return }
        if isPulling { pullAgain = true; return }
        isPulling = true
        defer { isPulling = false }

        repeat {
            pullAgain = false
            do {
                let members: [RemoteMember] = try await supabase.from("club_members")
                    .select("user_id, role, joined_at, profile:profiles(display_name, avatar_hex, silhouette)")
                    .eq("club_id", value: clubID)
                    .execute().value

                let others = members.map(\.userID).filter { $0 != userID }
                var shelves: [RemoteMemberBook] = []
                if !others.isEmpty {
                    shelves = try await supabase.from("user_books")
                        .select("user_id, shelf, current_page, added_at, book:books(title)")
                        .in("user_id", values: others.map(\.uuidString))
                        .execute().value
                }

                let meetups: [RemoteMeetup] = try await supabase.from("meetups")
                    .select("id, number, starts_at, place, address, read_up_to, bringing, book:books(title, author), rsvps(user_id, status)")
                    .eq("club_id", value: clubID)
                    .order("number", ascending: false)
                    .limit(3)
                    .execute().value

                let options: [RemotePickOption] = try await supabase.from("pick_options")
                    .select("id, book_id, closes_at, book:books(title, author)")
                    .eq("club_id", value: clubID)
                    .execute().value

                let votes: [RemoteVote] = try await supabase.from("pick_votes")
                    .select("user_id, option_id")
                    .eq("club_id", value: clubID)
                    .execute().value

                // the ledger: every past meetup, with the club's average rating from notes
                let ledger: [RemoteLedgerRow] = try await supabase.from("club_ledger")
                    .select("meetup_id, starts_at, title, author, book_id, club_rating")
                    .eq("club_id", value: clubID)
                    .order("starts_at", ascending: false)
                    .execute().value
                let myRatings: [RemoteMyRating] = try await supabase.from("notes")
                    .select("book_id, rating, created_at")
                    .eq("club_id", value: clubID)
                    .eq("author_id", value: userID)
                    .execute().value

                let club: RemoteClubInfo = try await supabase.from("clubs")
                    .select("name, created_at")
                    .eq("id", value: clubID)
                    .single()
                    .execute().value
                UserDefaults.standard.set(club.name, forKey: AppKeys.clubName)
                UserDefaults.standard.set(Calendar.current.component(.year, from: club.createdAt), forKey: AppKeys.clubFoundedYear)

                applyMembers(members, shelves: shelves, me: userID, in: context)
                applyLedger(ledger, myRatings: myRatings, in: context)
                applyMeetups(meetups, me: userID, in: context)
                applyPicks(options, votes: votes, me: userID, in: context)
                try? context.save()
                lastError = nil
            } catch {
                report(error, "pull")
            }
        } while pullAgain
    }

    private func applyMembers(_ rows: [RemoteMember], shelves: [RemoteMemberBook], me: UUID, in context: ModelContext) {
        if let mine = rows.first(where: { $0.userID == me }) {
            let defaults = UserDefaults.standard
            defaults.set(mine.role == "host", forKey: AppKeys.isHost)
            // your portrait follows you to a new phone
            if let pick = mine.profile?.silhouette { defaults.set(pick, forKey: AppKeys.mySilhouette) }
            if let hex = mine.profile?.avatarHex { defaults.set(hex, forKey: AppKeys.myAvatarHex) }
        }
        let others = rows.filter { $0.userID != me }
        let local = (try? context.fetch(FetchDescriptor<ClubMember>())) ?? []
        let byID = upsertIndex(local, id: \.remoteID, keep: Set(others.map(\.userID)), in: context)

        let booksByUser = Dictionary(grouping: shelves, by: \.userID)
        for row in others {
            let member = byID[row.userID] ?? {
                let new = ClubMember(name: "", colorHex: Theme.Spine.forest, booksRead: 0, status: "")
                new.remoteID = row.userID
                context.insert(new)
                return new
            }()
            let name = row.profile?.displayName ?? ""
            member.name = name.isEmpty ? "A member" : name
            member.colorHex = Self.colorHex(for: row)
            member.silhouette = row.profile?.silhouette ?? -1
            member.isHost = row.role == "host"
            member.joinedAt = row.joinedAt

            let books = booksByUser[row.userID] ?? []
            member.booksRead = books.filter { $0.shelf == "finished" }.count
            if let reading = books.filter({ $0.shelf == "reading" }).max(by: { $0.addedAt < $1.addedAt }) {
                member.status = "\(reading.book.title) · p. \(reading.currentPage)"
            } else if let last = books.filter({ $0.shelf == "finished" }).max(by: { $0.addedAt < $1.addedAt }) {
                member.status = "Finished \(last.book.title)"
            } else {
                member.status = "Just joined"
            }
        }
    }

    private func applyLedger(_ rows: [RemoteLedgerRow], myRatings: [RemoteMyRating], in context: ModelContext) {
        let local = (try? context.fetch(FetchDescriptor<LedgerEntry>())) ?? []
        let byID = upsertIndex(local, id: \.remoteID, keep: Set(rows.map(\.meetupID)), in: context)

        // your latest rating for each book
        var mine: [UUID: Int] = [:]
        for rating in myRatings.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let stars = rating.rating { mine[rating.bookID] = stars }
        }

        for row in rows {
            let entry = byID[row.meetupID] ?? {
                let new = LedgerEntry(month: row.startsAt, title: row.title, author: row.author, clubRating: 0, spineHex: "")
                new.remoteID = row.meetupID
                context.insert(new)
                return new
            }()
            entry.month = row.startsAt
            entry.title = row.title
            entry.author = row.author
            entry.clubRating = row.clubRating ?? 0          // 0 = nobody rated it yet
            entry.myRating = mine[row.bookID]
            entry.spineHex = Catalog.spineHex(for: row.title)
        }
    }

    private func applyMeetups(_ rows: [RemoteMeetup], me: UUID, in context: ModelContext) {
        let local = (try? context.fetch(FetchDescriptor<Meetup>())) ?? []
        let byID = upsertIndex(local, id: \.remoteID, keep: Set(rows.map(\.id)), in: context)

        for row in rows {
            let meetup = byID[row.id] ?? {
                let new = Meetup(number: row.number, date: row.startsAt, place: row.place, bookTitle: "", readUpTo: "")
                new.remoteID = row.id
                context.insert(new)
                return new
            }()
            meetup.number = row.number
            meetup.date = row.startsAt
            meetup.place = row.place
            meetup.address = row.address
            meetup.readUpTo = row.readUpTo
            meetup.bringing = row.bringing
            meetup.bookTitle = row.book?.title ?? "To be decided"
            meetup.bookAuthor = row.book?.author ?? ""
            meetup.spineHex = Catalog.spineHex(for: meetup.bookTitle)

            let others = row.rsvps.filter { $0.userID != me }
            let going = others.filter { $0.status == "going" }
            meetup.goingIDs = going.map(\.userID.uuidString)
            meetup.goingCount = going.count
            meetup.maybeCount = others.filter { $0.status == "maybe" }.count
            meetup.rsvpRaw = row.rsvps.first { $0.userID == me }
                .flatMap { Meetup.RSVP(remoteValue: $0.status) }?.rawValue ?? ""
        }
    }

    private func applyPicks(_ rows: [RemotePickOption], votes: [RemoteVote], me: UUID, in context: ModelContext) {
        let local = (try? context.fetch(FetchDescriptor<PickOption>())) ?? []
        let byID = upsertIndex(local, id: \.remoteID, keep: Set(rows.map(\.id)), in: context)
        let myVote = votes.first { $0.userID == me }?.optionID

        for row in rows {
            let option = byID[row.id] ?? {
                let new = PickOption(title: "", author: "", votes: 0)
                new.remoteID = row.id
                context.insert(new)
                return new
            }()
            option.catalogID = row.bookID
            option.title = row.book?.title ?? "Untitled"
            option.author = row.book?.author ?? ""
            option.votes = votes.filter { $0.optionID == row.id && $0.userID != me }.count
            option.isMyVote = myVote == row.id
        }
    }

    /// Deletes local rows that aren't on the server (including leftover sample data) and indexes the rest by id.
    private func upsertIndex<T: PersistentModel>(_ local: [T], id: KeyPath<T, UUID?>, keep: Set<UUID>,
                                                in context: ModelContext) -> [UUID: T] {
        var index: [UUID: T] = [:]
        for model in local {
            if let remote = model[keyPath: id], keep.contains(remote), index[remote] == nil {
                index[remote] = model
            } else {
                context.delete(model)
            }
        }
        return index
    }

    private static let palette = [Theme.Spine.rust, Theme.Spine.forest, Theme.Spine.navy, Theme.Spine.plum,
                                  Theme.Spine.olive, Theme.Spine.mustard, Theme.Spine.oxblood]

    /// Their chosen colour, or one picked from their id until they choose.
    private static func colorHex(for row: RemoteMember) -> String {
        if let hex = row.profile?.avatarHex, !hex.isEmpty { return hex }
        let sum = row.userID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    // MARK: actions (each one updates the UI right away, then the server)

    func setRSVP(_ status: Meetup.RSVP, for meetup: Meetup) async {
        guard let userID, let meetupID = meetup.remoteID else { return }
        do {
            try await supabase.from("rsvps")
                .upsert(RSVPWrite(meetupID: meetupID, userID: userID, status: status.remoteValue, updatedAt: .now),
                        onConflict: "meetup_id,user_id")
                .execute()
        } catch {
            report(error, "rsvp")
            await pull()        // put the screen back to what the server has
        }
    }

    /// Pass nil to take your vote back.
    func vote(for option: PickOption?) async {
        guard let userID, let clubID else { return }
        do {
            if let optionID = option?.remoteID {
                try await supabase.from("pick_votes")
                    .upsert(VoteWrite(clubID: clubID, userID: userID, optionID: optionID), onConflict: "club_id,user_id")
                    .execute()
            } else {
                try await supabase.from("pick_votes").delete()
                    .eq("club_id", value: clubID)
                    .eq("user_id", value: userID)
                    .execute()
            }
        } catch {
            report(error, "vote")
            await pull()
        }
    }

    /// Host: put a book up for next month's vote.
    func addPickOption(catalogID: UUID?, title: String, author: String, year: Int?, pageCount: Int) async throws {
        guard let clubID else { return }
        let bookID = try await resolve(catalogID, title: title, author: author, year: year, pageCount: pageCount)
        try await supabase.from("pick_options")
            .upsert(PickOptionWrite(clubID: clubID, bookID: bookID), onConflict: "club_id,book_id")
            .execute()
        await pull()
    }

    /// Host: send next month's meetup to the club. Clears the vote so a fresh one can start.
    func planMeetup(number: Int, date: Date, place: String, readUpTo: String,
                    catalogID: UUID?, title: String, author: String, year: Int?, pageCount: Int) async throws {
        guard let clubID else { return }
        let bookID = try await resolve(catalogID, title: title, author: author, year: year, pageCount: pageCount)
        try await supabase.from("meetups")
            .insert(MeetupWrite(clubID: clubID, number: number, bookID: bookID, startsAt: date, place: place, readUpTo: readUpTo))
            .execute()
        try? await supabase.from("pick_options").delete().eq("club_id", value: clubID).execute()
        await pull()
    }

    private func resolve(_ catalogID: UUID?, title: String, author: String, year: Int?, pageCount: Int) async throws -> UUID {
        if let catalogID { return catalogID }
        return try await CatalogService.bookID(title: title, author: author, year: year, pageCount: pageCount)
    }

    private func report(_ error: Error, _ step: String) {
        lastError = error.localizedDescription
        print("ClubSync \(step) failed:", error)
    }
}

// MARK: - wire types

nonisolated struct RemoteMember: Decodable, Sendable {
    nonisolated struct Profile: Decodable, Sendable {
        let displayName: String?
        let avatarHex: String?
        let silhouette: Int?
        enum CodingKeys: String, CodingKey {
            case silhouette
            case displayName = "display_name"
            case avatarHex = "avatar_hex"
        }
    }
    let userID: UUID
    let role: String
    let joinedAt: Date
    let profile: Profile?
    enum CodingKeys: String, CodingKey {
        case role, profile
        case userID = "user_id"
        case joinedAt = "joined_at"
    }
}

nonisolated struct RemoteMemberBook: Decodable, Sendable {
    nonisolated struct Book: Decodable, Sendable { let title: String }
    let userID: UUID
    let shelf: String
    let currentPage: Int
    let addedAt: Date
    let book: Book
    enum CodingKeys: String, CodingKey {
        case shelf, book
        case userID = "user_id"
        case currentPage = "current_page"
        case addedAt = "added_at"
    }
}

nonisolated struct RemoteLedgerRow: Decodable, Sendable {
    let meetupID: UUID
    let startsAt: Date
    let title: String
    let author: String
    let bookID: UUID
    let clubRating: Double?
    enum CodingKeys: String, CodingKey {
        case title, author
        case meetupID = "meetup_id"
        case startsAt = "starts_at"
        case bookID = "book_id"
        case clubRating = "club_rating"
    }
}

nonisolated struct RemoteMyRating: Decodable, Sendable {
    let bookID: UUID
    let rating: Int?
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case rating
        case bookID = "book_id"
        case createdAt = "created_at"
    }
}

nonisolated struct RemoteClubInfo: Decodable, Sendable {
    let name: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case name
        case createdAt = "created_at"
    }
}

nonisolated struct RemoteBookTitle: Decodable, Sendable {
    let title: String
    let author: String
}

nonisolated struct RemoteMeetup: Decodable, Sendable {
    nonisolated struct RSVP: Decodable, Sendable {
        let userID: UUID
        let status: String
        enum CodingKeys: String, CodingKey {
            case status
            case userID = "user_id"
        }
    }
    let id: UUID
    let number: Int
    let startsAt: Date
    let place: String
    let address: String
    let readUpTo: String
    let bringing: String
    let book: RemoteBookTitle?
    let rsvps: [RSVP]
    enum CodingKeys: String, CodingKey {
        case id, number, place, address, bringing, book, rsvps
        case startsAt = "starts_at"
        case readUpTo = "read_up_to"
    }
}

nonisolated struct RemotePickOption: Decodable, Sendable {
    let id: UUID
    let bookID: UUID
    let book: RemoteBookTitle?
    enum CodingKeys: String, CodingKey {
        case id, book
        case bookID = "book_id"
    }
}

nonisolated struct RemoteVote: Decodable, Sendable {
    let userID: UUID
    let optionID: UUID
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case optionID = "option_id"
    }
}

nonisolated struct RSVPWrite: Encodable, Sendable {
    let meetupID: UUID
    let userID: UUID
    let status: String
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case status
        case meetupID = "meetup_id"
        case userID = "user_id"
        case updatedAt = "updated_at"
    }
}

nonisolated struct VoteWrite: Encodable, Sendable {
    let clubID: UUID
    let userID: UUID
    let optionID: UUID
    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case userID = "user_id"
        case optionID = "option_id"
    }
}

nonisolated struct PickOptionWrite: Encodable, Sendable {
    let clubID: UUID
    let bookID: UUID
    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case bookID = "book_id"
    }
}

nonisolated struct MeetupWrite: Encodable, Sendable {
    let clubID: UUID
    let number: Int
    let bookID: UUID
    let startsAt: Date
    let place: String
    let readUpTo: String
    enum CodingKeys: String, CodingKey {
        case number, place
        case clubID = "club_id"
        case bookID = "book_id"
        case startsAt = "starts_at"
        case readUpTo = "read_up_to"
    }
}
