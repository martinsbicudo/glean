import Testing
@testable import Glean

struct PronunciationScoreTests {
    @Test func perfectMatchIgnoresCaseAndPunctuation() {
        let result = PronunciationScore.compare(target: "Let's wrap up the meeting.", heard: "lets wrap up the meeting")
        #expect(result.score == 1)
    }

    @Test func missingWordsAreMarked() {
        let result = PronunciationScore.compare(target: "push back on the deadline", heard: "push on the dead line")
        #expect(result.missed == ["back", "deadline"])
        #expect(result.score == 0.6)
    }

    @Test func wordOrderMatters() {
        let result = PronunciationScore.compare(target: "pick up", heard: "up pick")
        #expect(result.score == 0.5)
    }

    @Test func nothingHeardScoresZero() {
        #expect(PronunciationScore.compare(target: "apprised", heard: "").score == 0)
    }
}
