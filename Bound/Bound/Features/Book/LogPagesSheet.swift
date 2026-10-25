import Foundation
import SwiftUI

struct LogPagesSheet: View {
    @Bindable var book: Book
    @Environment(\.dismiss) private var dismiss
    @State private var page: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Theme.Colors.lineStrong).frame(width: 40, height: 4).padding(.top, 10)
            MonoLabel("Where are you in \(book.title)?")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("p. \(Int(page))").font(Theme.Fonts.display(56))
                Text("of \(book.pageCount)").font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.inkMuted)
            }
            .foregroundStyle(Theme.Colors.ink)

            HStack(spacing: 12) {
                stepButton("−10", -10)
                Slider(value: $page, in: 0...Double(max(book.pageCount, 1)), step: 1)
                    .tint(Theme.Colors.forest)
                    .accessibilityLabel("Current page")
                stepButton("+10", 10)
            }

            Button("Save", action: save)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .presentationDetents([.height(320)])
        .presentationBackground(Theme.Colors.paper)
        .onAppear { page = Double(book.currentPage) }
    }

    private func stepButton(_ title: String, _ delta: Double) -> some View {
        Button(title) { page = min(max(page + delta, 0), Double(book.pageCount)) }
            .font(Theme.Fonts.mono(13, medium: true))
            .foregroundStyle(Theme.Colors.ink)
            .frame(width: 52, height: 44)
            .overlay(Capsule().stroke(Theme.Colors.lineStrong, lineWidth: 1.5))
            .buttonStyle(.plain)
    }

    private func save() {
        book.currentPage = Int(page)
        // moving pages moves the book between shelves too
        if book.currentPage >= book.pageCount {
            book.shelf = .finished
        } else if book.currentPage > 0 && book.shelf == .toRead {
            book.shelf = .reading
        }
        dismiss()
    }
}
