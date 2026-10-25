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

private struct NameRecord: Decodable, Sendable {
    let displayName: String?
    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
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
