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
                GroupBox("Add it to your desktop") {
                    Text("Right-click the desktop → Edit Widgets → search “WalkScape” → drag a size onto the desktop.")
                        .font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
            }
            Spacer(minLength: 0)
            Text("No password needed: WalkScape character stats are public. Unofficial fan project, not affiliated with WalkScape.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 480, height: 560)
    }
}

@main
struct WalkScapeWidgetApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }.windowResizability(.contentSize)
    }
}
