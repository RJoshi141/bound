import Foundation
import SwiftUI

struct OnboardingView: View {
    enum Step { case welcome, join, start }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome

    var body: some View {
        ZStack {
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
                    .transition(.opacity)
            case .start:
                JoinClubView(mode: .start, onBack: back)
                    .zIndex(0)
                    .transition(.opacity)
            }
        }
    }

    private func go(to next: Step) {
        withAnimation(.tear) { step = next }
    }

    private func back() {
        withAnimation(.easeInOut(duration: 0.25)) { step = .welcome }
    }
}
