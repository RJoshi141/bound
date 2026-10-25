import Foundation
import SwiftUI

enum AppTab: Hashable {
    case shelves, meetup, club, me
}

struct MainTabsView: View {
    @State private var tab: AppTab = .shelves

    var body: some View {
        TabView(selection: $tab) {
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
