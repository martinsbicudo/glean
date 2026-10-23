import Foundation

struct SpaceReviews {
    let space: Space
    let reviews: [ReviewEntry]
}

struct DayCount: Equatable, Identifiable {
    let day: Date
    let count: Int

    var id: Date { day }
}

struct SpaceRetention: Equatable, Identifiable {
    let spaceID: UUID
    let name: String
    let reviews: Int
    let remembered: Int

    var id: UUID { spaceID }
    var percent: Int? { reviews == 0 ? nil : Int((Double(remembered) * 100 / Double(reviews)).rounded()) }
}

struct GoalProgress: Equatable {
    let done: Int
    let goal: Int

    var reached: Bool { done >= goal }
    var fraction: Double { goal <= 0 ? 0 : min(1, Double(done) / Double(goal)) }
}

struct StudyProgress: Equatable {
    static let windowDays = 30

    let today: Date
    let currentStreak: Int
    let bestStreak: Int
    let studiedToday: Bool
    let retentions: [SpaceRetention]
    private let counts: [UUID: [Date: Int]]
    private let calendar: Calendar

    static let empty = StudyProgress(spaces: [], now: Date())

    init(spaces: [SpaceReviews], now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: 1 - Self.windowDays, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        var counts: [UUID: [Date: Int]] = [:]
        var retentions: [SpaceRetention] = []
        for entry in spaces {
            var days: [Date: Int] = [:]
            var recent = 0
            var remembered = 0
            for review in entry.reviews {
                guard let rating = review.rating, review.date < tomorrow else { continue }
                days[calendar.startOfDay(for: review.date), default: 0] += 1
                guard review.date >= windowStart else { continue }
                recent += 1
                if rating != .again { remembered += 1 }
            }
            counts[entry.space.id] = days
            retentions.append(SpaceRetention(spaceID: entry.space.id, name: entry.space.name, reviews: recent, remembered: remembered))
        }
        let studied = Set(counts.values.flatMap { $0.keys })
        self.today = today
        self.calendar = calendar
        self.counts = counts
        self.retentions = retentions
        studiedToday = studied.contains(today)
        currentStreak = Self.currentStreak(studied, today: today, calendar: calendar)
        bestStreak = Self.bestStreak(studied, calendar: calendar)
    }

    func reviewed(in id: UUID) -> Int { counts[id]?[today] ?? 0 }

    func goal(for space: Space) -> GoalProgress { GoalProgress(done: reviewed(in: space.id), goal: space.dailyGoal) }

    func last30Days(in id: UUID? = nil) -> [DayCount] {
        (0..<Self.windowDays).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = id.map { counts[$0]?[day] ?? 0 } ?? counts.values.reduce(0) { $0 + ($1[day] ?? 0) }
            return DayCount(day: day, count: total)
        }
    }

    func retention(for id: UUID) -> SpaceRetention? { retentions.first { $0.spaceID == id } }

    private static func currentStreak(_ days: Set<Date>, today: Date, calendar: Calendar) -> Int {
        var day = today
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private static func bestStreak(_ days: Set<Date>, calendar: Calendar) -> Int {
        var best = 0
        for day in days {
            guard let before = calendar.date(byAdding: .day, value: -1, to: day), !days.contains(before) else { continue }
            var length = 1
            var cursor = day
            while let after = calendar.date(byAdding: .day, value: 1, to: cursor), days.contains(after) {
                length += 1
                cursor = after
            }
            best = max(best, length)
        }
        return best
    }
}
