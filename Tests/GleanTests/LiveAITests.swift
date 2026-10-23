import Foundation
import Testing
@testable import Glean

@MainActor
struct LiveAITests {
    nonisolated static let enabled = ProcessInfo.processInfo.environment["GLEAN_LIVE_AI"] != nil

    func tutor(_ engine: AIEngine) -> (Tutor, URL) {
        let root = TestSupport.temporaryRoot()
        let directory = SpacePaths.directory(in: root, id: UUID())
        let defaults = UserDefaults(suiteName: "glean-live-\(UUID().uuidString)") ?? UserDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.engine = engine
        let store = CardStore(directory: directory)
        store.add([Card(term: "push back")])
        let space = Space(name: "English", target: "en-US", native: "pt-BR")
        return (Tutor(settings: settings, space: space, store: store, insights: InsightsStore(directory: directory)), root)
    }

    @Test(.enabled(if: LiveAITests.enabled))
    func addsCardsThroughTheChatWithClaudeCode() async throws {
        let (tutor, directory) = tutor(.claudeCode)
        defer { try? FileManager.default.removeItem(at: directory) }
        let turn = try await tutor.addChat(history: [], request: "3 phrasal verbs for travel. I already have push back.")
        print(turn.text, turn.cards.map { "\($0.term) | \($0.translations) | \($0.examples.count) examples" })
        #expect(!turn.cards.isEmpty)
        #expect(!turn.cards.contains { Card.normalize($0.term) == "push back" })
        #expect(turn.cards.allSatisfy { $0.examples.count >= 5 && !$0.translations.isEmpty })
    }

    @Test(.enabled(if: LiveAITests.enabled))
    func checksASentenceWithClaudeCode() async throws {
        let (tutor, directory) = tutor(.claudeCode)
        defer { try? FileManager.default.removeItem(at: directory) }
        let check = try await tutor.checkSentence(card: Card(term: "push back"), sentence: "I pushed back the meeting for him yesterday of the boss.")
        print(check)
        #expect(!check.ok)
        #expect(!check.corrected.isEmpty)
    }

    @Test(.enabled(if: LiveAITests.enabled))
    func answersAQuestionAboutACard() async throws {
        let (tutor, directory) = tutor(.claudeCode)
        defer { try? FileManager.default.removeItem(at: directory) }
        let answer = try await tutor.ask(about: Card(term: "touch base", kind: .idiom), history: [], question: "Posso usar num email formal?")
        print(answer)
        #expect(answer.count > 20)
    }

    @Test(.enabled(if: LiveAITests.enabled))
    func completesACardWithCodex() async throws {
        let (tutor, directory) = tutor(.codex)
        defer { try? FileManager.default.removeItem(at: directory) }
        let filled = try await tutor.fill(Card(term: "wrap up", kind: .phrasalVerb))
        print("codex:", filled.translations, filled.pronunciation, filled.examples.count)
        #expect(!filled.translations.isEmpty)
        #expect(filled.examples.count >= 5)
    }
}
