import Foundation
import UserNotifications

struct PlannedReminder: Equatable {
    struct Group: Equatable {
        let space: String
        let count: Int
        let terms: [String]
    }

    let date: Date
    let groups: [Group]
    var streakDays: Int?

    var count: Int { groups.reduce(0) { $0 + $1.count } }
    var title: String { count == 1 ? "1 card to review" : "\(count) cards to review" }
    var body: String {
        let list = groups.map { group in
            "\(group.space): \(group.terms.joined(separator: ", "))" + (group.count > group.terms.count ? "…" : "")
        }.joined(separator: "; ")
        let tail = streakDays.map { " Nothing studied today yet: study now to keep your \($0)-day streak." } ?? " Open Glean to keep your streak."
        return (list.hasSuffix("…") ? list : list + ".") + tail
    }

    static func plan(spaces: [SpaceCards], hours: [Int], now: Date, days: Int = 7, calendar: Calendar = .current, progress: StudyProgress? = nil) -> [PlannedReminder] {
        let start = calendar.startOfDay(for: now)
        let lastHour = hours.max()
        var result: [PlannedReminder] = []
        for day in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: day, to: start) else { continue }
            for hour in hours.sorted() {
                guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart), date > now else { continue }
                let groups = spaces.compactMap { group(for: $0, at: date) }
                guard !groups.isEmpty else { continue }
                let atRisk = day == 0 && hour == lastHour && progress?.studiedToday == false
                let streak = atRisk ? progress?.currentStreak : nil
                result.append(PlannedReminder(date: date, groups: groups, streakDays: streak.flatMap { $0 > 0 ? $0 : nil }))
            }
        }
        return result
    }

    static func isStale(plannedAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        !calendar.isDate(plannedAt, inSameDayAs: now)
    }

    private static func group(for space: SpaceCards, at date: Date) -> Group? {
        let due = space.cards.filter { $0.isDue(at: date) }.sorted { $0.schedule.due < $1.schedule.due }
        return due.isEmpty ? nil : Group(space: space.space.name, count: due.count, terms: due.prefix(3).map(\.term))
    }
}

final class Reminders: NSObject, UNUserNotificationCenterDelegate {
    static let prefix = "glean-reminder-"
    var onOpen: (() -> Void)?

    func activate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error { Log.write("notification authorization failed: \(error)") }
        }
    }

    func reschedule(_ plan: [PlannedReminder]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for reminder in plan {
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = reminder.body
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                let id = Self.prefix + String(Int(reminder.date.timeIntervalSince1970))
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let open = onOpen
        DispatchQueue.main.async { open?() }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
