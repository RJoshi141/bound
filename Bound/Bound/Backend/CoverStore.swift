import Foundation
import SwiftData
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Fetches real covers from Open Library and tints each spine to match its cover.
/// (No open database has spine photos, so the spine borrows the colour along the cover's right edge.)
@MainActor
final class CoverStore {
    static let shared = CoverStore()
    private var inFlight: Set<PersistentIdentifier> = []

    /// Finds covers for any books that don't have one yet. Safe to call often.
    func fill(_ books: [Book]) async {
        await retintFromRightEdgeOnce(books)
        for book in books where book.coverData == nil && !book.coverLookupDone {
            guard !inFlight.contains(book.persistentModelID) else { continue }
            inFlight.insert(book.persistentModelID)
            defer { inFlight.remove(book.persistentModelID) }

            let (title, author, knownCover) = (book.title, book.author, book.coverID)
            do {
                var coverID = knownCover
                if coverID == nil, let match = try await OpenLibrary.lookup(title: title, author: author) {
                    coverID = match.coverID
                    if !book.isDeleted, book.openLibraryKey == nil { book.openLibraryKey = match.key }
                }
                guard let coverID, let data = try await OpenLibrary.coverData(id: coverID) else {
                    if !book.isDeleted { book.coverLookupDone = true }     // nothing out there
                    continue
                }
                let hex = await Task.detached { Self.spineHex(from: data) }.value
                guard !book.isDeleted else { continue }
                book.coverID = coverID
                book.coverData = data
                if let hex { book.spineHex = hex }       // syncs, so clubmates see the same spine
                book.coverLookupDone = true
            } catch {
                // offline or rate-limited: try again next time the shelves appear
            }
        }
    }

    /// Spines used to come from the left edge. Re-tint covers we already have, one time.
    private func retintFromRightEdgeOnce(_ books: [Book]) async {
        let key = "spinesFromRightEdge"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        for book in books {
            guard let data = book.coverData else { continue }
            let hex = await Task.detached { Self.spineHex(from: data) }.value
            if let hex, !book.isDeleted { book.spineHex = hex }
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Average colour of the cover's right edge, nudged so gilt and the title still read on it.
    nonisolated static func spineHex(from data: Data) -> String? {
        guard let image = CIImage(data: data) else { return nil }
        let extent = image.extent
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = CGRect(x: extent.maxX - extent.width * 0.1, y: extent.minY, width: extent.width * 0.1, height: extent.height)
        guard let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                    format: .RGBA8, colorSpace: nil)

        // very pale edges (white covers) become a warm cream instead of glaring white
        var (r, g, b) = (Double(pixel[0]), Double(pixel[1]), Double(pixel[2]))
        let light = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        if light > 0.9 { (r, g, b) = (r * 0.93, g * 0.9, b * 0.84) }
        return String(format: "%02X%02X%02X", Int(r), Int(g), Int(b))
    }
}


/// The real cover if we have it, cloth otherwise. Used in small places (slips, lists).
struct CoverThumb: View {
    let book: Book
    var width: CGFloat = 40
    var height: CGFloat = 60

    var body: some View {
        if let data = book.coverData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.Colors.ink.opacity(0.15), lineWidth: 0.5))
                .accessibilityHidden(true)
        } else {
            SpineSwatch(hex: book.spineHex, width: width * 0.7, height: height)
        }
    }
}
