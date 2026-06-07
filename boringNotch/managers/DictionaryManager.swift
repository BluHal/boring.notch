//
//  DictionaryManager.swift
//  boringNotch
//
//  Drives the dictionary tab: searches Jisho and pushes entries to Anki.
//

import Combine
import Defaults
import Foundation

enum AnkiAddState: Equatable {
    case idle
    case adding
    case added
    case failed(String)
}

@MainActor
final class DictionaryManager: ObservableObject {
    static let shared = DictionaryManager()

    @Published var query: String = ""
    @Published var results: [JishoEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasSearched: Bool = false
    @Published var ankiStatus: [String: AnkiAddState] = [:]

    private var searchTask: Task<Void, Never>?

    private init() {}

    func search() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()

        guard !keyword.isEmpty else {
            results = []
            errorMessage = nil
            hasSearched = false
            return
        }

        isLoading = true
        errorMessage = nil

        searchTask = Task { [keyword] in
            do {
                let entries = try await JishoService.search(keyword)
                guard !Task.isCancelled else { return }
                results = entries
                ankiStatus = [:]
                errorMessage = entries.isEmpty ? "No results for \"\(keyword)\"." : nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                errorMessage = error.localizedDescription
            }
            hasSearched = true
            isLoading = false
        }
    }

    func ankiState(for entry: JishoEntry) -> AnkiAddState {
        ankiStatus[entry.slug] ?? .idle
    }

    func addToAnki(_ entry: JishoEntry) {
        ankiStatus[entry.slug] = .adding

        let note = AnkiNoteFields(
            deckName: Defaults[.ankiDeckName],
            modelName: Defaults[.ankiNoteType],
            fields: [
                Defaults[.ankiFrontField]: front(for: entry),
                Defaults[.ankiBackField]: back(for: entry)
            ],
            tags: ["boringnotch", "jisho"]
        )

        Task {
            do {
                try await AnkiConnectService.addNote(note)
                ankiStatus[entry.slug] = .added
            } catch {
                ankiStatus[entry.slug] = .failed(error.localizedDescription)
            }
        }
    }

    private func front(for entry: JishoEntry) -> String {
        entry.primaryWord
    }

    private func back(for entry: JishoEntry) -> String {
        var lines: [String] = []
        if let reading = entry.primaryReading {
            lines.append(reading)
        }
        for (index, sense) in entry.senses.enumerated() {
            let definitions = sense.englishDefinitions.joined(separator: "; ")
            guard !definitions.isEmpty else { continue }
            lines.append("\(index + 1). \(definitions)")
        }
        return lines.joined(separator: "<br>")
    }
}
