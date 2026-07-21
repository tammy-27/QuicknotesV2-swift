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

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
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
        panel.minSize = NSSize(width: 420, height: 300)

        // Critical: allow panel to become key so keyboard shortcuts work
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
        let panelSize = panel.frame.size
        let x = buttonFrame.origin.x + (buttonFrame.width - panelSize.width) / 2
        let y = buttonFrame.origin.y - panelSize.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installOutsideClickMonitors()
    }

    private func hidePanel() {
        // Don't hide if preferences window is open and key
        if let key = NSApp.keyWindow, key != panel { return }
        panel.orderOut(nil)
        removeOutsideClickMonitors()
    }

    private func installOutsideClickMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panelWindow = self.panel else { return event }
            if event.window != panelWindow {
                // Don't close if another app window is clicked (e.g. preferences, folder picker)
                if event.window?.isKind(of: NSPanel.self) == false && event.window != nil {
                    return event
                }
                self.hidePanel()
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
