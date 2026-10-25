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

    @State private var showPlan = false

    var body: some View {
        NavigationStack {
            Group {
                if let meetup = meetups.first {
                    content(meetup)
                } else {
                    ContentUnavailableView("No meetup yet", systemImage: "calendar")
                }
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPlan) {
                PlanMeetupView(nextNumber: (meetups.first?.number ?? 0) + 1)
            }
        }
    }

    private func content(_ meetup: Meetup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel("Meeting no. \(meetup.number)", color: Theme.Colors.oxblood)
                        Text(meetup.date.formatted(.dateTime.month(.wide)))
                            .font(Theme.Fonts.display(46))
                            .foregroundStyle(Theme.Colors.ink)
                    }
                    Spacer()
                    Button {
                        showPlan = true
                    } label: {
                        Label("Plan next", systemImage: "square.and.pencil")
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

                monthStrip(current: meetup)
                TicketCard(meetup: meetup)
                rsvpSection(meetup)
                if !agenda.isEmpty { agendaSection }
                voteSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
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
                    let isOn = meetup.rsvp == option
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { meetup.rsvp = option }
                        if option == .going { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
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

            let going = meetup.goingCount + (meetup.rsvp == .going ? 1 : 0)
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(members.prefix(meetup.goingCount)) { member in
                        Avatar(initial: member.initial, hex: member.colorHex, size: 30)
                            .overlay(Circle().stroke(Theme.Colors.paper, lineWidth: 2))
                    }
                }
                Text("\(going) going · \(meetup.maybeCount) maybe")
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
            SectionTitle(title: "Next month's pick", trailing: "Closes in 4 days")
            ForEach(picks) { pick in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        let wasMine = pick.isMyVote
                        picks.forEach { $0.isMyVote = false }
                        pick.isMyVote = !wasMine
                    }
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
        }
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
            if meetup.rsvp == .going {
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
