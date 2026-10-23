import Foundation
import Testing
@testable import Glean

struct StudyProgressTests {
    func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .current
        return calendar
    }

    var saoPaulo: Calendar { calendar("America/Sao_Paulo") }

    func at(_ day: Int, _ hour: Int, _ minute: Int = 0, in calendar: Calendar? = nil) -> Date {
        (calendar ?? saoPaulo).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? Date()
    }

    func entry(_ date: Date, _ rating: Rating? = .good) -> ReviewEntry {
        ReviewEntry(cardID: UUID(), date: date, rating: rating)
    }

    func space(_ name: String = "English", goal: Int = 20) -> Space {
        Space(name: name, target: "en-US", native: "pt-BR", dailyGoal: goal)
    }

    func progress(_ reviews: [ReviewEntry], now: Date, calendar: Calendar? = nil) -> StudyProgress {
        StudyProgress(spaces: [SpaceReviews(space: space(), reviews: reviews)], now: now, calendar: calendar ?? saoPaulo)
    }

    @Test func streakCountsConsecutiveDaysAcrossMidnight() {
        let reviews = [entry(at(19, 23, 59)), entry(at(20, 0, 1)), entry(at(21, 12)), entry(at(22, 8))]
        let result = progress(reviews, now: at(22, 20))
        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
        #expect(result.studiedToday)
    }

    @Test func todayNotStudiedYetKeepsStreakThroughYesterday() {
        let result = progress([entry(at(20, 10)), entry(at(21, 10))], now: at(22, 9))
        #expect(result.currentStreak == 2)
        #expect(!result.studiedToday)
    }

    @Test func missedYesterdayBreaksCurrentStreakButNotBest() {
        let reviews = [entry(at(15, 10)), entry(at(16, 10)), entry(at(17, 10)), entry(at(20, 10))]
        let result = progress(reviews, now: at(22, 9))
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 3)
    }

    @Test func gapsSplitStreaks() {
        let reviews = [entry(at(10, 10)), entry(at(11, 10)), entry(at(13, 10)), entry(at(14, 10)), entry(at(15, 10)), entry(at(16, 10)), entry(at(18, 10))]
        let result = progress(reviews, now: at(18, 12))
        #expect(result.currentStreak == 1)
        #expect(result.bestStreak == 4)
    }

    @Test func streakUsesAnyspace() {
        let spaces = [
            SpaceReviews(space: space("English"), reviews: [entry(at(20, 10)), entry(at(22, 10))]),
            SpaceReviews(space: space("Spanish"), reviews: [entry(at(21, 10))]),
        ]
        let result = StudyProgress(spaces: spaces, now: at(22, 12), calendar: saoPaulo)
        #expect(result.currentStreak == 3)
        #expect(result.last30Days().suffix(3).map(\.count) == [1, 1, 1])
    }

    @Test func timezoneDecidesWhichDayAReviewBelongsTo() {
        let instant = at(21, 23, 30)
        let now = at(22, 12)
        func result(_ zone: String) -> StudyProgress {
            StudyProgress(spaces: [SpaceReviews(space: space(), reviews: [entry(instant)])], now: now, calendar: calendar(zone))
        }
        #expect(!result("America/Sao_Paulo").studiedToday)
        #expect(result("UTC").studiedToday)
        #expect(!result("Asia/Tokyo").studiedToday)
        #expect(result("Asia/Tokyo").currentStreak == 1)
        #expect(result("UTC").currentStreak == 1)
    }

    @Test func goalProgressCountsTodayOfThisSpaceOnly() {
        let english = space("English", goal: 3)
        let spanish = space("Spanish", goal: 5)
        let spaces = [
            SpaceReviews(space: english, reviews: [entry(at(22, 8)), entry(at(22, 9)), entry(at(21, 9))]),
            SpaceReviews(space: spanish, reviews: [entry(at(22, 10))]),
        ]
        let result = StudyProgress(spaces: spaces, now: at(22, 12), calendar: saoPaulo)
        #expect(result.goal(for: english) == GoalProgress(done: 2, goal: 3))
        #expect(!result.goal(for: english).reached)
        #expect(result.goal(for: english).fraction > 0.66 && result.goal(for: english).fraction < 0.67)
        #expect(result.goal(for: spanish) == GoalProgress(done: 1, goal: 5))
        let reached = StudyProgress(spaces: [SpaceReviews(space: english, reviews: (0..<4).map { entry(at(22, $0 + 1)) })], now: at(22, 12), calendar: saoPaulo)
        #expect(reached.goal(for: english).reached)
        #expect(reached.goal(for: english).fraction == 1)
    }

    @Test func retentionCountsEverythingButAgainOverThirtyDays() {
        let reviews = [
            entry(at(22, 8), .good), entry(at(21, 8), .easy), entry(at(20, 8), .again), entry(at(19, 8), .hard),
            entry(at(1, 8), .good),
        ]
        let result = progress(reviews, now: at(22, 12))
        #expect(result.retentions.first?.reviews == 5)
        #expect(result.retentions.first?.percent == 80)
        let outside = StudyProgress(spaces: [SpaceReviews(space: space(), reviews: [entry(at(1, 8), .again)])], now: at(1, 8, in: saoPaulo).addingTimeInterval(31 * 86_400), calendar: saoPaulo)
        #expect(outside.retentions.first?.reviews == 0)
        #expect(outside.retentions.first?.percent == nil)
    }

    @Test func retentionIsPerSpace() {
        let english = space("English")
        let spanish = space("Spanish")
        let spaces = [
            SpaceReviews(space: english, reviews: [entry(at(22, 8), .good), entry(at(22, 9), .again)]),
            SpaceReviews(space: spanish, reviews: [entry(at(22, 8), .easy)]),
        ]
        let result = StudyProgress(spaces: spaces, now: at(22, 12), calendar: saoPaulo)
        #expect(result.retention(for: english.id)?.percent == 50)
        #expect(result.retention(for: spanish.id)?.percent == 100)
    }

    @Test func lastThirtyDaysIncludesEmptyDaysOldestFirst() {
        let reviews = [entry(at(22, 8)), entry(at(22, 9)), entry(at(10, 8)), entry(at(10, 8, 5))]
        let series = progress(reviews, now: at(22, 12)).last30Days()
        #expect(series.count == 30)
        #expect(series.last?.day == saoPaulo.startOfDay(for: at(22, 12)))
        #expect(series.last?.count == 2)
        #expect(series.first?.day == saoPaulo.startOfDay(for: at(22, 12, in: saoPaulo)).addingTimeInterval(-29 * 86_400))
        #expect(series.filter { $0.count == 0 }.count == 28)
        #expect(series.first { $0.day == saoPaulo.startOfDay(for: at(10, 8)) }?.count == 2)
    }

    @Test func seriesCanBeLimitedToOneSpace() {
        let english = space("English")
        let spanish = space("Spanish")
        let spaces = [
            SpaceReviews(space: english, reviews: [entry(at(22, 8))]),
            SpaceReviews(space: spanish, reviews: [entry(at(22, 8)), entry(at(22, 9))]),
        ]
        let result = StudyProgress(spaces: spaces, now: at(22, 12), calendar: saoPaulo)
        #expect(result.last30Days(in: english.id).last?.count == 1)
        #expect(result.last30Days(in: spanish.id).last?.count == 2)
        #expect(result.last30Days().last?.count == 3)
    }

    @Test func sentenceAndPronunciationEntriesAreNotReviews() {
        let sentence = ReviewEntry(cardID: UUID(), date: at(22, 8), sentence: "I gist it", sentenceOK: false)
        let spoken = ReviewEntry(cardID: UUID(), date: at(21, 8), pronunciationScore: 0.9, heard: "x")
        let result = progress([sentence, spoken], now: at(22, 12))
        #expect(result.currentStreak == 0)
        #expect(!result.studiedToday)
        #expect(result.goal(for: space()).done == 0)
        #expect(result.retentions.first?.reviews == 0)
        #expect(result.last30Days().allSatisfy { $0.count == 0 })
    }

    @Test func futureEntriesAreIgnored() {
        let result = progress([entry(at(25, 8))], now: at(22, 12))
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
    }

    @Test @MainActor func readingAllSpacesNeverWritesToThem() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SpaceStore(root: root, defaults: try TestSupport.isolatedDefaults())
        let first = try store.create(name: "English", target: "en-US", native: "pt-BR", level: .intermediate, dailyGoal: 5)
        let second = try store.create(name: "Spanish", target: "es-ES", native: "pt-BR", level: .beginner, dailyGoal: 5)
        let line = try String(data: JSONCoding.encoder(pretty: false).encode(entry(Date())), encoding: .utf8) ?? ""
        try TestSupport.write(line + "\nnot json\n", to: store.directory(for: first).appendingPathComponent("reviews.jsonl"))
        let before = try TestSupport.bytes(store.directory(for: first).appendingPathComponent("reviews.jsonl"))
        let snapshots = store.reviewSnapshots()
        #expect(snapshots.map(\.space.id) == [first.id, second.id])
        #expect(snapshots[0].reviews.count == 1)
        #expect(snapshots[1].reviews.isEmpty)
        #expect(try TestSupport.bytes(store.directory(for: first).appendingPathComponent("reviews.jsonl")) == before)
        #expect(!TestSupport.exists(store.directory(for: second).appendingPathComponent("reviews.jsonl")))
    }
}
