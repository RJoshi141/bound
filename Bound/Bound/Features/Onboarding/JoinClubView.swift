import Foundation
import SwiftUI

struct JoinClubView: View {
    enum Mode { case join, start }

    let mode: Mode
    let onBack: () -> Void

    @AppStorage(AppKeys.hasJoinedClub) private var hasJoined = false
    @AppStorage(AppKeys.memberName) private var memberName = ""
    @AppStorage(AppKeys.clubName) private var clubName = "Tuesday Night Readers"
    @AppStorage(AppKeys.isHost) private var isHost = false

    @State private var code = ""
    @State private var newClubName = ""
    @State private var name = ""
    @State private var importHistory = true
    @FocusState private var codeFocused: Bool

    private var canContinue: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        switch mode {
        case .join: return hasName && code.count == 6
        case .start: return hasName && !newClubName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BackButton(title: "Back", action: onBack)
                Spacer()
                MonoLabel(mode == .join ? "Step 1 of 2" : "New club")
            }
            .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode == .join ? "Join your club" : "Start a club")
                            .font(Theme.Fonts.display(44))
                            .foregroundStyle(Theme.Colors.ink)
                        Text(mode == .join
                             ? "Ask your host for the 6-character invite code."
                             : "Name your club. You'll get a code to share with members.")
                            .font(Theme.Fonts.body(15))
                            .foregroundStyle(Theme.Colors.inkMuted)
                    }

                    if mode == .join { codeField } else { clubNameField }

                    if mode == .join && code.count == 6 {
                        clubPreview
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your first name").font(Theme.Fonts.body(13, weight: .semibold))
                        TextField("", text: $name, prompt: Text("Ana").foregroundStyle(Theme.Colors.inkMuted))
                            .font(Theme.Fonts.body(17))
                            .textContentType(.givenName)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.lineStrong, lineWidth: 1.5))
                    }

                    Toggle(isOn: $importHistory) {
                        Text("Import my reading history from Goodreads or StoryGraph")
                            .font(Theme.Fonts.body(15))
                    }
                    .tint(Theme.Colors.forest)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: code.count == 6)
            }

            Button(mode == .join ? "Join club" : "Create club", action: finish)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.45)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .foregroundStyle(Theme.Colors.ink)
        .paperBackground()
        .onAppear { if mode == .join { codeFocused = true } }
    }

    // Six boxes backed by one hidden text field.
    private var codeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invite code").font(Theme.Fonts.body(13, weight: .semibold))
            ZStack {
                TextField("", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($codeFocused)
                    .opacity(0.02)
                    .onChange(of: code) { _, new in
                        code = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    }
                    .accessibilityLabel("Invite code")

                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        let chars = Array(code)
                        let isCurrent = index == chars.count && codeFocused
                        Text(index < chars.count ? String(chars[index]) : "")
                            .font(Theme.Fonts.mono(24, medium: true))
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isCurrent ? Theme.Colors.forest : Theme.Colors.ink, lineWidth: isCurrent ? 2.5 : 1.5)
                            )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onTapGesture { codeFocused = true }
        }
    }

    private var clubNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Club name").font(Theme.Fonts.body(13, weight: .semibold))
            TextField("", text: $newClubName, prompt: Text("Tuesday Night Readers").foregroundStyle(Theme.Colors.inkMuted))
                .font(Theme.Fonts.body(17))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.lineStrong, lineWidth: 1.5))
            MonoLabel("Your invite code: BND7Q2")
        }
    }

    private var clubPreview: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.forest)
                .frame(width: 52, height: 52)
                .overlay(Text("T").font(Theme.Fonts.masthead(30)).foregroundStyle(Theme.Colors.card))
            VStack(alignment: .leading, spacing: 2) {
                Text("Tuesday Night Readers").font(Theme.Fonts.body(16, weight: .semibold))
                Text("7 members · Now reading Middlemarch")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Colors.forest)
        }
        .padding(16)
        .paperCard(radius: 14)
    }

    private func finish() {
        memberName = name.trimmingCharacters(in: .whitespaces)
        if mode == .start {
            clubName = newClubName.trimmingCharacters(in: .whitespaces)
            isHost = true
        }
        hasJoined = true     // ContentView animates the tear
    }
}
