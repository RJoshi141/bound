import Foundation
import SwiftUI
import UIKit
import Observation

/// Drives the paper-tear between screens: drop the sheet, swap underneath, tear it back up.
@Observable
final class TearCoordinator {
    var isCovered = false
    private(set) var isRunning = false

    private let curve = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.55)

    func run(_ change: @escaping () -> Void) {
        guard !isRunning else { return }

        // Reduce Motion: quick crossfade instead of the sheet.
        if UIAccessibility.isReduceMotionEnabled {
            withAnimation(.easeInOut(duration: 0.15)) { change() }
            return
        }

        isRunning = true
        withAnimation(curve) { isCovered = true }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(580))

            // swap with animations off so the change happens hidden under the sheet
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { change() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(curve) { isCovered = false }
            try? await Task.sleep(for: .milliseconds(600))
            isRunning = false
        }
    }
}

/// The forest-green sheet with a ripped, fibrous bottom edge.
struct TearOverlay: View {
    @Environment(TearCoordinator.self) private var tear

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            VStack(spacing: 0) {
                ZStack {
                    Theme.Colors.tearSheet
                    Text("Bound")
                        .font(Theme.Fonts.masthead(88))
                        .foregroundStyle(Theme.Colors.tearMark)
                }
                .frame(height: height)

                ZStack(alignment: .top) {
                    TornEdge(fiber: true).fill(Theme.Colors.fibre)
                    TornEdge(fiber: false).fill(Theme.Colors.tearSheet)
                }
                .frame(height: 46)
            }
            .offset(y: tear.isCovered ? 0 : -(height + 60))
        }
        .ignoresSafeArea()
        .allowsHitTesting(tear.isRunning)
        .accessibilityHidden(true)
    }
}

/// Jagged torn-paper edge. Same seed for both layers so the fibre band hugs the edge.
struct TornEdge: Shape {
    var fiber = false

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width, y: 0))

        var state: UInt64 = 7
        func random() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) % 1000) / 1000
        }

        var x = rect.width
        while x > 0 {
            var y = 0.38 + 0.16 * sin(x / 41) + 0.09 * sin(x / 13 + 1) + random() * 0.14
            let fibreDepth = 0.08 + random() * 0.2      // always drawn so both layers stay in sync
            if fiber { y += fibreDepth }
            path.addLine(to: CGPoint(x: x, y: min(y, 1) * rect.height))
            x -= 6
        }
        path.addLine(to: CGPoint(x: 0, y: (fiber ? 0.6 : 0.42) * rect.height))
        path.closeSubpath()
        return path
    }
}
