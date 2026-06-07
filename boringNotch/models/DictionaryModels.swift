//
//  DictionaryModels.swift
//  boringNotch
//
//  Codable models for the Jisho.org words API.
//

import Foundation

struct JishoResponse: Decodable {
    let data: [JishoEntry]
}

struct JishoEntry: Decodable, Identifiable {
    let slug: String
    let isCommon: Bool?
    let jlpt: [String]
    let japanese: [JishoJapanese]
    let senses: [JishoSense]

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case isCommon = "is_common"
        case jlpt
        case japanese
        case senses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = try container.decode(String.self, forKey: .slug)
        isCommon = try container.decodeIfPresent(Bool.self, forKey: .isCommon)
        jlpt = try container.decodeIfPresent([String].self, forKey: .jlpt) ?? []
        japanese = try container.decodeIfPresent([JishoJapanese].self, forKey: .japanese) ?? []
        senses = try container.decodeIfPresent([JishoSense].self, forKey: .senses) ?? []
    }

    /// The headword in kanji/kana, falling back to the reading for kana-only words.
    var primaryWord: String {
        japanese.first?.word ?? japanese.first?.reading ?? slug
    }

    /// The kana reading, only when it differs from the displayed word.
    var primaryReading: String? {
        guard let first = japanese.first, let reading = first.reading, first.word != nil else {
            return nil
        }
        return reading
    }

    /// JLPT levels formatted for display, e.g. ["N5"].
    var jlptLevels: [String] {
        jlpt.map { $0.replacingOccurrences(of: "jlpt-", with: "").uppercased() }
    }
}

struct JishoJapanese: Decodable {
    let word: String?
    let reading: String?
}

struct JishoSense: Decodable {
    let englishDefinitions: [String]
    let partsOfSpeech: [String]

    enum CodingKeys: String, CodingKey {
        case englishDefinitions = "english_definitions"
        case partsOfSpeech = "parts_of_speech"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        englishDefinitions = try container.decodeIfPresent([String].self, forKey: .englishDefinitions) ?? []
        partsOfSpeech = try container.decodeIfPresent([String].self, forKey: .partsOfSpeech) ?? []
    }
}
