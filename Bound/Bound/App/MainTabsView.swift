import Foundation
import SwiftUI
import UIKit

enum AppTab: Hashable, CaseIterable {
    case shelves, meetup, club, me

    var title: String {
        switch self {
        case .shelves: "Shelves"
        case .meetup: "Meetup"
        case .club: "Club"
        case .me: "Me"
        }
    }

    var symbol: String {
        switch self {
        case .shelves: "books.vertical"
        case .meetup: "calendar"
        case .club: "person.2"
        case .me: "person.crop.circle"
        }
    }
}

struct MainTabsView: View {
    @State private var tab: AppTab = .shelves

    var body: some View {
        TabView(selection: $tab) {
            Tab(AppTab.shelves.title, systemImage: AppTab.shelves.symbol, value: AppTab.shelves) {
                ShelvesView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(AppTab.meetup.title, systemImage: AppTab.meetup.symbol, value: AppTab.meetup) {
                MeetupView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(AppTab.club.title, systemImage: AppTab.club.symbol, value: AppTab.club) {
                ClubView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(AppTab.me.title, systemImage: AppTab.me.symbol, value: AppTab.me) {
                MeView().toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        // our own bar instead of the floating glass one
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WoodTabBar(selection: $tab)
        }
    }
}

/// Bottom navigation as a dark mahogany rail with a gilt edge.
/// Selected tab: cream with a little gilt rule above it, like a bookmark.
struct WoodTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                let isOn = item == selection
                Button {
                    guard item != selection else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    selection = item
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 19, weight: isOn ? .semibold : .regular))
                            .frame(height: 24)
                        Text(item.title)
                            .font(Theme.Fonts.letterpress(14))
                            .tracking(1.2)
                    }
                    .foregroundStyle(isOn ? Theme.Colors.paperFixed : Color(hex: "B49784"))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .overlay(alignment: .top) {
                        // gilt bookmark over the selected tab
                        Rectangle()
                            .fill(Theme.Colors.gilt)
                            .frame(width: 30, height: 2.5)
                            .offset(y: -8)
                            .opacity(isOn ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 8)
        .background {
            Mahogany(deep: true)
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                }
        }
        .overlay(alignment: .top) {
            // gilt edge with a dark groove under it
            VStack(spacing: 0) {
                Rectangle().fill(Theme.Colors.gilt).frame(height: 1)
                Rectangle().fill(.black.opacity(0.45)).frame(height: 1)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: -4)
        .animation(.easeOut(duration: 0.2), value: selection)
    }
}
