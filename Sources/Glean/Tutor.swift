import Foundation

struct ChatTurn: Identifiable, Equatable {
    enum Role {
        case learner, tutor

        var label: String { self == .learner ? "Learner" : "Tutor" }
    }

    let id = UUID()
    let role: Role
    let text: String
}

@MainActor
struct Tutor {
    let settings: AppSettings
    let space: Space
    let store: CardStore
    let insights: InsightsStore

    var isConnected: Bool { settings.engine != .none }

    private var agent: AgentCLI {
        let settings = settings
        return AgentCLI(engine: settings.engine) { settings.model(for: $0) }
    }

    var profile: LearnerProfile {
        LearnerProfile(target: space.targetLanguage, native: space.nativeLanguage, level: space.level, insights: insights.profileNotes)
    }

    func addChat(history: [AddTurn], request: String) async throws -> AddTurn {
        let message = Prompts.addChatMessage(
            profile: profile, existing: store.cards.map(\.term), history: AddChat.history(history), request: request
        )
        let reply = try await agent.run(systemPrompt: Prompts.addChatSystem, userMessage: message, activity: "chatting about new cards")
        return AddChat.turn(from: reply.text, known: Set(store.cards.map(\.normalizedTerm)))
    }

    func checkSentence(card: Card, sentence: String) async throws -> SentenceCheck {
        let reply = try await agent.run(
            systemPrompt: Prompts.sentenceSystem, userMessage: Prompts.sentenceMessage(card: card, sentence: sentence, profile: profile),
            activity: "checking a sentence"
        )
        return try AIJSON.sentence(from: reply.text)
    }

    func fill(_ card: Card) async throws -> Card {
        let reply = try await agent.run(
            systemPrompt: Prompts.fillSystem, userMessage: Prompts.fillMessage(card: card, profile: profile), activity: "completing a card"
        )
        return try AIJSON.card(from: reply.text).card(keeping: card)
    }

    func ask(about card: Card, history: [ChatTurn], question: String) async throws -> String {
        let message = Prompts.askMessage(card: card, stats: store.stats()[card.id], history: history, question: question)
        let reply = try await agent.run(systemPrompt: Prompts.askSystem(profile: profile), userMessage: message, activity: "answering a question")
        return reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func coach() async throws -> CoachReport {
        let report = StudyReport.text(cards: store.cards, reviews: store.reviews)
        let message = Prompts.coachMessage(profile: profile, report: report, existing: store.cards.map(\.term))
        let reply = try await agent.run(systemPrompt: Prompts.coachSystem, userMessage: message, activity: "coaching")
        var result = try AIJSON.coach(from: reply.text)
        result.date = Date()
        result.cards = result.cards.filter { !store.contains(term: $0.term) }
        insights.save(result)
        return result
    }
}
