import Foundation
import SwiftUI

/// Your own portrait, wherever you appear. Falls back to the name-based one until you pick.
struct MyAvatar: View {
    var size: CGFloat = 34
    @AppStorage(AppKeys.memberName) private var memberName = ""
    @AppStorage(AppKeys.mySilhouette) private var silhouette = -1
    @AppStorage(AppKeys.myAvatarHex) private var hex = ""

    var body: some View {
        Avatar(name: memberName.isEmpty ? "You" : memberName,
               hex: hex.isEmpty ? Theme.Spine.forest : hex,
               size: size,
               kind: SilhouetteKind(rawValue: silhouette))
    }
}

/// Pick a silhouette and an oval colour. Saved to your profile so the club sees it.
struct AvatarPicker: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppKeys.memberName) private var memberName = ""
    @AppStorage(AppKeys.mySilhouette) private var savedSilhouette = -1
    @AppStorage(AppKeys.myAvatarHex) private var savedHex = ""
    @AppStorage(AppKeys.userID) private var userID = ""

    @State private var kind: SilhouetteKind = .topHat
    @State private var hex = Theme.Spine.forest
    @State private var isSaving = false
    @State private var errorText: String?

    static let colours = [Theme.Spine.forest, Theme.Spine.oxblood, Theme.Spine.rust, Theme.Spine.mustard,
                          Theme.Spine.olive, Theme.Spine.sage, Theme.Spine.navy, Theme.Spine.plum, Theme.Spine.ink]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(Theme.Fonts.letterpress(18))
                    .buttonStyle(.plain)
                Spacer()
                Text("Your portrait").font(Theme.Fonts.body(17, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 56, height: 1)
            }
            .padding(.top, 12)

            // big preview
            HStack {
                Spacer()
                Avatar(name: memberName, hex: hex, size: 120, kind: kind)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: kind)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                MonoLabel("Silhouette")
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SilhouetteKind.allCases, id: \.self) { option in
                        Button {
                            kind = option
                        } label: {
                            VStack(spacing: 6) {
                                Avatar(name: memberName, hex: hex, size: 64, kind: option)
                                Text(option.title).font(Theme.Fonts.body(12))
                            }
                            .frame(maxWidth: .infinity, minHeight: 96)
                            .background(option == kind ? Theme.Colors.card : .clear)
                            .overlay(Rectangle().stroke(option == kind ? Theme.Colors.ink : Theme.Colors.line,
                                                        lineWidth: option == kind ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(option == kind ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                MonoLabel("Colour")
                HStack(spacing: 10) {
                    ForEach(Self.colours, id: \.self) { option in
                        Button {
                            hex = option
                        } label: {
                            Ellipse()
                                .fill(Color(hex: option))
                                .frame(width: 28, height: 34)
                                .overlay(Ellipse().inset(by: -4).stroke(option == hex ? Theme.Colors.ink : .clear, lineWidth: 1.5))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Colour \(option)")
                        .accessibilityAddTraits(option == hex ? .isSelected : [])
                    }
                }
            }

            Spacer(minLength: 0)

            if let errorText {
                Text(errorText).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.oxblood)
            }
            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 10) {
                    if isSaving { ProgressView().tint(Theme.Colors.card) }
                    Text("Save")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving)
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .paperBackground()
        .onAppear {
            kind = SilhouetteKind(rawValue: savedSilhouette) ?? .forName(memberName.isEmpty ? "You" : memberName)
            hex = savedHex.isEmpty ? Theme.Spine.forest : savedHex
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        // show it everywhere straight away; the server copy is for your clubmates
        savedSilhouette = kind.rawValue
        savedHex = hex
        if let id = UUID(uuidString: userID) {
            do {
                try await ClubService.setAvatar(silhouette: kind.rawValue, hex: hex, for: id)
            } catch {
                errorText = "Saved on this phone, but couldn't reach your club. Try saving again."
                return
            }
        }
        dismiss()
    }
}
