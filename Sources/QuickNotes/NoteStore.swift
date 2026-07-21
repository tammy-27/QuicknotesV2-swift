import SwiftUI
import AppKit
import Combine

struct NoteFolder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var noteIDs: [UUID] = []
}

struct Note: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var rtfData: Data
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var folderID: UUID?

    var preview: String {
        guard let attr = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else { return "" }
        return String(attr.string.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var folders: [NoteFolder] = []
    @Published var selectedNoteID: UUID?
    @Published var selectedFolderID: UUID? = nil  // nil = All Notes
    @Published var searchQuery: String = ""
    @Published var savedLabel: String = ""
    @Published var currentAttributedText: NSAttributedString = NSAttributedString(string: "")
    weak var coordinator: RichTextEditor.Coordinator?

    private let settings = AppSettings.shared
    private var saveTimer: Timer?

    var selectedNote: Note? {
        get { notes.first { $0.id == selectedNoteID } }
    }

    var filteredNotes: [Note] {
        var list = notes
        if let folderID = selectedFolderID {
            let ids = folders.first { $0.id == folderID }?.noteIDs ?? []
            list = list.filter { ids.contains($0.id) }
        }
        if !searchQuery.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.preview.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        return list.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    init() {
        load()
        if notes.isEmpty { createNote() }
        selectedNoteID = notes.first?.id
        if let note = selectedNote {
            loadText(from: note)
        }
    }

    func createNote(inFolder folderID: UUID? = nil) {
        let empty = NSAttributedString(
            string: "",
            attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]
        )
        let data = (try? empty.data(
            from: NSRange(location: 0, length: 0),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )) ?? Data()

        var note = Note(title: "New Note", rtfData: data, folderID: folderID ?? selectedFolderID)
        if let fid = note.folderID, let idx = folders.firstIndex(where: { $0.id == fid }) {
            folders[idx].noteIDs.append(note.id)
        }
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        currentAttributedText = empty
        coordinator?.setText(empty)
        saveAll()
    }

    func deleteNote(_ note: Note) {
        // Remove from folders
        for i in folders.indices {
            folders[i].noteIDs.removeAll { $0 == note.id }
        }
        notes.removeAll { $0.id == note.id }
        // Also delete file
        let file = saveURL(for: note)
        try? FileManager.default.removeItem(at: file)
        saveAll()
        selectedNoteID = filteredNotes.first?.id
        if let n = selectedNote { loadText(from: n) }
    }

    func selectNote(_ note: Note) {
        // Save current before switching
        saveCurrentText()
        selectedNoteID = note.id
        loadText(from: note)
    }

    func loadText(from note: Note) {
        if let attr = try? NSAttributedString(
            data: note.rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            currentAttributedText = attr
            coordinator?.setText(attr)
        }
    }

    func textDidChange(_ attr: NSAttributedString) {
        currentAttributedText = attr
        guard let idx = notes.firstIndex(where: { $0.id == selectedNoteID }) else { return }
        // Update title from first line
        let firstLine = attr.string.components(separatedBy: "\n").first ?? ""
        notes[idx].title = firstLine.isEmpty ? "Untitled" : String(firstLine.prefix(40))
        notes[idx].modifiedAt = Date()
        // Debounce save
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.saveCurrentText()
        }
    }

    func saveCurrentText() {
        guard let idx = notes.firstIndex(where: { $0.id == selectedNoteID }) else { return }
        guard let data = try? currentAttributedText.data(
            from: NSRange(location: 0, length: currentAttributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return }
        notes[idx].rtfData = data
        notes[idx].modifiedAt = Date()
        saveAll()
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        savedLabel = "Saved \(f.string(from: Date()))"
        // Write RTF file to disk
        writeFileToDisk(notes[idx])
    }

    func writeFileToDisk(_ note: Note) {
        let dir = settings.saveLocation
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = saveURL(for: note)
        try? note.rtfData.write(to: url)
    }

    func saveURL(for note: Note) -> URL {
        settings.saveLocation
            .appendingPathComponent(note.id.uuidString)
            .appendingPathExtension("rtf")
    }

    // MARK: Folders
    func createFolder(name: String) {
        folders.append(NoteFolder(name: name))
        saveAll()
    }

    func deleteFolder(_ folder: NoteFolder) {
        // Move notes back to unfoldered
        if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            for nid in folders[idx].noteIDs {
                if let ni = notes.firstIndex(where: { $0.id == nid }) {
                    notes[ni].folderID = nil
                }
            }
            folders.remove(at: idx)
        }
        if selectedFolderID == folder.id { selectedFolderID = nil }
        saveAll()
    }

    func moveNote(_ note: Note, toFolder folderID: UUID?) {
        guard let ni = notes.firstIndex(where: { $0.id == note.id }) else { return }
        // Remove from old folder
        if let oldFID = notes[ni].folderID, let fi = folders.firstIndex(where: { $0.id == oldFID }) {
            folders[fi].noteIDs.removeAll { $0 == note.id }
        }
        notes[ni].folderID = folderID
        if let fid = folderID, let fi = folders.firstIndex(where: { $0.id == fid }) {
            folders[fi].noteIDs.append(note.id)
        }
        saveAll()
    }

    // MARK: Formatting
    func toggleBold() { coordinator?.toggleTrait(.boldFontMask) }
    func toggleItalic() { coordinator?.toggleTrait(.italicFontMask) }
    func toggleUnderline() { coordinator?.toggleUnderline() }
    func toggleBullets() { coordinator?.toggleBulletList() }
    func toggleNumbers() { coordinator?.toggleNumberedList() }
    func toggleCheckbox() { coordinator?.toggleCheckbox() }
    func applyHeading(_ style: HeadingStyle) { coordinator?.applyHeading(style) }
    func applyFontColor(_ color: NSColor) { coordinator?.applyFontColor(color) }
    func applyFontSize(_ size: CGFloat) { coordinator?.applyFontSize(size) }

    func clear() {
        let empty = NSAttributedString(string: "", attributes: [.font: NSFont.systemFont(ofSize: settings.fontSize)])
        currentAttributedText = empty
        coordinator?.setText(empty)
        textDidChange(empty)
    }

    // MARK: Persistence
    private func saveAll() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: "qn.notes")
        }
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "qn.folders")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "qn.notes"),
           let loaded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = loaded
        }
        if let data = UserDefaults.standard.data(forKey: "qn.folders"),
           let loaded = try? JSONDecoder().decode([NoteFolder].self, from: data) {
            folders = loaded
        }
    }
}
