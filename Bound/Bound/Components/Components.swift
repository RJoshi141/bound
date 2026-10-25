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

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.Colors.forest

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(16, weight: .semibold))
            .foregroundStyle(Theme.Colors.card)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(16, weight: .semibold))
            .foregroundStyle(Theme.Colors.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(Capsule().stroke(Theme.Colors.ink, lineWidth: 1.5))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Round 44pt icon button with an outline.
struct CircleIconButton: View {
    let systemName: String
    let label: String
    var color: Color = Theme.Colors.ink
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(filled ? Theme.Colors.card : color)
                .frame(width: 44, height: 44)
                .background(filled ? color : .clear, in: Circle())
                .overlay(Circle().stroke(color, lineWidth: 1.5))
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
                .font(Theme.Fonts.body(13, weight: .medium))
                .foregroundStyle(isOn ? Theme.Colors.paper : Theme.Colors.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(isOn ? Theme.Colors.ink : .clear, in: Capsule())
                .overlay(Capsule().stroke(isOn ? Theme.Colors.ink : Theme.Colors.lineStrong, lineWidth: 1.5))
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
                Text(title).font(Theme.Fonts.body(16))
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
            .font(Theme.Fonts.body(size * 0.4, weight: .semibold))
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
