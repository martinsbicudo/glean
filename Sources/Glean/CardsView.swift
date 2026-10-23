import SwiftUI

struct CardsView: View {
    @Environment(AppModel.self) private var model
    @StateObject private var ui = CardsViewState()
    let workspace: Workspace

    private var filtered: [Card] {
        let key = Card.normalize(ui.query)
        return workspace.store.cards
            .filter { ui.kind == nil || $0.kind == ui.kind }
            .filter { key.isEmpty || $0.normalizedTerm.contains(key) || $0.translations.contains { Card.normalize($0).contains(key) } }
            .sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }

    var body: some View {
        HSplitView {
            List(filtered, selection: $ui.selection) { card in
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.term).font(.body.weight(.medium))
                    Text(card.translations.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .tag(card.id)
                .contextMenu {
                    Button("Edit…") { ui.editing = card }
                    Button("Delete", role: .destructive) { workspace.store.delete([card.id]) }
                }
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            .searchable(text: $ui.query, placement: .sidebar, prompt: "Search cards or translations")

            Group {
                if let id = ui.selection, let card = workspace.store.card(id) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            CardHeader(card: card).frame(maxWidth: .infinity)
                            CardDetails(card: card)
                            ScheduleLine(card: card)
                            Divider()
                            ChatPanel(workspace: workspace, card: card)
                            Divider()
                            PronunciationPanel(workspace: workspace, card: card)
                        }
                        .padding(28)
                        .frame(maxWidth: 720, alignment: .leading)
                    }
                } else {
                    Text(workspace.store.cards.isEmpty ? "No cards yet" : "Select a card")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard model.newCardRequested else { return }
            model.newCardRequested = false
            ui.editing = Card(term: "")
        }
        .navigationTitle("Cards")
        .navigationSubtitle("\(workspace.space.name) · \(workspace.store.cards.count) cards")
        .toolbar {
            Picker("Kind", selection: $ui.kind) {
                Text("All kinds").tag(CardKind?.none)
                ForEach(CardKind.allCases) { Text($0.label).tag(CardKind?.some($0)) }
            }
            Button { ui.editing = Card(term: "") } label: { Label("New Card", systemImage: "plus") }
                .keyboardShortcut("n")
            if let id = ui.selection, let card = workspace.store.card(id) {
                Button { ui.editing = card } label: { Label("Edit", systemImage: "pencil") }
                    .keyboardShortcut("e")
            }
        }
        .sheet(item: $ui.editing) { card in
            CardEditor(card: card, tutor: workspace.tutor) { saved in
                if workspace.store.card(saved.id) != nil {
                    workspace.store.update(saved)
                } else {
                    workspace.store.add([saved])
                }
                ui.selection = saved.id
            }
        }
    }
}

struct ScheduleLine: View {
    let card: Card

    var body: some View {
        HStack(spacing: 16) {
            Label {
                Text(card.isDue() ? "Due now" : "Due \(card.schedule.due, format: .relative(presentation: .named))")
            } icon: { Image(systemName: "calendar") }
            Label("\(card.schedule.reps) in a row", systemImage: "checkmark")
            Label("\(card.schedule.lapses) forgotten", systemImage: "arrow.uturn.backward")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

@MainActor
final class CardsViewState: ObservableObject {
    @Published var query = ""
    @Published var kind: CardKind?
    @Published var selection: UUID?
    @Published var editing: Card?
}
