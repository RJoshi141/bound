import Foundation
import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import UIKit

struct MeetupView: View {
    @Query(sort: \Meetup.number, order: .reverse) private var meetups: [Meetup]
    @Query(sort: \LedgerEntry.month, order: .reverse) private var ledger: [LedgerEntry]
    @Query(sort: \PickOption.votes, order: .reverse) private var picks: [PickOption]
    @Query private var members: [ClubMember]
    @Query(filter: #Predicate<Note> { $0.discussAtMeetup }) private var agenda: [Note]

    @Query(sort: \Book.addedAt, order: .reverse) private var shelfBooks: [Book]
    @AppStorage(AppKeys.isHost) private var isHost = false

    @State private var showPlan = false
    @State private var showAddOption = false
    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            Group {
                content(meetups.first)
            }
            .paperBackground()
            .paperMenu(isPresented: $showAddOption, topOffset: 120) { addOptionMenu }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPlan) {
                PlanMeetupView(nextNumber: (meetups.first?.number ?? 0) + 1)
            }
        }
    }

    private func content(_ meetup: Meetup?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel(meetup.map { "Meeting no. \($0.number)" } ?? "Meetups", color: Theme.Colors.oxblood)
                        Text(meetup?.date.formatted(.dateTime.month(.wide)) ?? "Next up")
                            .font(Theme.Fonts.display(46))
                            .foregroundStyle(Theme.Colors.ink)
                    }
                    Spacer()
                    if isHost { planButton(first: meetup == nil) }
                }

                if let meetup {
                    monthStrip(current: meetup)
                    TicketCard(meetup: meetup)
                    rsvpSection(meetup)
                } else {
                    emptyTicket
                }
                if !agenda.isEmpty { agendaSection }
                voteSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func planButton(first: Bool) -> some View {
        Button {
            showPlan = true
        } label: {
            Label(first ? "Plan one" : "Plan next", systemImage: "square.and.pencil")
                .font(Theme.Fonts.letterpress(17))
                .tracking(1)
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .overlay(Rectangle().strokeBorder(Theme.Colors.ink, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private var emptyTicket: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No meetup on the books yet").font(Theme.Fonts.display(26))
            Text(isHost
                 ? "Put a few books up for a vote below, then plan the meetup when the club has picked."
                 : "Your host hasn't planned one yet. You can still vote on next month's book below.")
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.inkMuted)
        }
        .foregroundStyle(Theme.Colors.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .overlay(Rectangle().strokeBorder(Theme.Colors.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }

    // Past months double as club history.
    private func monthStrip(current: Meetup) -> some View {
        let past = ledger.prefix(2).reversed()
        return HStack(spacing: 6) {
            ForEach(Array(past), id: \.id) { entry in
                monthCell(entry.month.formatted(.dateTime.month(.abbreviated)), entry.title, style: .past)
            }
            monthCell(current.date.formatted(.dateTime.month(.abbreviated)), current.bookTitle, style: .current)
            monthCell("Next", "Voting", style: .next)
        }
    }

    private enum CellStyle { case past, current, next }

    private func monthCell(_ month: String, _ title: String, style: CellStyle) -> some View {
        VStack(spacing: 2) {
            MonoLabel(month, color: style == .current ? Theme.Colors.paperDeep : Theme.Colors.inkMuted, size: 10)
            Text(title)
                .font(Theme.Fonts.display(15))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(style == .current ? Theme.Colors.card : (style == .next ? Theme.Colors.inkMuted : Theme.Colors.ink))
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(style == .current ? Theme.Colors.forest : .clear, in: Rectangle())
        .overlay(
            Rectangle()
                .strokeBorder(style == .current ? .clear : Theme.Colors.lineStrong,
                              style: StrokeStyle(lineWidth: 1, dash: style == .next ? [4, 3] : []))
        )
    }

    private func rsvpSection(_ meetup: Meetup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Are you coming?").font(Theme.Fonts.body(13, weight: .semibold))
            HStack(spacing: 8) {
                ForEach(Meetup.RSVP.allCases) { option in
                    let isOn = meetup.myRSVP == option
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { meetup.rsvp = option }
                        if option == .going { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
                        Task { await ClubSync.shared.setRSVP(option, for: meetup) }
                    } label: {
                        Text(option.title)
                            .font(Theme.Fonts.letterpress(19))
                            .tracking(1.2)
                            .foregroundStyle(isOn ? Theme.Colors.card : Theme.Colors.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(isOn ? Color(hex: option.hex) : .clear)
                            .overlay(Rectangle().stroke(isOn ? Color(hex: option.hex) : Theme.Colors.ink, lineWidth: 1.5))
                            .overlay(Rectangle().inset(by: 3).stroke(isOn ? Color(hex: "E9D6A8") : .clear, lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }

            let going = meetup.goingCount + (meetup.myRSVP == .going ? 1 : 0)
            let maybe = meetup.maybeCount + (meetup.myRSVP == .maybe ? 1 : 0)
            let goingMembers = members.filter { meetup.goingIDs.contains($0.remoteID?.uuidString ?? "") }
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(goingMembers.prefix(6)) { member in
                        Avatar(name: member.name, hex: member.colorHex, size: 36, kind: member.silhouetteKind)
                    }
                }
                Text("\(going) going · \(maybe) maybe")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.inkMuted)
            }
        }
        .foregroundStyle(Theme.Colors.ink)
    }

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "On the agenda", trailing: "\(agenda.count) from notes")
            ForEach(agenda) { note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.oxblood)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text).font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.ink)
                        MonoLabel("\(note.authorName) · p. \(note.page)", size: 10)
                    }
                }
            }
        }
    }

    private var voteSection: some View {
        let total = max(picks.reduce(0) { $0 + $1.total }, 1)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Next month's pick", trailing: picks.isEmpty ? "" : "Tap to vote")
            if picks.isEmpty && !isHost {
                Text("Nothing up for a vote yet.")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.inkMuted)
            }
            ForEach(picks) { pick in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        let wasMine = pick.isMyVote
                        picks.forEach { $0.isMyVote = false }
                        pick.isMyVote = !wasMine
                    }
                    let choice = pick.isMyVote ? pick : nil
                    Task { await ClubSync.shared.vote(for: choice) }
                } label: {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(pick.isMyVote ? Theme.Colors.mustard.opacity(0.35) : Theme.Colors.paperDeep)
                                .frame(width: geo.size.width * CGFloat(pick.total) / CGFloat(total))
                            HStack {
                                Text(pick.title).font(Theme.Fonts.display(20))
                                Text(pick.author).font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.inkMuted)
                                Spacer()
                                if pick.isMyVote {
                                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                }
                                MonoLabel("\(pick.total) votes", color: Theme.Colors.ink, size: 11)
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                    .frame(height: 50)
                    .foregroundStyle(Theme.Colors.ink)
                    .background(Theme.Colors.card)
                    .clipShape(Rectangle())
                    .overlay(Rectangle().stroke(pick.isMyVote ? Theme.Colors.forest : Theme.Colors.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(pick.title), \(pick.total) votes")
                .accessibilityAddTraits(pick.isMyVote ? .isSelected : [])
            }
            if isHost {
                Button {
                    showAddOption = true
                } label: {
                    Label("Add a book to the vote", systemImage: "plus")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.inkMuted)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            if let actionError {
                Text(actionError).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.oxblood)
            }
        }
    }

    /// Host picks from their own shelves, to-read first.
    private var addOptionMenu: [PaperMenuSection] {
        let taken = Set(picks.map { $0.title.lowercased() })
        let candidates = shelfBooks
            .filter { !taken.contains($0.title.lowercased()) && $0.shelf != .finished }
            .sorted { ($0.shelf == .toRead ? 0 : 1) < ($1.shelf == .toRead ? 0 : 1) }
            .prefix(8)
        guard !candidates.isEmpty else {
            return [PaperMenuSection(label: "Add books to your To read shelf first", items: [])]
        }
        return [PaperMenuSection(label: "From your shelves", items: candidates.map { book in
            PaperMenuItem(title: book.title) {
                let (catalogID, title, author, year, pages) = (book.catalogID, book.title, book.author, book.year, book.pageCount)
                Task {
                    do {
                        try await ClubSync.shared.addPickOption(catalogID: catalogID, title: title, author: author,
                                                                year: year, pageCount: pages)
                        actionError = nil
                    } catch {
                        actionError = "Couldn't add \(title). Try again in a moment."
                    }
                }
            }
        })]
    }
}

