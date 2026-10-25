import Foundation
import Observation
import Supabase

/// Passwordless sign-in: we email a 6-digit code, the user types it in.
/// (Codes instead of magic links means no deep-link setup, and it matches the invite-code boxes.)
@Observable
final class AuthStore {
    private(set) var session: Session?
    var userID: UUID? { session?.user.id }
    var isSignedIn: Bool { session != nil }

    /// Restores a saved session and keeps listening for sign-in / sign-out.
    func start() async {
        session = try? await supabase.auth.session
        for await (_, newSession) in supabase.auth.authStateChanges {
            session = newSession
        }
    }

    func sendCode(to email: String) async throws {
        try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    func verify(email: String, code: String) async throws {
        try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
        session = try? await supabase.auth.session
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        session = nil
    }
}
