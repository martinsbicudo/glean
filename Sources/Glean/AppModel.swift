import AppKit
import Observation

enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case review, cards, add, coach

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review: "Review"
        case .cards: "Cards"
        case .add: "Add with AI"
        case .coach: "Coach"
        }
    }

    var symbol: String {
        switch self {
        case .review: "rectangle.stack"
        case .cards: "list.bullet.rectangle"
        case .add: "sparkles"
        case .coach: "chart.line.uptrend.xyaxis"
        }
    }
}

struct Workspace {
    let space: Space
    let store: CardStore
    let insights: InsightsStore
    let tutor: Tutor
}

enum SpaceSheetTarget: Identifiable {
    case new
    case edit(Space)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let space): space.id.uuidString
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let spaces: SpaceStore
    let speaker = Speaker()
    let reminders = Reminders()
    var section: AppSection = .review
    var sheet: SpaceSheetTarget?
    var spaceError: String?
    var newCardRequested = false
    private(set) var store: CardStore?
    private(set) var insights: InsightsStore?
    private(set) var dueCount = 0
    private(set) var spaceDue: [SpaceDue] = []
    private(set) var progress = StudyProgress.empty
    private var boundID: UUID?
    private var addChats: [UUID: AddChatState] = [:]
    private var timer: Timer?
    private var plannedAt = Date()

    var workspace: Workspace? {
        guard case .ready(let space) = spaces.state, boundID == space.id, let store, let insights else { return nil }
        return Workspace(space: space, store: store, insights: insights, tutor: Tutor(settings: settings, space: space, store: store, insights: insights))
    }

    var speechLocale: String { spaces.selected?.target ?? "en-US" }

    var currentDue: Int { store?.dueCards().count ?? 0 }

    var alertMessage: String? {
        spaceError ?? spaces.state.message ?? store?.lastError
    }

    var alertFolder: URL {
        store?.lastError != nil ? (store?.directory ?? spaces.root) : spaces.root
    }

    init(spaces: SpaceStore, settings: AppSettings) {
        self.spaces = spaces
        self.settings = settings
        bind()
        reminders.onOpen = { [weak self] in self?.openReview() }
        reminders.activate()
        DispatchQueue.main.async { [weak self] in self?.refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard !PlannedReminder.isStale(plannedAt: plannedAt, now: Date()) else { return refresh() }
        updateDue(spaces.snapshots())
        progress = StudyProgress(spaces: spaces.reviewSnapshots(), now: Date())
    }

    func refresh() {
        let snapshots = spaces.snapshots()
        updateDue(snapshots)
        let now = Date()
        plannedAt = now
        progress = StudyProgress(spaces: spaces.reviewSnapshots(), now: now)
        let plan = settings.remindersOn
            ? PlannedReminder.plan(spaces: snapshots, hours: settings.reminderHours, now: now, progress: progress)
            : []
        reminders.reschedule(plan)
    }

    func reload() {
        spaceError = nil
        spaces.reload()
        bind()
        store?.load()
        refresh()
    }

    func createSpace(name: String, target: String, native: String, level: Level, dailyGoal: Int, direction: ReviewDirection) throws {
        defer { spacesChanged() }
        try spaces.create(name: name, target: target, native: native, level: level, dailyGoal: dailyGoal, direction: direction)
    }

    func updateSpace(_ space: Space) throws {
        defer { spacesChanged() }
        try spaces.update(space)
    }

    func selectSpace(_ id: UUID) {
        change { try spaces.select(id) }
    }

    func deleteSpace(_ id: UUID) {
        change { try spaces.delete(id) }
    }

    func addChat(for space: Space) -> AddChatState {
        if let state = addChats[space.id] { return state }
        let state = AddChatState()
        addChats[space.id] = state
        return state
    }

    func requestNewCard() {
        newCardRequested = true
        section = .cards
    }

    func openReview() {
        section = .review
        if currentDue == 0, let next = spaceDue.first(where: { $0.due > 0 }) { selectSpace(next.space.id) }
        NSWorkspace.shared.open(Bundle.main.bundleURL)
        NSApp.activate()
    }

    private func change(_ action: () throws -> Void) {
        defer { spacesChanged() }
        do {
            try action()
            spaceError = nil
        } catch {
            Log.write("space change failed: \(error.localizedDescription)")
            spaceError = error.localizedDescription
        }
    }

    private func spacesChanged() {
        bind()
        refresh()
    }

    private func bind() {
        guard case .ready(let space) = spaces.state else {
            store = nil
            insights = nil
            boundID = nil
            return
        }
        guard boundID != space.id else { return }
        let directory = spaces.directory(for: space)
        let newStore = CardStore(directory: directory)
        newStore.onChange = { [weak self] in self?.refresh() }
        store = newStore
        insights = InsightsStore(directory: directory)
        boundID = space.id
    }

    private func updateDue(_ snapshots: [SpaceCards]) {
        spaceDue = snapshots.map { $0.due() }
        dueCount = spaceDue.reduce(0) { $0 + $1.due }
        NSApplication.shared.dockTile.badgeLabel = dueCount > 0 ? "\(dueCount)" : nil
    }
}
