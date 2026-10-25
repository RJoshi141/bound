import Foundation
import Supabase

/// One shared client for the whole app.
let supabase = SupabaseClient(supabaseURL: Secrets.supabaseURL, supabaseKey: Secrets.supabaseAnonKey)

/// Club as returned by the create_club / join_club functions.
struct ClubRecord: Decodable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
    }
}

struct MembershipRecord: Decodable, Sendable {
    let role: String
    let club: ClubRecord
}

nonisolated struct AvatarPatch: Encodable, Sendable {
    let silhouette: Int
    let avatarHex: String
    enum CodingKeys: String, CodingKey {
        case silhouette
        case avatarHex = "avatar_hex"
    }
}

private struct NameRecord: Decodable, Sendable {
    let displayName: String?
    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
}

/// The shared `books` catalog. It has no update policy, so it's find-then-insert.
enum CatalogService {
    /// Until Open Library search lands, catalog books are keyed by title + author.
    static func key(title: String, author: String) -> String {
        "local:" + "\(title)|\(author)".lowercased().trimmingCharacters(in: .whitespaces)
    }

    static func bookID(title: String, author: String, year: Int?, pageCount: Int,
                       openLibraryKey: String? = nil) async throws -> UUID {
        let key = openLibraryKey ?? key(title: title, author: author)
        if let found = try await find(key: key) { return found }
        do {
            let inserted: IDRow = try await supabase.from("books")
                .insert(CatalogBookWrite(openLibraryKey: key, title: title, author: author, year: year, pageCount: pageCount))
                .select("id")
                .single()
                .execute()
                .value
            return inserted.id
        } catch {
            // someone else added it a moment ago
            if let found = try await find(key: key) { return found }
            throw error
        }
    }

    private static func find(key: String) async throws -> UUID? {
        let rows: [IDRow] = try await supabase.from("books")
            .select("id")
            .eq("open_library_key", value: key)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }
}

enum ClubService {
    /// The first club you belong to (one club per person for now).
    static func myClub(userID: UUID) async throws -> MembershipRecord? {
        let rows: [MembershipRecord] = try await supabase.from("club_members")
            .select("role, club:clubs(id, name, invite_code)")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Your portrait: which silhouette and which colour.
    static func setAvatar(silhouette: Int, hex: String, for userID: UUID) async throws {
        try await supabase.from("profiles")
            .update(AvatarPatch(silhouette: silhouette, avatarHex: hex))
            .eq("id", value: userID)
            .execute()
    }

    static func displayName(for userID: UUID) async throws -> String? {
        let row: NameRecord = try await supabase.from("profiles")
            .select("display_name")
            .eq("id", value: userID)
            .single()
            .execute()
            .value
        return row.displayName
    }

    /// Checks the invite code on the server and adds you as a member.
    static func join(code: String) async throws -> ClubRecord {
        try await supabase.rpc("join_club", params: ["code": code]).execute().value
    }

    /// Creates the club and makes you its host.
    static func create(name: String) async throws -> ClubRecord {
        try await supabase.rpc("create_club", params: ["club_name": name]).execute().value
    }

    static func setDisplayName(_ name: String, for userID: UUID) async throws {
        try await supabase.from("profiles")
            .update(["display_name": name])
            .eq("id", value: userID)
            .execute()
    }
}
