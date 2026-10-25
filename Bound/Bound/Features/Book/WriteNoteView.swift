import Foundation
import SwiftUI
import SwiftData

struct WriteNoteView: View {
    @Bindable var book: Book
    /// Set when editing one of your notes instead of writing a new one.
    var editing: Note? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.memberName) private var memberName = ""

    @State private var rating: Int?
    @State private var finished = false
    @State private var text = ""
    @State private var tags: Set<String> = []
    @State private var spoilers = false
    @FocusState private var editorFocused: Bool
    @State private var isSaving = false
    @State private var errorText: String?

    private let quickTags = ["Would recommend", "Slow start", "Tearjerker", "Discuss at meetup"]
    private var canPost: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(Theme.Fonts.letterpress(18))
                    .frame(minHeight: 44)
                Spacer()
                Text(editing == nil ? "Your note" : "Edit note").font(Theme.Fonts.body(17, weight: .semibold))
                Spacer()
                Button(editing == nil ? "Post" : "Save") {
                    if editing == nil { post() } else { Task { await save() } }
                }
                    .buttonStyle(SmallButtonStyle(filled: true))
                    .opacity(canPost && !isSaving ? 1 : 0.4)
                    .disabled(!canPost || isSaving)
            }
            .foregroundStyle(Theme.Colors.ink)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if let errorText {
                Text(errorText)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.oxblood)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        SpineSwatch(hex: book.spineHex, width: 26, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title).font(Theme.Fonts.display(24))
                            Text("You're on p. \(book.currentPage) of \(book.pageCount)")
                                .font(Theme.Fonts.body(13))
                                .foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your rating").font(Theme.Fonts.body(13, weight: .semibold))
                        StarPicker(rating: $rating).offset(x: -10)
                        Text("Optional until you finish the book")
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.inkMuted)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where are you?").font(Theme.Fonts.body(13, weight: .semibold))
                        Picker("Where are you?", selection: $finished) {
                            Text("Still reading · p. \(book.currentPage)").tag(false)
                            Text("Finished").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your note").font(Theme.Fonts.body(13, weight: .semibold))
                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("What stayed with you?")
                                    .font(Theme.Fonts.body(16))
                                    .foregroundStyle(Theme.Colors.inkMuted)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 20)
                            }
                            TextEditor(text: $text)
                                .font(Theme.Fonts.body(16))
                                .scrollContentBackground(.hidden)
                                .focused($editorFocused)
                                .padding(12)
                        }
                        .frame(minHeight: 160)
                        .background(Theme.Colors.card)
                        .overlay(Rectangle().stroke(Theme.Colors.ink, lineWidth: 1.5))
                        HStack {
                            Spacer()
                            MonoLabel("\(text.count) / 500", size: 10)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick tags").font(Theme.Fonts.body(13, weight: .semibold))
                        FlowLayout(spacing: 8) {
                            ForEach(quickTags, id: \.self) { tag in
                                Chip(title: tag, isOn: tags.contains(tag)) {
                                    if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
                                }
                            }
                        }
                    }

                    Toggle("Contains spoilers past p. \(book.currentPage)", isOn: $spoilers)
                        .font(Theme.Fonts.body(15))
                        .tint(Theme.Colors.oxblood)
                }
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .paperBackground()
        .onChange(of: text) { _, new in
            if new.count > 500 { text = String(new.prefix(500)) }
        }
        .onAppear {
            if let editing {
                text = editing.text
                rating = editing.rating
                spoilers = editing.containsSpoilers
                finished = editing.page >= book.pageCount
                if editing.discussAtMeetup { tags.insert("Discuss at meetup") }
            } else {
                finished = book.shelf == .finished
            }
        }
    }

    /// Editing keeps the page you wrote it at, unless you now mark it as written after finishing.
    private func save() async {
        guard let editing else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await ShelfSync.shared.updateNote(
                editing,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                rating: rating,
                page: finished ? book.pageCount : min(editing.page, book.pageCount),
                containsSpoilers: spoilers,
                discussAtMeetup: tags.contains("Discuss at meetup")
            )
            dismiss()
        } catch {
            errorText = "Couldn't save your edit. Check your connection and try again."
        }
    }

    private func post() {
        let note = Note(
            authorName: memberName.isEmpty ? "You" : memberName,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: rating,
            page: finished ? book.pageCount : book.currentPage,
            discussAtMeetup: tags.contains("Discuss at meetup"),
            containsSpoilers: spoilers
        )
        context.insert(note)
        note.book = book
        if finished {
            book.currentPage = book.pageCount
            book.shelf = .finished
        }
        dismiss()
    }
}

/// Wraps chips onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var index = 0
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for _ in 0..<row.count {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .unspecified)
                x += size.width + spacing
                index += 1
            }
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(count: Int, y: CGFloat, height: CGFloat)] {
        var rows: [(count: Int, y: CGFloat, height: CGFloat)] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, count = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && count > 0 {
                rows.append((count, y, rowHeight))
                y += rowHeight + spacing
                x = 0; rowHeight = 0; count = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            count += 1
        }
        if count > 0 { rows.append((count, y, rowHeight)) }
        return rows
    }
}
