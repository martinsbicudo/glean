import Foundation

struct SpaceCards {
    let space: Space
    let cards: [Card]

    func due(at date: Date = Date()) -> SpaceDue {
        SpaceDue(space: space, due: cards.filter { $0.isDue(at: date) }.count)
    }
}

struct SpaceDue: Identifiable, Equatable {
    let space: Space
    let due: Int

    var id: UUID { space.id }
}

extension SpaceStore {
    func snapshots() -> [SpaceCards] {
        spaces.map { SpaceCards(space: $0, cards: readCards(of: $0)) }
    }

    func dueCounts(at date: Date = Date()) -> [SpaceDue] {
        snapshots().map { $0.due(at: date) }
    }

    func reviewSnapshots() -> [SpaceReviews] {
        spaces.map { SpaceReviews(space: $0, reviews: CardStore.readReviews(directory(for: $0).appendingPathComponent("reviews.jsonl"))) }
    }

    private func readCards(of space: Space) -> [Card] {
        let url = directory(for: space).appendingPathComponent("cards.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            return try CardFile.read(url).cards
        } catch {
            Log.write("couldn't read \(url.path): \(error.localizedDescription)")
            return []
        }
    }
}
