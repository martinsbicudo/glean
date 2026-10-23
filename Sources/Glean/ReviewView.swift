import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @StateObject private var ui = ReviewViewState()
    let workspace: Workspace

    private var current: Card? { workspace.store.dueCards().first }

    var body: some View {
        VStack(spacing: 0) {
            GoalHeader(space: workspace.space, progress: model.progress)
            Divider()
            if let card = current {
                session(card)
            } else {
                DoneView(workspace: workspace, reviewed: ui.reviewedToday)
            }
        }
        .navigationTitle("Review")
        .navigationSubtitle(subtitle)
    }

    private var subtitle: String {
        let due = workspace.store.dueCards().count
        return due > 0 ? "\(workspace.space.name) · \(due) due" : workspace.space.name
    }

    private func session(_ card: Card) -> some View {
        HSplitView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        front(card).padding(.top, 36)
                        if ui.flipped {
                            if let verdict = ui.verdict {
                                AnswerResult(verdict: verdict, typed: ui.typed, term: card.term)
                            }
                            Divider()
                            CardDetails(card: card)
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                Divider()
                controls(card).padding(16)
            }
            .frame(minWidth: 460)
            if ui.flipped {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ChatPanel(workspace: workspace, card: card) { ui.askFocused = $0 }
                        Divider()
                        SentencePanel(workspace: workspace, card: card) { ui.sentenceFocused = $0 }
                        Divider()
                        PronunciationPanel(workspace: workspace, card: card)
                    }
                    .padding(20)
                }
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 440)
            }
        }
    }

    private func side(_ card: Card) -> ReviewSide { workspace.space.direction.side(for: card) }

    @ViewBuilder
    private func front(_ card: Card) -> some View {
        if side(card) == .recall {
            if ui.flipped {
                CardHeader(card: card)
            } else {
                RecallFront(card: card, typed: $ui.typed) { flip(card) }.id(card.id)
            }
        } else {
            CardHeader(card: card)
            if !ui.flipped {
                Text("Do you remember what it means? Say it in a sentence, then flip.").foregroundStyle(.secondary)
            }
        }
    }

    private func flip(_ card: Card) {
        let typed = ui.typed.trimmingCharacters(in: .whitespacesAndNewlines)
        ui.verdict = side(card) == .recall && !typed.isEmpty ? AnswerCheck.compare(typed: typed, expected: card.term) : nil
        ui.flipped = true
    }

    @ViewBuilder
    private func controls(_ card: Card) -> some View {
        if ui.flipped {
            HStack(spacing: 10) {
                ForEach(Rating.allCases) { rating in
                    Button { rate(card, rating) } label: {
                        VStack(spacing: 2) {
                            Text(rating.label).font(.headline)
                            Text(Scheduler.preview(card.schedule, rating: rating)).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint(rating))
                    .keyboardShortcut(ui.typing ? nil : KeyboardShortcut(KeyEquivalent(rating.shortcut), modifiers: []))
                    .help("Press \(rating.rawValue)")
                }
            }
        } else {
            Button { flip(card) } label: {
                Text("Show answer").font(.headline).frame(maxWidth: 320).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(side(card) == .recall ? .return : .space, modifiers: [])
        }
    }

    private func tint(_ rating: Rating) -> Color {
        switch rating {
        case .again: .red
        case .hard: .orange
        case .good: .green
        case .easy: Brand.accent
        }
    }

    private func rate(_ card: Card, _ rating: Rating) {
        workspace.store.review(card.id, rating: rating)
        ui.reviewedToday += 1
        ui.flipped = false
        ui.askFocused = false
        ui.sentenceFocused = false
        ui.typed = ""
        ui.verdict = nil
    }
}

struct DoneView: View {
    @Environment(AppModel.self) private var model
    let workspace: Workspace
    let reviewed: Int

    private var goal: GoalProgress { model.progress.goal(for: workspace.space) }

    private var celebration: some View {
        VStack(spacing: 4) {
            Label("Daily goal reached: \(goal.done) of \(goal.goal)", systemImage: "party.popper.fill")
                .font(.headline)
                .foregroundStyle(.green)
            if model.progress.currentStreak > 0 {
                Text("\(StreakText.days(model.progress.currentStreak)) in a row. Come back tomorrow to keep it going.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: workspace.store.cards.isEmpty ? "rectangle.stack.badge.plus" : goal.reached ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Brand.accent)
            if workspace.store.cards.isEmpty {
                Text("No cards yet").font(.title2.weight(.semibold))
                Text("Create cards with AI or add them by hand.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Add with AI") { model.section = .add }
                        .buttonStyle(.borderedProminent)
                    Button("Add by hand") { model.section = .cards }
                }
            } else {
                Text(reviewed > 0 ? "All done for now. \(reviewed) reviewed." : "Nothing to review right now")
                    .font(.title2.weight(.semibold))
                if goal.reached { celebration }
                if let next = workspace.store.cards.map(\.schedule.due).min() {
                    Text("Next card \(next, format: .relative(presentation: .named)).").foregroundStyle(.secondary)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class ReviewViewState: ObservableObject {
    @Published var flipped = false
    @Published var askFocused = false
    @Published var sentenceFocused = false

    var typing: Bool { askFocused || sentenceFocused }
    @Published var typed = ""
    @Published var verdict: AnswerVerdict?
    @Published var reviewedToday = 0
}
