import Foundation

struct PronunciationScore: Equatable {
    struct Word: Equatable {
        let text: String
        let matched: Bool
    }

    let words: [Word]
    let heard: String

    var score: Double {
        words.isEmpty ? 0 : Double(words.filter(\.matched).count) / Double(words.count)
    }

    var missed: [String] { words.filter { !$0.matched }.map(\.text) }

    static func compare(target: String, heard: String) -> PronunciationScore {
        let expected = target.split(whereSeparator: \.isWhitespace).map(String.init)
        let keys = expected.map(Card.normalize)
        let said = Card.normalize(heard).split(separator: " ").map(String.init)
        let matched = lcsMatches(keys, said)
        let words = expected.indices.map { Word(text: expected[$0], matched: keys[$0].isEmpty || matched.contains($0)) }
        return PronunciationScore(words: words, heard: heard)
    }

    private static func lcsMatches(_ a: [String], _ b: [String]) -> Set<Int> {
        guard !a.isEmpty, !b.isEmpty else { return [] }
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = same(a[i], b[j]) ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var result = Set<Int>()
        var i = 0, j = 0
        while i < a.count, j < b.count {
            if same(a[i], b[j]) {
                result.insert(i)
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return result
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        a.replacingOccurrences(of: " ", with: "") == b.replacingOccurrences(of: " ", with: "")
    }
}
