import SwiftUI

struct ChatPanel: View {
    @StateObject private var ui = ChatPanelState()
    @FocusState private var focused: Bool
    let workspace: Workspace
    let card: Card
    var onTyping: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask the AI").font(.headline)
            if !workspace.tutor.isConnected {
                Text("Connect Claude Code or Codex in Settings to ask questions about this card.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                SettingsLink { Text("Open Settings…") }
            } else {
                ForEach(ui.turns) { turn in
                    Text(Self.rendered(turn.text))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(turn.role == .learner ? Brand.accent.opacity(0.14) : Color.secondary.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10))
                }
                if ui.thinking { ProgressView().controlSize(.small) }
                if let message = ui.failure { Text(message).font(.callout).foregroundStyle(.red) }
                if ui.turns.isEmpty { suggestions }
                HStack {
                    TextField("e.g. Can I use this in a formal email?", text: $ui.question, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit(send)
                        .focused($focused)
                        .onChange(of: focused) { onTyping(focused) }
                    Button("Ask", action: send)
                        .disabled(ui.question.trimmingCharacters(in: .whitespaces).isEmpty || ui.thinking)
                }
                if let last = ui.turns.last, last.role == .tutor {
                    Button("Save answer to card notes") { saveToNotes(last.text) }
                        .buttonStyle(.link)
                }
            }
        }
        .onChange(of: card.id) {
            ui.turns = []
            ui.failure = nil
        }
    }

    static func rendered(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private var suggestions: some View {
        FlowLayout(spacing: 6) {
            ForEach(["Give me 3 more examples", "What's the difference from similar words?", "Is it formal or informal?", "How do I pronounce it?"], id: \.self) { text in
                Button(text) {
                    ui.question = text
                    send()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func send() {
        let text = ui.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !ui.thinking else { return }
        let history = ui.turns
        ui.turns.append(ChatTurn(role: .learner, text: text))
        ui.question = ""
        ui.thinking = true
        ui.failure = nil
        let cardID = card.id
        Task {
            defer { ui.thinking = false }
            do {
                let answer = try await workspace.tutor.ask(about: card, history: history, question: text)
                if cardID == card.id { ui.turns.append(ChatTurn(role: .tutor, text: answer)) }
            } catch {
                ui.failure = error.localizedDescription
            }
        }
    }

    private func saveToNotes(_ text: String) {
        var updated = workspace.store.card(card.id) ?? card
        updated.notes = updated.notes.isEmpty ? text : updated.notes + "\n\n" + text
        workspace.store.update(updated)
    }
}

@MainActor
final class ChatPanelState: ObservableObject {
    @Published var turns: [ChatTurn] = []
    @Published var question = ""
    @Published var thinking = false
    @Published var failure: String?
}
