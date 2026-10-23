import Foundation

struct AddTurn: Identifiable, Equatable {
    let id = UUID()
    let role: ChatTurn.Role
    var text: String
    var cards: [Card]
    var selected: Set<UUID>
    var added = 0

    init(role: ChatTurn.Role, text: String, cards: [Card] = []) {
        self.role = role
        self.text = text
        self.cards = cards
        selected = Set(cards.map(\.id))
    }
}

struct ChatReply: Equatable {
    var message: String
    var cards: [CardDraft]
}

private struct ChatPayload: Decodable {
    var message: String?
    var cards: [CardDraft]?

    private enum CodingKeys: String, CodingKey { case message, cards }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        cards = try c.decodeIfPresent([LenientDraft].self, forKey: .cards)?.compactMap(\.draft)
        guard message != nil || cards != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "not a chat reply"))
        }
    }
}

private struct LenientDraft: Decodable {
    var draft: CardDraft?

    init(from decoder: Decoder) throws {
        do {
            draft = try CardDraft(from: decoder)
        } catch {
            Log.write("skipping a malformed card in the AI reply: \(error.localizedDescription)")
            draft = nil
        }
    }
}

extension AIJSON {
    static func chat(from text: String) throws -> ChatReply {
        for data in candidates(text) {
            if let payload = try? JSONDecoder().decode(ChatPayload.self, from: data) {
                let message = (payload.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let cards = payload.cards ?? []
                if !message.isEmpty || !cards.isEmpty { return ChatReply(message: message, cards: cards) }
            }
            if let list = try? JSONDecoder().decode([CardDraft].self, from: data), !list.isEmpty {
                return ChatReply(message: "", cards: list)
            }
            if let card = try? JSONDecoder().decode(CardDraft.self, from: data) {
                return ChatReply(message: "", cards: [card])
            }
        }
        throw ParseError.noJSON
    }
}

enum AddChat {
    static let historyLimit = 10

    static func history(_ turns: [AddTurn]) -> String {
        turns.suffix(historyLimit).map(line).joined(separator: "\n")
    }

    static func freshCards(_ drafts: [CardDraft], known: Set<String>) -> [Card] {
        var seen = known
        return drafts.map { $0.card() }.filter { !$0.normalizedTerm.isEmpty && seen.insert($0.normalizedTerm).inserted }
    }

    static func turn(from text: String, known: Set<String>) -> AddTurn {
        let reply: ChatReply
        do {
            reply = try AIJSON.chat(from: text)
        } catch {
            Log.write("add chat: the reply wasn't JSON, showing it as text")
            reply = ChatReply(message: text.trimmingCharacters(in: .whitespacesAndNewlines), cards: [])
        }
        let cards = freshCards(reply.cards, known: known)
        var message = reply.message
        if !reply.cards.isEmpty && cards.isEmpty {
            message += (message.isEmpty ? "" : "\n\n") + "Everything I suggested is already in this space."
        } else if message.isEmpty {
            message = "Here \(cards.count == 1 ? "is 1 card" : "are \(cards.count) cards")."
        }
        return AddTurn(role: .tutor, text: message, cards: cards)
    }

    private static func line(_ turn: AddTurn) -> String {
        var text = "\(turn.role.label): \(turn.text)"
        if !turn.cards.isEmpty {
            let list = turn.cards.enumerated().map { "\($0.offset + 1). \($0.element.term)" }.joined(separator: "; ")
            text += "\n(cards shown: \(list))"
        }
        return text
    }
}
