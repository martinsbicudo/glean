import Foundation
import Testing
@testable import Glean

struct AddChatTests {
    @Test func aMalformedCardKeepsTheMessageAndTheOtherCards() throws {
        let reply = try AIJSON.chat(from: #"{"message":"Here you go","cards":[{"term":"get over"},{"term":"give up","translations":"desistir"},{"term":"carry on"}]}"#)
        #expect(reply.message == "Here you go")
        #expect(reply.cards.map(\.term) == ["get over", "carry on"])
    }

    @Test func readsMessageAndCards() throws {
        let reply = try AIJSON.chat(from: #"{"message":"Aqui vao.","cards":[{"term":"check in"},{"term":"board"}]}"#)
        #expect(reply.message == "Aqui vao.")
        #expect(reply.cards.map(\.term) == ["check in", "board"])
    }

    @Test func readsCardsOnlyAndABareArray() throws {
        let wrapped = try AIJSON.chat(from: #"{"cards":[{"term":"gist"}]}"#)
        #expect(wrapped.message.isEmpty)
        #expect(wrapped.cards.map(\.term) == ["gist"])
        #expect(try AIJSON.chat(from: #"[{"term":"a"},{"term":"b"}]"#).cards.count == 2)
        #expect(try AIJSON.chat(from: #"{"term":"solo"}"#).cards.map(\.term) == ["solo"])
    }

    @Test func readsAMessageWithNoCards() throws {
        let reply = try AIJSON.chat(from: #"{"message":"Which topic?","cards":[]}"#)
        #expect(reply.message == "Which topic?")
        #expect(reply.cards.isEmpty)
    }

    @Test func readsJSONInsideProseAndFences() throws {
        let text = "Sure! Step [1] done.\n```json\n{\"message\":\"Ok {smile}\",\"cards\":[{\"term\":\"gist\"}]}\n```\nEnjoy."
        let reply = try AIJSON.chat(from: text)
        #expect(reply.message == "Ok {smile}")
        #expect(reply.cards.map(\.term) == ["gist"])
    }

    @Test func skipsJunkJSONBeforeTheReply() throws {
        let reply = try AIJSON.chat(from: #"Notes {"a":1} [1,2] {} then {"message":"hi","cards":[{"term":"gist"}]}"#)
        #expect(reply.cards.map(\.term) == ["gist"])
    }

    @Test func rejectsRepliesWithoutAChatShape() {
        #expect(throws: AIJSON.ParseError.self) { try AIJSON.chat(from: #"Sorry. {"a":1} [1] {"message":"","cards":[]}"#) }
        #expect(throws: AIJSON.ParseError.self) { try AIJSON.chat(from: "No JSON here") }
    }

    @Test func historyKeepsTheLastTenTurnsAndSummarizesCards() {
        var turns: [AddTurn] = []
        for index in 1...7 {
            turns.append(AddTurn(role: .learner, text: "ask \(index)"))
            turns.append(AddTurn(role: .tutor, text: "answer \(index)", cards: [Card(term: "term \(index)a"), Card(term: "term \(index)b")]))
        }
        let lines = AddChat.history(turns).components(separatedBy: "\n")
        #expect(lines.first == "Learner: ask 3")
        #expect(lines.contains("Tutor: answer 7"))
        #expect(lines.contains("(cards shown: 1. term 7a; 2. term 7b)"))
        #expect(!AddChat.history(turns).contains("ask 2"))
        #expect(lines.filter { $0.hasPrefix("Learner:") || $0.hasPrefix("Tutor:") }.count == 10)
    }

    @Test func historyIsEmptyForANewChat() {
        #expect(AddChat.history([]).isEmpty)
    }

    @Test func dropsTermsAlreadyInTheDeckAndRepeatsInTheReply() {
        let known: Set<String> = [Card.normalize("Push Back")]
        let text = #"{"message":"ok","cards":[{"term":"push back"},{"term":"Wrap up!"},{"term":"wrap up"},{"term":" "}]}"#
        let turn = AddChat.turn(from: text, known: known)
        #expect(turn.cards.map(\.term) == ["Wrap up!"])
        #expect(turn.selected == Set(turn.cards.map(\.id)))
        #expect(turn.text == "ok")
    }

    @Test func saysSoWhenEverythingIsAlreadyInTheDeck() {
        let turn = AddChat.turn(from: #"{"message":"Here","cards":[{"term":"gist"}]}"#, known: [Card.normalize("gist")])
        #expect(turn.cards.isEmpty)
        #expect(turn.text.contains("already in this space"))
    }

    @Test func showsProseRepliesAsText() {
        let turn = AddChat.turn(from: "  I can't help with that.  ", known: [])
        #expect(turn.text == "I can't help with that.")
        #expect(turn.cards.isEmpty)
    }

    @Test func promptCarriesHistoryDeckAndRequest() {
        let profile = LearnerProfile(target: Language.named("es-ES"), native: Language.named("pt-BR"), level: .beginner, insights: "")
        let message = Prompts.addChatMessage(profile: profile, existing: ["a", "b"], history: "Learner: hi", request: "make #1 easier")
        #expect(message.contains("Spanish (Spain)"))
        #expect(message.contains("Already have (skip these): a; b"))
        #expect(message.contains("Conversation so far:\nLearner: hi"))
        #expect(message.hasSuffix("<<<\nmake #1 easier\n>>>"))
        #expect(!message.contains("Conversation so far:\n\n"))
    }
}
