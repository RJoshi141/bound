import Foundation
import SwiftUI

// The page tear: a rip runs across the bottom of the outgoing screen, then the
// page lifts straight up and away, revealing the new screen underneath.
// One-way. Used when leaving the start screen and when finishing the join flow.

extension Animation {
    /// Gentle in-out over the whole tear; the modifier splits it into rip → peel phases.
    static let tear = Animation.timingCurve(0.42, 0, 0.25, 1, duration: 2.6)
}

extension AnyTransition {
    /// Put on the OUTGOING view, with a higher zIndex so it stays on top while it lifts.
    static var tearAway: AnyTransition {
        .asymmetric(
            insertion: .identity,
            removal: .modifier(active: TearAway(progress: 1), identity: TearAway(progress: 0))
        )
    }

    /// For the screen being revealed underneath: settles up from slightly sunk and dim.
    static var revealUnder: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: RevealUnder(progress: 0), identity: RevealUnder(progress: 1)),
            removal: .identity
        )
    }
}

/// Maps 0...1 onto a sub-range with smoothstep easing, so phases overlap softly.
private func phase(_ t: Double, from start: Double, to end: Double) -> Double {
    let x = min(max((t - start) / (end - start), 0), 1)
    return x * x * (3 - 2 * x)
}

struct TearAway: ViewModifier, Animatable {
    var progress: Double            // 0 = resting, 1 = gone

    // Animatable makes SwiftUI tween progress frame by frame.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let rip = phase(progress, from: 0.0, to: 0.38)     // rip travels left → right
        let peel = phase(progress, from: 0.22, to: 1.0)    // page lifts straight up

        return content
            // the torn mask, extended past the safe areas so nothing shows white
            .mask {
                TornPage(rip: rip).ignoresSafeArea()
            }
            // paper fibres along the rip
            .background {
                TornPage(rip: rip, fiber: true)
                    .fill(Theme.Colors.fibre)
                    .ignoresSafeArea()
            }
            .shadow(color: .black.opacity(0.28 * min(rip * 2, 1)), radius: 10 + 20 * peel, y: 8 + 16 * peel)
            // straight up, no tilt or curl
            .visualEffect { view, proxy in
                view.offset(y: -peel * (proxy.size.height + 260))
            }
    }
}

struct RevealUnder: ViewModifier, Animatable {
    var progress: Double            // 0 = sunk/dim, 1 = settled

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let settle = phase(progress, from: 0.2, to: 1.0)
        return content
            .scaleEffect(0.96 + 0.04 * settle)
            // no background here on purpose: the layer behind (root paper, or the join painting) fills the edges
            .overlay { Color.black.opacity(0.18 * (1 - settle)).ignoresSafeArea().allowsHitTesting(false) }
    }
}

/// A full page whose bottom edge tears as `rip` goes 0 → 1 (the rip front moves left to right).
/// `fiber` draws the deeper, lighter layer that peeks out below the rip.
struct TornPage: Shape {
    var rip: Double
    var fiber = false
    var edgeDepth: CGFloat = 48

    var animatableData: Double {
        get { rip }
        set { rip = newValue }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        guard rip > 0 else { return Path(rect) }

        var path = Path()
        let top = rect.maxY - edgeDepth
        let front = rect.minX + rect.width * 1.25 * rip      // where the tear has reached

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // seeded noise so the fibre layer follows the same rip line
        var state: UInt64 = 7
        func random() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) % 1000) / 1000
        }

        var x = rect.maxX
        while x >= rect.minX {
            var y = 0.38 + 0.16 * sin(x / 41) + 0.09 * sin(x / 13 + 1) + random() * 0.14
            let fibreDepth = 0.08 + random() * 0.2
            if fiber { y += fibreDepth }
            // untorn ahead of the front, fully torn ~60pt behind it
            let torn = min(max((front - x) / 60, 0), 1)
            let rippedY = top + min(y, 1) * edgeDepth
            path.addLine(to: CGPoint(x: x, y: rect.maxY + (rippedY - rect.maxY) * torn))
            x -= 5
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
