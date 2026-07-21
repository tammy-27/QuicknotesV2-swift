import Cocoa
import SwiftUI

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

        // Fix 1: Use a sensible fixed size that fits the content properly
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 500),
            styleMask: [
                .titled,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.isMovableByWindowBackground = true
        panel.contentViewController = NSHostingController(rootView: contentView)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = true
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.minSize = NSSize(width: 480, height: 360)

        // Fix 4: Must become key window so Cmd+A/C/V/X/Z work
        panel.becomesKeyOnlyIfNeeded = false
    }

    @objc func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        let buttonFrame = buttonWindow.frame
        let panelWidth = panel.frame.size.width
        let panelHeight = panel.frame.size.height

        // Fix 1: Position panel properly under menu bar icon, clamped to screen
        var x = buttonFrame.midX - panelWidth / 2
        var y = buttonFrame.minY - panelHeight - 6

        // Clamp to screen bounds
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            x = max(visibleFrame.minX + 4, min(x, visibleFrame.maxX - panelWidth - 4))
            y = max(visibleFrame.minY + 4, y)
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installOutsideClickMonitors()
    }

    private func hidePanel() {
        // Don't hide if any other app window (preferences, folder picker) is key
        if let key = NSApp.keyWindow, key != panel { return }
        panel.orderOut(nil)
        removeOutsideClickMonitors()
    }

    private func installOutsideClickMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panelWindow = self.panel else { return event }
            // Only dismiss if click is outside our panel AND no other app window is open
            if event.window != panelWindow {
                let otherWin = event.window
                // Keep open if it's the preferences window or any child window
                let isOurWindow = otherWin?.parent == panelWindow ||
                    panelWindow.childWindows?.contains(where: { $0 == otherWin }) == true
                if !isOurWindow {
                    self.hidePanel()
                }
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func removeOutsideClickMonitors() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }
}
