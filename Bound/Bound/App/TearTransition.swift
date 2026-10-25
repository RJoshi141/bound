import Foundation
import SwiftUI

// The page tear: the outgoing screen rips along its bottom edge and lifts away
// upward, revealing the new screen underneath. One-way, no sheet coming back.
// Only used when leaving the start screen.

extension Animation {
    static let tear = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.9)
}

extension AnyTransition {
    /// Use on the OUTGOING view, and give it a higher zIndex so it stays on top while it lifts.
    static var tearAway: AnyTransition {
        .asymmetric(
            insertion: .identity,
            removal: .modifier(active: TearAway(progress: 1), identity: TearAway(progress: 0))
        )
    }
}

struct TearAway: ViewModifier, Animatable {
    var progress: Double            // 0 = resting, 1 = fully lifted off screen

    // Animatable is what makes SwiftUI tween `progress` frame by frame.
    // Without it the transition just jumps from 0 to 1 and the page vanishes.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private let maxDepth: CGFloat = 44

    func body(content: Content) -> some View {
        // rip opens fast in the first ~10% of the animation, then the page lifts
        let depth = maxDepth * min(1, progress * 10)
        let lift = progress          // local copy for the nonisolated visualEffect closure

        return content
            .mask(TornPage(edgeDepth: depth))
            .background(TornPage(edgeDepth: depth, fiber: true).fill(Theme.Colors.fibre))
            .shadow(color: .black.opacity(progress > 0 ? 0.25 : 0), radius: 16, y: 10)
            .visualEffect { view, proxy in
                view.offset(y: -lift * (proxy.size.height + 80))
            }
    }
}

/// A full page whose bottom edge is torn. `fiber` draws the slightly deeper fibre layer.
struct TornPage: Shape {
    var edgeDepth: CGFloat = 44
    var fiber = false

    nonisolated func path(in rect: CGRect) -> Path {
        guard edgeDepth > 0 else { return Path(rect) }
        var path = Path()
        let top = rect.maxY - edgeDepth
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // seeded noise so both layers rip along the same line
        var state: UInt64 = 7
        func random() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) % 1000) / 1000
        }

        var x = rect.maxX
        while x > rect.minX {
            var y = 0.38 + 0.16 * sin(x / 41) + 0.09 * sin(x / 13 + 1) + random() * 0.14
            let fibreDepth = 0.08 + random() * 0.2
            if fiber { y += fibreDepth }
            path.addLine(to: CGPoint(x: x, y: top + min(y, 1) * edgeDepth))
            x -= 6
        }
        path.addLine(to: CGPoint(x: rect.minX, y: top + (fiber ? 0.6 : 0.42) * edgeDepth))
        path.closeSubpath()
        return path
    }
}
