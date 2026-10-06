import AppKit

/// Makes a downloaded copy of the app install itself, so no Terminal is needed:
/// moves to ~/Applications, clears macOS's "downloaded from the internet" flag,
/// and registers the widget with the system. Only runs outside the sandbox (this is the host app).
enum SelfInstall {
    private static var testDir: String? { ProcessInfo.processInfo.environment["WALKSCAPE_INSTALL_DIR"] }

    @discardableResult
    private static func sh(_ tool: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
    }

    /// Returns true if the app relaunched itself from Applications and this process should exit.
    static func run() -> Bool {
        let fm = FileManager.default
        let bundle = Bundle.main.bundlePath
        let destDir = testDir ?? (Config.realHome + "/Applications")
        let inApplications = bundle.hasPrefix("/Applications/") || bundle.hasPrefix(destDir + "/")

        if !inApplications {
            let target = destDir + "/WalkScape Widget.app"
            try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
            sh("/usr/bin/pkill", ["-f", target + "/Contents/PlugIns"])
            try? fm.removeItem(atPath: target)
            guard (try? fm.copyItem(atPath: bundle, toPath: target)) != nil else { return false }
            sh("/usr/bin/xattr", ["-cr", target])
            register(target)
            sh("/usr/bin/open", [target])
            return true
        }
        sh("/usr/bin/xattr", ["-cr", bundle])
        register(bundle)
        return false
    }

    private static func register(_ app: String) {
        guard testDir == nil else { return }
        let appex = app + "/Contents/PlugIns/WalkScapeSteps.appex"
        let marker = Config.dir.appendingPathComponent("registered-\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0")")
        if FileManager.default.fileExists(atPath: marker.path) { return }
        sh("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", app])
        sh("/usr/bin/pluginkit", ["-a", appex])
        if let id = Bundle(path: appex)?.bundleIdentifier { sh("/usr/bin/pluginkit", ["-e", "use", "-i", id]) }
        sh("/usr/bin/killall", ["chronod"])
        try? FileManager.default.createDirectory(at: Config.dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: marker.path, contents: nil)
    }
}
