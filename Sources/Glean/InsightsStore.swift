import Foundation
import Observation

@MainActor
@Observable
final class InsightsStore {
    let url: URL
    private(set) var canWrite: Bool
    private(set) var latest: CoachReport?

    init(directory: URL) {
        url = directory.appendingPathComponent("insights.json")
        canWrite = directory.standardizedFileURL.deletingLastPathComponent().lastPathComponent == "spaces"
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            latest = try JSONCoding.decoder.decode(CoachReport.self, from: data)
        } catch {
            canWrite = false
            Log.write("can't read \(url.path), so Glean won't overwrite it: \(error.localizedDescription)")
        }
    }

    var profileNotes: String {
        guard let latest else { return "" }
        return (latest.weaknesses.map { "  - weak: \($0)" } + [latest.summary].filter { !$0.isEmpty }.map { "  - summary: \($0)" })
            .joined(separator: "\n")
    }

    func save(_ report: CoachReport) {
        guard canWrite else {
            Log.write("not saving insights to \(url.path): outside a spaces folder or the file is unreadable")
            return
        }
        latest = report
        do {
            try JSONCoding.encoder(pretty: true).encode(report).write(to: url, options: .atomic)
        } catch {
            Log.write("couldn't save insights: \(error.localizedDescription)")
        }
    }

    func removeSuggestion(_ term: String) {
        guard var report = latest else { return }
        report.cards.removeAll { Card.normalize($0.term) == Card.normalize(term) }
        save(report)
    }
}
