import Testing
@testable import Glean

struct AIJSONTests {
    @Test func readsWrappedCardsInsideFences() throws {
        let text = """
        Here you go:
        ```json
        {"cards": [{"term": "push back", "kind": "phrasal verb", "translations": ["discordar", " "], "examples": ["a", "b"]}]}
        ```
        """
        let cards = try AIJSON.cards(from: text).map { $0.card() }
        #expect(cards.count == 1)
        #expect(cards[0].kind == .phrasalVerb)
        #expect(cards[0].translations == ["discordar"])
    }

    @Test func readsABareArrayOrSingleCard() throws {
        #expect(try AIJSON.cards(from: #"[{"term":"a"},{"term":"b"}]"#).count == 2)
        #expect(try AIJSON.card(from: #"{"term":"gist","kind":"word"}"#).term == "gist")
    }

    @Test func fillKeepsIdentityAndSchedule() throws {
        var base = Card(term: "wrap up")
        base.schedule.reps = 3
        let filled = try AIJSON.card(from: #"{"term":"wrap up","meaning":"finalizar","examples":["Let's wrap up."]}"#).card(keeping: base)
        #expect(filled.id == base.id)
        #expect(filled.schedule.reps == 3)
        #expect(filled.meaning == "finalizar")
    }

    @Test func ignoresBracketsInTheProseAroundTheJSON() throws {
        #expect(try AIJSON.cards(from: "[Note] here: {\"cards\":[{\"term\":\"gist\"}]}").map(\.term) == ["gist"])
        #expect(try AIJSON.cards(from: "```json\n{\"term\":\"a {b}\"}\n``` hope it helps {smile}").map(\.term) == ["a {b}"])
    }

    @Test func skipsJSONInTheProseThatIsNotACard() throws {
        #expect(try AIJSON.cards(from: "Step [1] done. {\"cards\":[{\"term\":\"gist\"}]}").map(\.term) == ["gist"])
        #expect(try AIJSON.card(from: "Options {\"a\":1} then {\"term\":\"wrap up\"}").term == "wrap up")
    }

    @Test func skipsJSONInTheProseThatIsNotACoachReport() throws {
        let report = try AIJSON.coach(from: "Based on [3] weeks {} here: {\"summary\":\"Practice th.\"}")
        #expect(report.summary == "Practice th.")
    }

    @Test func rejectsJSONThatIsNeitherCardsNorAReport() {
        #expect(throws: AIJSON.ParseError.self) { try AIJSON.cards(from: "[1, 2] {\"a\":1}") }
        #expect(throws: AIJSON.ParseError.self) { try AIJSON.coach(from: "[1] {}") }
    }

    @Test func rejectsProse() {
        #expect(throws: AIJSON.ParseError.self) { try AIJSON.cards(from: "Sorry, I can't.") }
    }

    @Test func readsCoachReportWithMissingFields() throws {
        let report = try AIJSON.coach(from: #"{"summary":"Good week.","weaknesses":["th sound"]}"#)
        #expect(report.summary == "Good week.")
        #expect(report.tips.isEmpty)
        #expect(report.cards.isEmpty)
    }
}
