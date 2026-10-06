import Foundation

/// The public API only exposes lifetime steps, so the widget keeps its own tiny daily log
/// (per-day first/last total) and derives "today" and the 7-day chart from it.
enum History {
    private static let key = "days.v1"
    private static let idKey = "days.id"

    private static var dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    struct Result { var today: Int; var series: [(label: String, steps: Int)]; var tracking: Bool }

    static func record(id: String, total: Int, now: Date = Date()) -> Result {
        let d = UserDefaults.standard
        var days = (d.dictionary(forKey: key) as? [String: [Int]]) ?? [:]
        if d.string(forKey: idKey) != id { days = [:]; d.set(id, forKey: idKey) }

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
        let cal = Calendar.current
        let wd = DateFormatter(); wd.dateFormat = "EEEEE"
        let series = (0..<7).reversed().map { back -> (label: String, steps: Int) in
            let date = cal.date(byAdding: .day, value: -back, to: now)!
            return (wd.string(from: date), delta[dayFormatter.string(from: date)] ?? 0)
        }
        return Result(today: delta[todayKey] ?? 0, series: series, tracking: ordered.count > 1)
    }
}
