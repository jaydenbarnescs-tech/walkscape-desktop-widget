import Foundation

/// Level maths. Skill levels use WalkScape's cumulative XP table (levels 1–99);
/// character level comes from lifetime steps using the formula on the official wiki.
enum Levels {
    static let xpTable = [0,83,174,276,388,512,650,801,969,1154,1358,1584,1833,2107,2411,2746,3115,3523,3973,4470,
        5018,5624,6291,7028,7842,8740,9730,10824,12031,13363,14833,16456,18247,20224,22406,24815,27473,30408,
        33648,37224,41171,45529,50339,55649,61512,67983,75127,83014,91721,101333,111945,123660,136594,150872,
        166636,184040,203254,224466,247886,273742,302288,333804,368599,407015,449428,496254,547953,605032,668051,
        737627,814445,899257,992895,1096278,1210421,1336443,1475581,1629200,1798808,1986068,2192818,2421087,2673114,
        2951373,3258594,3597792,3972294,4385776,4842295,5346332,5902831,6517253,7195629,7944614,8771558,9684577,
        10692629,11805606,13034431]

    struct Progress {
        var level: Int
        var toNext: Int?        // XP or steps still needed; nil at max level
        var fraction: Double    // 0...1 through the current level
    }

    static func skill(xp: Int) -> Progress {
        var lv = 1
        for (i, x) in xpTable.enumerated() where xp >= x { lv = i + 1 }
        guard lv < xpTable.count else { return Progress(level: lv, toNext: nil, fraction: 1) }
        let lo = xpTable[lv - 1], hi = xpTable[lv]
        return Progress(level: lv, toNext: hi - xp, fraction: Double(xp - lo) / Double(hi - lo))
    }

    // Character level: steps needed for level L = floor(sum_{i=1...L} floor(i + 300·2^(i/7)) / 4) · 4.6
    private static func stepsFor(_ level: Int) -> Double {
        guard level > 0 else { return 0 }
        var total = 0.0
        for i in 1...level { total += (Double(i) + 300 * pow(2, Double(i) / 7)).rounded(.down) }
        return (total / 4).rounded(.down) * 4.6
    }

    static func character(steps: Int) -> Progress {
        var lv = 1
        while stepsFor(lv) <= Double(steps) && lv < 500 { lv += 1 }
        let lo = stepsFor(lv - 1), hi = stepsFor(lv)
        return Progress(level: lv, toNext: Int((hi - Double(steps)).rounded(.up)),
                        fraction: max(0, min(1, (Double(steps) - lo) / (hi - lo))))
    }
}