/// The monthly "ticket": what, when, where. Perforated like a tear-off stub.
struct TicketCard: View {
    @Bindable var meetup: Meetup
    @Environment(\.openURL) private var openURL
    @State private var addedToCalendar = false

    // Mission District placeholder until places get real coordinates
    private let spot = CLLocationCoordinate2D(latitude: 37.7524, longitude: -122.4180)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                SpineSwatch(hex: meetup.spineHex, width: 30, height: 62)
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel("Discussing", size: 10)
                    Text(meetup.bookTitle).font(Theme.Fonts.display(28))
                    Text("\(meetup.readUpTo)\(meetup.bookAuthor.isEmpty ? "" : " · \(meetup.bookAuthor)")")
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.inkMuted)
                }
                Spacer()
            }
            .padding(16)

            Perforation()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel("When", size: 10)
                    Text(meetup.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(Theme.Fonts.display(26))
                    Text(meetup.date.formatted(date: .omitted, time: .shortened)).font(Theme.Fonts.body(14))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel("Where", size: 10)
                    Text(meetup.place).font(Theme.Fonts.display(26))
                    Text(meetup.address).font(Theme.Fonts.body(14))
                }
                Spacer()
            }
            .padding(16)

            Map(initialPosition: .region(MKCoordinateRegion(center: spot, latitudinalMeters: 900, longitudinalMeters: 900)), interactionModes: []) {
                Marker(meetup.place, systemImage: "book.closed.fill", coordinate: spot)
                    .tint(Theme.Colors.oxblood)
            }
            .frame(height: 110)
            .saturation(0.35)               // calmer map so it sits on paper
            .accessibilityLabel("Map of \(meetup.place)")

            if !meetup.bringing.isEmpty {
                HStack {
                    Text("Bringing: \(meetup.bringing)").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.inkMuted)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            HStack(spacing: 0) {
                Button {
                    addedToCalendar = true      // TODO: EventKit
                } label: {
                    Label(addedToCalendar ? "Added" : "Add to calendar", systemImage: addedToCalendar ? "checkmark" : "calendar.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                Rectangle().fill(Theme.Colors.line).frame(width: 1, height: 48)
                Button {
                    let query = "\(meetup.place) \(meetup.address)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "maps://?q=\(query)") { openURL(url) }
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .font(Theme.Fonts.letterpress(17))
            .tracking(1)
            .foregroundStyle(Theme.Colors.ink)
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
        }
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.card)
        .clipShape(Rectangle())
        .overlay(Rectangle().stroke(Theme.Colors.ink, lineWidth: 1.5))
        .overlay(alignment: .topTrailing) {
            if meetup.myRSVP == .going {
                InkStamp(top: "RSVP", middle: "Going", bottom: meetup.date.formatted(.dateTime.day().month(.twoDigits)), size: 88)
                    .padding(12)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
            }
        }
    }
}

/// Dashed tear line with half-circle notches at each end.
struct Perforation: View {
    var body: some View {
        ZStack {
            Line()
                .stroke(Theme.Colors.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .frame(height: 1)
                .padding(.horizontal, 16)
            HStack {
                Circle().fill(Theme.Colors.paper).frame(width: 22, height: 22).offset(x: -11)
                Spacer()
                Circle().fill(Theme.Colors.paper).frame(width: 22, height: 22).offset(x: 11)
            }
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }

    private struct Line: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

#Preview {
    MeetupView()
        .modelContainer(SampleData.previewContainer)
}
