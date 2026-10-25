import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            Tab("Shelves", systemImage: "books.vertical") {
                NavigationStack { ShelvesView() }
            }
            Tab("Meetup", systemImage: "calendar") {
                ComingSoon(title: "Meetup")
            }
            Tab("Club", systemImage: "person.2") {
                ComingSoon(title: "Club")
            }
            Tab("Me", systemImage: "person.crop.circle") {
                ComingSoon(title: "Me")
            }
        }
        .tint(Theme.Colors.forest)
        .task { SampleData.seedIfNeeded(context) }
    }
}

/// Placeholder until each tab gets built.
private struct ComingSoon: View {
    let title: String

    var body: some View {
        ZStack {
            Theme.Colors.paper.ignoresSafeArea()
            VStack(spacing: 8) {
                Text(title).font(Theme.Fonts.display(44))
                Text("Coming soon")
                    .font(Theme.Fonts.mono(11))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.inkMuted)
            }
            .foregroundStyle(Theme.Colors.ink)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
