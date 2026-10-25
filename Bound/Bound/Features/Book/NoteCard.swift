import Foundation
import SwiftUI

/// A club note styled like a ruled index card.
struct NoteCard: View {
    let note: Note
    var tilt: Double = 0
    var memberHex: String = Theme.Spine.olive

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(name: note.authorName, hex: memberHex, size: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(note.authorName).font(Theme.Fonts.body(14, weight: .semibold))
                    if let rating = note.rating {
                        Stars(rating: Double(rating), size: 10)
                    }
                    Spacer()
                    MonoLabel("p. \(note.page)", size: 10)
                }
                Text(note.text)
                    .font(Theme.Fonts.body(15))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if note.discussAtMeetup {
                    MonoLabel("Discuss at meetup", color: Theme.Colors.forest, size: 10)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(ruledPaper)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Theme.Colors.ink.opacity(0.1), radius: 8, y: 5)
        .rotationEffect(.degrees(tilt))
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
