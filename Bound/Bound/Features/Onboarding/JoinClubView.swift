import Foundation
import SwiftUI
import UIKit

/// Join or start a club. Two phases:
///   1. details: invite code (or club name), first name, email → we email a sign-in code
///   2. code: type the 6-digit code → sign in → join/create the club on the server
struct JoinClubView: View {
    enum Mode { case join, start }
    enum Phase { case details, code }

    /// Must match Supabase → Authentication → Sign In / Providers → Email → "Email OTP Length".
    static let signInCodeLength = 8

    let mode: Mode
    let onBack: () -> Void

    @Environment(AuthStore.self) private var auth
    @AppStorage(AppKeys.hasJoinedClub) private var hasJoined = false
    @AppStorage(AppKeys.memberName) private var memberName = ""
    @AppStorage(AppKeys.clubName) private var clubName = "Tuesday Night Readers"
    @AppStorage(AppKeys.clubID) private var clubID = ""
    @AppStorage(AppKeys.inviteCode) private var inviteCode = ""
    @AppStorage(AppKeys.isHost) private var isHost = false

    @State private var phase: Phase = .details
    @State private var code = ""
    @State private var newClubName = ""
    @State private var name = ""
    @State private var email = ""
    @State private var otp = ""
    @State private var importHistory = true
    @State private var isWorking = false
    @State private var errorText: String?
    @FocusState private var codeFocused: Bool
    @FocusState private var otpFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces).lowercased() }

    private var detailsReady: Bool {
        let base = !trimmedName.isEmpty && trimmedEmail.contains("@") && trimmedEmail.contains(".")
        switch mode {
        case .join: return base && code.count == 6
        case .start: return base && !newClubName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BackButton(title: "Back", color: Theme.Colors.card) {
                    if phase == .code { withAnimation { phase = .details; otp = ""; errorText = nil } } else { onBack() }
                }
                Spacer()
                MonoLabel(phase == .details ? "Step 1 of 2" : "Step 2 of 2", color: Theme.Colors.card.opacity(0.75))
            }
            .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch phase {
                    case .details: detailsForm
                    case .code: codeForm
                    }

                    if let errorText {
                        Text(errorText)
                            .font(Theme.Fonts.body(14, weight: .semibold))
                            .foregroundStyle(Color(hex: "F2B8A2"))
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .animation(.easeInOut(duration: 0.25), value: phase)
                .animation(.easeInOut(duration: 0.2), value: errorText)
            }

            Button(action: primaryAction) {
                HStack(spacing: 10) {
                    if isWorking { ProgressView().tint(Theme.Colors.card) }
                    Text(primaryTitle)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!primaryEnabled || isWorking)
            .opacity(primaryEnabled ? 1 : 0.45)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .foregroundStyle(Theme.Colors.card)
        // backdrop lives in OnboardingView so it's full-screen from the first frame of the tear
        .onAppear { if mode == .join { codeFocused = true } }
    }

    // MARK: phases

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(mode == .join ? "Join your club" : "Start a club")
                    .font(Theme.Fonts.display(44))
                Text(mode == .join
                     ? "Ask your host for the 6-character invite code."
                     : "Name your club. You'll get a code to share with members.")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.card.opacity(0.8))
            }

            if mode == .join {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite code").font(Theme.Fonts.body(13, weight: .semibold))
                    CodeBoxes(text: $code, focused: $codeFocused, allowLetters: true)
                }
            } else {
                field("Club name", text: $newClubName, prompt: "Tuesday Night Readers")
            }

            field("Your first name", text: $name, prompt: "Ana", content: .givenName)
            field("Email", text: $email, prompt: "you@example.com", content: .emailAddress, keyboard: .emailAddress)

            Toggle(isOn: $importHistory) {
                Text("Import my reading history from Goodreads or StoryGraph")
                    .font(Theme.Fonts.body(15))
            }
            .tint(Theme.Colors.forest)
        }
    }

    private var codeForm: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Check your email").font(Theme.Fonts.display(44))
                Text("We sent a \(Self.signInCodeLength)-digit sign-in code to \(trimmedEmail).")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.card.opacity(0.8))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Sign-in code").font(Theme.Fonts.body(13, weight: .semibold))
                CodeBoxes(text: $otp, focused: $otpFocused, allowLetters: false, length: Self.signInCodeLength)
            }
            Button("Resend code") { Task { await sendCode() } }
                .buttonStyle(SmallButtonStyle(color: Theme.Colors.card))
                .disabled(isWorking)
        }
        .onAppear { otpFocused = true }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String,
                       content: UITextContentType? = nil, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Theme.Fonts.body(13, weight: .semibold))
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.Colors.inkMuted))
                .font(Theme.Fonts.body(17))
                .foregroundStyle(Theme.Colors.ink)
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Theme.Colors.card)
                .overlay(Rectangle().stroke(Theme.Colors.lineStrong, lineWidth: 1.5))
        }
    }

    // MARK: actions

    private var primaryTitle: String {
        switch phase {
        case .details: "Email me a code"
        case .code: mode == .join ? "Join club" : "Create club"
        }
    }

    private var primaryEnabled: Bool {
        phase == .details ? detailsReady : otp.count == Self.signInCodeLength
    }

    private func primaryAction() {
        Task {
            switch phase {
            case .details:
                if await sendCode() { withAnimation { phase = .code } }
            case .code:
                await verifyAndFinish()
            }
        }
    }

    @discardableResult
    private func sendCode() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.sendCode(to: trimmedEmail)
            errorText = nil
            return true
        } catch {
            errorText = "Couldn't send the code. Check the email address and try again."
            return false
        }
    }

    private func verifyAndFinish() async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await auth.verify(email: trimmedEmail, code: otp)
        } catch {
            errorText = "That code didn't work. Check the latest email, or resend."
            return
        }

        do {
            let club = mode == .join
                ? try await ClubService.join(code: code)
                : try await ClubService.create(name: newClubName.trimmingCharacters(in: .whitespaces))
            if let userID = auth.userID {
                try? await ClubService.setDisplayName(trimmedName, for: userID)
            }
            memberName = trimmedName
            clubName = club.name
            clubID = club.id.uuidString
            inviteCode = club.inviteCode
            isHost = mode == .start
            hasJoined = true     // ContentView animates the tear
        } catch {
            errorText = String(describing: error).contains("invalid invite code")
                ? "That invite code didn't match a club. Check it with your host."
                : "Signed in, but couldn't reach your club. Try again in a moment."
        }
    }
}

