import Foundation

@MainActor
final class ShadowSession: ObservableObject {
    enum Phase: Equatable {
        case idle, speaking, listening, scoring
    }

    @Published private(set) var phase = Phase.idle
    @Published private(set) var sequence: ShadowSequence?
    @Published private(set) var result: PronunciationScore?
    @Published private(set) var failure: String?
    private var flow: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var generation = 0
    private var speaker: Speaker?
    private var recorder: PronunciationRecorder?
    private var locale = "en-US"
    private var record: (Double, String) -> Void = { _, _ in }

    var isActive: Bool { sequence != nil }

    func begin(phrases: [String], startAt start: Int, speaker: Speaker, recorder: PronunciationRecorder, locale: String, record: @escaping (Double, String) -> Void) {
        cancel()
        guard !phrases.isEmpty else { return }
        self.speaker = speaker
        self.recorder = recorder
        self.locale = locale
        self.record = record
        sequence = ShadowSequence(phrases: phrases, startAt: start)
        round()
    }

    func round() {
        guard let phrase = sequence?.current, let speaker, let recorder else { return }
        stopWork()
        result = nil
        failure = nil
        phase = .speaking
        let token = generation
        flow = Task {
            let finished = await speaker.sayAndWait(phrase, locale: locale)
            guard token == generation else { return }
            guard finished else {
                phase = .idle
                return
            }
            do {
                try await recorder.start()
                guard token == generation else {
                    recorder.cancel()
                    return
                }
                phase = .listening
                scheduleStop(after: Shadow.autoStop(for: phrase), token: token)
            } catch {
                guard token == generation else { return }
                phase = .idle
                failure = error.localizedDescription
            }
        }
    }

    func finishListening() {
        guard phase == .listening, let recorder, let phrase = sequence?.current else { return }
        timer?.cancel()
        phase = .scoring
        let token = generation
        let locale = locale
        flow = Task {
            do {
                let heard = try await recorder.stop(locale: locale)
                guard token == generation else { return }
                let score = PronunciationScore.compare(target: phrase, heard: heard)
                sequence?.record(score.score)
                result = score
                record(score.score, heard)
            } catch {
                guard token == generation else { return }
                failure = error.localizedDescription
            }
            phase = .idle
        }
    }

    func next() {
        guard sequence?.advance() == true else {
            cancel()
            return
        }
        round()
    }

    func cancel() {
        stopWork()
        recorder?.cancel()
        sequence = nil
        result = nil
        failure = nil
        phase = .idle
    }

    private func stopWork() {
        generation += 1
        flow?.cancel()
        timer?.cancel()
        flow = nil
        timer = nil
        speaker?.stop()
        recorder?.cancel()
    }

    private func scheduleStop(after seconds: TimeInterval, token: Int) {
        timer = Task {
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            guard token == generation else { return }
            finishListening()
        }
    }
}
