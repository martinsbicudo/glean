import Foundation
import Testing
@testable import Glean

struct RemindersTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return calendar
    }()

    func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? Date()
    }

    func card(_ term: String, due: Date) -> Card {
        var card = Card(term: term)
        card.schedule.due = due
        return card
    }

    func space(_ name: String, _ cards: [Card]) -> SpaceCards {
        SpaceCards(space: Space(name: name, target: "en-US", native: "pt-BR"), cards: cards)
    }

    @Test func aPlanFromAnEarlierDayIsReplanned() {
        #expect(!PlannedReminder.isStale(plannedAt: date(22, 0), now: date(22, 23), calendar: calendar))
        #expect(PlannedReminder.isStale(plannedAt: date(21, 23), now: date(22, 0), calendar: calendar))
        #expect(PlannedReminder.isStale(plannedAt: date(20, 12), now: date(22, 12), calendar: calendar))
    }

    @Test func remindsOnlyWhenCardsAreDue() {
        let cards = [card("pick up", due: date(22, 10)), card("gist", due: date(23, 15))]
        let plan = PlannedReminder.plan(spaces: [space("English", cards)], hours: [9, 14, 19], now: date(22, 12), days: 2, calendar: calendar)
        #expect(plan.map(\.date) == [date(22, 14), date(22, 19), date(23, 9), date(23, 14), date(23, 19)])
        #expect(plan.map(\.count) == [1, 1, 1, 1, 2])
        #expect(plan.last?.groups.first?.terms == ["pick up", "gist"])
    }

    @Test func nothingDueMeansNoReminders() {
        let plan = PlannedReminder.plan(spaces: [space("English", [card("gist", due: date(30, 9))])], hours: [9], now: date(22, 8), days: 3, calendar: calendar)
        #expect(plan.isEmpty)
    }

    @Test func bodyListsTermsAndHintsAtMore() {
        let reminder = PlannedReminder(date: Date(), groups: [.init(space: "English", count: 5, terms: ["a", "b", "c"])])
        #expect(reminder.title == "5 cards to review")
        #expect(reminder.body.hasPrefix("English: a, b, c…"))
    }

    @Test func planCoversAllSpacesAndNamesThem() {
        let english = space("English", [card("pick up", due: date(22, 10))])
        let spanish = space("Spanish", [card("hola", due: date(22, 9)), card("adiós", due: date(30, 9))])
        let empty = space("French", [])
        let plan = PlannedReminder.plan(spaces: [english, spanish, empty], hours: [14], now: date(22, 12), days: 1, calendar: calendar)
        #expect(plan.count == 1)
        #expect(plan[0].title == "2 cards to review")
        #expect(plan[0].groups.map(\.space) == ["English", "Spanish"])
        #expect(plan[0].body == "English: pick up; Spanish: hola. Open Glean to keep your streak.")
    }

    func progress(_ stamps: [Date], now: Date) -> StudyProgress {
        let reviews = stamps.map { ReviewEntry(cardID: UUID(), date: $0, rating: .good) }
        return StudyProgress(spaces: [SpaceReviews(space: Space(name: "English", target: "en-US", native: "pt-BR"), reviews: reviews)], now: now, calendar: calendar)
    }

    @Test func lastReminderTodayMentionsTheStreakWhenNothingWasStudied() {
        let spaces = [space("English", [card("gist", due: date(22, 8))])]
        let streak = progress([date(20, 10), date(21, 10)], now: date(22, 12))
        let plan = PlannedReminder.plan(spaces: spaces, hours: [14, 19], now: date(22, 12), days: 2, calendar: calendar, progress: streak)
        #expect(plan.map(\.streakDays) == [nil, 2, nil, nil])
        #expect(plan[1].body.contains("2-day streak"))
        #expect(!plan[0].body.contains("2-day streak"))
    }

    @Test func noStreakTextWhenStudiedTodayOrNoStreakToLose() {
        let spaces = [space("English", [card("gist", due: date(22, 8))])]
        let studied = progress([date(21, 10), date(22, 9)], now: date(22, 12))
        let none = progress([date(10, 10)], now: date(22, 12))
        for given in [studied, none] {
            let plan = PlannedReminder.plan(spaces: spaces, hours: [19], now: date(22, 12), days: 1, calendar: calendar, progress: given)
            #expect(plan.map(\.streakDays) == [nil])
            #expect(plan[0].body.hasSuffix("Open Glean to keep your streak."))
        }
        let plain = PlannedReminder.plan(spaces: spaces, hours: [19], now: date(22, 12), days: 1, calendar: calendar)
        #expect(plain.map(\.streakDays) == [nil])
    }
}
