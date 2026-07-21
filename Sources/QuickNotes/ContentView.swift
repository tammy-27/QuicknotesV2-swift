import SwiftUI
import AppKit

// MARK: - Root

struct ContentView: View {
    @StateObject private var store = NoteStore()
    @ObservedObject private var settings = AppSettings.shared
    @State private var sidebarVisible = true
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                SidebarView(store: store)
                    .frame(width: 210)           // Fix 1: wider sidebar
                    .transition(.move(edge: .leading))
                Divider()
            }
            EditorPane(store: store, onQuit: onQuit, sidebarVisible: $sidebarVisible)
        }
        .frame(minWidth: sidebarVisible ? 680 : 460, minHeight: 420)  // Fix 1: bigger default
        .preferredColorScheme(settings.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: sidebarVisible)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var store: NoteStore
    @State private var showNewFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { PreferencesWindowController.shared.show() }) {
                    Image(systemName: "gearshape").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Preferences")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundColor(.secondary)
                TextField("Search", text: $store.searchQuery)
                    .font(.system(size: 11)).textFieldStyle(.plain)
                if !store.searchQuery.isEmpty {
                    Button(action: { store.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)
            .padding(.horizontal, 8).padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FolderRow(label: "All Notes", icon: "note.text",
                              count: store.notes.count,
                              isSelected: store.selectedFolderID == nil) {
                        store.selectedFolderID = nil
                    }

                    if !store.folders.isEmpty {
                        Text("FOLDERS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)
                    }

                    ForEach(store.folders) { folder in
                        FolderRow(label: folder.name, icon: "folder",
                                  count: folder.noteIDs.count,
                                  isSelected: store.selectedFolderID == folder.id) {
                            store.selectedFolderID = folder.id
                        }
                        .contextMenu {
                            Button("Delete Folder", role: .destructive) { store.deleteFolder(folder) }
                        }
                    }

                    if showNewFolder {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 11)).foregroundColor(.accentColor)
                            TextField("Folder name", text: $newFolderName)
                                .font(.system(size: 12)).textFieldStyle(.plain)
                                .onSubmit {
                                    if !newFolderName.isEmpty { store.createFolder(name: newFolderName) }
                                    newFolderName = ""; showNewFolder = false
                                }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5)
                    }

                    Button(action: { showNewFolder.toggle() }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                            .font(.system(size: 11)).foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain).padding(.horizontal, 12).padding(.top, 6)

                    Divider().padding(.vertical, 6)

                    ForEach(store.filteredNotes) { note in
                        NoteRow(note: note, isSelected: store.selectedNoteID == note.id)
                            .onTapGesture { store.selectNote(note) }
                            .contextMenu {
                                if !store.folders.isEmpty {
                                    Menu("Move to Folder") {
                                        Button("No Folder") { store.moveNote(note, toFolder: nil) }
                                        ForEach(store.folders) { f in
                                            Button(f.name) { store.moveNote(note, toFolder: f.id) }
                                        }
                                    }
                                }
                                Divider()
                                Button("Delete Note", role: .destructive) { store.deleteNote(note) }
                            }
                    }
                }
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                Button(action: { store.createNote() }) {
                    Image(systemName: "square.and.pencil").font(.system(size: 13))
                }
                .buttonStyle(.plain).foregroundColor(.accentColor).help("New Note")
                Spacer()
                Text("\(store.notes.count) note\(store.notes.count == 1 ? "" : "s")")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct FolderRow: View {
    let label: String; let icon: String; let count: Int
    let isSelected: Bool; let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .accentColor).frame(width: 14)
                Text(label).font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
                Text("\(count)").font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : (hovering ? Color.primary.opacity(0.06) : Color.clear))
            .cornerRadius(6).padding(.horizontal, 4)
        }
        .buttonStyle(.plain).onHover { hovering = $0 }
    }
}

struct NoteRow: View {
    let note: Note; let isSelected: Bool
    @State private var hovering = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary).lineLimit(1)
            Text(note.preview.isEmpty ? "No content" : note.preview)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor : (hovering ? Color.primary.opacity(0.06) : Color.clear))
        .cornerRadius(6).padding(.horizontal, 4)
        .onHover { hovering = $0 }
    }
}

// MARK: - Editor Pane

