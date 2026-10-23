import Foundation

enum Shadow {
    static let wordsPerSecond = 2.5
    static let charactersPerSecond = 15.0
    static let margin = 1.6
    static let grace: TimeInterval = 1

    static func estimatedDuration(of text: String) -> TimeInterval {
        let words = Double(text.split(whereSeparator: \.isWhitespace).count)
        let characters = Double(text.filter { !$0.isWhitespace }.count)
        return max(words / wordsPerSecond, characters / charactersPerSecond)
    }

    static func autoStop(for text: String) -> TimeInterval {
        estimatedDuration(of: text) * margin + grace
    }

    static func phrases(for card: Card) -> [String] {
        var seen = Set<String>()
        return ([card.term] + card.examples)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

struct ShadowSequence: Equatable {
    let phrases: [String]
    private(set) var index = 0
    private(set) var scores: [Double?]

    init(phrases: [String], startAt start: Int = 0) {
        self.phrases = phrases
        index = phrases.indices.contains(start) ? start : 0
        scores = Array(repeating: nil, count: phrases.count)
    }

    var current: String? { phrases.indices.contains(index) ? phrases[index] : nil }
    var isLast: Bool { index >= phrases.count - 1 }
    var currentScore: Double? { scores.indices.contains(index) ? scores[index] : nil }

    var average: Double? {
        let done = scores.compactMap { $0 }
        return done.isEmpty ? nil : done.reduce(0, +) / Double(done.count)
    }

    mutating func record(_ score: Double) {
        guard scores.indices.contains(index) else { return }
        scores[index] = score
    }

    @discardableResult
    mutating func advance() -> Bool {
        guard !isLast else { return false }
        index += 1
        return true
    }
}
