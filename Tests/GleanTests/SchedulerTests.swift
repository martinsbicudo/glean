import Foundation
import Testing
@testable import Glean

struct SchedulerTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func newCardGoodComesBackTomorrow() {
        let next = Scheduler.review(.new(at: now), rating: .good, at: now)
        #expect(next.interval == 1)
        #expect(next.reps == 1)
        #expect(next.due == now.addingTimeInterval(Scheduler.day))
    }

    @Test func goodTwiceThenGrowsByEase() {
        var schedule = Scheduler.review(.new(at: now), rating: .good, at: now)
        schedule = Scheduler.review(schedule, rating: .good, at: now)
        #expect(schedule.interval == 3)
        schedule = Scheduler.review(schedule, rating: .good, at: now)
        #expect(schedule.interval == 7.5)
    }

    @Test func againRelearnsInTenMinutesAndCountsALapse() {
        var schedule = Scheduler.review(.new(at: now), rating: .good, at: now)
        schedule = Scheduler.review(schedule, rating: .again, at: now)
        #expect(schedule.due == now.addingTimeInterval(600))
        #expect(schedule.reps == 0)
        #expect(schedule.lapses == 1)
        #expect(schedule.ease == 2.3)
    }

    @Test func againOnANewCardIsNotALapse() {
        let schedule = Scheduler.review(.new(at: now), rating: .again, at: now)
        #expect(schedule.lapses == 0)
    }

    @Test func easeNeverDropsBelowMinimum() {
        var schedule = Schedule.new(at: now)
        for _ in 0..<20 { schedule = Scheduler.review(schedule, rating: .again, at: now) }
        #expect(schedule.ease == Scheduler.minimumEase)
    }

    @Test func easyGivesLongerIntervalThanGood() {
        let start = Scheduler.review(Scheduler.review(.new(at: now), rating: .good, at: now), rating: .good, at: now)
        let good = Scheduler.review(start, rating: .good, at: now)
        let easy = Scheduler.review(start, rating: .easy, at: now)
        let hard = Scheduler.review(start, rating: .hard, at: now)
        #expect(hard.interval < good.interval)
        #expect(good.interval < easy.interval)
    }

    @Test func previewLabels() {
        let schedule = Schedule.new(at: now)
        #expect(Scheduler.preview(schedule, rating: .again, at: now) == "10 min")
        #expect(Scheduler.preview(schedule, rating: .good, at: now) == "1 d")
        #expect(Scheduler.preview(schedule, rating: .easy, at: now) == "4 d")
    }
}
