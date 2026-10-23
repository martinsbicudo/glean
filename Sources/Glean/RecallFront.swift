import SwiftUI

struct RecallFront: View {
    let card: Card
    @Binding var typed: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("RECALL THE \(card.kind.label.uppercased())")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            if !card.translations.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(card.translations, id: \.self) { item in
                        Text(item)
                            .font(.title3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Brand.accent.opacity(0.14), in: Capsule())
                    }
                }
            }
            if !card.meaning.isEmpty { Text(card.meaning).multilineTextAlignment(.center) }
            if let example = Cloze.example(for: card) {
                Text(example).italic().foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            TextField("Type it (optional)", text: $typed)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
                .focused($focused)
                .onSubmit(onSubmit)
        }
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
    }
}

struct AnswerResult: View {
    let verdict: AnswerVerdict
    let typed: String
    let term: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(color)
            .textSelection(.enabled)
    }

    private var text: String {
        switch verdict {
        case .correct: "Correct"
        case .close: "Close: you wrote “\(typed)”"
        case .wrong: "Not quite: you wrote “\(typed)”, it is “\(term)”"
        }
    }

    private var symbol: String {
        switch verdict {
        case .correct: "checkmark.circle.fill"
        case .close: "equal.circle.fill"
        case .wrong: "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch verdict {
        case .correct: .green
        case .close: .orange
        case .wrong: .red
        }
    }
}
