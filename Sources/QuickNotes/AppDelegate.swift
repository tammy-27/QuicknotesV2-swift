import Cocoa
import SwiftUI

// Fix: SwiftUI controls hosted in a .nonactivatingPanel silently eat their first
// click whenever the panel isn't already key (e.g. after the color panel, the
// Preferences window, or another app took focus). AppKit asks the hit-tested
// view whether it "accepts first mouse" before it will treat a click as a real
// action rather than just a focus/activation click; NSHostingView says no by
// default. Overriding it here means every SwiftUI button underneath (heading,
// bold/italic, sidebar toggle, etc.) responds on the very first click.
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "square.and.pencil",
                accessibilityDescription: "QuickNotes"
            )
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        let contentView = ContentView(onQuit: { [weak self] in
            self?.removeOutsideClickMonitors()
            NSApplication.shared.terminate(nil)
        })

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.contentView = ClickThroughHostingView(rootView: contentView)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = true
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.minSize = NSSize(width: 500, height: 380)
        panel.becomesKeyOnlyIfNeeded = false
    }

    // Fix: menu bar icon click always hides/unhides the notes panel, full stop —
    // it no longer defers to the "keep panel open while color panel/prefs are
    // open" guard. That guard still applies to the outside-click auto-dismiss
    // below, just not to an explicit click on the icon itself.
    @objc func togglePanel(_ sender: Any?) {
        if panel.isVisible { hidePanel(force: true) } else { showPanel() }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.frame
        let panelWidth  = panel.frame.size.width
        let panelHeight = panel.frame.size.height
        var x = buttonFrame.midX - panelWidth / 2
        var y = buttonFrame.minY - panelHeight - 6
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            x = max(vf.minX + 4, min(x, vf.maxX - panelWidth - 4))
            y = max(vf.minY + 4, y)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installOutsideClickMonitors()
    }

    private func hidePanel(force: Bool = false) {
        // Fix 4: Never auto-hide panel (outside click) when color panel or any
        // floating window is open. An explicit icon click (force: true) always
        // goes through regardless.
        if !force {
            let openWindows = NSApp.windows.filter { $0.isVisible && $0 != panel }
            if !openWindows.isEmpty { return }
        }
        panel.orderOut(nil)
        removeOutsideClickMonitors()
    }

    private func installOutsideClickMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panelWindow = self.panel else { return event }
            if event.window != panelWindow {
                // Fix 4: Don't close if color panel, preferences, or any other app window is open
                let allVisible = NSApp.windows.filter { $0.isVisible && $0 != panelWindow }
                if allVisible.isEmpty {
                    self.hidePanel()
                }
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // Fix 4: Don't close on global click if color panel or prefs window is open
            let allVisible = NSApp.windows.filter { $0.isVisible && $0 != self?.panel }
            if allVisible.isEmpty {
                self?.hidePanel()
            }
        }
    }

    private func removeOutsideClickMonitors() {
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor  = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }
}
