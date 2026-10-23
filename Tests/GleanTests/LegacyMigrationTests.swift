import Foundation
import Testing
@testable import Glean

@MainActor
struct LegacyMigrationTests {
    let cardsText = #"{"version":1,"cards":[{"term":"pick up","translations":["pegar"]},{"term":"gist"},{"term":"wrap up"}]}"#
    let reviewsText = "{\"cardID\":\"11111111-1111-1111-1111-111111111111\",\"date\":\"2026-01-01T00:00:00Z\",\"rating\":\"good\"}\n"
    let insightsText = #"{"summary":"ok","weaknesses":[],"tips":[],"cards":[]}"#

    func writeLegacy(_ root: URL, cards: String? = nil) throws {
        try TestSupport.write(cards ?? cardsText, to: root.appendingPathComponent("cards.json"))
        try TestSupport.write(reviewsText, to: root.appendingPathComponent("reviews.jsonl"))
        try TestSupport.write(insightsText, to: root.appendingPathComponent("insights.json"))
    }

    func legacyBytes(_ root: URL) throws -> [Data] {
        try LegacyMigration.files.map { try TestSupport.bytes(root.appendingPathComponent($0)) }
    }

    func failingCopy(_ name: String) -> MigrationFileOps {
        var ops = MigrationFileOps.live
        ops.copy = { source, destination in
            if destination.lastPathComponent == name { throw InjectedFailure() }
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return ops
    }

    func expectNothingWritten(_ root: URL) {
        #expect(!TestSupport.exists(SpacePaths.file(in: root)))
        #expect(TestSupport.names(in: SpacePaths.spacesDirectory(in: root)).isEmpty)
    }

    @Test func migratesIntoAnEnglishSpaceKeepingEveryFileIdentical() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try TestSupport.isolatedDefaults()
        defaults.set("es", forKey: "nativeLanguage")
        defaults.set("advanced", forKey: "level")
        defaults.set("en-GB", forKey: "accent")
        try writeLegacy(root)
        let before = try legacyBytes(root)

        let store = SpaceStore(root: root, defaults: defaults)
        guard case .ready(let space) = store.state else {
            Issue.record("expected ready, got \(store.state)")
            return
        }
        #expect([space.name, space.target, space.native, space.level.rawValue] == ["English", "en-GB", "es-ES", "advanced"])
        let directory = store.directory(for: space)
        for (name, original) in zip(LegacyMigration.files, before) {
            #expect(try TestSupport.bytes(directory.appendingPathComponent(name)) == original)
        }
        #expect(CardStore(directory: directory).cards.count == 3)
        #expect(try legacyBytes(root) == before)
        #expect(TestSupport.names(in: SpacePaths.spacesDirectory(in: root)) == [space.id.uuidString])

        let spacesBytes = try TestSupport.bytes(store.spacesURL)
        #expect(LegacyMigration.run(root: root, defaults: defaults) == .notNeeded)
        #expect(try SpaceStore(root: root, defaults: defaults).spaces == [space])
        #expect(try TestSupport.bytes(store.spacesURL) == spacesBytes)
    }

    @Test(arguments: [
        ("pt-BR", "pt-BR"), ("pt-PT", "pt-PT"), ("es", "es-ES"), ("fr", "fr-FR"), ("de", "de-DE"), ("it", "it-IT"),
        ("ja", "ja-JP"), ("zh-Hans", "zh-CN"), ("ko", "ko-KR"), ("ru", "ru-RU"), ("tr", "tr-TR"), ("ar", "ar-SA"),
        ("hi", "hi-IN"), ("xx", "pt-BR"),
    ])
    func mapsEveryOldNativeLanguage(old: String, expected: String) throws {
        let defaults = try TestSupport.isolatedDefaults()
        defaults.set(old, forKey: "nativeLanguage")
        #expect(LegacyMigration.legacySpace(id: UUID(), defaults: defaults).native == expected)
    }

    @Test(arguments: [("en-US", "en-US"), ("en-GB", "en-GB"), ("en-AU", "en-AU"), ("en-CA", "en-CA"), ("fr-FR", "en-US"), ("klingon", "en-US")])
    func mapsTheOldAccentToATarget(accent: String, expected: String) throws {
        let defaults = try TestSupport.isolatedDefaults()
        defaults.set(accent, forKey: "accent")
        #expect(LegacyMigration.legacySpace(id: UUID(), defaults: defaults).target == expected)
    }

    @Test func missingSettingsFallBackToTodaysDefaults() throws {
        let space = LegacyMigration.legacySpace(id: UUID(), defaults: try TestSupport.isolatedDefaults())
        #expect([space.target, space.native, space.level.rawValue] == ["en-US", "pt-BR", "intermediate"])
    }

    @Test func theOldKeysSurviveAndAreReadEvenAfterAppSettingsWasBuilt() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try TestSupport.isolatedDefaults()
        defaults.set("ja", forKey: "nativeLanguage")
        defaults.set("beginner", forKey: "level")
        defaults.set("en-AU", forKey: "accent")
        let settings = AppSettings(defaults: defaults)
        settings.remindersOn = false
        try writeLegacy(root)

