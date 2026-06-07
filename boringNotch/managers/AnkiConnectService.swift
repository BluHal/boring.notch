//
//  AnkiConnectService.swift
//  boringNotch
//
//  Talks to the AnkiConnect add-on over its local HTTP API (default
//  http://127.0.0.1:8765). Requires the Anki desktop app to be running with
//  the AnkiConnect add-on installed. Loopback requests are exempt from ATS,
//  so no Info.plist exceptions are needed.
//

import Foundation
import Defaults

enum AnkiConnectError: LocalizedError {
    case notReachable
    case api(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notReachable:
            return "Can't reach Anki. Make sure Anki is open and the AnkiConnect add-on is installed."
        case .api(let message):
            return message
        case .badResponse:
            return "AnkiConnect returned an unexpected response."
        }
    }
}

struct AnkiNoteFields {
    let deckName: String
    let modelName: String
    let fields: [String: String]
    let tags: [String]
}

enum AnkiConnectService {
    private static let version = 6

    private static var baseURL: URL? {
        URL(string: Defaults[.ankiConnectURL])
    }

    /// Sends a single AnkiConnect action and returns the decoded `result`.
    private static func invoke<Result: Decodable>(
        action: String,
        params: [String: Any] = [:],
        resultType: Result.Type
    ) async throws -> Result {
        guard let url = baseURL else { throw AnkiConnectError.notReachable }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "action": action,
            "version": version,
            "params": params
        ])

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw AnkiConnectError.notReachable
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnkiConnectError.badResponse
        }

        if let error = object["error"] as? String {
            throw AnkiConnectError.api(error)
        }

        guard let resultValue = object["result"] else {
            throw AnkiConnectError.badResponse
        }

        // AnkiConnect returns `null` for actions like addNote on success in some
        // versions; re-encode the raw value so we can decode it into the target type.
        let resultData = try JSONSerialization.data(
            withJSONObject: resultValue,
            options: [.fragmentsAllowed]
        )
        return try JSONDecoder().decode(Result.self, from: resultData)
    }

    @discardableResult
    static func checkConnection() async throws -> Int {
        try await invoke(action: "version", resultType: Int.self)
    }

    static func deckNames() async throws -> [String] {
        try await invoke(action: "deckNames", resultType: [String].self)
    }

    static func modelNames() async throws -> [String] {
        try await invoke(action: "modelNames", resultType: [String].self)
    }

    static func fieldNames(for modelName: String) async throws -> [String] {
        try await invoke(
            action: "modelFieldNames",
            params: ["modelName": modelName],
            resultType: [String].self
        )
    }

    static func addNote(_ note: AnkiNoteFields) async throws {
        let params: [String: Any] = [
            "note": [
                "deckName": note.deckName,
                "modelName": note.modelName,
                "fields": note.fields,
                "tags": note.tags,
                "options": ["allowDuplicate": false]
            ]
        ]
        // The note id (or null) is returned; we don't need the value.
        _ = try await invoke(action: "addNote", params: params, resultType: AnkiNoteID.self)
    }
}

/// AnkiConnect returns the new note id as a number, but may return null on some errors.
private struct AnkiNoteID: Decodable {
    init(from decoder: Decoder) throws {
        // Accept a number or null without failing.
        _ = try? decoder.singleValueContainer().decode(Int64.self)
    }
}
