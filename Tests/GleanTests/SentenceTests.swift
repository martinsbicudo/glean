import Foundation
import Testing
@testable import Glean

@MainActor
struct SentenceTests {
    @Test func parsesTheCheckReply() throws {
        let text = """
        Here is my review:
        {"ok": false, "corrected": " I pushed back the meeting. ", "explanation": "Falta o objeto.", "better": ["We moved the meeting.", " "]}
        """
        let check = try AIJSON.sentence(from: text)
        #expect(!check.ok)
        #expect(check.corrected == "I pushed back the meeting.")
        #expect(check.explanation == "Falta o objeto.")
        #expect(check.better == ["We moved the meeting."])
    }

    @Test func parsesAMinimalReplyAndSkipsOtherJSON() throws {
        let check = try AIJSON.sentence(from: #"Note [1] {"x": 2} {"ok": true}"#)
        #expect(check.ok)
        #expect(check.corrected.isEmpty)
        #expect(check.better.isEmpty)
    }

    @Test func rejectsRepliesWithoutOk() {
        #expect(throws: AIJSON.ParseError.self) { try AIJSON.sentence(from: #"{"corrected": "x"}"#) }
        #expect(throws: AIJSON.ParseError.self) { try AIJSON.sentence(from: "Looks fine to me.") }
    }

    @Test func oldReviewLinesStillDecode() throws {
        let old = #"{"cardID":"6F1D1B84-6B0B-4E5B-9E55-0B7F4F8B7A11","date":"2026-01-01T10:00:00Z","rating":3}"#
        let entry = try JSONCoding.decoder.decode(ReviewEntry.self, from: Data(old.utf8))
        #expect(entry.rating == .good)
        #expect(entry.sentence == nil)
        #expect(entry.sentenceOK == nil)
        let line = String(decoding: try JSONCoding.encoder(pretty: false).encode(entry), as: UTF8.self)
        #expect(!line.contains("sentence"))
    }

    @Test func sentenceEntriesRoundTripThroughTheLog() throws {
        let directory = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CardStore(directory: directory)
        let card = Card(term: "wrap up")
        store.add([card])
        store.recordSentence(card.id, sentence: "I wrap up it.", ok: false)
        let reloaded = CardStore.readReviews(store.reviewsURL)
        #expect(reloaded.count == 1)
        #expect(reloaded[0].sentence == "I wrap up it.")
        #expect(reloaded[0].sentenceOK == false)
        #expect(reloaded[0].rating == nil)
        #expect(store.stats()[card.id]?.reviews == 0)
    }

    @Test func studyReportListsRecentIncorrectSentencesOnly() {
        let wrap = Card(term: "wrap up")
        let gist = Card(term: "gist")
        let now = Date()
        let reviews = [
            ReviewEntry(cardID: wrap.id, date: now, sentence: "I wrap up it.", sentenceOK: false),
            ReviewEntry(cardID: gist.id, date: now, sentence: "I got the gist.", sentenceOK: true),
        ]
        let text = StudyReport.text(cards: [wrap, gist], reviews: reviews, now: now)
        #expect(text.contains("Recent sentences the learner wrote with mistakes:"))
        #expect(text.contains("\"wrap up\" and wrote \"I wrap up it.\""))
        #expect(!text.contains("I got the gist."))
        #expect(!StudyReport.text(cards: [gist], reviews: [reviews[1]], now: now).contains("wrote with mistakes"))
    }

    @Test func spacesWithoutADirectionDecodeAsMixed() throws {
        let json = """
        {"version":1,"spaces":[{"id":"6F1D1B84-6B0B-4E5B-9E55-0B7F4F8B7A11","name":"English","target":"en-US","native":"pt-BR","level":"intermediate","dailyGoal":20,"created":"2026-01-01T10:00:00Z"}]}
        """
        let file = try JSONCoding.decoder.decode(SpacesFile.self, from: Data(json.utf8))
        #expect(file.spaces[0].direction == .mixed)
    }

    @Test func existingSpacesFileLoadsAndKeepsItsDirectionAfterAnEdit() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let id = "6F1D1B84-6B0B-4E5B-9E55-0B7F4F8B7A11"
        try TestSupport.write(
            #"{"version":1,"selected":"\#(id)","spaces":[{"id":"\#(id)","name":"English","target":"en-US","native":"pt-BR","level":"intermediate","dailyGoal":20}]}"#,
            to: SpacePaths.file(in: root)
        )
        let store = SpaceStore(root: root, defaults: try TestSupport.isolatedDefaults())
        var space = try #require(store.selected)
        #expect(space.direction == .mixed)
        space.direction = .recall
        try store.update(space)
        let reopened = SpaceStore(root: root, defaults: try TestSupport.isolatedDefaults())
        #expect(reopened.selected?.direction == .recall)
        #expect(try store.create(name: "Spanish", target: "es-ES", native: "pt-BR", level: .beginner, dailyGoal: 10).direction == .mixed)
    }

    @Test func unknownDirectionFallsBackToMixed() throws {
        let json = #"{"id":"6F1D1B84-6B0B-4E5B-9E55-0B7F4F8B7A11","name":"E","target":"en-US","native":"pt-BR","direction":"sideways"}"#
        #expect(try JSONCoding.decoder.decode(Space.self, from: Data(json.utf8)).direction == .mixed)
    }
}
