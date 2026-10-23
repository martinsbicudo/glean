import Foundation

struct CardDraft: Codable, Equatable {
    var term: String
    var kind: String?
    var translations: [String]?
    var meaning: String?
    var definition: String?
    var pronunciation: String?
    var examples: [String]?
    var source: String?
    var tags: [String]?

    init(card: Card) {
        term = card.term
        kind = card.kind.rawValue
        translations = card.translations
        meaning = card.meaning
        definition = card.definition
        pronunciation = card.pronunciation
        examples = card.examples
        source = card.source
        tags = card.tags
    }

    func card(keeping base: Card? = nil) -> Card {
        var card = base ?? Card(term: term)
        card.term = clean(term) ?? card.term
        if let kind { card.kind = CardKind(loose: kind) }
        if let list = cleanList(translations) { card.translations = list }
        if let value = clean(meaning) { card.meaning = value }
        if let value = clean(definition) { card.definition = value }
        if let value = clean(pronunciation) { card.pronunciation = value }
        if let list = cleanList(examples) { card.examples = list }
        if let value = clean(source) { card.source = value }
        if let list = cleanList(tags) { card.tags = list.map { $0.lowercased() } }
        return card
    }

    private func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func cleanList(_ values: [String]?) -> [String]? {
        let list = (values ?? []).compactMap(clean)
        return list.isEmpty ? nil : list
    }
}

struct GeneratedCards: Decodable {
    var cards: [CardDraft]
}

struct CoachReport: Codable, Equatable {
    var summary: String
    var weaknesses: [String]
    var tips: [String]
    var cards: [CardDraft]
    var date: Date?

    private enum CodingKeys: String, CodingKey { case summary, weaknesses, tips, cards, date }

    init(summary: String, weaknesses: [String], tips: [String], cards: [CardDraft], date: Date?) {
        self.summary = summary
        self.weaknesses = weaknesses
        self.tips = tips
        self.cards = cards
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        weaknesses = try c.decodeIfPresent([String].self, forKey: .weaknesses) ?? []
        tips = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
        cards = try c.decodeIfPresent([CardDraft].self, forKey: .cards) ?? []
        date = try c.decodeIfPresent(Date.self, forKey: .date)
    }
}

enum AIJSON {
    enum ParseError: LocalizedError {
        case noJSON

        var errorDescription: String? { "The AI didn't answer with JSON. Try again." }
    }

    static func candidates(_ text: String) -> [Data] {
        let characters = Array(text)
        return characters.indices.compactMap { start in
            guard characters[start] == "{" || characters[start] == "[",
                  let end = balancedEnd(characters, from: start) else { return nil }
            let data = Data(String(characters[start...end]).utf8)
            return (try? JSONSerialization.jsonObject(with: data)) == nil ? nil : data
        }
    }

    private static func balancedEnd(_ characters: [Character], from start: Int) -> Int? {
        var depth = 0
        var inString = false
        var escaped = false
        for index in start..<characters.count {
            let character = characters[index]
            if inString {
                if escaped { escaped = false } else if character == "\\" { escaped = true } else if character == "\"" { inString = false }
                continue
            }
            switch character {
            case "\"": inString = true
            case "{", "[": depth += 1
            case "}", "]":
                depth -= 1
                if depth == 0 { return index }
            default: break
            }
        }
        return nil
    }

    static func cards(from text: String) throws -> [CardDraft] {
        for data in candidates(text) {
            if let wrapped = try? JSONDecoder().decode(GeneratedCards.self, from: data) { return wrapped.cards }
            if let list = try? JSONDecoder().decode([CardDraft].self, from: data) { return list }
            if let card = try? JSONDecoder().decode(CardDraft.self, from: data) { return [card] }
        }
        throw ParseError.noJSON
    }

    static func card(from text: String) throws -> CardDraft {
        guard let first = try cards(from: text).first else { throw ParseError.noJSON }
        return first
    }

    static func coach(from text: String) throws -> CoachReport {
        for data in candidates(text) {
            guard let report = try? JSONCoding.decoder.decode(CoachReport.self, from: data) else { continue }
            if !report.summary.isEmpty || !report.weaknesses.isEmpty || !report.tips.isEmpty || !report.cards.isEmpty {
                return report
            }
        }
        throw ParseError.noJSON
    }
}
