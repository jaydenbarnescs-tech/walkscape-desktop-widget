import WidgetKit
import SwiftUI

// MARK: data

struct Snapshot {
    var config: Config?
    var character: WS.Character?
    var portrait: Data?
    var today = 0
    var series: [History.Day] = []
    var biome = "meadow"
    var locationName: String?
    var activityName: String?
    var moving = false
}

extension Snapshot {
    /// Sample data for the widget gallery and screenshots.
    static var demo: Snapshot {
        var s = Snapshot()
        s.config = Config(characterId: "demo", characterName: "Adventurer")
        s.character = WS.Character(id: "demo", name: "Adventurer", totalSteps: 1_234_567, totalLevel: 210,
                                   totalXP: 3_400_000, achievementPoints: 40,
                                   skills: [("foraging", 904_000), ("mining", 520_000), ("fishing", 310_000), ("cooking", 120_000)],
                                   updatedAt: Date(), locationUID: nil, currentActivity: nil)
        s.today = 8_412
        s.locationName = "Port Skildar"
        s.activityName = "Small sail repair"
        let vals = [4000, 9000, 6500, 12000, 3000, 15000, 8412]
        s.series = ["M", "T", "W", "T", "F", "S", "S"].enumerated().map { History.Day(label: $1, steps: vals[$0], isToday: $0 == 6) }
        return s
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snap: Snapshot
}

func loadSnapshot() async -> Snapshot {
    guard let cfg = Config.load() else { return Snapshot() }
    var s = Snapshot(config: cfg)
    async let names = WS.gameNames()
    async let portrait = WS.fetchPortrait(id: cfg.characterId)
    if let c = await WS.fetchCharacter(id: cfg.characterId) {
        s.character = c
        let h = History.record(id: cfg.characterId, total: c.totalSteps)
        s.today = h.today; s.series = h.series; s.moving = h.movedRecently
        s.biome = cfg.background == "auto" ? Biome.forLocation(c.locationUID) : cfg.background
        let n = await names
        s.locationName = c.locationUID.flatMap { n.locations[$0] } ?? Biome.pretty(c.locationUID)
        s.activityName = c.currentActivity.flatMap { n.activities[$0] }
        s.portrait = await portrait
    }
    return s
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), snap: .demo) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(Entry(date: Date(), snap: await loadSnapshot())) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let s = await loadSnapshot()
            let next = Date().addingTimeInterval(s.character == nil ? 60 : 5 * 60)
            completion(Timeline(entries: [Entry(date: Date(), snap: s)], policy: .after(next)))
        }
    }
}

// MARK: style

func px(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font { .system(size: size, weight: weight, design: .monospaced) }

struct Backdrop: View {
    let biome: String
    var body: some View {
        ZStack {
            if let url = Bundle.main.url(forResource: "bg-\(biome)", withExtension: "jpg"),
               let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().interpolation(.none).scaledToFill()
            } else {
                LinearGradient(colors: [Color(red: 0.16, green: 0.36, blue: 0.30), ink], startPoint: .top, endPoint: .bottom)
            }
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.28), .black.opacity(0.62)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

struct Tile<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.38)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.14), lineWidth: 1))
    }
}

struct Caption: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(px(8.5, .bold)).tracking(0.8).foregroundStyle(.white.opacity(0.62)) }
}

struct Portrait: View {
    let data: Data?
    let size: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22)
        Group {
            if let d = data, let img = NSImage(data: d) {
                Image(nsImage: img).resizable().interpolation(.none).scaledToFill()
            } else {
                ZStack { Rectangle().fill(.black.opacity(0.45)); Image(systemName: "person.fill").foregroundStyle(gold) }
            }
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.35))
        .clipShape(shape)
        .overlay(shape.stroke(gold.opacity(0.85), lineWidth: 1.5))
    }
}

struct SyncBadge: View {
    let c: WS.Character
    var body: some View {
        let live = c.updatedAt.map { Date().timeIntervalSince($0) < 180 } ?? false
        HStack(spacing: 4) {
            Circle().fill(live ? mint : .orange).frame(width: 6, height: 6)
            if live { Text("LIVE").font(px(9)) }
            else if let t = c.updatedAt { Text(t, style: .relative).font(px(9, .bold)).lineLimit(1) }
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(.black.opacity(0.4)))
    }
}

