import Foundation
import Testing
@testable import Glean

@MainActor
struct CoachDataTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func studyReportListsHardestCardsAndPronunciationMisses() {
        let easy = Card(term: "wrap up", kind: .phrasalVerb)
        let hard = Card(term: "apprised", kind: .word)
        let reviews = [
            ReviewEntry(cardID: easy.id, date: now, rating: .good),
            ReviewEntry(cardID: hard.id, date: now, rating: .again),
            ReviewEntry(cardID: hard.id, date: now, rating: .hard),
            ReviewEntry(cardID: hard.id, date: now, pronunciationScore: 0.5, heard: "a price"),
        ]
        let text = StudyReport.text(cards: [easy, hard], reviews: reviews, now: now)
        #expect(text.contains("Reviews: 3 in total, 3 in the last 7 days."))
        #expect(text.contains("Word: 1 cards, 2 reviews, 1 forgotten, 1 hard."))
        #expect(text.contains("- apprised · word · 2 · 1 · 1"))
        #expect(!text.contains("- wrap up ·"))
        #expect(text.contains("heard \"a price\" (50%)"))
    }

    @Test func insightsPersistAndFeedTheProfile() {
        let root = TestSupport.temporaryRoot()
        let directory = SpacePaths.directory(in: root, id: UUID())
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = InsightsStore(directory: directory)
        #expect(store.profileNotes.isEmpty)
        store.save(CoachReport(summary: "Good week.", weaknesses: ["the th sound"], tips: [], cards: [CardDraft(card: Card(term: "Touch base"))], date: now))
        let reloaded = InsightsStore(directory: directory)
        #expect(reloaded.profileNotes == "  - weak: the th sound\n  - summary: Good week.")
        reloaded.removeSuggestion("touch base!")
        #expect(InsightsStore(directory: directory).latest?.cards.isEmpty == true)
    }

    @Test func unreadableInsightsAreNeverOverwritten() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = SpacePaths.directory(in: root, id: UUID())
        let file = directory.appendingPathComponent("insights.json")
        try TestSupport.write("{ not json", to: file)
        let insights = InsightsStore(directory: directory)
        insights.save(CoachReport(summary: "New", weaknesses: [], tips: [], cards: [], date: nil))
        #expect(try String(contentsOf: file, encoding: .utf8) == "{ not json")
    }

    @Test func insightsRefuseToWriteOutsideSpaces() throws {
        let root = TestSupport.temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = InsightsStore(directory: root)
        store.save(CoachReport(summary: "x", weaknesses: [], tips: [], cards: [], date: now))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("insights.json").path))
        #expect(store.latest == nil)
    }

    @Test func profileNamesTargetAndNativeLanguages() {
        let profile = LearnerProfile(target: Language.named("es-MX"), native: Language.named("pt-BR"), level: .advanced, insights: "")
        #expect(profile.description.contains("Spanish (Mexico) (es-MX)"))
        #expect(profile.description.contains("Portuguese (Brazil) (pt-BR)"))
        #expect(profile.description.contains("Advanced"))
        let prompts = [Prompts.cardSchema, Prompts.addChatSystem, Prompts.sentenceSystem, Prompts.fillSystem, Prompts.coachSystem]
        #expect(prompts.allSatisfy { !$0.localizedCaseInsensitiveContains("meeting") })
    }

    @Test func askMessageCarriesHistoryAndConversation() {
        var stats = CardStats()
        stats.reviews = 4
        stats.again = 2
        stats.pronunciationAttempts = 1
        stats.pronunciationTotal = 0.75
        let message = Prompts.askMessage(
            card: Card(term: "gist"), stats: stats,
            history: [ChatTurn(role: .learner, text: "oi"), ChatTurn(role: .tutor, text: "hi")], question: "Formal?"
        )
        #expect(message.contains("4 reviews, 2 forgotten, 0 hard, pronunciation check average 75%."))
        #expect(message.contains("Learner: oi\nTutor: hi"))
        #expect(message.hasSuffix("Learner: Formal?"))
    }
}
