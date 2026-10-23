import SwiftUI

struct CardEditor: View {
    @StateObject private var ui: CardEditorState
    let tutor: Tutor
    @Environment(\.dismiss) private var dismiss
    let onSave: (Card) -> Void

    init(card: Card, tutor: Tutor, onSave: @escaping (Card) -> Void) {
        _ui = StateObject(wrappedValue: CardEditorState(card: card))
        self.tutor = tutor
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Word, phrasal verb or sentence", text: $ui.card.term)
                Picker("Kind", selection: $ui.card.kind) {
                    ForEach(CardKind.allCases) { Text($0.label).tag($0) }
                }
                TextField("Translations (comma separated)", text: $ui.translations)
                TextField("Meaning (in your language)", text: $ui.card.meaning, axis: .vertical).lineLimit(2...4)
                TextField("Definition (simple, in the language you study)", text: $ui.card.definition, axis: .vertical).lineLimit(1...3)
                TextField("Pronunciation (IPA)", text: $ui.card.pronunciation)
                LabeledContent("Examples (one per line)") {
                    TextEditor(text: $ui.examples).font(.body).frame(minHeight: 110)
                }
                TextField("Where you heard it", text: $ui.card.source, axis: .vertical).lineLimit(1...3)
                TextField("Notes", text: $ui.card.notes, axis: .vertical).lineLimit(1...4)
                TextField("Tags (comma separated)", text: $ui.tags)
            }
            .formStyle(.grouped)
            if let message = ui.failure { Text(message).foregroundStyle(.red).font(.callout).padding(.horizontal) }
            HStack {
                Button(action: fill) {
                    Label(ui.filling ? "Completing…" : "Complete with AI", systemImage: "sparkles")
                }
                .disabled(ui.filling || ui.card.term.trimmingCharacters(in: .whitespaces).isEmpty || !tutor.isConnected)
                .help(tutor.isConnected ? "Fill in translations, meaning, IPA and examples" : "Connect Claude Code or Codex in Settings")
                if ui.filling { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(collected())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(ui.card.term.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 560, height: 640)
        .onAppear(perform: load)
    }

    private func load() {
        ui.translations = ui.card.translations.joined(separator: ", ")
        ui.examples = ui.card.examples.joined(separator: "\n")
        ui.tags = ui.card.tags.joined(separator: ", ")
    }

    private func collected() -> Card {
        var result = ui.card
        result.term = ui.card.term.trimmingCharacters(in: .whitespacesAndNewlines)
        result.translations = Self.list(ui.translations, separator: ",")
        result.examples = Self.list(ui.examples, separator: "\n")
        result.tags = Self.list(ui.tags, separator: ",").map { $0.lowercased() }
        return result
    }

    static func list(_ text: String, separator: Character) -> [String] {
        text.split(separator: separator).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func fill() {
        ui.filling = true
        ui.failure = nil
        let draft = collected()
        Task {
            defer { ui.filling = false }
            do {
                ui.card = try await tutor.fill(draft)
                load()
            } catch {
                ui.failure = error.localizedDescription
            }
        }
    }
}

@MainActor
final class CardEditorState: ObservableObject {
    @Published var card: Card
    @Published var translations = ""
    @Published var examples = ""
    @Published var tags = ""
    @Published var filling = false
    @Published var failure: String?

    init(card: Card) {
        self.card = card
    }
}
