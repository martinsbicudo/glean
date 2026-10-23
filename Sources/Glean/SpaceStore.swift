import Foundation
import Observation

@MainActor
@Observable
final class SpaceStore {
    nonisolated static var productionRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Glean", isDirectory: true)
    }

    let root: URL
    private let defaults: UserDefaults
    private let fileOps: MigrationFileOps
    private(set) var spaces: [Space] = []
    private(set) var selectedID: UUID?
    private(set) var state: DataState = .noSpaces

    var spacesURL: URL { SpacePaths.file(in: root) }
    var selected: Space? { spaces.first { $0.id == selectedID } ?? spaces.first }

    init(root: URL, defaults: UserDefaults, fileOps: MigrationFileOps = .live) {
        self.root = root
        self.defaults = defaults
        self.fileOps = fileOps
        reload()
    }

    func directory(for space: Space) -> URL {
        SpacePaths.directory(in: root, id: space.id)
    }

    func reload() {
        if FileManager.default.fileExists(atPath: spacesURL.path) { readFile() } else { migrate() }
    }

    @discardableResult
    func create(name: String, target: String, native: String, level: Level, dailyGoal: Int, direction: ReviewDirection = .mixed) throws -> Space {
        guard state.canCreate else { throw SpaceError.blocked(state.message ?? "") }
        let space = try Self.validated(Space(name: name, target: target, native: native, level: level, dailyGoal: dailyGoal, direction: direction))
        try persist(spaces + [space], selected: space.id)
        do {
            try FileManager.default.createDirectory(at: directory(for: space), withIntermediateDirectories: true)
        } catch {
            Log.write("couldn't create \(directory(for: space).path): \(error.localizedDescription)")
        }
        return space
    }

    func update(_ space: Space) throws {
        try requireReady()
        guard let index = spaces.firstIndex(where: { $0.id == space.id }) else { throw SpaceError.missing }
        var list = spaces
        list[index] = try Self.validated(space)
        try persist(list, selected: selectedID)
    }

    func select(_ id: UUID) throws {
        try requireReady()
        guard spaces.contains(where: { $0.id == id }) else { throw SpaceError.missing }
        try persist(spaces, selected: id)
    }

    func delete(_ id: UUID, at date: Date = Date()) throws {
        try requireReady()
        guard let space = spaces.first(where: { $0.id == id }) else { throw SpaceError.missing }
        let remaining = spaces.filter { $0.id != id }
        let trashed = try moveToTrash(space, at: date)
        do {
            try persist(remaining, selected: selectedID == id ? remaining.first?.id : selectedID)
        } catch {
            restore(trashed, to: directory(for: space))
            throw error
        }
    }

    private func requireReady() throws {
        guard case .ready = state else { throw SpaceError.blocked(state.message ?? "") }
    }

    private static func validated(_ space: Space) throws -> Space {
        var space = space
        space.name = space.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !space.name.isEmpty else { throw SpaceError.emptyName }
        guard !Language.sameBase(space.target, space.native) else { throw SpaceError.sameLanguage }
        space.dailyGoal = max(1, space.dailyGoal)
        return space
    }

    private func readFile() {
        do {
            let file = try JSONCoding.decoder.decode(SpacesFile.self, from: Data(contentsOf: spacesURL))
            if file.spaces.isEmpty && LegacyMigration.hasSpaceFolders(in: root) {
                Log.write("\(spacesURL.path) lists no spaces but space folders exist; not touching anything")
                clear(.orphanedSpaces)
                return
            }
            apply(file)
        } catch {
            let message = "Couldn't read \(spacesURL.path): \(error.localizedDescription) Glean won't change it until it can be read. Fix or restore it, then press Reload."
            Log.write(message)
            clear(.spacesUnreadable(message))
        }
    }

    private func migrate() {
        switch LegacyMigration.run(root: root, defaults: defaults, fileOps: fileOps) {
        case .migrated, .notNeeded: readFile()
        case .noLegacy: clear(.noSpaces)
        case .orphanedSpaces: clear(.orphanedSpaces)
        case .failed(let message): clear(.migrationNeeded(message))
        }
    }

    private func clear(_ newState: DataState) {
        spaces = []
        selectedID = nil
        state = newState
    }

    private func apply(_ file: SpacesFile) {
        spaces = file.spaces
        selectedID = file.spaces.contains { $0.id == file.selected } ? file.selected : file.spaces.first?.id
        state = selected.map(DataState.ready) ?? .noSpaces
    }

    private func persist(_ list: [Space], selected: UUID?) throws {
        let file = SpacesFile(spaces: list, selected: selected)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try JSONCoding.encoder(pretty: true).encode(file).write(to: spacesURL, options: .atomic)
        } catch {
            Log.write("couldn't save \(spacesURL.path): \(error.localizedDescription)")
            throw SpaceError.failed("Couldn't save \(spacesURL.path): \(error.localizedDescription)")
        }
        apply(file)
    }

    private func moveToTrash(_ space: Space, at date: Date) throws -> URL {
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        let target = SpacePaths.trashDirectory(in: root).appendingPathComponent("\(space.id.uuidString)-\(stamp.string(from: date))", isDirectory: true)
        let source = directory(for: space)
        do {
            let manager = FileManager.default
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if manager.fileExists(atPath: source.path) {
                try manager.moveItem(at: source, to: target)
            } else {
                try manager.createDirectory(at: target, withIntermediateDirectories: true)
            }
            try JSONCoding.encoder(pretty: true).encode(space).write(to: target.appendingPathComponent("space.json"), options: .atomic)
        } catch {
            Log.write("couldn't move \(source.path) to the trash: \(error.localizedDescription)")
            throw SpaceError.failed("Couldn't move the space to the Trash folder: \(error.localizedDescription)")
        }
        return target
    }

    private func restore(_ trashed: URL, to original: URL) {
        do {
            try FileManager.default.moveItem(at: trashed, to: original)
        } catch {
            Log.write("couldn't move \(trashed.path) back to \(original.path): \(error.localizedDescription)")
        }
    }
}
