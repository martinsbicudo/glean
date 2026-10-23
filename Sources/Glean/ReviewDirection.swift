import Foundation

enum ReviewSide: Equatable {
    case recognize, recall
}

enum ReviewDirection: String, Codable, CaseIterable, Identifiable {
    case recognize, recall, mixed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recognize: "Recognize"
        case .recall: "Recall"
        case .mixed: "Mixed"
        }
    }

    var detail: String {
        switch self {
        case .recognize: "You see the term and remember what it means."
        case .recall: "You see the meaning and remember the term."
        case .mixed: "New cards are Recognize; once you know them, they alternate."
        }
    }

    func side(for card: Card) -> ReviewSide {
        guard Recall.canPrompt(card) else { return .recognize }
        switch self {
        case .recognize: return .recognize
        case .recall: return .recall
        case .mixed: return card.schedule.reps >= 2 && card.schedule.reps % 2 == 0 ? .recall : .recognize
        }
    }
}
