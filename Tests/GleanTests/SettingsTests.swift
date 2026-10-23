import Foundation
import Testing
@testable import Glean

struct SettingsTests {
    @Test func parsesReminderHours() {
        #expect(AppSettings.hours("19, 9,14,9,30,x") == [9, 14, 19])
        #expect(AppSettings.hours(nil) == nil)
    }

    @Test func enginesPreferTheChosenOne() {
        let installed: Set<AIEngine> = [.claudeCode, .codex]
        #expect(AgentCLI.engines(preferred: .codex) { installed.contains($0) } == [.codex, .claudeCode])
        #expect(AgentCLI.engines(preferred: .none) { installed.contains($0) }.isEmpty)
        #expect(AgentCLI.engines(preferred: .claudeCode) { $0 == .codex } == [.codex])
    }

    @Test func kindsAcceptLooseNames() {
        #expect(CardKind(loose: "Phrasal Verb") == .phrasalVerb)
        #expect(CardKind(loose: "expression") == .phrase)
        #expect(CardKind(loose: "noun") == .word)
    }
}
