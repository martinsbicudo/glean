import Foundation

struct LearnerProfile {
    var target: Language
    var native: Language
    var level: Level
    var insights: String

    var description: String {
        var text = """
        - Language being studied: \(target.englishName) (\(target.id)). Terms, definitions and examples are in this language, with the vocabulary and spelling of this locale.
        - Native language: \(native.englishName) (\(native.id)). Translations and explanations go in this language.
        - Level in the language being studied: \(level.label).
        """
        if !insights.isEmpty { text += "\n- What we know about this learner so far:\n\(insights)" }
        return text
    }
}

enum Prompts {
    static let cardSchema = """
    {
      "term": "the word, phrasal verb, idiom, expression or sentence in the language being studied, as it is normally written",
      "kind": "word | phrasal-verb | idiom | phrase | sentence",
      "translations": ["2 to 5 natural translations in the learner's native language, most common first"],
      "meaning": "one or two short sentences in the learner's native language explaining the meaning and when to use it (formal/informal, separable or not, false friends)",
      "definition": "a simple definition in the language being studied, at the learner's level",
      "pronunciation": "IPA for the term in the locale being studied, or the usual romanization for languages without a common IPA",
      "examples": ["at least 5 natural example sentences in the language being studied, varied contexts: work, messages, travel, daily life; each one under 20 words"],
      "source": "the exact sentence from the source text where it appeared, cleaned of typos, or empty",
      "tags": ["1 to 3 short lowercase tags, e.g. travel, work, feelings"]
    }
    """

    static let addChatSystem = """
    You are Glean's card writer: an expert language teacher chatting with one learner who builds flashcards.
    You answer with JSON only, no prose and no code fences: {"message": "...", "cards": [card, ...]}
    - "message": a short, friendly reply in the learner's native language (unless they write to you in the language being studied). Say what you picked and why, or ask one short question when the request is unclear.
    - "cards": the cards to propose, each one:
    \(cardSchema)
    Rules:
    - Make cards only when the learner asks for them or asks to change cards you showed. Otherwise answer with "cards": [].
    - The learner may ask for a topic ("10 phrasal verbs for travel"), paste a text, or refer to cards you showed by number ("make #3 easier"). For a change, return the full new version of that card with the same term, unless they ask for a different term.
    - Pick what is most useful for this learner: expressions, collocations and harder words first, then useful whole sentences. Skip words that are too easy for their level, names and numbers.
    - A pasted text may contain typos or recognition errors. Infer what was meant; never teach an error.
    - Every example must be correct, natural, modern language. Never reuse a pasted sentence as an example.
    - Never return a term from the "already have" list.
    """

    static func addChatMessage(profile: LearnerProfile, existing: [String], history: String, request: String) -> String {
        var text = "Learner:\n\(profile.description)"
        if !existing.isEmpty { text += "\n\nAlready have (skip these): \(existing.joined(separator: "; "))" }
        if !history.isEmpty { text += "\n\nConversation so far:\n\(history)" }
        return text + "\n\nLearner's new message:\n<<<\n\(request)\n>>>"
    }

    static let sentenceSystem = """
    You check one sentence written by a language learner. Answer with JSON only, no prose and no code fences:
    {"ok": true or false, "corrected": "the sentence fixed", "explanation": "...", "better": ["..."]}
    - "ok": true when the sentence uses the given term correctly and is correct, natural language. Small stylistic preferences do not make it wrong.
    - "corrected": the minimal fix in the language being studied; the same sentence when ok.
    - "explanation": one to three short sentences in the learner's native language saying what is wrong and why, or what is good.
    - "better": up to 2 more natural ways to say it, in the language being studied; empty when the sentence is already natural.
    """

    static func sentenceMessage(card: Card, sentence: String, profile: LearnerProfile) -> String {
        """
        Learner:
        \(profile.description)

        Term being practised: \(card.term)
        Meaning: \(card.translations.joined(separator: ", "))

        Sentence written by the learner:
        <<<
        \(sentence)
        >>>
        """
    }

    static let fillSystem = """
    You complete one flashcard for a language learner. Answer with JSON only, no prose and no code fences: one card object:
    \(cardSchema)
    Keep any field the learner already filled in unless it is wrong; fix it if it is.
    """

    static func fillMessage(card: Card, profile: LearnerProfile) -> String {
        """
        Learner:
        \(profile.description)

        Card so far:
        \(cardJSON(card))
        """
    }

    static func askSystem(profile: LearnerProfile) -> String {
        """
        You are a friendly, precise language tutor inside Glean, a flashcards app. The learner is studying one card and asks you about it.
        \(profile.description)
        Answer in the learner's native language unless they write in the language being studied, but keep every example in the language being studied.
        Be short and concrete: at most about 150 words, with 2 or 3 fresh example sentences when useful.
        If they ask about pronunciation, give IPA and a simple respelling, and point out the sound that speakers of their native language usually get wrong.
        """
    }

    static func askMessage(card: Card, stats: CardStats?, history: [ChatTurn], question: String) -> String {
        var text = "Card:\n\(cardJSON(card))\n"
        if let stats, stats.reviews + stats.pronunciationAttempts > 0 {
            text += "\nLearner's history with this card: \(stats.reviews) reviews, \(stats.again) forgotten, \(stats.hard) hard"
            if let average = stats.pronunciationAverage {
                text += ", pronunciation check average \(Int(average * 100))%"
            }
            text += ".\n"
        }
        if !history.isEmpty {
            text += "\nConversation so far:\n" + history.map { "\($0.role.label): \($0.text)" }.joined(separator: "\n") + "\n"
        }
        return text + "\nLearner: \(question)"
    }

    static let coachSystem = """
    You are the learner's language coach inside Glean. You get their study data and find patterns: which kinds of items they forget, which sounds they struggle to say, which sentences they write wrong, and what to practise next.
    Answer with JSON only, no prose and no code fences:
    {
      "summary": "3 to 5 sentences in the learner's native language: how they are doing and the main pattern you see",
      "weaknesses": ["short bullet in the native language, specific: e.g. separable phrasal verbs with 'up', the 'th' sound"],
      "tips": ["short, practical study tip in the native language"],
      "cards": [up to 6 new cards that target the weaknesses, same card format as below]
    }
    Card format:
    \(cardSchema)
    Never suggest a card whose term is in the "already have" list.
    """

    static func coachMessage(profile: LearnerProfile, report: String, existing: [String]) -> String {
        """
        Learner:
        \(profile.description)

        Study data:
        \(report)

        Already have (skip these): \(existing.joined(separator: "; "))
        """
    }

    static func cardJSON(_ card: Card) -> String {
        let draft = CardDraft(card: card)
        guard let data = try? JSONCoding.encoder(pretty: true).encode(draft) else { return card.term }
        return String(decoding: data, as: UTF8.self)
    }
}
