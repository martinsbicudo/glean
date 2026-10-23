import Foundation

enum StudyReport {
    static func text(cards: [Card], reviews: [ReviewEntry], now: Date = Date()) -> String {
        let stats = CardStats.build(from: reviews)
        let rated = reviews.filter { $0.rating != nil }
        let lastWeek = rated.filter { now.timeIntervalSince($0.date) < 7 * Scheduler.day }
        var lines = [
            "Cards: \(cards.count). Due now: \(cards.filter { $0.isDue(at: now) }.count).",
            "Reviews: \(rated.count) in total, \(lastWeek.count) in the last 7 days.",
        ]

        let byKind = Dictionary(grouping: cards, by: \.kind)
        for kind in CardKind.allCases {
            guard let group = byKind[kind], !group.isEmpty else { continue }
            let total = group.compactMap { stats[$0.id] }.reduce(CardStats()) { sum, next in
                CardStats(reviews: sum.reviews + next.reviews, again: sum.again + next.again, hard: sum.hard + next.hard)
            }
            lines.append("\(kind.label): \(group.count) cards, \(total.reviews) reviews, \(total.again) forgotten, \(total.hard) hard.")
        }

        let hardest = cards
            .compactMap { card in stats[card.id].map { (card, $0) } }
            .filter { $0.1.reviews > 0 && $0.1.struggleRate > 0 }
            .sorted { $0.1.struggleRate > $1.1.struggleRate }
            .prefix(15)
        if !hardest.isEmpty {
            lines.append("\nHardest cards (term · kind · reviews · forgotten · hard):")
            lines += hardest.map { "- \($0.0.term) · \($0.0.kind.rawValue) · \($0.1.reviews) · \($0.1.again) · \($0.1.hard)" }
        }

        let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        lines += pronunciationMisses(reviews, byID: byID) + writingMistakes(reviews, byID: byID)
        return lines.joined(separator: "\n")
    }

    private static func pronunciationMisses(_ reviews: [ReviewEntry], byID: [UUID: Card]) -> [String] {
        let misses = reviews
            .filter { ($0.pronunciationScore ?? 1) < 0.9 }
            .suffix(15)
            .compactMap { entry -> String? in
                guard let card = byID[entry.cardID], let score = entry.pronunciationScore else { return nil }
                return "- said \"\(card.term)\", speech recognition heard \"\(entry.heard ?? "")\" (\(Int(score * 100))%)"
            }
        return misses.isEmpty ? [] : ["\nRecent pronunciation checks that missed:"] + misses
    }

    private static func writingMistakes(_ reviews: [ReviewEntry], byID: [UUID: Card]) -> [String] {
        let wrong = reviews
            .filter { $0.sentenceOK == false }
            .suffix(10)
            .compactMap { entry -> String? in
                guard let card = byID[entry.cardID], let sentence = entry.sentence else { return nil }
                return "- tried to use \"\(card.term)\" and wrote \"\(sentence)\", which the AI marked incorrect"
            }
        return wrong.isEmpty ? [] : ["\nRecent sentences the learner wrote with mistakes:"] + wrong
    }
}
