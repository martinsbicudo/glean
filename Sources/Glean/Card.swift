import Foundation

enum CardKind: String, Codable, CaseIterable, Identifiable {
    case word
    case phrasalVerb = "phrasal-verb"
    case idiom
    case phrase
    case sentence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .word: "Word"
        case .phrasalVerb: "Phrasal verb"
        case .idiom: "Idiom"
        case .phrase: "Expression"
        case .sentence: "Sentence"
        }
    }

    init(loose value: String) {
        let key = value.lowercased().replacingOccurrences(of: "_", with: "-").replacingOccurrences(of: " ", with: "-")
        switch key {
        case "phrasal-verb", "phrasal", "phrasalverb": self = .phrasalVerb
        case "idiom": self = .idiom
        case "phrase", "expression", "collocation": self = .phrase
        case "sentence": self = .sentence
        default: self = .word
        }
    }
}

struct Schedule: Equatable {
    var due: Date
    var interval: Double = 0
    var ease: Double = 2.5
    var reps: Int = 0
    var lapses: Int = 0
    var lastReviewed: Date?

    static func new(at date: Date = Date()) -> Schedule { Schedule(due: date) }
}

struct Card: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var term: String
    var kind: CardKind = .word
    var translations: [String] = []
    var meaning: String = ""
    var definition: String = ""
    var pronunciation: String = ""
    var examples: [String] = []
    var source: String = ""
    var notes: String = ""
    var tags: [String] = []
    var created: Date = Date()
    var schedule: Schedule = .new()

    var normalizedTerm: String { Card.normalize(term) }

    static func normalize(_ term: String) -> String {
        term.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func isDue(at date: Date = Date()) -> Bool { schedule.due <= date }
}

extension Schedule: Codable {
    private enum CodingKeys: String, CodingKey { case due, interval, ease, reps, lapses, lastReviewed }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        due = try c.decodeIfPresent(Date.self, forKey: .due) ?? Date()
        interval = try c.decodeIfPresent(Double.self, forKey: .interval) ?? 0
        ease = try c.decodeIfPresent(Double.self, forKey: .ease) ?? 2.5
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        lastReviewed = try c.decodeIfPresent(Date.self, forKey: .lastReviewed)
    }
}

extension Card {
    private enum CodingKeys: String, CodingKey {
        case id, term, kind, translations, meaning, definition, pronunciation, examples, source, notes, tags, created, schedule
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        term = try c.decode(String.self, forKey: .term)
        kind = CardKind(loose: try c.decodeIfPresent(String.self, forKey: .kind) ?? "word")
        translations = try c.decodeIfPresent([String].self, forKey: .translations) ?? []
        meaning = try c.decodeIfPresent(String.self, forKey: .meaning) ?? ""
        definition = try c.decodeIfPresent(String.self, forKey: .definition) ?? ""
        pronunciation = try c.decodeIfPresent(String.self, forKey: .pronunciation) ?? ""
        examples = try c.decodeIfPresent([String].self, forKey: .examples) ?? []
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        schedule = try c.decodeIfPresent(Schedule.self, forKey: .schedule) ?? .new()
    }
}
