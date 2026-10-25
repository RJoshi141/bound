import Foundation
import SwiftUI

/// Start screen: the oil painting fills the screen, wordmark on top, buttons at the bottom.
struct WelcomeView: View {
    let onJoin: () -> Void
    let onStart: () -> Void

    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Text("Bound")
                    .font(Theme.Fonts.masthead(96))
                    .foregroundStyle(Theme.Colors.card)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                Text("Your book club, all in one place.\nTrack what you read, share notes, plan the next meetup.")
                    .font(Theme.Fonts.body(16))
                    .foregroundStyle(Theme.Colors.card.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .padding(.top, 72)

            Spacer()

            VStack(spacing: 12) {
                Button("Join a club", action: onJoin)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Start a club", action: onStart)
                    .buttonStyle(SecondaryButtonStyle(color: Theme.Colors.card))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .opacity(shown ? 1 : 0)
        .background { painting }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { shown = true }
        }
    }

    // Full-bleed painting with darkened top and bottom so text and buttons stay readable.
    private var painting: some View {
        Color.clear
            .overlay {
                Image("WelcomePainting")
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .black.opacity(0.0), location: 0.35),
                        .init(color: .black.opacity(0.0), location: 0.6),
                        .init(color: .black.opacity(0.7), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityLabel("Oil painting of a stack of old books tied with a red ribbon")
    }
}

#Preview {
    WelcomeView(onJoin: {}, onStart: {})
}
