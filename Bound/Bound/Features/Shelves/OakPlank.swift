import Foundation
import SwiftUI

/// The wooden shelf the spines sit on.
struct OakPlank: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Colors.oak)
                .frame(height: 12)
                // faint grain lines
                .overlay(alignment: .top) {
                    VStack(spacing: 3) {
                        Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
                        Rectangle().fill(.black.opacity(0.08)).frame(height: 1)
                    }
                    .padding(.top, 3)
                }
            Rectangle()
                .fill(Theme.Colors.oakDark)
                .frame(height: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: Theme.Colors.ink.opacity(0.35), radius: 6, y: 5)
        .accessibilityHidden(true)
    }
}
