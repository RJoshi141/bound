import Foundation
import SwiftUI

struct OnboardingView: View {
    enum Step { case welcome, join, start }

    @Environment(TearCoordinator.self) private var tear
    @State private var step: Step = .welcome

    var body: some View {
        switch step {
        case .welcome:
            WelcomeView(
                onJoin: { tear.run { step = .join } },
                onStart: { tear.run { step = .start } }
            )
        case .join:
            JoinClubView(mode: .join, onBack: { tear.run { step = .welcome } })
        case .start:
            JoinClubView(mode: .start, onBack: { tear.run { step = .welcome } })
        }
    }
}
