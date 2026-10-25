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

enum ClubService {
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
