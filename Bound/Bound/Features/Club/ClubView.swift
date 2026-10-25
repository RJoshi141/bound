import Foundation
import SwiftUI
import SwiftData

struct ClubView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.clubName) private var clubName = "Tuesday Night Readers"
    @AppStorage(AppKeys.memberName) private var memberName = ""

    @Query(sort: \ClubMember.booksRead, order: .reverse) private var members: [ClubMember]
    @Query(sort: \LedgerEntry.month, order: .reverse) private var ledger: [LedgerEntry]
    @Query private var recs: [Recommendation]

    @State private var showLedger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    passedToYou
                    LedgerCard(entries: Array(ledger.prefix(5)), total: ledger.count) {
                        showLedger = true
                    }
                    membersList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showLedger) {
                LedgerView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel("\(members.count + 1) members · est. 2024", color: Theme.Colors.oxblood)
                Text(clubName)
                    .font(Theme.Fonts.display(42))
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            ShareLink(item: "Join \(clubName) on Bound with code TNR24K") {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(width: 44, height: 44)
                    .overlay(Rectangle().stroke(Theme.Colors.ink, lineWidth: 1.5))
            }
            .accessibilityLabel("Invite members")
            .padding(.top, 18)
        }
    }

    private var passedToYou: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Passed to you", trailing: "\(recs.filter { !$0.isAdded }.count) new")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recs) { rec in
                        RecCard(rec: rec) { add(rec) }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var membersList: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "Members")
            memberRow(initial: String((memberName.isEmpty ? "You" : memberName).prefix(1)), hex: Theme.Spine.forest,
                      name: memberName.isEmpty ? "You" : "\(memberName) (you)", status: "That's you", count: nil)
            ForEach(members) { member in
                memberRow(initial: member.initial, hex: member.colorHex,
                          name: member.isHost ? "\(member.name) · host" : member.name,
                          status: member.status, count: member.booksRead)
            }
        }
    }

    private func memberRow(initial: String, hex: String, name: String, status: String, count: Int?) -> some View {
        HStack(spacing: 12) {
            Avatar(initial: initial, hex: hex, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Theme.Fonts.body(15, weight: .semibold))
                Text(status).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer()
            if let count { MonoLabel("\(count) books", size: 10) }
        }
        .foregroundStyle(Theme.Colors.ink)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
    }

    private func add(_ rec: Recommendation) {
        guard !rec.isAdded else { return }
        context.insert(Book(title: rec.title, author: rec.author, pageCount: rec.pageCount, spineHex: rec.spineHex))
        withAnimation { rec.isAdded = true }
    }
}

struct RecCard: View {
    let rec: Recommendation
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SpineSwatch(hex: rec.spineHex, width: 26, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel("From \(rec.fromName)", color: Theme.Colors.oxblood, size: 10)
                    Text(rec.title).font(Theme.Fonts.display(22)).lineLimit(1)
                    Text(rec.reason)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.inkMuted)
                        .lineLimit(2)
                }
            }
            Button(action: onAdd) {
                Label(rec.isAdded ? "On your shelf" : "Add to To read", systemImage: rec.isAdded ? "checkmark" : "plus")
            }
            .buttonStyle(SmallButtonStyle(filled: rec.isAdded, fullWidth: true))
            .disabled(rec.isAdded)
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(14)
        .frame(width: 264)
        .paperCard()
    }
}

/// The club's reading history, styled like a library due-date card.
struct LedgerCard: View {
    let entries: [LedgerEntry]
    let total: Int
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel("Club ledger", size: 10)
                    Text("Books we've read").font(Theme.Fonts.display(26))
                }
                Spacer()
                Text("\(total)").font(Theme.Fonts.display(38)).foregroundStyle(Theme.Colors.oxblood)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.ink).frame(height: 2) }

            HStack {
                MonoLabel("Month", size: 9).frame(width: 64, alignment: .leading)
                MonoLabel("Title", size: 9)
                Spacer()
                MonoLabel("Club", size: 9).frame(width: 44, alignment: .trailing)
                MonoLabel("You", size: 9).frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .frame(height: 30)

            ForEach(entries) { entry in
                HStack {
                    Text(entry.month.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                        .font(Theme.Fonts.mono(12))
                        .foregroundStyle(Theme.Colors.oxblood)
                        .frame(width: 64, alignment: .leading)
                    Text(entry.title).font(Theme.Fonts.display(18)).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f", entry.clubRating))
                        .font(Theme.Fonts.body(14, weight: entry.clubRating >= 4.5 ? .bold : .regular))
                        .frame(width: 44, alignment: .trailing)
                    Text(entry.myRating.map(String.init) ?? "–")
                        .font(Theme.Fonts.body(14))
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 42)
                .overlay(alignment: .top) { Rectangle().fill(Color(hex: "C9D6E3")).frame(height: 1) }
            }

            if let onSeeAll {
                Button("See all \(total)", action: onSeeAll)
                    .font(Theme.Fonts.mono(11, medium: true))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.oxblood)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(alignment: .top) { Rectangle().fill(Color(hex: "C9D6E3")).frame(height: 1) }
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Theme.Colors.ink.opacity(0.15), radius: 14, y: 10)
    }
}

struct LedgerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LedgerEntry.month, order: .reverse) private var ledger: [LedgerEntry]

    private var average: Double {
        guard !ledger.isEmpty else { return 0 }
        return ledger.map(\.clubRating).reduce(0, +) / Double(ledger.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton(title: "Club") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel("Since 2024", color: Theme.Colors.oxblood)
                        Text("The ledger").font(Theme.Fonts.display(46))
                    }
                    HStack(spacing: 0) {
                        stat("\(ledger.count)", "Books")
                        stat(String(format: "%.1f", average), "Avg rating")
                        stat(ledger.max { $0.clubRating < $1.clubRating }?.title ?? "–", "Club favourite")
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.ink).frame(height: 1.5) }
                    LedgerCard(entries: ledger, total: ledger.count)
                }
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.Fonts.display(26)).lineLimit(1).minimumScaleFactor(0.6)
            MonoLabel(label, size: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

#Preview {
    ClubView()
        .modelContainer(SampleData.previewContainer)
}
