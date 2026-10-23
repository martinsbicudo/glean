import Foundation

struct MigrationFileOps {
    var createDirectory: (URL) throws -> Void
    var copy: (URL, URL) throws -> Void
    var move: (URL, URL) throws -> Void
    var remove: (URL) throws -> Void
    var write: (Data, URL) throws -> Void

    static let live = MigrationFileOps(
        createDirectory: { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true) },
        copy: { try FileManager.default.copyItem(at: $0, to: $1) },
        move: { try FileManager.default.moveItem(at: $0, to: $1) },
        remove: { try FileManager.default.removeItem(at: $0) },
        write: { try $0.write(to: $1, options: .atomic) }
    )
}

struct MigrationError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
        errorDescription = message
    }
}

enum LegacyMigration {
    enum Result: Equatable {
        case notNeeded
        case noLegacy
        case orphanedSpaces
        case migrated(Space)
        case failed(String)
    }

    static let files = ["cards.json", "reviews.jsonl", "insights.json"]
    static let stagingPrefix = ".migrating-"
    static let englishLocales = ["en-US", "en-GB", "en-AU", "en-CA"]
    static let nativeLocales = [
        "pt-BR": "pt-BR", "pt-PT": "pt-PT", "es": "es-ES", "fr": "fr-FR", "de": "de-DE", "it": "it-IT", "ja": "ja-JP",
        "zh-Hans": "zh-CN", "ko": "ko-KR", "ru": "ru-RU", "tr": "tr-TR", "ar": "ar-SA", "hi": "hi-IN",
    ]

    static func run(root: URL, defaults: UserDefaults, fileOps: MigrationFileOps = .live) -> Result {
        guard !FileManager.default.fileExists(atPath: SpacePaths.file(in: root).path) else { return .notNeeded }
        do {
            let entries = try folders(in: SpacePaths.spacesDirectory(in: root))
            if entries.contains(where: { !$0.lastPathComponent.hasPrefix(stagingPrefix) }) { return .orphanedSpaces }
            for stale in entries { try fileOps.remove(stale) }
            let legacy = root.appendingPathComponent("cards.json")
            guard FileManager.default.fileExists(atPath: legacy.path) else { return .noLegacy }
            return .migrated(try migrate(root: root, defaults: defaults, fileOps: fileOps))
        } catch {
            let message = "\(error.localizedDescription) Nothing was changed. Fix the problem, then press Reload."
            Log.write("migration failed: \(message)")
            return .failed(message)
        }
    }

    static func legacySpace(id: UUID, defaults: UserDefaults) -> Space {
        let accent = defaults.string(forKey: "accent") ?? "en-US"
        let native = defaults.string(forKey: "nativeLanguage") ?? "pt-BR"
        return Space(
            id: id,
            name: "English",
            target: englishLocales.contains(accent) ? accent : "en-US",
            native: nativeLocales[native] ?? "pt-BR",
            level: Level(rawValue: defaults.string(forKey: "level") ?? "") ?? .intermediate
        )
    }

    private static func migrate(root: URL, defaults: UserDefaults, fileOps: MigrationFileOps) throws -> Space {
        let legacy = root.appendingPathComponent("cards.json")
        let count: Int
        do {
            count = try CardFile.read(legacy).cards.count
        } catch {
            throw MigrationError("Couldn't read \(legacy.path): \(error.localizedDescription)")
        }
        let space = legacySpace(id: UUID(), defaults: defaults)
        let staging = SpacePaths.spacesDirectory(in: root).appendingPathComponent(stagingPrefix + UUID().uuidString, isDirectory: true)
        let final = SpacePaths.directory(in: root, id: space.id)
        do {
            try fileOps.createDirectory(staging)
            try copyAndVerify(from: root, to: staging, expectedCards: count, fileOps: fileOps)
            try fileOps.move(staging, final)
        } catch {
            discard(staging, fileOps)
            throw MigrationError("Couldn't copy your cards into a space: \(error.localizedDescription)")
        }
        do {
            let data = try JSONCoding.encoder(pretty: true).encode(SpacesFile(spaces: [space], selected: space.id))
            try fileOps.write(data, SpacePaths.file(in: root))
        } catch {
            discard(final, fileOps)
            throw MigrationError("Couldn't write \(SpacePaths.file(in: root).path): \(error.localizedDescription)")
        }
        return space
    }

    private static func copyAndVerify(from root: URL, to staging: URL, expectedCards: Int, fileOps: MigrationFileOps) throws {
        for name in files {
            let source = root.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let copy = staging.appendingPathComponent(name)
            try fileOps.copy(source, copy)
            guard try Data(contentsOf: source) == Data(contentsOf: copy) else {
                throw MigrationError("the copy of \(name) differs from the original")
            }
        }
        guard try CardFile.read(staging.appendingPathComponent("cards.json")).cards.count == expectedCards else {
            throw MigrationError("the copied cards.json has a different number of cards")
        }
    }

    static func hasSpaceFolders(in root: URL) -> Bool {
        let entries = (try? folders(in: SpacePaths.spacesDirectory(in: root))) ?? []
        return entries.contains { !$0.lastPathComponent.hasPrefix(stagingPrefix) }
    }

    private static func folders(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }

    private static func discard(_ url: URL, _ fileOps: MigrationFileOps) {
        do {
            try fileOps.remove(url)
        } catch {
            Log.write("couldn't remove \(url.path): \(error.localizedDescription)")
        }
    }
}
