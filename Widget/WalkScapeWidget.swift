import WidgetKit
import SwiftUI

// MARK: data

struct Snapshot {
    var config: Config?
    var character: WS.Character?
    var today = 0
    var series: [(label: String, steps: Int)] = []
    var tracking = false
    var biome = "meadow"
}

struct Entry: TimelineEntry {
    let date: Date
    let snap: Snapshot
}

func loadSnapshot() async -> Snapshot {
    guard let cfg = Config.load() else { return Snapshot() }
    var s = Snapshot(config: cfg)
    if let c = await WS.fetchCharacter(id: cfg.characterId) {
        s.character = c
        let h = History.record(id: cfg.characterId, total: c.totalSteps)
        s.today = h.today; s.series = h.series; s.tracking = h.tracking
        s.biome = cfg.background == "auto" ? Biome.forLocation(c.locationUID) : cfg.background
    }
    return s
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        var s = Snapshot()
        s.config = Config(characterId: "demo", characterName: "Adventurer")
        s.character = WS.Character(id: "demo", name: "Adventurer", totalSteps: 1_234_567, totalLevel: 210,
                                   totalXP: 3_400_000, achievementPoints: 40,
                                   skills: [("foraging", 900_000), ("mining", 500_000), ("fishing", 300_000)],
                                   updatedAt: Date(), locationUID: nil)
        s.today = 8_412
        s.series = ["M", "T", "W", "T", "F", "S", "S"].enumerated().map { ($1, [4000, 9000, 6500, 12000, 3000, 15000, 8412][$0]) }
        return Entry(date: Date(), snap: s)
    }
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
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.38)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.14), lineWidth: 1))
    }
}

struct Caption: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(px(8.5, .bold)).tracking(0.8).foregroundStyle(.white.opacity(0.62)) }
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

struct Bars: View {
    let series: [(label: String, steps: Int)]
    var height: CGFloat = 40
    var body: some View {
        let mx = max(series.map(\.steps).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(series.enumerated()), id: \.offset) { i, d in
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(i == series.count - 1 ? gold : gold.opacity(0.5))
                        .frame(height: max(3, CGFloat(d.steps) / CGFloat(mx) * height))
                    Text(d.label).font(px(8, .bold)).foregroundStyle(.white.opacity(0.55))
                }.frame(maxWidth: .infinity)
            }
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry
    var snap: Snapshot { entry.snap }

    var body: some View {
        Group {
            if let c = snap.character {
                switch family {
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
            Text(c.name).font(px(12)).lineLimit(1)
            Spacer(minLength: 0)
            Caption("TODAY")
            Text(fmt(snap.today)).font(px(30)).foregroundStyle(gold)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text("\(fmt(c.totalSteps)) total").font(px(9, .bold)).foregroundStyle(.white.opacity(0.85))
                .minimumScaleFactor(0.7).lineLimit(1)
            Spacer(minLength: 4)
            SyncBadge(c: c)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    func medium(_ c: WS.Character) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk").foregroundStyle(gold)
                    Text(c.name).font(px(13)).lineLimit(1)
                }
                Caption("TOTAL STEPS")
                Text(fmt(c.totalSteps)).font(px(25)).minimumScaleFactor(0.5).lineLimit(1)
                HStack(spacing: 6) {
                    Text("TODAY").font(px(9, .bold)).foregroundStyle(.white.opacity(0.65))
                    Text(fmt(snap.today)).font(px(13)).foregroundStyle(gold)
                }
                Spacer(minLength: 0)
                SyncBadge(c: c)
            }
            VStack(alignment: .leading, spacing: 6) {
                Caption("LAST 7 DAYS")
                Bars(series: snap.series, height: 44)
                Text("Lv \(c.totalLevel) · \(short(c.totalXP)) XP").font(px(9, .bold)).foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    func large(_ c: WS.Character) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "figure.walk").foregroundStyle(gold)
                Text(c.name).font(px(15)).lineLimit(1)
                Spacer()
                SyncBadge(c: c)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Caption("TOTAL STEPS")
                    Text(fmt(c.totalSteps)).font(px(32)).minimumScaleFactor(0.5).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Caption("TODAY")
                    Text(fmt(snap.today)).font(px(24)).foregroundStyle(gold)
                }
            }
            HStack(spacing: 7) {
                Tile { stat("LEVEL", "\(c.totalLevel)") }
                Tile { stat("TOTAL XP", short(c.totalXP)) }
                Tile { stat("ACHIEV.", "\(c.achievementPoints)") }
            }
            Tile {
                VStack(alignment: .leading, spacing: 4) {
                    Caption("LAST 7 DAYS" + (snap.tracking ? "" : " · FILLS AS YOU WALK"))
                    Bars(series: snap.series, height: 34)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Caption("TOP SKILLS")
                let top = Array(c.skills.filter { $0.xp > 0 }.prefix(3)); let mx = max(top.first?.xp ?? 1, 1)
                ForEach(Array(top.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 6) {
                        Text(s.name.capitalized).font(px(10, .bold)).frame(width: 74, alignment: .leading)
                        GeometryReader { g in
                            Rectangle().fill(mint).frame(width: max(4, g.size.width * CGFloat(s.xp) / CGFloat(mx)), height: 7)
                                .frame(maxHeight: .infinity)
                        }.frame(height: 10)
                        Text(short(s.xp)).font(px(9, .bold)).frame(width: 40, alignment: .trailing)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    func stat(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Caption(t)
            Text(v).font(px(17))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
struct WalkScapeStepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WalkScapeSteps", provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("WalkScape Steps")
        .description("Your WalkScape steps and stats, right on the desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
