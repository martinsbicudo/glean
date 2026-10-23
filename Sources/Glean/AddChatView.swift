import SwiftUI

struct AddChatView: View {
    @Environment(AppModel.self) private var model
    let workspace: Workspace
    @ObservedObject var ui: AddChatState

    private let suggestions = ["10 useful expressions for travel", "Words for ordering food", "Phrases to sound polite at work"]

    var body: some View {
        Group {
            if workspace.tutor.isConnected { chat } else { manual }
        }
        .navigationTitle("Add with AI")
        .navigationSubtitle(workspace.space.name)
    }

    private var manual: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles").font(.system(size: 48)).foregroundStyle(Brand.accent)
            Text("Connect an AI to chat for cards").font(.title2.weight(.semibold))
            Text("Choose Claude Code or Codex in Settings, then ask for cards here: a topic, a pasted text, or a change to a card you were shown. Until then you can add cards by hand.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            HStack {
                SettingsLink { Text("Open Settings…") }
                Button("New Card") { model.requestNewCard() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if ui.turns.isEmpty { intro }
                        ForEach(ui.turns) { turn in
                            TurnView(turn: turn, ui: ui, workspace: workspace).id(turn.id)
                        }
                        if ui.thinking { ProgressView().controlSize(.small).id("thinking") }
                        if let message = ui.failure { Text(message).foregroundStyle(.red) }
                    }
                    .padding(20)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: ui.turns.count) { proxy.scrollTo(ui.turns.last?.id, anchor: .bottom) }
            }
            Divider()
            inputBar.padding(14)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What do you want to learn?").font(.title3.weight(.semibold))
            Text("Ask for cards for \(workspace.space.targetLanguage.languageName): a topic, a pasted text, or changes like “make #3 easier”. You choose which cards to add.")
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(suggestions, id: \.self) { text in
                    Button(text) { send(text) }.buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom) {
            TextField("Ask for cards, or paste a text…", text: $ui.draft, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.roundedBorder)
                .onSubmit { send(ui.draft) }
            Button("Send") { send(ui.draft) }
                .buttonStyle(.borderedProminent)
                .disabled(ui.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ui.thinking)
            if !ui.turns.isEmpty {
                Button("New Chat") { ui.reset() }.disabled(ui.thinking)
            }
        }
    }

    private func send(_ text: String) {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !ui.thinking else { return }
        let history = ui.turns
        ui.turns.append(AddTurn(role: .learner, text: request))
        ui.draft = ""
        ui.thinking = true
        ui.failure = nil
        let tutor = workspace.tutor
        Task {
            defer { ui.thinking = false }
            do {
                ui.turns.append(try await tutor.addChat(history: history, request: request))
            } catch {
                Log.write("add chat failed: \(error.localizedDescription)")
                ui.failure = error.localizedDescription
            }
        }
    }
}

struct TurnView: View {
    let turn: AddTurn
    @ObservedObject var ui: AddChatState
    let workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ChatPanel.rendered(turn.text))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(turn.role == .learner ? Brand.accent.opacity(0.14) : Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 10))
            if !turn.cards.isEmpty { cards }
        }
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(turn.cards.enumerated()), id: \.element.id) { index, card in
                DisclosureGroup {
                    CardDetails(card: card).padding(.vertical, 6)
                } label: {
                    Toggle(isOn: Binding(
                        get: { turn.selected.contains(card.id) },
                        set: { ui.select(card.id, on: $0, in: turn.id) }
                    )) {
                        HStack {
                            Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                            Text(card.term).font(.body.weight(.medium))
                            Text(card.kind.label).font(.caption).foregroundStyle(.secondary)
                            Text(card.translations.prefix(2).joined(separator: ", ")).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .disabled(turn.added > 0)
                }
            }
            if turn.added > 0 {
                Label("Added \(turn.added) cards. They're ready in Review.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(turn.selected.count == 1 ? "Add 1 card" : "Add \(turn.selected.count) cards") {
                    ui.add(turn.id, to: workspace.store)
                }
                .buttonStyle(.borderedProminent)
                .disabled(turn.selected.isEmpty)
            }
        }
        .padding(.leading, 6)
    }
}

@MainActor
final class AddChatState: ObservableObject {
    @Published var turns: [AddTurn] = []
    @Published var draft = ""
    @Published var thinking = false
    @Published var failure: String?

    func reset() {
        turns = []
        failure = nil
    }

    func select(_ cardID: UUID, on: Bool, in turnID: UUID) {
        guard let index = turns.firstIndex(where: { $0.id == turnID }) else { return }
        if on { turns[index].selected.insert(cardID) } else { turns[index].selected.remove(cardID) }
    }

    func add(_ turnID: UUID, to store: CardStore) {
        guard let index = turns.firstIndex(where: { $0.id == turnID }) else { return }
        let chosen = turns[index].cards.filter { turns[index].selected.contains($0.id) }
        turns[index].added = store.add(chosen)
    }
}
