import Foundation

struct Space: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var target: String
    var native: String
    var level: Level
    var dailyGoal: Int
    var direction: ReviewDirection
    var created: Date

    var targetLanguage: Language { .named(target) }
    var nativeLanguage: Language { .named(native) }

    init(id: UUID = UUID(), name: String, target: String, native: String, level: Level = .intermediate, dailyGoal: Int = 20, direction: ReviewDirection = .mixed, created: Date = Date()) {
        self.id = id
        self.name = name
        self.target = target
        self.native = native
        self.level = level
        self.dailyGoal = dailyGoal
        self.direction = direction
        self.created = created
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        target = try c.decode(String.self, forKey: .target)
        native = try c.decode(String.self, forKey: .native)
        level = (try c.decodeIfPresent(String.self, forKey: .level)).flatMap(Level.init(rawValue:)) ?? .intermediate
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? 20
        direction = (try c.decodeIfPresent(String.self, forKey: .direction)).flatMap(ReviewDirection.init(rawValue:)) ?? .mixed
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
    }
}

struct SpacesFile: Codable {
    var version = 1
    var spaces: [Space]
    var selected: UUID?

    init(spaces: [Space], selected: UUID?) {
        self.spaces = spaces
        self.selected = selected
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        spaces = try c.decodeIfPresent([Space].self, forKey: .spaces) ?? []
        selected = try c.decodeIfPresent(UUID.self, forKey: .selected)
    }
}

enum SpacePaths {
    static func file(in root: URL) -> URL { root.appendingPathComponent("spaces.json") }
    static func spacesDirectory(in root: URL) -> URL { root.appendingPathComponent("spaces", isDirectory: true) }
    static func trashDirectory(in root: URL) -> URL { root.appendingPathComponent("Trash", isDirectory: true) }

    static func directory(in root: URL, id: UUID) -> URL {
        spacesDirectory(in: root).appendingPathComponent(id.uuidString, isDirectory: true)
    }
}

enum DataState: Equatable {
    case ready(Space)
    case noSpaces
    case migrationNeeded(String)
    case spacesUnreadable(String)
    case orphanedSpaces

    var canCreate: Bool {
        switch self {
        case .ready, .noSpaces: true
        default: false
        }
    }

    var message: String? {
        switch self {
        case .ready, .noSpaces: nil
        case .migrationNeeded(let text), .spacesUnreadable(let text): text
        case .orphanedSpaces:
            "spaces.json is missing but space folders exist. Restore spaces.json or move ~/Glean/spaces aside, then press Reload."
        }
    }
}

enum SpaceError: LocalizedError {
    case blocked(String)
    case emptyName
    case sameLanguage
    case missing
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .blocked(let reason): reason.isEmpty ? "Spaces can't be changed right now." : reason
        case .emptyName: "Give the space a name."
        case .sameLanguage: "The language you study and your own language must be different."
        case .missing: "That space no longer exists."
        case .failed(let text): text
        }
    }
}
