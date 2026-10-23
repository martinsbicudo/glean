import Foundation
import Testing
@testable import Glean

@MainActor
struct LiveSpeechTests {
    nonisolated static let enabled = ProcessInfo.processInfo.environment["GLEAN_LIVE_SPEECH"] != nil

    @Test(.enabled(if: LiveSpeechTests.enabled))
    func transcribesASpokenPhraseAndScoresIt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("glean-speech-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let aiff = directory.appendingPathComponent("say.aiff")
        let caf = directory.appendingPathComponent("say.caf")
        let phrase = "Please push back if the deadline is not realistic."
        try await Shell.run(URL(fileURLWithPath: "/usr/bin/say"), ["-v", "Samantha", "-o", aiff.path, phrase])
        try await Shell.run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "caff", "-d", "LEI16@16000", "-c", "1", aiff.path, caf.path])
        let heard = try await PronunciationRecorder.transcribe(caf, locale: "en-US")
        let score = PronunciationScore.compare(target: phrase, heard: heard)
        print("heard:", heard, "score:", score.score)
        #expect(score.score >= 0.8)
    }
}
