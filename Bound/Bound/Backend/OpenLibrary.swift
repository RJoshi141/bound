import Foundation

/// Book search via Open Library (free, no key). https://openlibrary.org/dev/docs/api/search
enum OpenLibrary {
    /// Title / author search, or an ISBN lookup when the query is 10 or 13 digits.
    static func search(_ query: String) async throws -> [CatalogBook] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter { $0.isNumber || $0 == "X" || $0 == "x" }
        let looksLikeISBN = (digits.count == 10 || digits.count == 13)
            && trimmed.allSatisfy { $0.isNumber || "-xX ".contains($0) }

        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "q", value: looksLikeISBN ? "isbn:\(digits)" : trimmed),
            URLQueryItem(name: "fields", value: "key,title,author_name,first_publish_year,number_of_pages_median,cover_i"),
            URLQueryItem(name: "limit", value: "20"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bound/1.0 (iOS book club app)", forHTTPHeaderField: "User-Agent")   // OL asks apps to identify themselves
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let page = try JSONDecoder().decode(OpenLibraryPage.self, from: data)

        var seen = Set<String>()
        return page.docs.compactMap { doc in
            let key = doc.key.replacingOccurrences(of: "/works/", with: "")
            guard seen.insert(key).inserted else { return nil }
            return CatalogBook(
                title: doc.title,
                author: doc.authorName?.first ?? "Unknown author",
                year: doc.firstPublishYear,
                pageCount: doc.numberOfPagesMedian ?? 0,
                openLibraryKey: key,
                coverID: doc.coverID
            )
        }
    }
}

nonisolated struct OpenLibraryPage: Decodable, Sendable {
    let docs: [OpenLibraryDoc]
}

nonisolated struct OpenLibraryDoc: Decodable, Sendable {
    let key: String
    let title: String
    let authorName: [String]?
    let firstPublishYear: Int?
    let numberOfPagesMedian: Int?
    let coverID: Int?

    enum CodingKeys: String, CodingKey {
        case key, title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case numberOfPagesMedian = "number_of_pages_median"
        case coverID = "cover_i"
    }
}
