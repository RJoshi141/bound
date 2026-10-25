import Foundation
import SwiftUI

// MARK: - Text

/// Library-card label: DM Mono, tracked, uppercase.
struct MonoLabel: View {
    let text: String
    var color: Color = Theme.Colors.inkMuted
    var size: CGFloat = 11

    init(_ text: String, color: Color = Theme.Colors.inkMuted, size: CGFloat = 11) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(Theme.Fonts.mono(size))
            .tracking(size * 0.12)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// Italic serif section header with an optional mono label on the right.
struct SectionTitle: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.Fonts.displayItalic(26))
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            if let trailing { MonoLabel(trailing) }
        }
    }
}

// MARK: - Buttons
// Square corners + IM Fell small caps everywhere: printed, not app-y.

/// Big filled button: forest, with a cream hairline inset like a printed border.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.Colors.forest

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.letterpress(21))
            .tracking(1.5)
            .foregroundStyle(Theme.Colors.card)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(fill)
            .overlay(Rectangle().inset(by: 4).stroke(Color(hex: "E9D6A8"), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

/// Big outline button: ink rule with a second hairline just inside.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.letterpress(21))
            .tracking(1.5)
            .foregroundStyle(Theme.Colors.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay(Rectangle().stroke(Theme.Colors.ink, lineWidth: 1.5))
            .overlay(Rectangle().inset(by: 4).stroke(Theme.Colors.ink, lineWidth: 0.75))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Small inline button ("Log pages", "Open"). Filled = forest, otherwise ink outline.
struct SmallButtonStyle: ButtonStyle {
    var filled = false
    var color: Color = Theme.Colors.ink
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.letterpress(17))
            .tracking(1.2)
            .foregroundStyle(filled ? Theme.Colors.card : color)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 40)
            .background(filled ? Theme.Colors.forest : .clear)
            .overlay(Rectangle().stroke(filled ? Theme.Colors.forest : color, lineWidth: 1.5))
            .overlay {
                if filled { Rectangle().inset(by: 3).stroke(Color(hex: "E9D6A8"), lineWidth: 0.75) }
            }
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// 44pt icon button. Square ruled outline by default; `bordered: false` for bare icons.
struct IconButton: View {
    let systemName: String
    let label: String
    var color: Color = Theme.Colors.ink
    var filled = false
    var bordered = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(filled ? Theme.Colors.card : color)
                .frame(width: 44, height: 44)
                .background(filled ? color : .clear)
                .overlay(Rectangle().stroke(bordered ? color : .clear, lineWidth: 1.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct Chip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.letterpress(16))
                .tracking(1)
                .foregroundStyle(isOn ? Theme.Colors.paper : Theme.Colors.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(isOn ? Theme.Colors.ink : .clear)
                .overlay(Rectangle().stroke(isOn ? Theme.Colors.ink : Theme.Colors.lineStrong, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Header back button that runs the tear on the way out.
struct BackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                Text(title).font(Theme.Fonts.letterpress(18)).tracking(1)
            }
            .foregroundStyle(Theme.Colors.ink)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bits

struct Avatar: View {
    let initial: String
    let hex: String
    var size: CGFloat = 34

    var body: some View {
        Text(initial)
            .font(Theme.Fonts.script(size * 0.62))
            .offset(y: size * 0.04)
            .foregroundStyle(Color.isLight(hex: hex) ? Theme.Colors.ink : Theme.Colors.card)
            .frame(width: size, height: size)
            .background(Color(hex: hex), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Mini book spine, used in lists and cards.
struct SpineSwatch: View {
    let hex: String
    var width: CGFloat = 26
    var height: CGFloat = 60

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: hex))
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.Colors.gilt).frame(height: 1.5).padding(.horizontal, 2).padding(.top, 6)
            }
            .overlay(alignment: .trailing) {
                Rectangle().fill(.black.opacity(0.18)).frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .accessibilityHidden(true)
    }
}

/// Read-only star row.
struct Stars: View {
    let rating: Double
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating.rounded() ? "star.fill" : "star")
                    .font(.system(size: size))
            }
        }
        .foregroundStyle(Theme.Colors.oxblood)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%.1f out of 5 stars", rating))
    }
}

/// Tappable 1–5 stars. Tap the current value again to clear it.
struct StarPicker: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    rating = (rating == i) ? nil : i
                } label: {
                    Image(systemName: i <= (rating ?? 0) ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Colors.oxblood)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
            }
        }
    }
}

/// Rubber ink stamp, for RSVPs and finished books.
struct InkStamp: View {
    let top: String
    let middle: String
    let bottom: String
    var size: CGFloat = 92

    var body: some View {
        VStack(spacing: 0) {
            MonoLabel(top, color: Theme.Colors.oxblood, size: 9)
            Text(middle).font(Theme.Fonts.display(size * 0.3))
            MonoLabel(bottom, color: Theme.Colors.oxblood, size: 9)
        }
        .foregroundStyle(Theme.Colors.oxblood)
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.Colors.oxblood, lineWidth: 2.5))
        .overlay(Circle().inset(by: 6).stroke(Theme.Colors.oxblood, lineWidth: 1))
        .rotationEffect(.degrees(-14))
        .opacity(0.9)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Paper card: lighter fill, hairline, soft shadow.
    func paperCard(radius: CGFloat = 10) -> some View {
        self
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.Colors.line))
            .shadow(color: Theme.Colors.ink.opacity(0.08), radius: 10, y: 6)
    }

    /// Full-bleed paper background for a screen.
    func paperBackground() -> some View {
        self.background(Theme.Colors.paper.ignoresSafeArea())
    }
}
