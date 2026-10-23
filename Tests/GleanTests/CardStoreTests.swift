import Foundation
import Testing
@testable import Glean

@MainActor
struct CardStoreTests {
    func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("glean-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func aStoreWhoseSpaceWasDeletedDoesNotRecreateIt() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CardStore(directory: directory)
        store.add([Card(term: "gist")])
        let id = store.cards[0].id
        try? FileManager.default.removeItem(at: directory)
        store.add([Card(term: "wrap up")])
        #expect(store.lastError?.contains("no longer exists") == true)
        store.review(id, rating: .good)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func aReviewLogItCannotOpenIsNeverReplaced() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CardStore(directory: directory)
        store.add([Card(term: "gist")])
        store.review(store.cards[0].id, rating: .good)
        let log = directory.appendingPathComponent("reviews.jsonl")
        let before = try Data(contentsOf: log)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: log.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: log.path) }
        store.review(store.cards[0].id, rating: .hard)
        #expect(try Data(contentsOf: log) == before)
        #expect(store.lastError?.hasPrefix("Couldn't save the review") == true)
    }

    @Test func addSkipsDuplicatesAndPersists() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CardStore(directory: directory)
        #expect(store.add([Card(term: "Pick up"), Card(term: "pick up!"), Card(term: "wrap up")]) == 2)
        #expect(CardStore(directory: directory).cards.map(\.term) == ["Pick up", "wrap up"])
    }

    @Test func reviewReschedulesAndLogs() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CardStore(directory: directory)
        store.add([Card(term: "gist")])
        let id = store.cards[0].id
        store.review(id, rating: .good)
        store.recordPronunciation(id, score: 0.5, heard: "jist")
        #expect(store.dueCards().isEmpty)
        let reloaded = CardStore(directory: directory)
        #expect(reloaded.reviews.count == 2)
        #expect(reloaded.stats()[id]?.reviews == 1)
        #expect(reloaded.stats()[id]?.pronunciationAverage == 0.5)
    }

    @Test func neverOverwritesAFileItCouldNotRead() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let broken = #"{"cards":[{"term":"pick up"},"#
        let url = directory.appendingPathComponent("cards.json")
        try broken.write(to: url, atomically: true, encoding: .utf8)
        let store = CardStore(directory: directory)
        #expect(store.lastError != nil)
        #expect(store.isReadOnly)
        store.add([Card(term: "imported")])
        #expect(try String(contentsOf: url, encoding: .utf8) == broken)
        try #"{"cards":[{"term":"pick up"}]}"#.write(to: url, atomically: true, encoding: .utf8)
        store.load()
        #expect(!store.isReadOnly)
        #expect(store.add([Card(term: "imported")]) == 1)
        #expect(CardStore(directory: directory).cards.count == 2)
    }

    @Test func aPartialScheduleDoesNotBreakTheDeck() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #"{"cards":[{"term":"gist","schedule":{"due":"2030-01-01T00:00:00Z"}},{"term":"apprised"}]}"#
            .write(to: directory.appendingPathComponent("cards.json"), atomically: true, encoding: .utf8)
        let store = CardStore(directory: directory)
        #expect(store.lastError == nil)
        #expect(store.cards.count == 2)
        #expect(store.cards[0].schedule.ease == 2.5)
        #expect(store.dueCards().map(\.term) == ["apprised"])
    }

    @Test func toleratesHandWrittenCards() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #"{"cards":[{"term":"touch base","kind":"idiom"}]}"#.write(to: directory.appendingPathComponent("cards.json"), atomically: true, encoding: .utf8)
        let store = CardStore(directory: directory)
        #expect(store.cards.first?.kind == .idiom)
        #expect(store.dueCards().count == 1)
        #expect(store.lastError == nil)
    }
}
