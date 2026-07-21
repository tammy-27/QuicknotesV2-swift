import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var colorScheme: ColorScheme? {
        didSet { UserDefaults.standard.set(colorSchemeRaw, forKey: "qn.colorScheme") }
    }
    @Published var saveLocation: URL {
        didSet {
            UserDefaults.standard.set(saveLocation.path, forKey: "qn.saveLocation")
        }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "qn.fontSize") }
    }

    private var colorSchemeRaw: String {
        switch colorScheme {
        case .dark: return "dark"
        case .light: return "light"
        default: return "system"
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "qn.colorScheme") ?? "system"
        switch raw {
        case "dark": colorScheme = .dark
        case "light": colorScheme = .light
        default: colorScheme = nil
        }

        let savedPath = UserDefaults.standard.string(forKey: "qn.saveLocation")
        if let p = savedPath {
            saveLocation = URL(fileURLWithPath: p)
        } else {
            saveLocation = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("QuickNotes")
        }

        let fs = UserDefaults.standard.double(forKey: "qn.fontSize")
        fontSize = fs > 0 ? fs : 13
    }
}
