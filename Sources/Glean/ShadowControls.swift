import SwiftUI

struct ShadowControls: View {
    @ObservedObject var session: ShadowSession

    var body: some View {
        if let sequence = session.sequence, let phrase = sequence.current {
            VStack(alignment: .leading, spacing: 8) {
                Text("Phrase \(sequence.index + 1) of \(sequence.phrases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(phrase).font(.body.weight(.medium))
                status
                if let score = session.result { ScoreView(result: score) }
                if let message = session.failure { Text(message).font(.callout).foregroundStyle(.red) }
                HStack {
                    if session.phase == .listening {
                        Button { session.finishListening() } label: { Label("Stop", systemImage: "stop.circle.fill") }
                    }
                    if session.phase == .idle {
                        Button("Try again") { session.round() }
                        Button(sequence.isLast ? "Finish" : "Next") { session.next() }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Button("Exit") { session.cancel() }.help("Exit shadowing")
                }
                if sequence.isLast, session.phase == .idle, let average = sequence.average {
                    Text("Average \(Int((average * 100).rounded()))%").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch session.phase {
        case .speaking: Label("Listen…", systemImage: "speaker.wave.2.fill").foregroundStyle(.secondary)
        case .listening: Label("Now you. Stops by itself, or press Stop.", systemImage: "mic.fill").foregroundStyle(.red)
        case .scoring: ProgressView().controlSize(.small)
        case .idle: EmptyView()
        }
    }
}
