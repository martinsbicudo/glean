import Foundation
import Testing
@testable import Glean

enum TestSupport {
    static func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("glean-tests-\(UUID().uuidString)", isDirectory: true)
    }

    static func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "glean-tests-\(UUID().uuidString)"))
    }

    static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func bytes(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func names(in directory: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
    }
}

struct InjectedFailure: Error {}