struct StatusLine: View {
    let snap: Snapshot
    var body: some View {
        let loc = snap.locationName
        let text: String = {
            if let a = snap.activityName { return loc.map { "\(a) · \($0)" } ?? a }
            if snap.moving { return loc.map { "Walking · near \($0)" } ?? "Walking" }
            return loc.map { "In \($0)" } ?? "Resting"
        }()
        HStack(spacing: 4) {
            Image(systemName: snap.activityName != nil ? "hammer.fill" : (snap.moving ? "figure.walk" : "mappin.and.ellipse"))
                .font(.system(size: 9, weight: .bold)).foregroundStyle(mint)
            Text(text).font(px(9.5, .bold)).foregroundStyle(.white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

struct Bars: View {
    let series: [History.Day]
    var height: CGFloat = 40
    var body: some View {
        let mx = max(series.compactMap(\.steps).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(series.enumerated()), id: \.offset) { _, d in
                VStack(spacing: 2) {
                    Text(d.steps.map(short) ?? "–").font(px(8, .bold))
                        .foregroundStyle(d.isToday ? gold : .white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.6)
                    Rectangle()
                        .fill(d.isToday ? gold : gold.opacity(d.steps == nil ? 0.15 : 0.5))
                        .frame(height: max(3, CGFloat(d.steps ?? 0) / CGFloat(mx) * height))
                    Text(d.label).font(px(8, .bold)).foregroundStyle(.white.opacity(0.55))
                }.frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 26, alignment: .bottom)
    }
}

struct SkillRow: View {
    let name: String
    let xp: Int
    var body: some View {
        let p = Levels.skill(xp: xp)
        HStack(spacing: 6) {
            Text(name.capitalized).font(px(10, .bold)).frame(width: 68, alignment: .leading).lineLimit(1)
            Text("Lv \(p.level)").font(px(10)).foregroundStyle(gold).frame(width: 36, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.14))
                    Rectangle().fill(mint).frame(width: max(3, g.size.width * p.fraction))
                }.frame(height: 7).frame(maxHeight: .infinity)
            }.frame(height: 10)
            Text(p.toNext.map { "\(short($0)) to \(p.level + 1)" } ?? "MAX").font(px(8.5, .bold))
                .frame(width: 66, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry
    var forced: WidgetFamily? = nil
    var snap: Snapshot { entry.snap }

    var body: some View {
        Group {
            if let c = snap.character {
                switch forced ?? family {
                case .systemSmall: small(c)
                case .systemMedium: medium(c)
                default: large(c)
                }
            } else {
                setup
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { Backdrop(biome: snap.biome) }
    }

    var setup: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.walk").font(.system(size: 26, weight: .bold)).foregroundStyle(gold)
            Text(snap.config == nil ? "Choose your character" : "Can't reach WalkScape")
                .font(px(12)).multilineTextAlignment(.center)
            Text(snap.config == nil ? "Open the “WalkScape Widget” app" : "Retrying soon")
                .font(px(9, .semibold)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
    }

    func small(_ c: WS.Character) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Portrait(data: snap.portrait, size: 26)
                Text(c.name).font(px(12)).lineLimit(1)
            }
            Spacer(minLength: 0)
            Caption("TODAY")
            Text(fmt(snap.today)).font(px(28)).foregroundStyle(gold).minimumScaleFactor(0.5).lineLimit(1)
            Text("\(fmt(c.totalSteps)) total").font(px(9, .bold)).foregroundStyle(.white.opacity(0.85))
                .minimumScaleFactor(0.7).lineLimit(1)
            Spacer(minLength: 4)
            StatusLine(snap: snap)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    func medium(_ c: WS.Character) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Portrait(data: snap.portrait, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.name).font(px(13)).lineLimit(1)
                        let p = Levels.character(steps: c.totalSteps)
                        Text("Lv \(p.level) · \(fmt(c.totalSteps)) steps").font(px(8.5, .bold)).foregroundStyle(.white.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 2)
                Caption("TODAY")
                Text(fmt(snap.today)).font(px(26)).foregroundStyle(gold).minimumScaleFactor(0.5).lineLimit(1)
                Spacer(minLength: 2)
                StatusLine(snap: snap)
                SyncBadge(c: c)
            }
            VStack(alignment: .leading, spacing: 6) {
                Caption("LAST 7 DAYS")
                Bars(series: snap.series, height: 46)
            }
        }
    }

    func large(_ c: WS.Character) -> some View {
        let cl = Levels.character(steps: c.totalSteps)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Portrait(data: snap.portrait, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(px(15)).lineLimit(1)
                    StatusLine(snap: snap)
                }
                Spacer()
                SyncBadge(c: c)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Caption("TOTAL STEPS")
                    Text(fmt(c.totalSteps)).font(px(30)).minimumScaleFactor(0.5).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Caption("TODAY")
                    Text(fmt(snap.today)).font(px(22)).foregroundStyle(gold)
                }
            }
            HStack(spacing: 7) {
                Tile { VStack(alignment: .leading, spacing: 1) {
                    Caption("LEVEL")
                    Text("\(cl.level)").font(px(16))
                    Text("\(short(cl.toNext ?? 0)) steps to \(cl.level + 1)").font(px(7.5, .bold)).foregroundStyle(.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.6)
                }.frame(maxWidth: .infinity, alignment: .leading) }
                Tile { VStack(alignment: .leading, spacing: 1) {
                    Caption("SKILLS TOTAL")
                    Text("\(c.totalLevel)").font(px(16))
                    Text("\(short(c.totalXP)) XP").font(px(7.5, .bold)).foregroundStyle(.white.opacity(0.65))
                }.frame(maxWidth: .infinity, alignment: .leading) }
            }
            Tile {
                VStack(alignment: .leading, spacing: 3) {
                    Caption("LAST 7 DAYS")
                    Bars(series: snap.series, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Caption("SKILLS · LEVEL AND XP TO NEXT")
                ForEach(Array(c.skills.filter { $0.xp > 0 }.prefix(4).enumerated()), id: \.offset) { _, s in
                    SkillRow(name: s.name, xp: s.xp)
                }
            }
            if let t = c.updatedAt, Date().timeIntervalSince(t) > 600 {
                Text("Open WalkScape on your phone to sync").font(px(8.5, .bold)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
    }
}

@main
struct WalkScapeStepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WalkScapeSteps", provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Steps Widget for WalkScape")
        .description("Your WalkScape steps and stats, right on the desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
