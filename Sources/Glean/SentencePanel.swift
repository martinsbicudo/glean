import SwiftUI

struct SentencePanel: View {
    @StateObject private var ui = SentencePanelState()
    @FocusState private var focused: Bool
    let workspace: Workspace
    let card: Card
    var onTyping: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Use it in a sentence").font(.headline)
            if !workspace.tutor.isConnected {
                Text("Connect Claude Code or Codex in Settings to get your sentence checked.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                SettingsLink { Text("Open Settings…") }
            } else {
                TextField("Write a sentence with “\(card.term)”", text: $ui.sentence, axis: .vertical)
                    .lineLimit(1...4)
                    .onSubmit(check)
                    .focused($focused)
                    .onChange(of: focused) { onTyping(focused) }
                HStack {
                    Button("Check", action: check)
                        .disabled(ui.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ui.checking)
                    if ui.checking { ProgressView().controlSize(.small) }
                }
                if let result = ui.result { SentenceResult(result: result) }
                if let message = ui.failure { Text(message).font(.callout).foregroundStyle(.red) }
            }
        }
        .onChange(of: card.id) { ui.reset() }
    }

    private func check() {
        let text = ui.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !ui.checking else { return }
        ui.checking = true
        ui.failure = nil
        ui.result = nil
        let cardID = card.id
        let card = card
        let workspace = workspace
        Task {
            defer { ui.checking = false }
            do {
                let result = try await workspace.tutor.checkSentence(card: card, sentence: text)
                workspace.store.recordSentence(cardID, sentence: text, ok: result.ok)
                if cardID == self.card.id {
                    ui.result = result
                    focused = false
                }
            } catch {
                Log.write("sentence check failed: \(error.localizedDescription)")
                if cardID == self.card.id { ui.failure = error.localizedDescription }
            }
        }
    }
}

struct SentenceResult: View {
    let result: SentenceCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(result.ok ? "Looks right" : "Needs a fix", systemImage: result.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.headline)
                .foregroundStyle(result.ok ? .green : .orange)
            if !result.ok && !result.corrected.isEmpty {
                Text(result.corrected).textSelection(.enabled)
            }
            if !result.explanation.isEmpty { Text(result.explanation).foregroundStyle(.secondary) }
            if !result.better.isEmpty {
                Text("More natural").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(result.better, id: \.self) { Text("• \($0)").textSelection(.enabled) }
            }
        }
        .font(.callout)
    }
}

@MainActor
final class SentencePanelState: ObservableObject {
    @Published var sentence = ""
    @Published var checking = false
    @Published var result: SentenceCheck?
    @Published var failure: String?

    func reset() {
        sentence = ""
        result = nil
        failure = nil
    }
}
