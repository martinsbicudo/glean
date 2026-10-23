import Foundation
import Testing
@testable import Glean

struct AgentCLITests {
    @Test func claudeArgumentsRunHeadlessWithoutTools() {
        let args = AgentCLI.claudeCodeArguments(model: "sonnet", systemPrompt: "SYS")
        #expect(args == [
            "-p", "--output-format", "json", "--setting-sources", "project", "--strict-mcp-config",
            "--no-session-persistence", "--tools", "", "--system-prompt", "SYS", "--model", "sonnet",
        ])
    }

    @Test func codexArgumentsAreReadOnlyAndEphemeral() {
        let dir = URL(fileURLWithPath: "/tmp/w")
        let args = AgentCLI.codexArguments(model: nil, workDir: dir, output: dir.appendingPathComponent("a.md"))
        #expect(args == [
            "exec", "--skip-git-repo-check", "--ephemeral", "--ignore-user-config", "--ignore-rules",
            "-s", "read-only", "-C", "/tmp/w", "-o", "/tmp/w/a.md", "-",
        ])
    }

    @Test func claudeResultIsReadOrReportedAsAnError() throws {
        #expect(try AgentCLI.claudeCodeText(#"{"subtype":"success","is_error":false,"result":"hello"}"#) == "hello")
        #expect(throws: AgentCLIError.failed(engine: "Claude Code", detail: "Not logged in")) {
            try AgentCLI.claudeCodeText(#"{"subtype":"success","is_error":true,"result":"Not logged in"}"#)
        }
        #expect(throws: AgentCLIError.emptyResponse("Claude Code")) {
            try AgentCLI.claudeCodeText(#"{"subtype":"success","result":"  "}"#)
        }
    }
}
