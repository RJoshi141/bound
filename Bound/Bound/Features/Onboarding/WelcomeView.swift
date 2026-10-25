import Foundation
import SwiftUI

struct WelcomeView: View {
    let onJoin: () -> Void
    let onStart: () -> Void

    @State private var shelfIn = false

    // the little illustrated shelf: (colour, width, height)
    private let spines: [(String, CGFloat, CGFloat)] = [
        (Theme.Spine.mustard, 22, 112), (Theme.Spine.oxblood, 30, 132), (Theme.Spine.olive, 18, 98),
        (Theme.Spine.rust, 26, 122), (Theme.Spine.forest, 40, 144), (Theme.Spine.mustard, 24, 116),
        (Theme.Spine.oxblood, 20, 104), (Theme.Spine.olive, 28, 128), (Theme.Spine.navy, 22, 110),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // wordmark
            HStack(alignment: .bottom, spacing: 14) {
                BookMark()
                    .padding(.bottom, 12)
                Text("Bound")
                    .font(Theme.Fonts.masthead(84))
                    .foregroundStyle(Theme.Colors.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Bound")

            Text("Your book club, all in one place. Track what you read, share notes, plan the next meetup.")
                .font(Theme.Fonts.body(17))
                .foregroundStyle(Theme.Colors.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 16)

            Spacer(minLength: 24)

            // spines rise onto the shelf one by one
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(spines.enumerated()), id: \.offset) { index, spine in
                        SpineSwatch(hex: spine.0, width: spine.1, height: spine.2)
                            .rotationEffect(.degrees(index == spines.count - 1 ? -10 : 0), anchor: .bottomLeading)
                            .offset(y: shelfIn ? 0 : 40)
                            .opacity(shelfIn ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25 + Double(index) * 0.05), value: shelfIn)
                    }
                }
                .frame(height: 150, alignment: .bottom)
                OakPlank()
            }
            .padding(.horizontal, 36)
            .accessibilityHidden(true)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button("Join a club", action: onJoin)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Start a club", action: onStart)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .paperBackground()
        .onAppear { shelfIn = true }
    }
}

/// The little bound-book mark next to the wordmark.
struct BookMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Theme.Colors.forest)
            .frame(width: 40, height: 54)
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.Colors.paper).frame(width: 3).padding(.leading, 5)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.Colors.gilt).frame(height: 2).padding(.horizontal, 12).padding(.top, 10)
            }
    }
}

#Preview {
    WelcomeView(onJoin: {}, onStart: {})
}
