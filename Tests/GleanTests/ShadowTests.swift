import Testing
@testable import Glean

struct ShadowTests {
    @Test func punctuationAloneMeansNothingWasHeard() {
        #expect(!PronunciationRecorder.heardWords("."))
        #expect(!PronunciationRecorder.heardWords(" ¿? "))
        #expect(!PronunciationRecorder.heardWords(""))
        #expect(PronunciationRecorder.heardWords("al punto."))
        #expect(PronunciationRecorder.heardWords("2"))
        #expect(PronunciationRecorder.heardWords("こんにちは"))
    }

    @Test func durationGrowsWithWordsAndHasAFloorForSingleWords() {
        #expect(Shadow.estimatedDuration(of: "gist") > 0)
        #expect(Shadow.estimatedDuration(of: "she picked up the phone and left") > Shadow.estimatedDuration(of: "pick up"))
        #expect(Shadow.estimatedDuration(of: "   ") == 0)
    }

    @Test func longUnspacedTextUsesCharacterCount() {
        #expect(Shadow.estimatedDuration(of: "今日は天気がとてもいいですね") > Shadow.estimatedDuration(of: "天気"))
        #expect(Shadow.estimatedDuration(of: "今日は天気がとてもいいですね") > 0.8)
    }

    @Test func autoStopIsDurationTimesOnePointSixPlusOneSecond() {
        let text = "one two three four five"
        let duration = Shadow.estimatedDuration(of: text)
        #expect(duration == 2.0)
        #expect(Shadow.autoStop(for: text) == 2.0 * 1.6 + 1)
        #expect(Shadow.autoStop(for: "") == 1)
    }

    @Test func phrasesAreTermThenExamplesWithoutBlanksOrRepeats() {
        var card = Card(term: "pick up")
        card.examples = ["I pick up my kids.", "  ", "pick up", "I pick up my kids.", "Pick up the pace."]
        #expect(Shadow.phrases(for: card) == ["pick up", "I pick up my kids.", "Pick up the pace."])
    }

    @Test func sequenceWalksInOrderAndStopsAtTheEnd() {
        var sequence = ShadowSequence(phrases: ["a", "b", "c"])
        #expect(sequence.current == "a")
        #expect(!sequence.isLast)
        let first = sequence.advance()
        let second = sequence.advance()
        #expect(first && second)
        #expect(sequence.current == "c")
        #expect(sequence.isLast)
        let third = sequence.advance()
        #expect(!third)
        #expect(sequence.current == "c")
    }

    @Test func sequenceCanStartMidwayAndFallsBackWhenOutOfRange() {
        #expect(ShadowSequence(phrases: ["a", "b", "c"], startAt: 1).current == "b")
        #expect(ShadowSequence(phrases: ["a", "b"], startAt: 9).current == "a")
        #expect(ShadowSequence(phrases: []).current == nil)
        #expect(ShadowSequence(phrases: []).isLast)
    }

    @Test func scoresAreKeptPerPhraseAndAveraged() {
        var sequence = ShadowSequence(phrases: ["a", "b", "c"])
        #expect(sequence.average == nil)
        sequence.record(1)
        sequence.advance()
        #expect(sequence.currentScore == nil)
        sequence.record(0.5)
        #expect(sequence.scores == [1, 0.5, nil])
        #expect(sequence.average == 0.75)
        sequence.record(0.25)
        #expect(sequence.currentScore == 0.25)
        #expect(sequence.scores == [1, 0.25, nil])
    }
}
