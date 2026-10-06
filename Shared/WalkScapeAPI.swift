import Foundation

/// Minimal client for WalkScape's public, unauthenticated portal endpoints.
/// Unofficial: not affiliated with or endorsed by WalkScape.
enum WS {
    static let base = "https://api.web.walkscape.app"

    struct Character {
        var id: String
        var name: String
        var totalSteps: Int
        var totalLevel: Int
        var totalXP: Int
        var achievementPoints: Int
        var skills: [(name: String, xp: Int)]
        var updatedAt: Date?
        var locationUID: String?
    }

    struct DirectoryEntry: Codable {
        var id: String
        var name: String
        var steps: Int
    }

    static func get(_ url: URL) async -> Data? {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("walkscape-widget/1.0 (open source desktop widget)", forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    static func iso(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    static func fetchCharacter(id: String) async -> Character? {
        guard let enc = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/portal/shared/characters/\(enc)"),
              let data = await get(url),
              let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let name = o["character_name"] as? String else { return nil }
        let stats = (o["statistics"] as? [String: Any]) ?? [:]
        let skip: Set<String> = ["total_xp", "total_level", "total_steps", "achievement_points", "character_id"]
        let skills = stats.compactMap { k, v -> (name: String, xp: Int)? in
            guard !skip.contains(k), let n = v as? Int else { return nil }
            return (k, n)
        }.sorted { $0.xp > $1.xp }
        return Character(
            id: id, name: name,
            totalSteps: (o["total_steps"] as? Int) ?? (stats["total_steps"] as? Int) ?? 0,
            totalLevel: (stats["total_level"] as? Int) ?? 0,
            totalXP: (stats["total_xp"] as? Int) ?? 0,
            achievementPoints: (stats["achievement_points"] as? Int) ?? 0,
            skills: skills,
            updatedAt: (o["updated_at"] as? String).flatMap(iso),
            locationUID: o["location_uid"] as? String)
    }

    // MARK: identifiers

    /// Accepts a raw character id, or any URL that contains one (walkstats.app/user/<id>, portal links…).
    static func parseIdentifier(_ input: String) -> String? {
        let text = input.removingPercentEncoding ?? input
        let pattern = "[a-z0-9_]+-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range, in: text) else { return nil }
        return String(text[r]).lowercased()
    }

    // MARK: name directory (built from the public leaderboard, cached for a day)

    static var directoryCache: URL { Config.dir.appendingPathComponent("directory.json") }

    static func cachedDirectory(maxAge: TimeInterval = 24 * 3600) -> [DirectoryEntry]? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: directoryCache.path),
              let mod = attrs[.modificationDate] as? Date, Date().timeIntervalSince(mod) < maxAge,
              let data = try? Data(contentsOf: directoryCache) else { return nil }
        return try? JSONDecoder().decode([DirectoryEntry].self, from: data)
    }

    /// Reads every leaderboard page (~1000 players each). A few requests in flight at a time, once a day.
    static func loadDirectory(progress: @escaping @Sendable (Int) -> Void) async -> [DirectoryEntry] {
        if let c = cachedDirectory() { return c }
        var all: [DirectoryEntry] = []
        var page = 1, done = false
        while !done && page <= 120 {
            let batch = Array(page..<(page + 4))
            let results = await withTaskGroup(of: (Int, [DirectoryEntry]?).self) { group -> [(Int, [DirectoryEntry]?)] in
                for p in batch {
                    group.addTask {
                        guard let url = URL(string: "\(base)/leaderboards?type=total_steps&page=\(p)"),
                              let data = await get(url),
                              let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                              let entries = o["entries"] as? [[String: Any]] else { return (p, nil) }
                        return (p, entries.compactMap { e in
                            guard let id = e["character_id"] as? String, let n = e["character_name"] as? String else { return nil }
                            return DirectoryEntry(id: id, name: n, steps: (e["total_steps"] as? Int) ?? 0)
                        })
                    }
                }
                var out: [(Int, [DirectoryEntry]?)] = []
                for await r in group { out.append(r) }
                return out.sorted { $0.0 < $1.0 }
            }
            for (_, rows) in results {
                guard let rows else { done = true; continue }
                all += rows
                if rows.isEmpty { done = true }
            }
            progress(all.count)
            page += 4
        }
        if !all.isEmpty {
            try? FileManager.default.createDirectory(at: Config.dir, withIntermediateDirectories: true)
            try? JSONEncoder().encode(all).write(to: directoryCache, options: .atomic)
        }
        return all
    }

    static func search(_ query: String, in dir: [DirectoryEntry], limit: Int = 25) -> [DirectoryEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        func rank(_ e: DirectoryEntry) -> Int {
            let n = e.name.lowercased()
            return n == q ? 0 : n.hasPrefix(q) ? 1 : n.contains(q) ? 2 : 3
        }
        return Array(dir.filter { rank($0) < 3 }.sorted {
            (rank($0), -$0.steps) < (rank($1), -$1.steps)
        }.prefix(limit))
    }
}

enum Biome {
    static let all = ["meadow", "forest", "coast", "mountain", "desert"]

    /// location_uid looks like "location-blackspell_port-<uuid>".
    static func forLocation(_ uid: String?) -> String {
        guard let uid else { return "meadow" }
        let parts = uid.split(separator: "-").map(String.init)
        let slug = (parts.count > 2 ? parts[1] : uid).lowercased()
        func has(_ words: [String]) -> Bool { words.contains { slug.contains($0) } }
        if has(["port", "harbor", "harbour", "bay", "coast", "dock", "isle", "island", "sea", "reef", "shore"]) { return "coast" }
        if has(["frost", "snow", "ice", "glacier", "mountain", "peak", "summit"]) { return "mountain" }
        if has(["forest", "wood", "grove", "jungle", "swamp", "hollow", "glade"]) { return "forest" }
        if has(["desert", "sand", "dune", "oasis", "canyon", "dust", "mesa"]) { return "desert" }
        return "meadow"
    }

    static func pretty(_ uid: String?) -> String? {
        guard let uid else { return nil }
        let parts = uid.split(separator: "-").map(String.init)
        guard parts.count > 2 else { return nil }
        return parts[1].replacingOccurrences(of: "_", with: " ").capitalized
    }
}
