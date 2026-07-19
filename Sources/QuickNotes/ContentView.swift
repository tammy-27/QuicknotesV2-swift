import SwiftUI
import AppKit

// MARK: - Root

struct ContentView: View {
    @StateObject private var store = NoteStore()
    @StateObject private var settings = AppSettings.shared
    @State private var showPreferences = false
    @State private var showSearch = false
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(store: store, showPreferences: $showPreferences)
                .frame(width: 160)

            Divider()

            EditorPane(store: store, onQuit: onQuit, showPreferences: $showPreferences)
        }
        .frame(minWidth: 520, minHeight: 360)
        .preferredColorScheme(settings.colorScheme)
        .sheet(isPresented: $showPreferences) {
            PreferencesView(isPresented: $showPreferences)
                .preferredColorScheme(settings.colorScheme)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var store: NoteStore
    @Binding var showPreferences: Bool
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
                Button(action: { showPreferences = true }) {
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
                    ) {
                        store.selectedFolderID = nil
                    }

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
                        ) {
                            store.selectedFolderID = folder.id
                        }
                        .contextMenu {
                            Button("Delete Folder", role: .destructive) {
                                store.deleteFolder(folder)
                            }
                        }
                    }

                    // New Folder
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

                    // Note list
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
                                Button("Delete Note", role: .destructive) {
                                    store.deleteNote(note)
                                }
                            }
                    }
                }
                .padding(.bottom, 8)
            }

            Divider()

            // Bottom bar
            HStack {
                Button(action: { store.createNote() }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .help("New Note")
                Spacer()
                Text("\(store.notes.count) notes")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.primary.opacity(0.03))
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
            .padding(.horizontal, 10)
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
        .padding(.horizontal, 10)
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
    @Binding var showPreferences: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar — no macOS traffic lights here, panel handles that
            HStack(spacing: 4) {
                FormatButton(systemName: "bold") { store.toggleBold() }
                    .help("Bold (select text first)")
                FormatButton(systemName: "italic") { store.toggleItalic() }
                    .help("Italic")
                FormatButton(systemName: "underline") { store.toggleUnderline() }
                    .help("Underline")
                Rectangle().frame(width: 1, height: 16).foregroundColor(.primary.opacity(0.15)).padding(.horizontal, 2)
                FormatButton(systemName: "list.bullet") { store.toggleBullets() }
                    .help("Bullet list")
                FormatButton(systemName: "list.number") { store.toggleNumbers() }
                    .help("Numbered list")
                FormatButton(systemName: "checkmark.square") { store.toggleCheckbox() }
                    .help("Checkbox")
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))

            Divider()

            if let _ = store.selectedNote {
                RichTextEditor(
                    text: $store.currentAttributedText,
                    coordinatorRef: $store.coordinator,
                    fontSize: AppSettings.shared.fontSize
                )
                .padding(6)
                .onAppear {
                    store.coordinator?.onChange = { [weak store] attr in
                        store?.textDidChange(attr)
                    }
                }
            } else {
                Spacer()
                Text("No note selected")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Spacer()
            }
        }
    }
}

struct FormatButton: View {
    let systemName: String
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
    }
}

// MARK: - Preferences

struct PreferencesView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtStartup = LoginItemManager.shared.isEnabled
    @State private var showFolderPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Text("Preferences")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Appearance
                    SectionHeader("Appearance")

                    PrefRow(label: "Theme") {
                        Picker("", selection: Binding(
                            get: {
                                switch settings.colorScheme {
                                case .dark: return "dark"
                                case .light: return "light"
                                default: return "system"
                                }
                            },
                            set: {
                                switch $0 {
                                case "dark": settings.colorScheme = .dark
                                case "light": settings.colorScheme = .light
                                default: settings.colorScheme = nil
                                }
                            }
                        )) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    PrefRow(label: "Font Size") {
                        HStack(spacing: 8) {
                            Slider(value: $settings.fontSize, in: 10...20, step: 1)
                                .frame(width: 120)
                            Text("\(Int(settings.fontSize)) pt")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 36)
                        }
                    }

                    Divider().padding(.vertical, 8)

                    // Storage
                    SectionHeader("Storage")

                    PrefRow(label: "Save Location") {
                        HStack(spacing: 6) {
                            Text(settings.saveLocation.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 200)
                            Button("Browse…") {
                                showFolderPicker = true
                            }
                            .controlSize(.small)
                        }
                    }

                    Divider().padding(.vertical, 8)

                    // System
                    SectionHeader("System")

                    PrefRow(label: "Launch at startup") {
                        Toggle("", isOn: $launchAtStartup)
                            .toggleStyle(.switch)
                            .onChange(of: launchAtStartup) { val in
                                LoginItemManager.shared.isEnabled = val
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 340)
        .onAppear {
            if showFolderPicker { pickFolder() }
        }
        .onChange(of: showFolderPicker) { show in
            if show { pickFolder(); showFolderPicker = false }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select where QuickNotes saves your notes"
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveLocation = url
        }
    }
}

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
            .padding(.top, 4)
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
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 140, alignment: .leading)
            Spacer()
            content
        }
        .padding(.vertical, 7)
    }
}
