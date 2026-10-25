import Foundation
import SwiftUI

enum AppTab: Hashable {
    case shelves, meetup, club, me
}

struct MainTabsView: View {
    @Environment(TearCoordinator.self) private var tear
    @State private var tab: AppTab = .shelves

    var body: some View {
        // every tab switch goes through the tear
        let selection = Binding<AppTab>(
            get: { tab },
            set: { newTab in
                guard newTab != tab else { return }
                tear.run { tab = newTab }
            }
        )

        TabView(selection: selection) {
            Tab("Shelves", systemImage: "books.vertical", value: AppTab.shelves) {
                ShelvesView()
            }
            Tab("Meetup", systemImage: "calendar", value: AppTab.meetup) {
                MeetupView()
            }
            Tab("Club", systemImage: "person.2", value: AppTab.club) {
                ClubView()
            }
            Tab("Me", systemImage: "person.crop.circle", value: AppTab.me) {
                MeView()
            }
        }
        .tint(Theme.Colors.forest)
    }
}
