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
                    .frame(width: 175)
                    .transition(.move(edge: .leading))
                Divider()
            }
            EditorPane(store: store, onQuit: onQuit, sidebarVisible: $sidebarVisible)
        }
        .frame(minWidth: sidebarVisible ? 420 : 280, minHeight: 300)
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
            // Header
            HStack {
                Text("Notes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { PreferencesWindowController.shared.show() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Preferences")
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                TextField("Search", text: $store.searchQuery)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                if !store.searchQuery.isEmpty {
                    Button(action: { store.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // All Notes
                    FolderRow(
                        label: "All Notes",
                        icon: "note.text",
                        count: store.notes.count,
                        isSelected: store.selectedFolderID == nil
                    ) { store.selectedFolderID = nil }

                    if !store.folders.isEmpty {
                        Text("FOLDERS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                    }

                    ForEach(store.folders) { folder in
                        FolderRow(
                            label: folder.name,
                            icon: "folder",
                            count: folder.noteIDs.count,
                            isSelected: store.selectedFolderID == folder.id
                        ) { store.selectedFolderID = folder.id }
                        .contextMenu {
                            Button("Delete Folder", role: .destructive) {
                                store.deleteFolder(folder)
                            }
                        }
                    }

                    if showNewFolder {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            TextField("Folder name", text: $newFolderName)
                                .font(.system(size: 12))
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    if !newFolderName.isEmpty {
                                        store.createFolder(name: newFolderName)
                                    }
                                    newFolderName = ""
                                    showNewFolder = false
                                }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }

                    Button(action: { showNewFolder.toggle() }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

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
                                Button("Delete Note", role: .destructive) {
                                    store.deleteNote(note)
                                }
                            }
                    }
                }
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                Button(action: { store.createNote() }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .help("New Note")
                Spacer()
                Text("\(store.notes.count) note\(store.notes.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct FolderRow: View {
    let label: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : (hovering ? Color.primary.opacity(0.06) : Color.clear))
            .cornerRadius(6)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
            Text(note.preview.isEmpty ? "No content" : note.preview)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor : (hovering ? Color.primary.opacity(0.06) : Color.clear))
        .cornerRadius(6)
        .padding(.horizontal, 4)
        .onHover { hovering = $0 }
    }
}

// MARK: - Editor Pane

struct EditorPane: View {
    @ObservedObject var store: NoteStore
    var onQuit: () -> Void
    @Binding var sidebarVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 4) {
                // Sidebar toggle
                Button(action: { withAnimation { sidebarVisible.toggle() } }) {
                    Image(systemName: sidebarVisible ? "sidebar.left" : "sidebar.left")
                        .font(.system(size: 12))
                        .foregroundColor(sidebarVisible ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(sidebarVisible ? "Hide Sidebar" : "Show Sidebar")

                Divider().frame(height: 16).padding(.horizontal, 2)

                FormatButton(systemName: "bold", helpText: "Bold (select text first)") { store.toggleBold() }
                FormatButton(systemName: "italic", helpText: "Italic") { store.toggleItalic() }
                FormatButton(systemName: "underline", helpText: "Underline") { store.toggleUnderline() }

                Divider().frame(height: 16).padding(.horizontal, 2)

                FormatButton(systemName: "list.bullet", helpText: "Bullet list") { store.toggleBullets() }
                FormatButton(systemName: "list.number", helpText: "Numbered list") { store.toggleNumbers() }
                FormatButton(systemName: "checkmark.square", helpText: "Checkbox") { store.toggleCheckbox() }

                Spacer()

                Text(store.savedLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Button(action: onQuit) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Quit QuickNotes")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if store.selectedNote != nil {
                RichTextEditor(
                    text: $store.currentAttributedText,
                    coordinatorRef: $store.coordinator,
                    fontSize: AppSettings.shared.fontSize
                )
                .onAppear {
                    store.coordinator?.onChange = { [weak store] attr in
                        store?.textDidChange(attr)
                    }
                }
            } else {
                Spacer()
                Text("No note selected")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct FormatButton: View {
    let systemName: String
    var helpText: String = ""
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(5)
        .onHover { hovering = $0 }
        .help(helpText)
    }
}

// MARK: - Preferences (no Form, plain VStack layout)

struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtStartup = LoginItemManager.shared.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Appearance ──────────────────────────────────────────
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

            PrefRow(label: "Font Size") {
                HStack(spacing: 8) {
                    Slider(value: $settings.fontSize, in: 10...20, step: 1)
                        .frame(width: 140)
                    Text("\(Int(settings.fontSize)) pt")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 34, alignment: .leading)
                }
            }

            Divider().padding(.vertical, 8)

            // ── Storage ─────────────────────────────────────────────
            PrefSectionHeader("Storage")

            PrefRow(label: "Save Location") {
                HStack(spacing: 6) {
                    Text(settings.saveLocation.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 120, alignment: .trailing)
                    Button("Browse…") { pickFolder() }
                        .controlSize(.small)
                }
            }

            Divider().padding(.vertical, 8)

            // ── System ───────────────────────────────────────────────
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
                    .controlSize(.regular)
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(width: 480, height: 300)
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
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
    }
}

struct PrefRow<Content: View>: View {
    let label: String
    let content: Content
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 140, alignment: .leading)
            Spacer()
            content
        }
        .padding(.vertical, 8)
    }
}
