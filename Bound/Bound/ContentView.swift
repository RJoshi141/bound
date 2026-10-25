import Foundation
import SwiftUI
import SwiftData

/// Root: onboarding until you've joined a club, then the tabs. The tear sheet sits on top of both.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.hasJoinedClub) private var hasJoined = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if hasJoined {
                MainTabsView()
                    .zIndex(0)
            } else {
                // the start flow tears away to reveal the app underneath
                OnboardingView()
                    .zIndex(1)
                    .transition(reduceMotion ? .opacity : .tearAway)
            }
        }
        .preferredColorScheme(.light)       // paper look is light-only for now
        .task { SampleData.seedIfNeeded(context) }
    }
}

enum AppKeys {
    static let hasJoinedClub = "hasJoinedClub"
    static let memberName = "memberName"
    static let clubName = "clubName"
    static let isHost = "isHost"
    static let readingGoal = "readingGoal"
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
