import Foundation

struct ReviewEntry: Codable, Equatable {
    var cardID: UUID
    var date: Date
    var rating: Rating?
    var pronunciationScore: Double?
    var heard: String?
    var sentence: String?
    var sentenceOK: Bool?
}

struct CardStats: Equatable {
    var reviews = 0
    var again = 0
    var hard = 0
    var pronunciationAttempts = 0
    var pronunciationTotal = 0.0

    var pronunciationAverage: Double? {
        pronunciationAttempts == 0 ? nil : pronunciationTotal / Double(pronunciationAttempts)
    }

    var struggleRate: Double {
        reviews == 0 ? 0 : (Double(again) + 0.5 * Double(hard)) / Double(reviews)
    }

    static func build(from entries: [ReviewEntry]) -> [UUID: CardStats] {
        var result: [UUID: CardStats] = [:]
        for entry in entries {
            var stats = result[entry.cardID] ?? CardStats()
            if let rating = entry.rating {
                stats.reviews += 1
                if rating == .again { stats.again += 1 }
                if rating == .hard { stats.hard += 1 }
            }
            if let score = entry.pronunciationScore {
                stats.pronunciationAttempts += 1
                stats.pronunciationTotal += score
            }
            result[entry.cardID] = stats
        }
        return result
    }
}
