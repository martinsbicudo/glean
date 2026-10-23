import Foundation

enum Recall {
    static func canPrompt(_ card: Card) -> Bool {
        !card.translations.isEmpty || !card.meaning.isEmpty
    }
}

enum AnswerVerdict: Equatable {
    case correct, close, wrong
}

enum AnswerCheck {
    static func compare(typed: String, expected: String) -> AnswerVerdict {
        let typed = normalized(typed)
        let expected = normalized(expected)
        guard !typed.isEmpty, !expected.isEmpty else { return .wrong }
        if typed == expected { return .correct }
        let allowed = expected.count < 4 ? 0 : max(1, expected.count / 6)
        return distance(Array(typed), Array(expected)) <= allowed ? .close : .wrong
    }

    static func normalized(_ text: String) -> String {
        Card.normalize(text.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: ""))
    }

    static func distance(_ a: [Character], _ b: [Character]) -> Int {
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var row = [i + 1]
            for (j, right) in b.enumerated() {
                row.append(min(previous[j + 1] + 1, row[j] + 1, previous[j] + (left == right ? 0 : 1)))
            }
            previous = row
        }
        return previous[b.count]
    }
}

enum Cloze {
    static let blank = "_____"

    static func example(for card: Card) -> String? {
        card.examples.lazy.compactMap { blank(term: card.term, in: $0) }.first
    }

    static func blank(term: String, in sentence: String) -> String? {
        let words = term.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first else { return nil }
        if words.count == 1, first.unicodeScalars.contains(where: isSpaceless) {
            return replace(NSRegularExpression.escapedPattern(for: first), in: sentence)
        }
        let rest = words.dropFirst().map(NSRegularExpression.escapedPattern(for:))
        let exact = ([NSRegularExpression.escapedPattern(for: first)] + rest).joined(separator: "\\s+")
        if let result = replace(bounded(exact), in: sentence) { return result }
        let stem = stem(of: first)
        guard stem.count >= 4 else { return nil }
        let loose = ([NSRegularExpression.escapedPattern(for: stem) + "\\p{L}*"] + rest).joined(separator: "\\s+")
        return replace(bounded(loose), in: sentence)
    }

    private static func bounded(_ pattern: String) -> String {
        "(?<![\\p{L}\\p{N}])" + pattern + "(?![\\p{L}\\p{N}])"
    }

    private static func stem(of word: String) -> String {
        let lower = word.lowercased()
        guard lower.count > 4, lower.hasSuffix("e") || lower.hasSuffix("y") else { return lower }
        return String(lower.dropLast())
    }

    private static func isSpaceless(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF, 0x4E00...0x9FFF, 0xAC00...0xD7AF, 0x0E00...0x0E7F: true
        default: false
        }
    }

    private static func replace(_ pattern: String, in sentence: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(sentence.startIndex..., in: sentence)
            guard let match = regex.firstMatch(in: sentence, range: range), let found = Range(match.range, in: sentence) else { return nil }
            return sentence.replacingCharacters(in: found, with: blank)
        } catch {
            Log.write("cloze pattern failed: \(error.localizedDescription)")
            return nil
        }
    }
}
