import Foundation

/// The public API only reports lifetime steps, so the widget keeps its own small daily log
/// (per-day first/last total) and derives "today" and the 7-day chart from it.
/// Days before the widget was installed show as unknown unless a history-seed.json exists.
enum History {
    private static let key = "days.v1"
    private static let idKey = "days.id"
    private static let moveKey = "lastIncrease"
    private static let totalKey = "lastTotal"

    private static var dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    struct Day { var label: String; var steps: Int?; var isToday: Bool }
    struct Result { var today: Int; var series: [Day]; var movedRecently: Bool }

    /// Optional ~/.config/walkscape-widget/history-seed.json: {"2026-10-01": 6817, ...} fills days we never saw.
    private static func seed() -> [String: Int] {
        let url = Config.dir.appendingPathComponent("history-seed.json")
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    /// Optional corrections.json written by the setup app ("Calibrate today"): the in-game count for a day
    /// at a known lifetime total. Today's number is then that count plus whatever has been added since.
    private struct Correction: Codable { var date: String; var steps: Int; var atTotal: Int }
    private static func correction() -> Correction? {
        guard let data = try? Data(contentsOf: Config.dir.appendingPathComponent("corrections.json")) else { return nil }
        return try? JSONDecoder().decode(Correction.self, from: data)
    }

    static func record(id: String, total: Int, now: Date = Date()) -> Result {
        let d = UserDefaults.standard
        var days = (d.dictionary(forKey: key) as? [String: [Int]]) ?? [:]
        if d.string(forKey: idKey) != id {
            days = [:]; d.set(id, forKey: idKey); d.removeObject(forKey: moveKey); d.removeObject(forKey: totalKey)
        }

        if let prev = d.object(forKey: totalKey) as? Int, total > prev { d.set(now, forKey: moveKey) }
        d.set(total, forKey: totalKey)

        let todayKey = dayFormatter.string(from: now)
        if var t = days[todayKey] { t[1] = total; days[todayKey] = t } else { days[todayKey] = [total, total] }
        for k in days.keys.sorted().dropLast(21) { days.removeValue(forKey: k) }
        d.set(days, forKey: key)

        let ordered = days.keys.sorted()
        var delta: [String: Int] = [:]
        for (i, k) in ordered.enumerated() {
            let base = i > 0 ? days[ordered[i - 1]]![1] : days[k]![0]
            delta[k] = max(0, days[k]![1] - base)
        }
        if let c = correction(), c.date == todayKey { delta[todayKey] = c.steps + max(0, total - c.atTotal) }
        let seeded = seed()
        let cal = Calendar.current
        let wd = DateFormatter(); wd.dateFormat = "EEEEE"
        let series = (0..<7).reversed().map { back -> Day in
            let date = cal.date(byAdding: .day, value: -back, to: now)!
            let k = dayFormatter.string(from: date)
            return Day(label: wd.string(from: date), steps: delta[k] ?? seeded[k], isToday: back == 0)
        }
        let moved = (d.object(forKey: moveKey) as? Date).map { now.timeIntervalSince($0) < 10 * 60 } ?? false
        return Result(today: delta[todayKey] ?? 0, series: series, movedRecently: moved)
    }
}
