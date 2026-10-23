import AVFoundation
import Speech

@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completions: [ObjectIdentifier: (Bool) -> Void] = [:]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String, locale: String, slow: Bool = false, completion: ((Bool) -> Void)? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
        if utterance.voice == nil { Log.write("no system voice for \(locale)") }
        utterance.rate = slow ? AVSpeechUtteranceDefaultSpeechRate * 0.7 : AVSpeechUtteranceDefaultSpeechRate
        if let completion { completions[ObjectIdentifier(utterance)] = completion }
        synthesizer.speak(utterance)
    }

    func sayAndWait(_ text: String, locale: String) async -> Bool {
        await withCheckedContinuation { continuation in
            say(text, locale: locale) { continuation.resume(returning: $0) }
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.completions.removeValue(forKey: id)?(true) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.completions.removeValue(forKey: id)?(false) }
    }
}

enum PronunciationError: LocalizedError {
    case microphoneDenied
    case unavailable
    case nothingHeard

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "Glean can't use the microphone. Allow it in System Settings → Privacy & Security → Microphone."
        case .unavailable: "Apple speech recognition has no model for this language on this Mac."
        case .nothingHeard: "I didn't hear anything. Try again a little closer to the microphone."
        }
    }
}

@MainActor
final class PronunciationRecorder {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    var isRecording: Bool { recorder?.isRecording == true }

    func start() async throws {
        guard await AVAudioApplication.requestRecordPermission() else { throw PronunciationError.microphoneDenied }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("glean-say-\(UUID().uuidString).caf")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else { throw PronunciationError.microphoneDenied }
        self.recorder = recorder
        fileURL = url
    }

    nonisolated static func heardWords(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.letters.union(.decimalDigits).contains($0) }
    }

    func stop(locale: String) async throws -> String {
        recorder?.stop()
        recorder = nil
        guard let url = fileURL else { throw PronunciationError.nothingHeard }
        fileURL = nil
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try await Self.transcribe(url, locale: locale)
        guard Self.heardWords(text) else { throw PronunciationError.nothingHeard }
        return text
    }

    func cancel() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        fileURL = nil
    }

    static func transcribe(_ url: URL, locale: String) async throws -> String {
        guard SpeechTranscriber.isAvailable else { throw PronunciationError.unavailable }
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: locale)) else {
            throw PronunciationError.unavailable
        }
        let transcriber = SpeechTranscriber(locale: supported, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            Log.write("downloading speech model for \(supported.identifier)")
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let collector = Task {
            var parts: [String] = []
            for try await result in transcriber.results where result.isFinal {
                parts.append(String(result.text.characters))
            }
            return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let file = try AVAudioFile(forReading: url)
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
        return try await collector.value
    }
}
