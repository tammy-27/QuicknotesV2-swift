import Foundation
import ServiceManagement

final class LoginItemManager {
    static let shared = LoginItemManager()

    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                // Fallback: check LaunchAgents plist existence
                return launchAgentPlistExists()
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("LoginItem error: \(error)")
                }
            } else {
                newValue ? installLaunchAgent() : removeLaunchAgent()
            }
        }
    }

    // MARK: - macOS 12 fallback via LaunchAgent plist

    private var launchAgentURL: URL {
        let support = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent("com.tanmay.quicknotes.plist")
    }

    private func launchAgentPlistExists() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    private func installLaunchAgent() {
        guard let execURL = Bundle.main.executableURL else { return }
        let plist: [String: Any] = [
            "Label": "com.tanmay.quicknotes",
            "ProgramArguments": [execURL.path],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        try? FileManager.default.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try? data?.write(to: launchAgentURL)
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(at: launchAgentURL)
    }
}
