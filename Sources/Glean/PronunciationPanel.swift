import SwiftUI

struct PronunciationPanel: View {
    @Environment(AppModel.self) private var model
    @StateObject private var ui = PronunciationPanelState()
    @StateObject private var shadowSession = ShadowSession()
    let workspace: Workspace
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Say it").font(.headline)
            Picker("Phrase", selection: $ui.target) {
                Text(card.term).tag(card.term)
                ForEach(card.examples, id: \.self) { Text($0).lineLimit(1).tag($0) }
            }
            .labelsHidden()
            HStack {
                Button(action: toggle) {
                    Label(ui.recording ? "Stop" : "Record", systemImage: ui.recording ? "stop.circle.fill" : "mic.circle.fill")
                }
                .controlSize(.large)
                .disabled(ui.working || shadowSession.isActive)
                Button(action: startShadow) { Label("Shadow", systemImage: "person.wave.2.fill") }
                    .controlSize(.large)
                    .disabled(ui.working || ui.recording || shadowSession.isActive)
                    .help("Hear the phrase, then say it right after")
                if ui.working { ProgressView().controlSize(.small) }
                Spacer()
            }
            ShadowControls(session: shadowSession)
            if let score = ui.result { ScoreView(result: score) }
            if let message = ui.failure { Text(message).font(.callout).foregroundStyle(.red) }
            Text("Checks whether speech recognition understood you, word by word. It doesn't grade individual sounds.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { ui.target = card.term }
        .onChange(of: card.id) {
            ui.target = card.term
            ui.result = nil
            ui.failure = nil
            ui.recorder.cancel()
            ui.recording = false
            shadowSession.cancel()
        }
        .onDisappear {
            ui.recorder.cancel()
            shadowSession.cancel()
        }
    }

    private func startShadow() {
        ui.result = nil
        ui.failure = nil
        let cardID = card.id
        let store = workspace.store
        let phrases = Shadow.phrases(for: card)
        shadowSession.begin(
            phrases: phrases,
            startAt: phrases.firstIndex(of: ui.target) ?? 0,
            speaker: model.speaker,
            recorder: ui.recorder,
            locale: workspace.space.target
        ) { score, heard in store.recordPronunciation(cardID, score: score, heard: heard) }
    }

    private func toggle() {
        ui.failure = nil
        if ui.recording {
            ui.recording = false
            ui.working = true
            Task {
                defer { ui.working = false }
                do {
                    let heard = try await ui.recorder.stop(locale: workspace.space.target)
                    let score = PronunciationScore.compare(target: ui.target, heard: heard)
                    ui.result = score
                    workspace.store.recordPronunciation(card.id, score: score.score, heard: heard)
                } catch {
                    ui.failure = error.localizedDescription
                }
            }
        } else {
            ui.result = nil
            Task {
                do {
                    try await ui.recorder.start()
                    ui.recording = true
                } catch {
                    ui.failure = error.localizedDescription
                }
            }
        }
    }
}

struct ScoreView: View {
    let result: PronunciationScore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int((result.score * 100).rounded()))%")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(result.score >= 0.9 ? .green : result.score >= 0.6 ? .orange : .red)
                Text(verdict).foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 4) {
                ForEach(Array(result.words.enumerated()), id: \.offset) { _, word in
                    Text(word.text)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((word.matched ? Color.green : Color.red).opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                }
            }
            Text("Heard: “\(result.heard)”").font(.callout).foregroundStyle(.secondary)
        }
    }

    private var verdict: String {
        switch result.score {
        case 0.9...: "Clear!"
        case 0.6..<0.9: "Almost. Try the red words again."
        default: "Not understood yet. Listen and try again."
        }
    }
}

@MainActor
final class PronunciationPanelState: ObservableObject {
    @Published var target = ""
    @Published var recorder = PronunciationRecorder()
    @Published var recording = false
    @Published var working = false
    @Published var result: PronunciationScore?
    @Published var failure: String?
}
