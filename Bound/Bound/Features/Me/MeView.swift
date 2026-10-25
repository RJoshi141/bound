import Foundation
import SwiftUI
import SwiftData

struct MeView: View {
    @AppStorage(AppKeys.memberName) private var memberName = ""
    @AppStorage(AppKeys.clubName) private var clubName = "Tuesday Night Readers"
    @AppStorage(AppKeys.hasJoinedClub) private var hasJoined = true
    @AppStorage(AppKeys.readingGoal) private var goal = 24

    @Query(sort: \Book.addedAt) private var books: [Book]
    @Query private var notes: [Note]
    @Query private var meetups: [Meetup]

    @State private var selected: Book?
    @State private var notificationsOn = true

    private var name: String { memberName.isEmpty ? "You" : memberName }
    private var finished: [Book] { books.filter { $0.shelf == .finished } }
    private var favourites: [Book] { books.filter(\.isFavourite) }
    private var myNotes: Int { notes.filter { $0.authorName == memberName || $0.authorName == "You" }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                stats
                favouritesShelf
                goalCard
                settings
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .paperBackground()
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: selected?.id)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Avatar(initial: String(name.prefix(1)), hex: Theme.Spine.forest, size: 68)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Theme.Fonts.display(40))
                Text("Member of \(clubName)").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
        .padding(.top, 8)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("\(finished.count)", "Books read")
            Divider().frame(height: 44)
            stat("\(myNotes)", "Notes")
            Divider().frame(height: 44)
            stat("\(meetups.count)", "Meetups")
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.ink).frame(height: 1.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.Fonts.display(34))
            MonoLabel(label, size: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.leading, 12)
    }

    private var favouritesShelf: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "★ Favourites", trailing: "\(favourites.count) books")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(favourites) { book in
                        SpineView(book: book, isLifted: selected?.id == book.id) {
                            selected = (selected?.id == book.id) ? nil : book
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 28)
            }
            .frame(height: 156, alignment: .bottom)
            OakPlank()
            if let selected {
                Text("\(selected.title) · \(selected.author)")
                    .font(Theme.Fonts.displayItalic(20))
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reading goal").font(Theme.Fonts.body(15, weight: .semibold))
                Spacer()
                Stepper("\(goal) books", value: $goal, in: 1...200)
                    .font(Theme.Fonts.body(14))
                    .fixedSize()
            }
            ProgressBar(value: min(Double(finished.count) / Double(max(goal, 1)), 1))
            MonoLabel("\(finished.count) of \(goal) this year", size: 10)
        }
        .padding(16)
        .paperCard()
    }

    private var settings: some View {
        VStack(spacing: 0) {
            Toggle("Meetup reminders", isOn: $notificationsOn)
                .tint(Theme.Colors.forest)
                .frame(minHeight: 52)
            row("Import from Goodreads", systemImage: "square.and.arrow.down")
            Button(role: .destructive) {
                hasJoined = false
            } label: {
                HStack {
                    Text("Leave club (restart onboarding)")
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .foregroundStyle(Theme.Colors.oxblood)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .font(Theme.Fonts.body(15))
    }

    private func row(_ title: String, systemImage: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage).foregroundStyle(Theme.Colors.inkMuted)
        }
        .frame(minHeight: 52)
        .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
    }
}

#Preview {
    MeView()
        .modelContainer(SampleData.previewContainer)
}
