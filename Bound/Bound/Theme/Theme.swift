import Foundation
import SwiftUI
import UIKit

/// Bound's design tokens. Paper ground, ink text, fall bookcloth accents.
enum Theme {
    enum Colors {
        static let paper     = Color(hex: "F2EADB")   // app background
        static let paperDeep = Color(hex: "E8DDC7")   // fills, inactive chips
        static let card      = Color(hex: "FAF5EA")   // slips, cards
        // Text + rules flip with the surface: ink on paper, cream on mahogany (dark colour scheme).
        static let ink       = Color.dynamic(light: "221A14", dark: "F4EBDD")   // primary text
        static let inkMuted  = Color.dynamic(light: "5E5246", dark: "CDB9A2")   // secondary text, 4.5:1+ on both
        static let line      = Color.dynamic(light: "DCCFB6", dark: "6A4535")   // hairlines
        static let lineStrong = Color.dynamic(light: "A79C88", dark: "A07E68")  // chip outlines
        static let inverse   = Color.dynamic(light: "F2EADB", dark: "2A120C")   // text on an ink fill

        // Never flip: spines, silhouettes, shadows.
        static let inkFixed   = Color(hex: "221A14")
        static let paperFixed = Color(hex: "F2EADB")

        // Mahogany
        static let mahogany     = Color(hex: "4A1D12")
        static let mahoganyDeep = Color(hex: "2A100A")

        static let forest  = Color(hex: "2F4A35")     // primary actions
        static let oxblood = Color.dynamic(light: "8A2C22", dark: "E3A47E")   // accents; warm apricot on wood
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
        /// Engraved small caps for every button. Pair with a little tracking.
        static func letterpress(_ size: CGFloat) -> Font {
            .custom("IM_FELL_English_SC", size: size, relativeTo: .body)
        }
        /// Copperplate script. Only used for avatar initials (the "profile picture").
        /// Runs small, so use roughly 1.4x the size you'd give body text.
        static func script(_ size: CGFloat) -> Font {
            .custom("PinyonScript-Regular", size: size, relativeTo: .body)
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
    static let fibre     = Color(hex: "EFE6D3")   // torn paper fibres
}


extension Color {
    /// One colour for paper surfaces (light scheme) and one for mahogany (dark scheme).
    static func dynamic(light: String, dark: String) -> Color {
        let lightColor = UIColor(hex: light), darkColor = UIColor(hex: dark)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor })
    }
}

extension UIColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
