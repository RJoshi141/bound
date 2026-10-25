import Foundation
import SwiftUI

struct OnboardingView: View {
    enum Step { case welcome, join, start }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome

    var body: some View {
        ZStack {
            // join/start backdrop sits underneath from the start, full-screen,
            // so the tear reveals it with no gaps at the top or bottom
            // different painting for each path
            Group {
                if step == .start { JoinBackdrop.start } else { JoinBackdrop() }
            }
            .zIndex(-1)
            .transaction { $0.animation = nil }     // swap instantly, it's hidden under the start screen

            switch step {
            case .welcome:
                // the start screen tears away, bottom to top, to reveal the next page
                WelcomeView(
                    onJoin: { go(to: .join) },
                    onStart: { go(to: .start) }
                )
                .zIndex(1)
                .transition(reduceMotion ? .opacity : .tearAway)
            case .join:
                JoinClubView(mode: .join, onBack: back)
                    .zIndex(0)
                    .transition(reduceMotion ? .opacity : .revealUnder)
            case .start:
                JoinClubView(mode: .start, onBack: back)
                    .zIndex(0)
                    .transition(reduceMotion ? .opacity : .revealUnder)
            }
        }
        .environment(\.colorScheme, .light)
    }

    // (onboarding colours are hand-set for the paintings, keep tokens in their paper values)
    private func go(to next: Step) {
        withAnimation(.tear) { step = next }
    }

    private func back() {
        withAnimation(.easeInOut(duration: 0.25)) { step = .welcome }
    }
}
