import SwiftUI
import WidgetKit

@MainActor
final class Model: ObservableObject {
    @Published var config = Config.load()
    @Published var current: WS.Character?
    @Published var query = ""
    @Published var results: [WS.DirectoryEntry] = []
    @Published var busy = false
    @Published var status = ""
    @Published var directory: [WS.DirectoryEntry] = WS.cachedDirectory() ?? []

    init() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { await refreshCurrent() }
    }

    func refreshCurrent() async {
        guard let cfg = config else { current = nil; return }
        current = await WS.fetchCharacter(id: cfg.characterId)
    }

    func search() async {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        results = []; busy = true; defer { busy = false }
        if let id = WS.parseIdentifier(input) {
            status = "Looking up that profile…"
            if let c = await WS.fetchCharacter(id: id) {
                results = [.init(id: c.id, name: c.name, steps: c.totalSteps)]
                status = ""
            } else { status = "No WalkScape character found for that link." }
            return
        }
        if directory.isEmpty {
            status = "Loading the player list (first time only, about a minute)…"
            directory = await WS.loadDirectory { n in Task { @MainActor in self.status = "Loading the player list… \(n) players" } }
        }
        results = WS.search(input, in: directory)
        status = results.isEmpty
            ? "No match. Names are matched as written in game; if you hide your steps, paste your walkstats.app link instead."
            : ""
    }

    func choose(_ e: WS.DirectoryEntry) async {
        busy = true; defer { busy = false }
        guard let c = await WS.fetchCharacter(id: e.id) else { status = "Couldn't load that character, try again."; return }
        let cfg = Config(characterId: c.id, characterName: c.name, background: config?.background ?? "auto")
        do { try cfg.save() } catch { status = "Couldn't save settings: \(error.localizedDescription)"; return }
        config = cfg; current = c; results = []; query = ""; status = ""
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Lets the user fix "today" using the number on the game's Stats page.
    func calibrate(todaySteps: Int) async {
        guard let cfg = config, let c = await WS.fetchCharacter(id: cfg.characterId) else { status = "Couldn't reach WalkScape."; return }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let corr = ["date": f.string(from: Date()), "steps": todaySteps, "atTotal": c.totalSteps] as [String: Any]
        guard let data = try? JSONSerialization.data(withJSONObject: corr) else { return }
        try? FileManager.default.createDirectory(at: Config.dir, withIntermediateDirectories: true)
        try? data.write(to: Config.dir.appendingPathComponent("corrections.json"), options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
        status = "Today set to \(fmt(todaySteps)). The widget will update shortly."
    }

    func setBackground(_ b: String) {
        guard var cfg = config else { return }
        cfg.background = b
        try? cfg.save(); config = cfg
        WidgetCenter.shared.reloadAllTimelines()
    }

    func signOut() {
        Config.clear(); config = nil; current = nil
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct SetupView: View {
    @StateObject var m = Model()
    @State private var calibration = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk").font(.system(size: 26, weight: .bold)).foregroundStyle(gold)
                VStack(alignment: .leading) {
                    Text("WalkScape Widget").font(.title2.bold())
                    Text("Your steps and stats on the macOS desktop").font(.callout).foregroundStyle(.secondary)
                }
            }

            if let cfg = m.config {
                GroupBox {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Signed in as").font(.caption).foregroundStyle(.secondary)
                            Text(cfg.characterName).font(.title3.bold())
                            if let c = m.current {
                                Text("\(fmt(c.totalSteps)) steps · level \(c.totalLevel)").foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Sign out") { m.signOut() }
                    }.padding(4)
                }
                Picker("Background", selection: Binding(get: { cfg.background }, set: { m.setBackground($0) })) {
                    Text("Automatic (matches your location)").tag("auto")
                    ForEach(Biome.all, id: \.self) { Text($0.capitalized).tag($0) }
                }
                Divider()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(m.config == nil ? "Find your character" : "Switch character").font(.headline)
                HStack {
                    TextField("Character name, or paste your walkstats.app link", text: $m.query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await m.search() } }
                    Button("Search") { Task { await m.search() } }.disabled(m.busy)
                }
                if m.busy { ProgressView().controlSize(.small) }
                if !m.status.isEmpty { Text(m.status).font(.callout).foregroundStyle(.secondary) }
                ForEach(m.results, id: \.id) { r in
                    Button { Task { await m.choose(r) } } label: {
                        HStack {
                            Text(r.name).bold()
                            Spacer()
                            Text("\(fmt(r.steps)) steps").foregroundStyle(.secondary)
                        }.padding(8).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                }
            }

            if m.config != nil {
                GroupBox("Today's steps look off?") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The widget only learns your steps when the game syncs, so a day can be off. Type today's number from the game's Stats page (Daily steps) to fix it.")
                            .font(.callout).foregroundStyle(.secondary)
                        HStack {
                            TextField("Today's steps in the game", text: $calibration).textFieldStyle(.roundedBorder)
                            Button("Set") {
                                if let n = Int(calibration.filter(\.isNumber)) { Task { await m.calibrate(todaySteps: n); calibration = "" } }
                            }
                        }
                    }.padding(4)
                }
                GroupBox("Add it to your desktop") {
                    Text("Right-click the desktop → Edit Widgets → search “WalkScape” → drag a size onto the desktop.")
                        .font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("No password needed: WalkScape character stats are public.")
                Text("WalkScape © Not a Cult Oy. This is an unofficial fan project, not affiliated with or endorsed by WalkScape.")
                Link("Play WalkScape: walkscape.app", destination: URL(string: "https://walkscape.app")!)
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 480, height: 640)
    }
}

@main
struct WalkScapeWidgetApp: App {
    init() { if SelfInstall.run() { exit(0) } }
    var body: some Scene {
        WindowGroup { SetupView() }.windowResizability(.contentSize)
    }
}
