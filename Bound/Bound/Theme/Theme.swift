import Foundation
import SwiftUI

/// Bound's design tokens. Paper ground, ink text, fall bookcloth accents.
enum Theme {
    enum Colors {
        static let paper     = Color(hex: "F2EADB")   // app background
        static let paperDeep = Color(hex: "E8DDC7")   // fills, inactive chips
        static let card      = Color(hex: "FAF5EA")   // slips, cards
        static let ink       = Color(hex: "221A14")   // primary text
        static let inkMuted  = Color(hex: "5E5246")   // secondary text, passes 4.5:1 on paper
        static let line      = Color(hex: "DCCFB6")   // hairlines
        static let lineStrong = Color(hex: "A79C88")  // chip outlines

        static let forest  = Color(hex: "2F4A35")     // primary actions
        static let oxblood = Color(hex: "8A2C22")     // labels, accents
        static let rust    = Color(hex: "B4572A")
        static let mustard = Color(hex: "C69A3A")
        static let olive   = Color(hex: "6F7442")
        static let gilt    = Color(hex: "A9813A")     // decoration only, too light for text

        static let oak     = Color(hex: "7A4B2E")     // shelf plank
        static let oakDark = Color(hex: "57341F")     // plank front edge
    }

    /// Spine colours, stored on each Book as hex so a book keeps its colour.
    enum Spine {
        static let forest = "2F4A35", oxblood = "8A2C22", rust = "B4572A", mustard = "C69A3A"
        static let olive = "6F7442", ink = "221A14", plum = "5A3A4E", navy = "2B3A55"
        static let cream = "E9DFC8", sage = "7D8B6A"
    }

    enum Fonts {
        /// Blackletter masthead, for the "Bound" wordmark only.
        static func masthead(_ size: CGFloat) -> Font {
            .custom("UnifrakturMaguntia", size: size, relativeTo: .largeTitle)
        }
        /// Editorial serif for titles and shelf headers.
        static func display(_ size: CGFloat) -> Font {
            .custom("InstrumentSerif-Regular", size: size, relativeTo: .title)
        }
        static func displayItalic(_ size: CGFloat) -> Font {
            .custom("InstrumentSerif-Italic", size: size, relativeTo: .title2)
        }
        /// UI + body text. Variable font, so .weight() works.
        static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom("HankenGrotesk-Regular", size: size, relativeTo: .body).weight(weight)
        }
        /// Library-card labels: dates, counts, shelf tags. Pair with .tracking + uppercase.
        static func mono(_ size: CGFloat, medium: Bool = false) -> Font {
            .custom(medium ? "DMMono-Medium" : "DMMono-Regular", size: size, relativeTo: .caption)
        }
    }
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// True for light spines, so their titles switch to ink instead of paper.
    static func isLight(hex: String) -> Bool {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF), g = Double((value >> 8) & 0xFF), b = Double(value & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 160
    }
}

extension Theme.Colors {
    static let tearSheet = Color(hex: "233A2B")   // the tear sheet
    static let tearMark  = Color(hex: "2E4A38")   // wordmark printed on it
    static let fibre     = Color(hex: "EFE6D3")   // torn paper fibres
}
