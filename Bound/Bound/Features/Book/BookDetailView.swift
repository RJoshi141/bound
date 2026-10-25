import Foundation
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var members: [ClubMember]

    enum Pane: String, CaseIterable { case notes = "Club notes", about = "About" }
    @State private var pane: Pane = .notes
    @State private var revealAll = false
    @State private var showingLog = false
    @State private var showingWrite = false
    @State private var showMenu = false

    // MARK: spoiler folding
    // A note is safe if it was written at or before your page (or you've finished),
    // and nobody flagged it as a spoiler.
    private var sortedNotes: [Note] { book.notes.sorted { $0.page < $1.page } }
    private var isSafe: (Note) -> Bool {
        { [book] note in
            book.shelf == .finished || (note.page <= book.currentPage && !note.containsSpoilers)
        }
    }
    private var visibleNotes: [Note] { revealAll ? sortedNotes : sortedNotes.filter(isSafe) }
    private var foldedCount: Int { revealAll ? 0 : sortedNotes.filter { !isSafe($0) }.count }

    private var clubAverage: Double? {
        let ratings = book.notes.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    ratingRow
                    panePicker
                    switch pane {
                    case .notes: notesList
                    case .about: about
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showingWrite = true
            } label: {
                Label("Write a note", systemImage: "pencil")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.Colors.paper.shadow(.drop(color: Theme.Colors.ink.opacity(0.08), radius: 8, y: -4)))
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingLog) { LogPagesSheet(book: book) }
        .sheet(isPresented: $showingWrite) { WriteNoteView(book: book) }
        .task { await ShelfSync.shared.pullNotes() }
        .animation(.easeInOut(duration: 0.25), value: revealAll)
        .paperMenu(isPresented: $showMenu) { menuSections }
    }

    private var menuSections: [PaperMenuSection] {
        [
            PaperMenuSection(label: "Move to shelf", items: ShelfKind.allCases.map { kind in
                PaperMenuItem(title: kind.title, isChecked: book.shelf == kind) { book.shelf = kind }
            }),
            PaperMenuSection(items: [
                PaperMenuItem(title: "Remove from shelves", isDestructive: true) {
                    // pop first, then delete, so the screen never renders a deleted model
                    let doomed = book
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        context.delete(doomed)
                    }
                }
            ]),
        ]
    }

    // MARK: sections

    private var topBar: some View {
        HStack(spacing: 8) {
            BackButton(title: "Shelves") { dismiss() }
            Spacer()
            IconButton(
                systemName: book.isFavourite ? "heart.fill" : "heart",
                label: book.isFavourite ? "Remove from favourites" : "Add to favourites",
                color: Theme.Colors.oxblood,
                bordered: false
            ) { book.isFavourite.toggle() }
            IconButton(systemName: "ellipsis", label: "More options", bordered: false) {
                showMenu.toggle()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 18) {
            BookCover(book: book)

            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(book.isClubPick ? "\(book.shelf.title) · Club pick" : book.shelf.title, color: Theme.Colors.oxblood, size: 10)
                Text(book.title)
                    .font(Theme.Fonts.display(36))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Text([book.author, book.year.map(String.init)].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.inkMuted)

                Spacer(minLength: 8)

                HStack {
                    MonoLabel("p. \(book.currentPage) / \(book.pageCount)", color: Theme.Colors.ink, size: 10)
                    Spacer()
                    MonoLabel("\(Int(book.progress * 100))%", size: 10)
                }
                ProgressBar(value: book.progress)
                Button("Log pages") { showingLog = true }
                    .buttonStyle(SmallButtonStyle(fullWidth: true))
                    .padding(.top, 4)
            }
            .foregroundStyle(Theme.Colors.ink)
        }
        .frame(height: 190)
    }

    private var ratingRow: some View {
        HStack(spacing: 16) {
            Text(clubAverage.map { String(format: "%.1f", $0) } ?? "–")
                .font(Theme.Fonts.display(56))
                .foregroundStyle(Theme.Colors.ink)
            VStack(alignment: .leading, spacing: 6) {
                Stars(rating: clubAverage ?? 0, size: 15)
                MonoLabel("Club average · \(book.notes.count) notes", size: 10)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.ink).frame(height: 1.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
    }

    private var panePicker: some View {
        HStack(spacing: 24) {
            ForEach(Pane.allCases, id: \.self) { option in
                Button {
                    pane = option
                } label: {
                    VStack(spacing: 6) {
                        Text(option == .notes ? "\(option.rawValue) (\(book.notes.count))" : option.rawValue)
                            .font(Theme.Fonts.displayItalic(22))
                            .foregroundStyle(pane == option ? Theme.Colors.ink : Theme.Colors.inkMuted)
                        Rectangle()
                            .fill(pane == option ? Theme.Colors.oxblood : .clear)
                            .frame(height: 2)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(pane == option ? .isSelected : [])
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var notesList: some View {
        VStack(alignment: .leading, spacing: 14) {
            if book.notes.isEmpty {
                Text("No notes yet. Be the first to write in the margins.")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.inkMuted)
            }
            ForEach(Array(visibleNotes.enumerated()), id: \.element.id) { index, note in
                NoteCard(note: note, tilt: [0, -0.6, 0.5][index % 3], memberHex: hex(for: note.authorName))
            }
            if foldedCount > 0 {
                Button {
                    revealAll = true
                } label: {
                    HStack {
                        Image(systemName: "eye.slash")
                        Text("\(foldedCount) note\(foldedCount == 1 ? "" : "s") past p. \(book.currentPage) folded away")
                            .font(Theme.Fonts.body(14))
                        Spacer()
                        Text("Reveal").font(Theme.Fonts.letterpress(17)).tracking(1)
                    }
                    .foregroundStyle(Theme.Colors.inkMuted)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Theme.Colors.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var about: some View {
        VStack(spacing: 0) {
            aboutRow("Author", book.author)
            aboutRow("Published", book.year.map(String.init) ?? "Unknown")
            aboutRow("Pages", "\(book.pageCount)")
            aboutRow("Shelf", book.shelf.title)
            aboutRow("Added", book.addedAt.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            MonoLabel(label)
            Spacer()
            Text(value).font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.ink)
        }
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
    }

    private func hex(for name: String) -> String {
        members.first { $0.name == name }?.colorHex ?? Theme.Spine.forest
    }
}

/// Typographic bookcloth cover with a gilt double rule.
struct BookCover: View {
    let book: Book
    var width: CGFloat = 122

    var body: some View {
        let textColor = Color.isLight(hex: book.spineHex) ? Theme.Colors.ink : Color(hex: "E9D6A8")
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 6, topTrailingRadius: 6)
                .fill(Color(hex: book.spineHex))
            Rectangle()
                .strokeBorder(Theme.Colors.gilt, lineWidth: 1)
                .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 8))
            Rectangle()
                .strokeBorder(Theme.Colors.gilt, lineWidth: 0.75)
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 12))
            VStack(spacing: 8) {
                Text(book.title)
                    .font(Theme.Fonts.displayItalic(20))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                MonoLabel(book.author, color: textColor, size: 7)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 24)
            // spine hinge
            HStack(spacing: 0) {
                Rectangle().fill(.black.opacity(0.22)).frame(width: 6)
                Spacer()
            }
        }
        .frame(width: width, height: width * 1.45)
        .shadow(color: Theme.Colors.ink.opacity(0.35), radius: 12, y: 10)
        .accessibilityHidden(true)
    }
}

struct ProgressBar: View {
    let value: Double
    var tint: Color = Theme.Colors.forest

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.Colors.paperDeep)
                Rectangle().fill(tint).frame(width: max(4, geo.size.width * value))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("\(Int(value * 100)) percent read")
    }
}

#Preview {
    let container = SampleData.previewContainer
    let book = try! container.mainContext.fetch(FetchDescriptor<Book>()).first { $0.title == "Middlemarch" }!
    NavigationStack { BookDetailView(book: book) }
        .modelContainer(container)
}
