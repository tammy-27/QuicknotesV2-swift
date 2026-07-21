import Cocoa
import SwiftUI

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: PreferencesView())
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        // Fix 2: Always bring preferences ABOVE the notes panel
        if let prefWindow = window, let panel = NSApp.windows.first(where: { $0 is NSPanel }) {
            // Position preferences window centered on screen, above the panel
            prefWindow.center()
            // Set level above floating panel so it's never hidden behind it
            prefWindow.level = .floating + 1
            prefWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window?.center()
            window?.level = .floating + 1
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // When preferences closes, restore key focus to the notes panel
    func windowWillClose(_ notification: Notification) {
        NSApp.windows
            .first(where: { $0 is NSPanel && $0.isVisible })?
            .makeKeyAndOrderFront(nil)
    }
}
