import Foundation
import SwiftUI

/// Victorian cut-paper profile portraits for avatars. All face right.
/// Drawn on a 100×100 grid, built from simple pieces filled the same ink colour.
enum SilhouetteKind: Int, CaseIterable {
    case topHat, updo, featherHat, bowler, bonnet, curls

    var title: String {
        switch self {
        case .topHat: "Top hat"
        case .updo: "Updo"
        case .featherHat: "Feather hat"
        case .bowler: "Bowler"
        case .bonnet: "Bonnet"
        case .curls: "Curls"
        }
    }

    /// Same person always gets the same silhouette.
    static func forName(_ name: String) -> SilhouetteKind {
        let seed = name.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return allCases[seed % allCases.count]
    }
}

struct SilhouetteView: View {
    let kind: SilhouetteKind

    var body: some View {
        ZStack {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                piece
            }
        }
        .accessibilityHidden(true)
    }

    private var pieces: [GridPiece] {
        var list: [GridPiece] = [.head]
        switch kind {
        case .topHat:
            list += [
                .ellipse(24, 26, 86, 34),           // brim
                .roundedRect(34, 2, 72, 30, 3),     // crown
                .ellipse(57, 71, 71, 81),           // cravat
            ]
        case .updo:
            list += [
                .ellipse(27, 17, 67, 52),           // hair over the crown
                .ellipse(20, 12, 42, 34),           // bun
                .ellipse(33, 50, 42, 62),           // curl at the nape
            ]
        case .featherHat:
            list += [
                .ellipse(27, 26, 64, 54),           // hair
                .ellipse(22, 40, 38, 58),           // low bun
                .ellipse(20, 22, 94, 34),           // wide brim
                .ellipse(36, 8, 72, 30),            // crown
                .rotatedEllipse(42, 0, 54, 20, -25),// feathers
                .rotatedEllipse(52, 2, 60, 16, 20),
            ]
        case .bowler:
            list += [
                .ellipse(34, 10, 70, 36),           // dome
                .ellipse(28, 28, 80, 35),           // brim
                .ellipse(65, 53, 77, 58),           // moustache
                .ellipse(55, 71, 70, 81),           // collar
            ]
        case .bonnet:
            list += [
                .ellipse(20, 12, 72, 58),           // bonnet
                .ellipse(56, 12, 72, 44),           // front brim
                .ellipse(57, 69, 70, 78),           // ribbon bow
            ]
        case .curls:
            list += [
                .ellipse(22, 22, 42, 42),           // curls around the back of the head
                .ellipse(32, 13, 52, 33),
                .ellipse(46, 12, 64, 30),
                .ellipse(20, 36, 38, 54),
                .ellipse(28, 48, 42, 62),
                .ellipse(30, 72, 82, 86),           // ruff collar
            ]
        }
        return list
    }
}

/// One piece of a silhouette, in 0–100 grid units.
struct GridPiece: Shape {
    enum Kind {
        case head
        case ellipse(CGFloat, CGFloat, CGFloat, CGFloat)
        case rotatedEllipse(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        case roundedRect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    }
    let kind: Kind

    static let head = GridPiece(kind: .head)
    static func ellipse(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> GridPiece { .init(kind: .ellipse(x0, y0, x1, y1)) }
    static func rotatedEllipse(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ degrees: CGFloat) -> GridPiece { .init(kind: .rotatedEllipse(x0, y0, x1, y1, degrees)) }
    static func roundedRect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ r: CGFloat) -> GridPiece { .init(kind: .roundedRect(x0, y0, x1, y1, r)) }

    nonisolated func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x / 100 * r.width, y: r.minY + y / 100 * r.height)
        }
        func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(origin: p(x0, y0), size: CGSize(width: (x1 - x0) / 100 * r.width, height: (y1 - y0) / 100 * r.height))
        }

        var path = Path()
        switch kind {
        case .head:
            // bust in profile, facing right: shoulders, nape, crown, brow, nose, lips, chin, chest
            path.move(to: p(4, 100))
            path.addQuadCurve(to: p(20, 82), control: p(6, 86))
            path.addQuadCurve(to: p(38, 74), control: p(30, 78))
            path.addLine(to: p(39, 64))
            path.addQuadCurve(to: p(30, 44), control: p(30, 58))
            path.addQuadCurve(to: p(52, 22), control: p(30, 22))
            path.addQuadCurve(to: p(68, 36), control: p(66, 24))
            path.addQuadCurve(to: p(69, 43), control: p(70, 40))
            path.addLine(to: p(76, 52))
            path.addQuadCurve(to: p(71, 55), control: p(75, 55))
            path.addQuadCurve(to: p(72, 58), control: p(73, 56))
            path.addLine(to: p(70, 59.5))
            path.addQuadCurve(to: p(71, 62), control: p(72, 60.5))
            path.addQuadCurve(to: p(66, 70), control: p(71, 69))
            path.addQuadCurve(to: p(60, 72), control: p(62, 70.5))
            path.addLine(to: p(61, 77))
            path.addQuadCurve(to: p(84, 86), control: p(70, 82))
            path.addQuadCurve(to: p(98, 100), control: p(94, 90))
            path.closeSubpath()
        case let .ellipse(x0, y0, x1, y1):
            path.addEllipse(in: box(x0, y0, x1, y1))
        case let .rotatedEllipse(x0, y0, x1, y1, degrees):
            let rect = box(x0, y0, x1, y1)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: degrees * .pi / 180)
                .translatedBy(x: -center.x, y: -center.y)
            path.addEllipse(in: rect, transform: transform)
        case let .roundedRect(x0, y0, x1, y1, radius):
            path.addRoundedRect(in: box(x0, y0, x1, y1), cornerSize: CGSize(width: radius, height: radius))
        }
        return path
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(SilhouetteKind.allCases, id: \.self) { kind in
            SilhouetteView(kind: kind)
                .foregroundStyle(Theme.Colors.ink)
                .frame(width: 50, height: 60)
        }
    }
    .padding()
    .background(Theme.Colors.paper)
}
