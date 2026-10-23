import Foundation

enum Rating: Int, Codable, CaseIterable, Identifiable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    var shortcut: Character { Character(String(rawValue)) }
}

enum Scheduler {
    static let minimumEase = 1.3
    static let relearnDelay: TimeInterval = 10 * 60
    static let day: TimeInterval = 24 * 60 * 60

    static func review(_ schedule: Schedule, rating: Rating, at now: Date = Date()) -> Schedule {
        var next = schedule
        next.lastReviewed = now
        switch rating {
        case .again:
            next.lapses += schedule.reps > 0 ? 1 : 0
            next.reps = 0
            next.interval = 0
            next.ease = max(minimumEase, schedule.ease - 0.2)
            next.due = now.addingTimeInterval(relearnDelay)
            return next
        case .hard:
            next.ease = max(minimumEase, schedule.ease - 0.15)
            next.interval = schedule.reps == 0 ? 1 : max(1, schedule.interval * 1.2)
        case .good:
            next.interval = switch schedule.reps {
            case 0: 1
            case 1: 3
            default: max(schedule.interval + 1, schedule.interval * schedule.ease)
            }
        case .easy:
            next.ease = schedule.ease + 0.15
            next.interval = switch schedule.reps {
            case 0: 4
            default: max(schedule.interval + 1, schedule.interval * schedule.ease * 1.3)
            }
        }
        next.interval = (next.interval * 10).rounded() / 10
        next.reps = schedule.reps + 1
        next.due = now.addingTimeInterval(next.interval * day)
        return next
    }

    static func preview(_ schedule: Schedule, rating: Rating, at now: Date = Date()) -> String {
        let seconds = review(schedule, rating: rating, at: now).due.timeIntervalSince(now)
        if seconds < 3600 { return "\(Int((seconds / 60).rounded())) min" }
        let days = seconds / day
        if days < 1 { return "\(Int((seconds / 3600).rounded())) h" }
        if days < 30 { return "\(Int(days.rounded())) d" }
        if days < 365 { return "\(Int((days / 30).rounded())) mo" }
        return String(format: "%.1f y", days / 365)
    }
}
