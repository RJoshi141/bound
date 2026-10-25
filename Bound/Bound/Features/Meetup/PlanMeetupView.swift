import Foundation
import SwiftUI
import SwiftData

/// Host tools: set next month's book, date, place. "Send to club" puts it on everyone's Meetup tab.
struct PlanMeetupView: View {
    let nextNumber: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PickOption.votes, order: .reverse) private var picks: [PickOption]
    @Query(sort: \Book.addedAt, order: .reverse) private var shelfBooks: [Book]
    @AppStorage(AppKeys.memberName) private var memberName = ""

    @State private var chosen: PlanBook?
    @State private var isSending = false
    @State private var errorText: String?
    @State private var dates: [Date] = PlanMeetupView.defaultDates()
    @State private var selectedDate = 0
    @State private var place = ""
    @State private var rotateHost = true
    @State private var wholeBook = true
    @State private var newDate = Date.now
    @State private var addingDate = false
    @State private var showBookMenu = false

    private var winner: PickOption? {
        picks.max { $0.total < $1.total }
    }
    private var book: PlanBook? {
        chosen ?? winner.map(PlanBook.init)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton(title: "Meetup") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel("Host tools · meeting no. \(nextNumber)", color: Theme.Colors.oxblood)
                        Text("Plan next month").font(Theme.Fonts.display(44))
                    }

                    // Book
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Book")
                        HStack(spacing: 12) {
                            SpineSwatch(hex: Catalog.spineHex(for: book?.title ?? ""), width: 26, height: 50)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book?.title ?? "No pick yet").font(Theme.Fonts.body(16, weight: .semibold))
                                if let book, let winner, book.title == winner.title {
                                    Text("Won the club vote with \(winner.total)").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.inkMuted)
                                } else if let book {
                                    Text(book.author).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.inkMuted)
                                }
                            }
                            Spacer()
                            Button("Change") { showBookMenu = true }
                                .buttonStyle(SmallButtonStyle())
                        }
                        .padding(14)
                        .paperCard()
                    }

                    // Dates
                    VStack(alignment: .leading, spacing: 0) {
                        fieldLabel("When").padding(.bottom, 6)
                        ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                            Button {
                                selectedDate = index
                            } label: {
                                HStack {
                                    Image(systemName: selectedDate == index ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(Theme.Colors.forest)
                                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                                        .font(Theme.Fonts.body(16))
                                    Spacer()
                                    if selectedDate == index { MonoLabel("Default", size: 10) }
                                }
                                .frame(minHeight: 48)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
                        }
                        if addingDate {
                            HStack {
                                DatePicker("New date", selection: $newDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                Spacer()
                                Button("Add") {
                                    dates.append(newDate)
                                    addingDate = false
                                }
                                .font(Theme.Fonts.body(14, weight: .semibold))
                                .tint(Theme.Colors.forest)
                            }
                            .frame(minHeight: 52)
                        } else {
                            Button {
                                addingDate = true
                            } label: {
                                Label("Add a date", systemImage: "plus")
                                    .font(Theme.Fonts.body(16))
                                    .foregroundStyle(Theme.Colors.inkMuted)
                                    .frame(minHeight: 48)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Place
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Where")
                        TextField("", text: $place, prompt: Text("Lucia's place").foregroundStyle(Theme.Colors.inkMuted))
                            .font(Theme.Fonts.body(16))
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Theme.Colors.card)
                            .overlay(Rectangle().stroke(Theme.Colors.lineStrong, lineWidth: 1.5))
                        Toggle("Rotate host each month", isOn: $rotateHost)
                            .font(Theme.Fonts.body(15))
                            .tint(Theme.Colors.forest)
                    }

                    // Reading goal
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Read up to")
                        Picker("Read up to", selection: $wholeBook) {
                            Text("Whole book").tag(true)
                            Text("Up to a chapter").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            if let errorText {
                Text(errorText)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.oxblood)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            Button {
                Task { await send() }
            } label: {
                HStack(spacing: 10) {
                    if isSending { ProgressView().tint(Theme.Colors.card) }
                    Text("Send to club")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(book == nil || isSending)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .paperMenu(isPresented: $showBookMenu, topOffset: 250) {
            bookMenu
        }
    }

    private var bookMenu: [PaperMenuSection] {
        var sections: [PaperMenuSection] = []
        if !picks.isEmpty {
            sections.append(PaperMenuSection(label: "Club vote", items: picks.map { pick in
                PaperMenuItem(title: pick.title, isChecked: pick.title == book?.title) { chosen = PlanBook(pick) }
            }))
        }
        let pickTitles = Set(picks.map(\.title))
        let mine = shelfBooks.filter { $0.shelf != .finished && !pickTitles.contains($0.title) }.prefix(6)
        if !mine.isEmpty {
            sections.append(PaperMenuSection(label: "From your shelves", items: mine.map { shelfBook in
                PaperMenuItem(title: shelfBook.title, isChecked: shelfBook.title == book?.title) { chosen = PlanBook(shelfBook) }
            }))
        }
        return sections
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(Theme.Fonts.body(13, weight: .semibold))
    }

    private func send() async {
        guard let book, dates.indices.contains(selectedDate) else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await ClubSync.shared.planMeetup(
                number: nextNumber,
                date: dates[selectedDate],
                place: place.trimmingCharacters(in: .whitespaces),
                readUpTo: wholeBook ? "Whole book" : "Up to chapter 12",
                catalogID: book.catalogID, title: book.title, author: book.author,
                year: book.year, pageCount: book.pageCount
            )
            dismiss()
        } catch {
            errorText = "Couldn't send it to the club. Check your connection and try again."
        }
    }

    /// Next month's first Thursday and Saturday at sensible times.
    private static func defaultDates() -> [Date] {
        let cal = Calendar.current
        guard let nextMonth = cal.date(byAdding: .month, value: 1, to: .now),
              let start = cal.date(from: cal.dateComponents([.year, .month], from: nextMonth)) else { return [.now] }
        func first(weekday: Int, hour: Int) -> Date {
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = hour
            return cal.nextDate(after: start, matching: comps, matchingPolicy: .nextTime) ?? start
        }
        return [first(weekday: 5, hour: 19), first(weekday: 7, hour: 16)]
    }
}

/// The book being planned, from the vote or from your shelves.
struct PlanBook: Equatable {
    var catalogID: UUID?
    var title: String
    var author: String
    var year: Int?
    var pageCount: Int

    init(_ pick: PickOption) {
        catalogID = pick.catalogID
        title = pick.title
        author = pick.author
        year = nil
        pageCount = 0
    }

    init(_ book: Book) {
        catalogID = book.catalogID
        title = book.title
        author = book.author
        year = book.year
        pageCount = book.pageCount
    }
}