struct EditorPane: View {
    @ObservedObject var store: NoteStore
    var onQuit: () -> Void
    @Binding var sidebarVisible: Bool
    @ObservedObject private var settings = AppSettings.shared
    @State private var toolbarFontSize: Double = AppSettings.shared.fontSize

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────────
            HStack(spacing: 2) {

                // Sidebar toggle
                ToolbarIconButton(systemName: "sidebar.left",
                                  isActive: sidebarVisible,
                                  help: sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    withAnimation { sidebarVisible.toggle() }
                }

                ToolbarDivider()

                // Fix 7: Heading as a compact dropdown
                HeadingMenu { style in
                    store.applyHeading(style)
                }

                // Bold, Italic, Underline
                ToolbarIconButton(systemName: "bold",      help: "Bold (select text)") { store.toggleBold() }
                ToolbarIconButton(systemName: "italic",    help: "Italic")             { store.toggleItalic() }
                ToolbarIconButton(systemName: "underline", help: "Underline")          { store.toggleUnderline() }

                ToolbarDivider()

                // Font size − n +
                ToolbarStepButton(icon: "minus") {
                    toolbarFontSize = max(8, toolbarFontSize - 1)
                    store.applyFontSize(CGFloat(toolbarFontSize))
                }
                Text("\(Int(toolbarFontSize))")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .frame(width: 24, alignment: .center)
                ToolbarStepButton(icon: "plus") {
                    toolbarFontSize = min(96, toolbarFontSize + 1)
                    store.applyFontSize(CGFloat(toolbarFontSize))
                }

                // Font color
                ColorPickerButton(help: "Font Color") { color in
                    store.applyFontColor(color)
                }

                ToolbarDivider()

                // Fix 5: No checkbox — only bullets and numbers
                ToolbarIconButton(systemName: "list.bullet", help: "Bullet list")   { store.toggleBullets() }
                ToolbarIconButton(systemName: "list.number", help: "Numbered list") { store.toggleNumbers() }

                Spacer()

                Text(store.savedLabel).font(.system(size: 10)).foregroundColor(.secondary)

                ToolbarIconButton(systemName: "power", help: "Quit QuickNotes") { onQuit() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if store.selectedNote != nil {
                RichTextEditor(
                    text: $store.currentAttributedText,
                    coordinatorRef: $store.coordinator,
                    fontSize: toolbarFontSize
                )
                .onAppear {
                    store.coordinator?.onChange = { [weak store] attr in
                        store?.textDidChange(attr)
                    }
                    toolbarFontSize = settings.fontSize
                }
            } else {
                Spacer()
                Text("No note selected").foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Toolbar helpers

struct ToolbarIconButton: View {
    let systemName: String
    var isActive: Bool = false
    let help: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(5)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .frame(width: 1, height: 16)
            .foregroundColor(Color.primary.opacity(0.15))
            .padding(.horizontal, 3)
    }
}

// Fix 7: Heading control collapsed into a single dropdown (was 4 separate
// buttons side by side, which is most of what made the toolbar feel too wide)
struct HeadingMenu: View {
    let onSelect: (HeadingStyle) -> Void
    @State private var active: HeadingStyle = .body
    @State private var hovering = false

    var body: some View {
        Menu {
            ForEach(HeadingStyle.allCases, id: \.self) { style in
                Button {
                    active = style
                    onSelect(style)
                } label: {
                    if active == style {
                        Label(style.rawValue == "Body" ? "Body (Normal text)" : "Heading \(style.rawValue)",
                              systemImage: "checkmark")
                    } else {
                        Text(style.rawValue == "Body" ? "Body (Normal text)" : "Heading \(style.rawValue)")
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(active.rawValue)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .frame(width: 56, height: 22)
            .background(hovering ? Color.primary.opacity(0.1) : Color.primary.opacity(0.06))
            .cornerRadius(5)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { hovering = $0 }
        .help("Heading Style")
    }
}

struct ToolbarStepButton: View {
    let icon: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 20, height: 22)
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.1) : Color.primary.opacity(0.06))
        .cornerRadius(4)
        .onHover { hovering = $0 }
    }
}

// Fix 4: Color picker — keeps panel open, live color changes
struct ColorPickerButton: View {
    let help: String
    let onColorPicked: (NSColor) -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: openColorPanel) {
            Image(systemName: "paintpalette")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(5)
        .onHover { hovering = $0 }
        .help(help)
        .onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)) { _ in
            if NSColorPanel.shared.isVisible {
                onColorPicked(NSColorPanel.shared.color)
            }
        }
    }

    private func openColorPanel() {
        let panel = NSColorPanel.shared
        panel.isContinuous = true   // Fix 4: live updates as cursor moves
        panel.showsAlpha   = false
        panel.orderFront(nil)
        // Fix 4: don't steal first responder — panel floats independently
        panel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Preferences

struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtStartup = LoginItemManager.shared.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PrefSectionHeader("Appearance")

            PrefRow(label: "Theme") {
                Picker("", selection: Binding(
                    get: {
                        switch settings.colorScheme {
                        case .dark:  return "dark"
                        case .light: return "light"
                        default:     return "system"
                        }
                    },
                    set: {
                        switch $0 {
                        case "dark":  settings.colorScheme = .dark
                        case "light": settings.colorScheme = .light
                        default:      settings.colorScheme = nil
                        }
                    }
                )) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider().padding(.vertical, 8)

            PrefSectionHeader("Storage")

            PrefRow(label: "Save Location") {
                HStack(spacing: 6) {
                    Text(settings.saveLocation.lastPathComponent)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .lineLimit(1).frame(maxWidth: 140, alignment: .trailing)
                    Button("Browse…") { pickFolder() }.controlSize(.small)
                }
            }

            Divider().padding(.vertical, 8)

            PrefSectionHeader("System")

            PrefRow(label: "Launch at startup") {
                Toggle("", isOn: $launchAtStartup)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtStartup) { val in
                        LoginItemManager.shared.isEnabled = val
                    }
            }

            Spacer()
            Divider()

            HStack {
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .padding(.horizontal, 24).padding(.top, 20)
        .frame(width: 460, height: 260)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveLocation = url
        }
    }
}

struct PrefSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary).padding(.bottom, 6)
    }
}

struct PrefRow<Content: View>: View {
    let label: String; let content: Content
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label; self.content = content()
    }
    var body: some View {
        HStack(alignment: .center) {
            Text(label).font(.system(size: 13)).frame(width: 140, alignment: .leading)
            Spacer()
            content
        }
        .padding(.vertical, 8)
    }
}
