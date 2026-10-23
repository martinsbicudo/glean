import Foundation
import Observation

struct CardFile: Codable {
    var version = 1
    var cards: [Card]

    init(cards: [Card]) {
        self.cards = cards
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        cards = try c.decodeIfPresent([Card].self, forKey: .cards) ?? []
    }

    static func read(_ url: URL) throws -> CardFile {
        try JSONCoding.decoder.decode(CardFile.self, from: Data(contentsOf: url))
    }
}

@MainActor
@Observable
final class CardStore {
    let directory: URL
    private(set) var cards: [Card] = []
    private(set) var reviews: [ReviewEntry] = []
    private(set) var lastError: String?
    private(set) var isReadOnly = false
    var onChange: (() -> Void)?

    var cardsURL: URL { directory.appendingPathComponent("cards.json") }
    var reviewsURL: URL { directory.appendingPathComponent("reviews.jsonl") }

    init(directory: URL) {
        self.directory = directory
        load()
    }

    func load() {
        lastError = nil
        isReadOnly = false
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: cardsURL.path) {
                cards = try CardFile.read(cardsURL).cards
            }
            reviews = Self.readReviews(reviewsURL)
        } catch {
            isReadOnly = true
            lastError = "Couldn't read \(cardsURL.path): \(error.localizedDescription) Glean won't change the file until it can read it. Fix or restore it, then press Reload."
            Log.write(lastError ?? "")
        }
    }

    static func readReviews(_ url: URL) -> [ReviewEntry] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            do {
                return try JSONCoding.decoder.decode(ReviewEntry.self, from: Data(line.utf8))
            } catch {
                Log.write("skipping unreadable line in \(url.lastPathComponent): \(error.localizedDescription)")
                return nil
            }
        }
    }

    func dueCards(at date: Date = Date()) -> [Card] {
        cards.filter { $0.isDue(at: date) }.sorted { $0.schedule.due < $1.schedule.due }
    }

    func card(_ id: UUID) -> Card? { cards.first { $0.id == id } }

    func contains(term: String) -> Bool {
        let key = Card.normalize(term)
        return cards.contains { $0.normalizedTerm == key }
    }

    @discardableResult
    func add(_ newCards: [Card]) -> Int {
        var known = Set(cards.map(\.normalizedTerm))
        var added = 0
        for card in newCards where !card.term.trimmingCharacters(in: .whitespaces).isEmpty {
            guard known.insert(card.normalizedTerm).inserted else { continue }
            cards.append(card)
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    func update(_ card: Card) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index] = card
        save()
    }

    func delete(_ ids: Set<UUID>) {
        cards.removeAll { ids.contains($0.id) }
        save()
    }

    func review(_ id: UUID, rating: Rating, at date: Date = Date()) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].schedule = Scheduler.review(cards[index].schedule, rating: rating, at: date)
        save()
        append(ReviewEntry(cardID: id, date: date, rating: rating))
    }

    func recordPronunciation(_ id: UUID, score: Double, heard: String, at date: Date = Date()) {
        append(ReviewEntry(cardID: id, date: date, pronunciationScore: score, heard: heard))
    }

    func recordSentence(_ id: UUID, sentence: String, ok: Bool, at date: Date = Date()) {
        append(ReviewEntry(cardID: id, date: date, sentence: sentence, sentenceOK: ok))
    }

    func stats() -> [UUID: CardStats] { CardStats.build(from: reviews) }

    private func append(_ entry: ReviewEntry) {
        guard !isReadOnly else { return }
        reviews.append(entry)
        do {
            var line = try JSONCoding.encoder(pretty: false).encode(entry)
            line.append(0x0A)
            if FileManager.default.fileExists(atPath: reviewsURL.path) {
                let handle = try FileHandle(forWritingTo: reviewsURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } else if FileManager.default.fileExists(atPath: directory.path) {
                try line.write(to: reviewsURL, options: .atomic)
            } else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: directory.path])
            }
        } catch {
            lastError = "Couldn't save the review: \(error.localizedDescription)"
            Log.write(lastError ?? "")
        }
        onChange?()
    }

    private func save() {
        guard !isReadOnly else {
            Log.write("not saving: \(cardsURL.path) couldn't be read")
            onChange?()
            return
        }
        guard FileManager.default.fileExists(atPath: directory.path) else {
            lastError = "Not saving: \(directory.path) no longer exists (was the space deleted?)."
            Log.write(lastError ?? "")
            onChange?()
            return
        }
        do {
            let data = try JSONCoding.encoder(pretty: true).encode(CardFile(cards: cards))
            try data.write(to: cardsURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Couldn't save \(cardsURL.path): \(error.localizedDescription)"
            Log.write(lastError ?? "")
        }
        onChange?()
    }
}

enum JSONCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encoder(pretty: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
