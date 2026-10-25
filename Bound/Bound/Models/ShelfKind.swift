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

    /// The value of the `shelf_kind` enum in Supabase.
    var remoteValue: String {
        switch self {
        case .toRead: "to_read"
        case .reading: "reading"
        case .finished: "finished"
        }
    }

    init?(remoteValue: String) {
        guard let match = Self.allCases.first(where: { $0.remoteValue == remoteValue }) else { return nil }
        self = match
    }
}