        let store = SpaceStore(root: root, defaults: defaults)
        #expect(store.selected?.target == "en-AU")
        #expect(store.selected?.native == "ja-JP")
        #expect(store.selected?.level == .beginner)
        #expect([defaults.string(forKey: "nativeLanguage"), defaults.string(forKey: "level"), defaults.string(forKey: "accent")] == ["ja", "beginner", "en-AU"])
    }

    @Test func anUndecodableLegacyFileBlocksCreationUntilFixed() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try TestSupport.isolatedDefaults()
        let broken = #"{"cards":[{"term":"pick up"},"#
        try writeLegacy(root, cards: broken)
        let store = SpaceStore(root: root, defaults: defaults)
        guard case .migrationNeeded(let message) = store.state else {
            Issue.record("expected migrationNeeded, got \(store.state)")
            return
        }
        #expect(message.contains(root.appendingPathComponent("cards.json").path))
        #expect(throws: SpaceError.self) { try store.create(name: "Spanish", target: "es-ES", native: "pt-BR", level: .beginner, dailyGoal: 20) }
        expectNothingWritten(root)
        #expect(try String(contentsOf: root.appendingPathComponent("cards.json"), encoding: .utf8) == broken)

        try TestSupport.write(cardsText, to: root.appendingPathComponent("cards.json"))
        store.reload()
        guard case .ready(let space) = store.state else {
            Issue.record("expected ready, got \(store.state)")
            return
        }
        #expect(CardStore(directory: store.directory(for: space)).cards.count == 3)
        #expect(try String(contentsOf: root.appendingPathComponent("cards.json"), encoding: .utf8) == cardsText)
    }

    @Test(arguments: ["reviews.jsonl", "insights.json"])
    func aFailedCopyLeavesNothingBehindAndRetrySucceeds(file: String) throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try TestSupport.isolatedDefaults()
        try writeLegacy(root)
        let before = try legacyBytes(root)
        let store = SpaceStore(root: root, defaults: defaults, fileOps: failingCopy(file))
        guard case .migrationNeeded = store.state else {
            Issue.record("expected migrationNeeded, got \(store.state)")
            return
        }
        expectNothingWritten(root)
        #expect(try legacyBytes(root) == before)
        #expect(SpaceStore(root: root, defaults: defaults).selected?.name == "English")
    }

    @Test func aFailedSpacesJsonWriteRemovesTheRenamedFolderAndRetrySucceeds() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try TestSupport.isolatedDefaults()
        try writeLegacy(root)
        var ops = MigrationFileOps.live
        ops.write = { _, _ in throw InjectedFailure() }
        let store = SpaceStore(root: root, defaults: defaults, fileOps: ops)
        guard case .migrationNeeded = store.state else {
            Issue.record("expected migrationNeeded, got \(store.state)")
            return
        }
        expectNothingWritten(root)
        store.reload()
        guard case .migrationNeeded = store.state else {
            Issue.record("expected migrationNeeded again, got \(store.state)")
            return
        }
        let retry = SpaceStore(root: root, defaults: defaults)
        #expect(retry.selected?.name == "English")
        #expect(CardStore(directory: retry.directory(for: try #require(retry.selected))).cards.count == 3)
    }

    @Test func leftoverStagingFoldersAreCleaned() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try TestSupport.isolatedDefaults()
        try TestSupport.write("{}", to: SpacePaths.spacesDirectory(in: root).appendingPathComponent(".migrating-old/cards.json"))
        #expect(LegacyMigration.run(root: root, defaults: defaults) == .noLegacy)
        #expect(TestSupport.names(in: SpacePaths.spacesDirectory(in: root)).isEmpty)

        try TestSupport.write("{}", to: SpacePaths.spacesDirectory(in: root).appendingPathComponent(".migrating-older/cards.json"))
        try writeLegacy(root)
        let store = SpaceStore(root: root, defaults: defaults)
        #expect(TestSupport.names(in: SpacePaths.spacesDirectory(in: root)) == [try #require(store.selected).id.uuidString])
    }

    @Test func withoutLegacyCardsThereIsNothingToMigrate() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SpaceStore(root: root, defaults: try TestSupport.isolatedDefaults())
        #expect(store.state == .noSpaces)
        #expect(!TestSupport.exists(store.spacesURL))
        #expect(store.state.canCreate)
    }

    @Test(arguments: [true, false])
    func spaceFoldersWithoutSpacesJsonAreNeverTouched(withLegacy: Bool) throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try TestSupport.isolatedDefaults()
        let orphan = SpacePaths.directory(in: root, id: UUID())
        try TestSupport.write(cardsText, to: orphan.appendingPathComponent("cards.json"))
        if withLegacy { try writeLegacy(root) }
        let before = try TestSupport.bytes(orphan.appendingPathComponent("cards.json"))

        let store = SpaceStore(root: root, defaults: defaults)
        #expect(store.state == .orphanedSpaces)
        #expect(throws: SpaceError.self) { try store.create(name: "Spanish", target: "es-ES", native: "pt-BR", level: .beginner, dailyGoal: 20) }
        #expect(!TestSupport.exists(store.spacesURL))
        #expect(TestSupport.names(in: SpacePaths.spacesDirectory(in: root)) == [orphan.lastPathComponent])
        #expect(try TestSupport.bytes(orphan.appendingPathComponent("cards.json")) == before)
        if withLegacy { #expect(try String(contentsOf: root.appendingPathComponent("cards.json"), encoding: .utf8) == cardsText) }
    }
}
