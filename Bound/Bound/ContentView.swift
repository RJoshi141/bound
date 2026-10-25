import Foundation
import SwiftUI
import SwiftData

/// Root: onboarding until you've joined a club, then the tabs. The tear sheet sits on top of both.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var auth = AuthStore()
    @AppStorage(AppKeys.hasJoinedClub) private var hasJoined = false
    @AppStorage(AppKeys.clubID) private var clubID = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
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
        .background { Theme.Colors.paper.ignoresSafeArea() }
        .onChange(of: hasJoined) { _, joined in
            withAnimation(joined ? .tear : .easeInOut(duration: 0.3)) { showApp = joined }
        }
        .preferredColorScheme(.light)       // paper look is light-only for now
        .environment(auth)
        .task { SampleData.seedIfNeeded(context, includeSamples: !hasJoined) }
        .task { await auth.start() }      // restores the saved session, then listens
        // shelves follow whoever is signed in
        .task(id: "\(auth.userID?.uuidString ?? "")|\(clubID)") {
            UserDefaults.standard.set(auth.userID?.uuidString ?? "", forKey: AppKeys.userID)
            if let userID = auth.userID {
                await ShelfSync.shared.start(context: context, userID: userID)
                await ClubSync.shared.start(context: context, userID: userID)
            } else {
                ShelfSync.shared.stop()
                ClubSync.shared.stop()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await ShelfSync.shared.pull(); await ClubSync.shared.pull() }
            case .background: Task { await ShelfSync.shared.push() }
            default: break
            }
        }
    }
}

enum AppKeys {
    static let hasJoinedClub = "hasJoinedClub"
    static let memberName = "memberName"
    static let clubName = "clubName"
    static let isHost = "isHost"
    static let readingGoal = "readingGoal"
    static let clubID = "clubID"
    static let inviteCode = "inviteCode"
    static let clubFoundedYear = "clubFoundedYear"
    static let userID = "userID"
    static let mySilhouette = "mySilhouette"     // -1 = not chosen
    static let myAvatarHex = "myAvatarHex"       // "" = not chosen
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