/// A row of boxes backed by one hidden text field. Letters + digits for invite codes, digits for sign-in codes.
struct CodeBoxes: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var allowLetters: Bool
    var length = 6

    var body: some View {
        ZStack {
            TextField("", text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(allowLetters ? .asciiCapable : .numberPad)
                .textContentType(allowLetters ? nil : .oneTimeCode)
                .focused(focused)
                .opacity(0.02)
                .onChange(of: text) { _, new in
                    let cleaned = new.uppercased().filter { allowLetters ? ($0.isLetter || $0.isNumber) : $0.isNumber }
                    text = String(cleaned.prefix(length))
                }
                .accessibilityLabel(allowLetters ? "Invite code" : "Sign-in code")

            HStack(spacing: length > 6 ? 6 : 8) {
                ForEach(0..<length, id: \.self) { index in
                    let chars = Array(text)
                    let isCurrent = index == chars.count && focused.wrappedValue
                    Text(index < chars.count ? String(chars[index]) : "")
                        .font(Theme.Fonts.mono(length > 6 ? 20 : 24, medium: true))
                        .foregroundStyle(Theme.Colors.ink)
                        .frame(maxWidth: .infinity, minHeight: length > 6 ? 52 : 60)
                        .background(Theme.Colors.card)
                        .overlay(
                            Rectangle()
                                .stroke(isCurrent ? Theme.Colors.forest : Theme.Colors.ink, lineWidth: isCurrent ? 2.5 : 1.5)
                        )
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused.wrappedValue = true }
    }
}

/// A dark painting fitted to the width at the bottom, with its own background
/// colour filling the rest so there's no seam.
struct JoinBackdrop: View {
    var imageName = "JoinPainting"      // stacked books (join)
    var canvasHex = "101012"            // sampled from the painting's background

    /// Three books on a shelf, for the start-a-club page.
    static let start = JoinBackdrop(imageName: "StartPainting", canvasHex: "17150F")

    var body: some View {
        let canvas = Color(hex: canvasHex)
        ZStack(alignment: .bottom) {
            canvas
            Image(imageName)
                .resizable()
                .scaledToFit()
                .overlay(alignment: .top) {
                    LinearGradient(colors: [canvas, canvas.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 60)
                }
                .opacity(0.85)
            // keep the form readable over the books
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
