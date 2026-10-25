import Foundation
import SwiftUI

/// A club note styled like a ruled index card.
struct NoteCard: View {
    let note: Note
    var tilt: Double = 0
    var memberHex: String = Theme.Spine.olive
    var memberKind: SilhouetteKind? = nil
    var isMine = false
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showActions = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isMine {
                MyAvatar(size: 36)
            } else {
                Avatar(name: note.authorName, hex: memberHex, size: 36, kind: memberKind)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(note.authorName).font(Theme.Fonts.body(14, weight: .semibold))
                    if let rating = note.rating {
                        Stars(rating: Double(rating), size: 10)
                    }
                    Spacer()
                    MonoLabel("p. \(note.page)", size: 10)
                    if isMine, onEdit != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showActions.toggle()
                                confirmingDelete = false
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.inkMuted)
                                .frame(width: 32, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Note options")
                    }
                }
                Text(note.text)
                    .font(Theme.Fonts.body(15))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if note.discussAtMeetup {
                    MonoLabel("Discuss at meetup", color: Theme.Colors.forest, size: 10)
                }
                if showActions { actions.transition(.opacity.combined(with: .move(edge: .top))) }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(ruledPaper)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Theme.Colors.ink.opacity(0.1), radius: 8, y: 5)
        .rotationEffect(.degrees(tilt))
    }

    /// Inline, on the card itself: Edit · Delete, and a second tap to confirm a delete.
    private var actions: some View {
        HStack(spacing: 8) {
            if confirmingDelete {
                Text("Delete for everyone?")
                    .font(Theme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.oxblood)
                Spacer()
                Button("Keep") { withAnimation { confirmingDelete = false } }
                    .buttonStyle(SmallButtonStyle())
                Button("Delete") {
                    showActions = false
                    onDelete?()
                }
                .buttonStyle(SmallButtonStyle(filled: true, color: Theme.Colors.oxblood))
            } else {
                Spacer()
                Button("Edit") {
                    showActions = false
                    onEdit?()
                }
                .buttonStyle(SmallButtonStyle())
                Button("Delete") { withAnimation { confirmingDelete = true } }
                    .buttonStyle(SmallButtonStyle(color: Theme.Colors.oxblood))
            }
        }
        .padding(.top, 4)
    }

    // index-card ruling: blue lines + one red margin line
    private var ruledPaper: some View {
        Canvas { context, size in
            var y: CGFloat = 36
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Color(hex: "C9D6E3")))
                y += 24
            }
            context.fill(Path(CGRect(x: 52, y: 0, width: 1, height: size.height)), with: .color(Color(hex: "D99A93")))
        }
        .background(Theme.Colors.card)
    }
}
