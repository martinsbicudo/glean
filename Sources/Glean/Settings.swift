import Foundation
import Observation

enum AIEngine: String, CaseIterable, Identifiable {
    case none
    case claudeCode = "claude-code"
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None (manual)"
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }

    var binaryName: String? {
        switch self {
        case .none: nil
        case .claudeCode: "claude"
        case .codex: "codex"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var engine: AIEngine { didSet { defaults.set(engine.rawValue, forKey: "engine") } }
    var remindersOn: Bool { didSet { defaults.set(remindersOn, forKey: "remindersOn") } }
    var reminderHours: [Int] { didSet { defaults.set(reminderHours.map(String.init).joined(separator: ","), forKey: "reminderHours") } }
    var claudeModel: String { didSet { defaults.set(claudeModel, forKey: "claudeModel") } }
    var codexModel: String { didSet { defaults.set(codexModel, forKey: "codexModel") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        engine = AIEngine(rawValue: defaults.string(forKey: "engine") ?? "") ?? .claudeCode
        remindersOn = defaults.object(forKey: "remindersOn") == nil || defaults.bool(forKey: "remindersOn")
        reminderHours = Self.hours(defaults.string(forKey: "reminderHours")) ?? [9, 14, 19]
        claudeModel = defaults.string(forKey: "claudeModel") ?? ""
        codexModel = defaults.string(forKey: "codexModel") ?? ""
    }

    nonisolated static func hours(_ text: String?) -> [Int]? {
        guard let text else { return nil }
        let hours = text.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { (0..<24).contains($0) }
        return Array(Set(hours)).sorted()
    }

    func model(for engine: AIEngine) -> String? {
        let value = (engine == .codex ? codexModel : claudeModel).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
