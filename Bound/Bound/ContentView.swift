import Foundation
import SwiftUI
import SwiftData

/// Root: onboarding until you've joined a club, then the tabs. The tear sheet sits on top of both.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.hasJoinedClub) private var hasJoined = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // AppStorage writes don't carry withAnimation, so mirror it into State and animate that
    @State private var showApp = UserDefaults.standard.bool(forKey: AppKeys.hasJoinedClub)

    var body: some View {
        ZStack {
            if showApp {
                MainTabsView()
                    .zIndex(0)
                    .transition(reduceMotion ? .opacity : .revealUnder)
            } else {
                // the start flow tears away to reveal the app underneath
                OnboardingView()
                    .zIndex(1)
                    .transition(reduceMotion ? .opacity : .tearAway)
            }
        }
        // paper all the way to the screen edges, under everything, so no white ever peeks through
        .background { Mahogany(deep: true) }
        .onChange(of: hasJoined) { _, joined in
            withAnimation(joined ? .tear : .easeInOut(duration: 0.3)) { showApp = joined }
        }
        // Dark scheme = mahogany surfaces + light status bar. Cards and sheets opt back into light.
        .preferredColorScheme(.dark)
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
