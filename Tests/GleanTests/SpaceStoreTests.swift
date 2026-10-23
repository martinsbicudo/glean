import Foundation
import Testing
@testable import Glean

@MainActor
struct SpaceStoreTests {
    func makeStore(_ root: URL) throws -> SpaceStore {
        SpaceStore(root: root, defaults: try TestSupport.isolatedDefaults())
    }

    func addSpace(_ store: SpaceStore, _ name: String, target: String = "es-ES", native: String = "pt-BR") throws -> Space {
        try store.create(name: name, target: target, native: native, level: .beginner, dailyGoal: 10)
    }

    @Test func aNewSpaceSuggestsALanguageNotStudiedYet() {
        let english = Space(name: "English", target: "en-US", native: "pt-BR")
        let sheet = SpaceSheetState(target: .new, existing: [english])
        #expect(sheet.target == "es-ES")
        #expect(sheet.name == "Spanish")
        #expect(sheet.native == "pt-BR")
        let both = SpaceSheetState(target: .new, existing: [english, Space(name: "Spanish", target: "es-MX", native: "pt-BR")])
        #expect(both.target == "fr-FR")
    }

    @Test func freshRootHasNoSpacesAndCreatingWritesSpacesJson() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root)
        #expect(store.state == .noSpaces)
        #expect(!TestSupport.exists(store.spacesURL))
        let space = try addSpace(store, "Spanish")
        #expect(store.state == .ready(space))
        #expect(TestSupport.exists(store.spacesURL))
    }

    @Test(arguments: ["{}", #"{"spaces":null}"#, #"{"version":1,"spaces":[]}"#])
    func aSpacesFileWithNoSpacesNextToSpaceFoldersIsNeverReplaced(_ content: String) throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = SpacePaths.directory(in: root, id: UUID())
        try TestSupport.write(#"{"cards":[]}"#, to: folder.appendingPathComponent("cards.json"))
        let spacesFile = SpacePaths.file(in: root)
        try TestSupport.write(content, to: spacesFile)
        let store = try makeStore(root)
        #expect(store.state == .orphanedSpaces)
        #expect(throws: (any Error).self) { try addSpace(store, "Spanish") }
        #expect(try String(contentsOf: spacesFile, encoding: .utf8) == content)
    }

    @Test func roundTripSelectAndEdit() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root)
        let spanish = try addSpace(store, "Spanish")
        let french = try addSpace(store, "French", target: "fr-FR")
        #expect(store.selected?.id == french.id)
        try store.select(spanish.id)
        var edited = spanish
        edited.name = "Español"
        edited.level = .advanced
        edited.dailyGoal = 35
        try store.update(edited)

        let reloaded = try makeStore(root)
        #expect(reloaded.spaces.map(\.name) == ["Español", "French"])
        #expect(reloaded.selected?.id == spanish.id)
        #expect(reloaded.selected?.level == .advanced)
        #expect(reloaded.selected?.dailyGoal == 35)
        #expect(reloaded.selected?.name == "Español")
    }

    @Test func createValidatesNameAndLanguages() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root)
        #expect(throws: SpaceError.self) { try store.create(name: "  ", target: "es-ES", native: "pt-BR", level: .beginner, dailyGoal: 20) }
        #expect(throws: SpaceError.self) { try store.create(name: "Same", target: "en-US", native: "en-GB", level: .beginner, dailyGoal: 20) }
        #expect(store.spaces.isEmpty)
        #expect(!TestSupport.exists(store.spacesURL))
    }

    @Test func deleteMovesTheFolderToTrash() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root)
        let spanish = try addSpace(store, "Spanish")
        let french = try addSpace(store, "French", target: "fr-FR")
        let cards = CardStore(directory: store.directory(for: french))
        cards.add([Card(term: "bonjour")])

        try store.delete(french.id)
        #expect(store.spaces.map(\.id) == [spanish.id])
        #expect(store.selected?.id == spanish.id)
        #expect(!TestSupport.exists(store.directory(for: french)))
        let trash = SpacePaths.trashDirectory(in: root)
        let entries = TestSupport.names(in: trash)
        #expect(entries.count == 1)
        #expect(entries[0].hasPrefix(french.id.uuidString + "-"))
        let folder = trash.appendingPathComponent(entries[0])
        #expect(TestSupport.exists(folder.appendingPathComponent("cards.json")))
        let saved = try JSONCoding.decoder.decode(Space.self, from: Data(contentsOf: folder.appendingPathComponent("space.json")))
        #expect(saved.name == "French")
        #expect(try makeStore(root).spaces.map(\.id) == [spanish.id])
    }

    @Test func deletingSpacesWithTheSameNameOrASlashDoesNotCollide() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root)
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try addSpace(store, "Trip")
        let second = try addSpace(store, "Trip")
        let slash = try addSpace(store, "a/b", target: "de-DE")
        for space in [first, second, slash] { try store.delete(space.id, at: when) }
        #expect(store.spaces.isEmpty)
        #expect(store.state == .noSpaces)
        #expect(TestSupport.names(in: SpacePaths.trashDirectory(in: root)).count == 3)
        #expect(try addSpace(store, "Again").name == "Again")
    }

    @Test func anUnreadableSpacesFileMakesTheStoreReadOnlyAndIsNeverTouched() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let broken = #"{"spaces":[{"id":"#
        try TestSupport.write(broken, to: SpacePaths.file(in: root))
        let store = try makeStore(root)
        guard case .spacesUnreadable = store.state else {
            Issue.record("expected spacesUnreadable, got \(store.state)")
            return
        }
        #expect(throws: SpaceError.self) { try addSpace(store, "Spanish") }
        #expect(throws: SpaceError.self) { try store.select(UUID()) }
        #expect(throws: SpaceError.self) { try store.delete(UUID()) }
        #expect(try String(contentsOf: store.spacesURL, encoding: .utf8) == broken)
        #expect(!TestSupport.exists(SpacePaths.spacesDirectory(in: root)))

        let space = Space(name: "Spanish", target: "es-ES", native: "pt-BR")
        try TestSupport.write(String(decoding: JSONCoding.encoder(pretty: false).encode(SpacesFile(spaces: [space], selected: space.id)), as: UTF8.self), to: store.spacesURL)
        store.reload()
        #expect(store.selected?.id == space.id)
    }

    @Test func dueCountsCoverEverySpace() throws {
        let root = TestSupport.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root)
        let spanish = try addSpace(store, "Spanish")
        let french = try addSpace(store, "French", target: "fr-FR")
        let empty = try addSpace(store, "German", target: "de-DE")
        var later = Card(term: "demain")
        later.schedule.due = Date().addingTimeInterval(10 * Scheduler.day)
        CardStore(directory: store.directory(for: spanish)).add([Card(term: "hola"), Card(term: "adiós")])
        CardStore(directory: store.directory(for: french)).add([Card(term: "bonjour"), later])

        let counts = store.dueCounts()
        #expect(counts.map(\.space.id) == [spanish.id, french.id, empty.id])
        #expect(counts.map(\.due) == [2, 1, 0])
    }

    @Test func languageListIsUniqueAndComparedByBaseLanguage() {
        #expect(Language.all.count == 20)
        #expect(Set(Language.all.map(\.id)).count == 20)
        #expect(Language.sameBase("en-US", "en-GB"))
        #expect(Language.sameBase("pt-BR", "pt-PT"))
        #expect(!Language.sameBase("es-ES", "pt-BR"))
        #expect(Language.named("zh-CN").languageName == "Chinese")
    }

    @Test func levelRawValuesStillDecodeOldSettings() {
        #expect(Level(rawValue: "upper-intermediate") == .upperIntermediate)
        #expect(Level.allCases.map(\.rawValue) == ["beginner", "intermediate", "upper-intermediate", "advanced"])
    }
}
