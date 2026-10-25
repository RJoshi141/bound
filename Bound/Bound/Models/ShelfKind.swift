import Foundation

enum ShelfKind: String, CaseIterable, Codable, Identifiable {
    case toRead, reading, finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toRead: "To read"
        case .reading: "Reading now"
        case .finished: "Finished"
        }
    }
}
