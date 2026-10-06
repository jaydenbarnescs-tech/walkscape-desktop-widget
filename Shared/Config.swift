import Foundation

/// Settings shared between the setup app (writes) and the widget (reads).
/// Stored as plain JSON in ~/.config/walkscape-widget/ — no passwords, no tokens.
struct Config: Codable {
    var characterId: String
    var characterName: String
    /// "auto" picks a background from the character's location.
    var background: String = "auto"

    static var realHome: String {
        // The widget is sandboxed, so NSHomeDirectory() would be its container.
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }
    static var dir: URL { URL(fileURLWithPath: realHome).appendingPathComponent(".config/walkscape-widget") }
    static var file: URL { dir.appendingPathComponent("config.json") }

    static func load() -> Config? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Config.self, from: data)
    }
    func save() throws {
        try FileManager.default.createDirectory(at: Config.dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Config.file, options: .atomic)
    }
    static func clear() { try? FileManager.default.removeItem(at: file) }
}
