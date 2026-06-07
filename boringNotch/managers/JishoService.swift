//
//  JishoService.swift
//  boringNotch
//
//  Queries the unofficial Jisho.org words API.
//

import Foundation

enum JishoServiceError: LocalizedError {
    case invalidQuery
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search term."
        case .badResponse:
            return "Jisho returned an unexpected response."
        }
    }
}

enum JishoService {
    private static let endpoint = "https://jisho.org/api/v1/search/words"

    static func search(_ keyword: String) async throws -> [JishoEntry] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw JishoServiceError.invalidQuery }

        var components = URLComponents(string: endpoint)
        components?.queryItems = [URLQueryItem(name: "keyword", value: trimmed)]
        guard let url = components?.url else { throw JishoServiceError.invalidQuery }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw JishoServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(JishoResponse.self, from: data)
        return decoded.data
    }
}
