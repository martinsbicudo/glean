import Foundation

enum AgentCLIError: LocalizedError, Equatable {
    case notConnected
    case notInstalled(String)
    case failed(engine: String, detail: String)
    case emptyResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "No AI is connected. Choose Claude Code or Codex in Settings."
        case .notInstalled(let tool): "\(tool) isn't installed or wasn't found in ~/.local/bin, /opt/homebrew/bin or /usr/local/bin."
        case .failed(let engine, let detail): "\(engine) failed: \(detail)"
        case .emptyResponse(let engine): "\(engine) returned an empty answer."
        }
    }
}

struct AgentReply: Equatable {
    let text: String
    let engine: AIEngine
}

struct AgentCLI {
    let engine: AIEngine
    let model: (AIEngine) -> String?

    static func binary(for engine: AIEngine) -> URL? {
        engine.binaryName.flatMap { Shell.find($0) }
    }

    static func engines(preferred: AIEngine, isInstalled: (AIEngine) -> Bool) -> [AIEngine] {
        guard preferred != .none else { return [] }
        let others = AIEngine.allCases.filter { $0 != preferred && $0 != .none }
        return ([preferred] + others).filter(isInstalled)
    }

    func run(systemPrompt: String, userMessage: String, activity: String) async throws -> AgentReply {
        guard engine != .none else { throw AgentCLIError.notConnected }
        let engines = Self.engines(preferred: engine) { Self.binary(for: $0) != nil }
        guard !engines.isEmpty else { throw AgentCLIError.notInstalled(engine.displayName) }
        var lastError: Error = AgentCLIError.notInstalled(engine.displayName)
        for candidate in engines {
            do {
                Log.write("\(activity) with \(candidate.displayName)")
                let text = try await run(candidate, systemPrompt: systemPrompt, userMessage: userMessage)
                return AgentReply(text: text, engine: candidate)
            } catch {
                Log.write("\(activity) with \(candidate.displayName) failed: \(error.localizedDescription)")
                lastError = error
            }
        }
        throw lastError
    }

    static func claudeCodeText(_ output: String) throws -> String {
        let result = try JSONDecoder.snakeCase.decode(ClaudeCodeResult.self, from: Data(output.utf8))
        guard result.isError != true, result.subtype == nil || result.subtype == "success" else {
            throw AgentCLIError.failed(engine: "Claude Code", detail: result.result ?? result.subtype ?? "unknown error")
        }
        return try nonEmpty(result.result ?? "", engine: "Claude Code")
    }

    static func claudeCodeArguments(model: String?, systemPrompt: String) -> [String] {
        var args = [
            "-p", "--output-format", "json",
            "--setting-sources", "project", "--strict-mcp-config", "--no-session-persistence",
            "--tools", "", "--system-prompt", systemPrompt,
        ]
        if let model { args += ["--model", model] }
        return args
    }

    static func codexArguments(model: String?, workDir: URL, output: URL) -> [String] {
        var args = [
            "exec", "--skip-git-repo-check", "--ephemeral", "--ignore-user-config", "--ignore-rules",
            "-s", "read-only", "-C", workDir.path, "-o", output.path,
        ]
        if let model { args += ["-m", model] }
        return args + ["-"]
    }

    static func codexPrompt(systemPrompt: String, userMessage: String) -> String {
        systemPrompt + "\n\nDo not run commands or read files; answer only from the text below.\n\n" + userMessage
    }

    static func nonEmpty(_ text: String, engine: String) throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AgentCLIError.emptyResponse(engine) }
        return text
    }

    private func run(_ engine: AIEngine, systemPrompt: String, userMessage: String) async throws -> String {
        guard let binary = Self.binary(for: engine) else { throw AgentCLIError.notInstalled(engine.displayName) }
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("glean-\(engine.rawValue)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        switch engine {
        case .none:
            throw AgentCLIError.notConnected
        case .claudeCode:
            let args = Self.claudeCodeArguments(model: model(engine), systemPrompt: systemPrompt)
            do {
                let output = try await Shell.run(binary, args, input: userMessage, in: workDir)
                return try Self.claudeCodeText(output)
            } catch let error as ShellError where !error.stdout.isEmpty {
                _ = try Self.claudeCodeText(error.stdout)
                throw error
            }
        case .codex:
            let output = workDir.appendingPathComponent("answer.md")
            let prompt = Self.codexPrompt(systemPrompt: systemPrompt, userMessage: userMessage)
            try await Shell.run(binary, Self.codexArguments(model: model(engine), workDir: workDir, output: output), input: prompt, in: workDir)
            return try Self.nonEmpty(try String(contentsOf: output, encoding: .utf8), engine: "Codex")
        }
    }
}

struct ClaudeCodeResult: Decodable {
    let subtype: String?
    let isError: Bool?
    let result: String?
}

extension JSONDecoder {
    static let snakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
