import SwiftUI

struct CardHeader: View {
    @Environment(AppModel.self) private var model
    let card: Card

    var body: some View {
        VStack(spacing: 10) {
            Text(card.kind.label.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(card.term)
                .font(.system(size: 34, weight: .semibold))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            HStack(spacing: 12) {
                if !card.pronunciation.isEmpty {
                    Text(card.pronunciation).font(.title3).foregroundStyle(.secondary)
                }
                Button { model.speaker.say(card.term, locale: model.speechLocale) } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .help("Listen")
                Button { model.speaker.say(card.term, locale: model.speechLocale, slow: true) } label: {
                    Image(systemName: "tortoise.fill")
                }
                .help("Listen slowly")
            }
            .buttonStyle(.borderless)
        }
    }
}

struct CardDetails: View {
    @Environment(AppModel.self) private var model
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !card.translations.isEmpty {
                block("Translations") {
                    FlowLayout(spacing: 6) {
                        ForEach(card.translations, id: \.self) { item in
                            Text(item)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Brand.accent.opacity(0.14), in: Capsule())
                        }
                    }
                }
            }
            if !card.meaning.isEmpty { block("Meaning") { Text(card.meaning) } }
            if !card.definition.isEmpty { block("Definition") { Text(card.definition) } }
            if !card.examples.isEmpty {
                block("Examples") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(card.examples.enumerated()), id: \.offset) { index, example in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                                Text(example).frame(maxWidth: .infinity, alignment: .leading)
                                Button { model.speaker.say(example, locale: model.speechLocale) } label: {
                                    Image(systemName: "speaker.wave.1")
                                }
                                .buttonStyle(.borderless)
                                .help("Listen")
                            }
                        }
                    }
                }
            }
            if !card.source.isEmpty {
                block("Where you heard it") { Text("“\(card.source)”").italic().foregroundStyle(.secondary) }
            }
            if !card.notes.isEmpty { block("Notes") { Text(card.notes) } }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in rows.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], width: CGFloat, height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (points, maxX, y + rowHeight)
    }
}
