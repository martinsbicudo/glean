import Foundation
import Testing
@testable import Glean

struct RecallTests {
    func card(reps: Int, translations: [String] = ["recolher"]) -> Card {
        var card = Card(term: "pick up")
        card.translations = translations
        card.schedule.reps = reps
        return card
    }

    @Test func recognizeAndRecallAreFixed() {
        #expect(ReviewDirection.recognize.side(for: card(reps: 5)) == .recognize)
        #expect(ReviewDirection.recall.side(for: card(reps: 0)) == .recall)
    }

    @Test func mixedStartsRecognizeThenAlternatesByReps() {
        let sides = (0...5).map { ReviewDirection.mixed.side(for: card(reps: $0)) }
        #expect(sides == [.recognize, .recognize, .recall, .recognize, .recall, .recognize])
    }

    @Test func cardsWithoutAPromptStayRecognize() {
        #expect(ReviewDirection.recall.side(for: card(reps: 4, translations: [])) == .recognize)
    }

    @Test func blanksCaseInsensitivelyAndKeepsTheRestOfTheSentence() {
        #expect(Cloze.blank(term: "Wrap Up", in: "Let's wrap up the call.") == "Let's _____ the call.")
        #expect(Cloze.blank(term: "gist", in: "I got the GIST of it.") == "I got the _____ of it.")
    }

    @Test func blanksMultiWordTermsAsOnePhrase() {
        #expect(Cloze.blank(term: "touch base", in: "I'll touch base with you tomorrow.") == "I'll _____ with you tomorrow.")
        #expect(Cloze.blank(term: "touch base", in: "I touch the base.") == nil)
    }

    @Test func blanksInflectedForms() {
        #expect(Cloze.blank(term: "pick up", in: "She picked up the phone.") == "She _____ the phone.")
        #expect(Cloze.blank(term: "pick up", in: "He is picking up speed?") == "He is _____ speed?")
        #expect(Cloze.blank(term: "carry on", in: "They carried on anyway.") == "They _____ anyway.")
        #expect(Cloze.blank(term: "make up", in: "She makes up stories.") == "She _____ stories.")
    }

    @Test func doesNotBlankInsideOtherWordsOrShortStems() {
        #expect(Cloze.blank(term: "go", in: "That is good.") == nil)
        #expect(Cloze.blank(term: "act", in: "He reacted fast.") == nil)
    }

    @Test func blanksSpacelessScripts() {
        #expect(Cloze.blank(term: "勉強", in: "毎日勉強します。") == "毎日_____します。")
    }

    @Test func returnsNilWhenThereIsNoMatch() {
        #expect(Cloze.blank(term: "wrap up", in: "Let's finish this.") == nil)
        #expect(Cloze.blank(term: "  ", in: "Anything") == nil)
    }

    @Test func usesTheFirstExampleThatMatches() {
        var card = Card(term: "gist")
        card.examples = ["Nothing here.", "I got the gist."]
        #expect(Cloze.example(for: card) == "I got the _____.")
        card.examples = ["Nothing here."]
        #expect(Cloze.example(for: card) == nil)
    }

    @Test func comparesExactIgnoringCaseAccentsAndPunctuation() {
        #expect(AnswerCheck.compare(typed: "Pick Up!", expected: "pick up") == .correct)
        #expect(AnswerCheck.compare(typed: "  CAFE ", expected: "café") == .correct)
        #expect(AnswerCheck.compare(typed: "it's  fine", expected: "its fine") == .correct)
    }

    @Test func comparesCloseByEditDistance() {
        #expect(AnswerCheck.compare(typed: "pik up", expected: "pick up") == .close)
        #expect(AnswerCheck.compare(typed: "recive", expected: "receive") == .close)
        #expect(AnswerCheck.compare(typed: "look forwad to it", expected: "look forward to it") == .close)
    }

    @Test func comparesWrong() {
        #expect(AnswerCheck.compare(typed: "pick", expected: "pick up") == .wrong)
        #expect(AnswerCheck.compare(typed: "put off", expected: "pick up") == .wrong)
        #expect(AnswerCheck.compare(typed: "cut", expected: "cat") == .wrong)
        #expect(AnswerCheck.compare(typed: "", expected: "cat") == .wrong)
    }
}
