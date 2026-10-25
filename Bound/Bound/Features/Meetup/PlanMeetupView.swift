import Foundation
import SwiftUI
import SwiftData

/// Host tools: set next month's book, date options, place.
struct PlanMeetupView: View {
    let nextNumber: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PickOption.votes, order: .reverse) private var picks: [PickOption]
    @AppStorage(AppKeys.memberName) private var memberName = ""

    @State private var chosenTitle: String?
    @State private var dates: [Date] = PlanMeetupView.defaultDates()
    @State private var selectedDate = 0
    @State private var place = "Priya's place"
    @State private var rotateHost = true
    @State private var wholeBook = true
    @State private var newDate = Date.now
    @State private var addingDate = false

    private var winner: PickOption? {
        picks.max { $0.total < $1.total }
    }
    private var book: PickOption? {
        picks.first { $0.title == chosenTitle } ?? winner
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
                                if let book, book.title == winner?.title {
                                    Text("Won the club vote with \(book.total)").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.inkMuted)
                                } else if let book {
                                    Text(book.author).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.inkMuted)
                                }
                            }
                            Spacer()
                            Menu("Change") {
                                ForEach(picks) { pick in
                                    Button(pick.title) { chosenTitle = pick.title }
                                }
                            }
                            .font(Theme.Fonts.letterpress(17))
                            .tint(Theme.Colors.forest)
                        }
                        .padding(14)
                        .paperCard()
                    }

                    // Dates
                    VStack(alignment: .leading, spacing: 0) {
                        fieldLabel("Date options · members vote").padding(.bottom, 6)
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
                        TextField("Place", text: $place)
                            .font(Theme.Fonts.script(26))
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

            Button("Send to club", action: send)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(book == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(Theme.Fonts.body(13, weight: .semibold))
    }

    private func send() {
        guard let book, dates.indices.contains(selectedDate) else { return }
        let meetup = Meetup(
            number: nextNumber,
            date: dates[selectedDate],
            place: place,
            address: "",
            bookTitle: book.title,
            bookAuthor: book.author,
            spineHex: Catalog.spineHex(for: book.title),
            readUpTo: wholeBook ? "Whole book" : "Up to chapter 12",
            rsvp: .going,
            goingCount: 0
        )
        context.insert(meetup)
        dismiss()
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
