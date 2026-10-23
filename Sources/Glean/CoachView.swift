import SwiftUI

struct CoachView: View {
    @Environment(AppModel.self) private var model
    @StateObject private var ui = CoachViewState()
    let workspace: Workspace

    private var stats: [UUID: CardStats] { workspace.store.stats() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                overview
                ProgressSection(space: workspace.space, progress: model.progress)
                hardest
                report
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Coach")
        .navigationSubtitle(workspace.space.name)
    }

    private var overview: some View {
        let reviews = workspace.store.reviews.filter { $0.rating != nil }
        let week = reviews.filter { Date().timeIntervalSince($0.date) < 7 * Scheduler.day }
        let remembered = week.filter { ($0.rating ?? .again) != .again }.count
        let pronunciation = workspace.store.reviews.compactMap(\.pronunciationScore)
        return HStack(spacing: 14) {
            Tile(value: "\(workspace.store.cards.count)", label: "cards")
            Tile(value: "\(workspace.store.dueCards().count)", label: "due now")
            Tile(value: "\(week.count)", label: "reviews this week")
            Tile(value: week.isEmpty ? "–" : "\(remembered * 100 / week.count)%", label: "remembered")
            Tile(value: pronunciation.isEmpty ? "–" : "\(Int(pronunciation.reduce(0, +) / Double(pronunciation.count) * 100))%", label: "understood when speaking")
        }
    }

    private var hardest: some View {
        let list = workspace.store.cards
            .compactMap { card in stats[card.id].map { (card, $0) } }
            .filter { $0.1.struggleRate > 0 }
            .sorted { $0.1.struggleRate > $1.1.struggleRate }
            .prefix(8)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Hardest for you").font(.title3.weight(.semibold))
            if list.isEmpty {
                Text("Review a few cards and mark the hard ones honestly. They will show up here.").foregroundStyle(.secondary)
            }
            ForEach(Array(list), id: \.0.id) { card, stat in
                HStack {
                    Text(card.term).font(.body.weight(.medium))
                    Spacer()
                    Text("\(stat.again) forgotten · \(stat.hard) hard · \(stat.reviews) reviews").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var report: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("What to work on").font(.title3.weight(.semibold))
                Spacer()
                if ui.working { ProgressView().controlSize(.small) }
                Button(action: analyze) { Label("Analyze with AI", systemImage: "sparkles") }
                    .disabled(ui.working || !workspace.tutor.isConnected || workspace.store.reviews.isEmpty)
                    .help(workspace.tutor.isConnected ? "Send your study stats to the AI and get a plan" : "Connect Claude Code or Codex in Settings")
            }
            if let message = ui.failure { Text(message).foregroundStyle(.red) }
            if let latest = workspace.insights.latest {
                if let date = latest.date {
                    Text("Last analysis \(date, format: .relative(presentation: .named)). The AI uses it when it answers your questions and writes new cards.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(latest.summary).textSelection(.enabled)
                bullets("Weak spots", latest.weaknesses)
                bullets("Tips", latest.tips)
                if !latest.cards.isEmpty { suggestions(latest.cards) }
            } else {
                Text("After some reviews, ask the AI to look at what you forget and what you mispronounce. It suggests what to practise and new cards for your weak spots.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bullets(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !items.isEmpty {
                Text(title).font(.headline)
                ForEach(items, id: \.self) { Text("• \($0)").textSelection(.enabled) }
            }
        }
    }

    private func suggestions(_ drafts: [CardDraft]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Suggested cards").font(.headline)
                Spacer()
                Button("Add All") {
                    workspace.store.add(drafts.map { $0.card() })
                    drafts.forEach { workspace.insights.removeSuggestion($0.term) }
                }
            }
            ForEach(drafts, id: \.term) { draft in
                HStack {
                    Text(draft.term).font(.body.weight(.medium))
                    Text((draft.translations ?? []).prefix(2).joined(separator: ", ")).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button("Add") {
                        workspace.store.add([draft.card()])
                        workspace.insights.removeSuggestion(draft.term)
                    }
                }
            }
        }
    }

    private func analyze() {
        ui.working = true
        ui.failure = nil
        Task {
            defer { ui.working = false }
            do {
                _ = try await workspace.tutor.coach()
            } catch {
                ui.failure = error.localizedDescription
            }
        }
    }
}

struct Tile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
final class CoachViewState: ObservableObject {
    @Published var working = false
    @Published var failure: String?
}
