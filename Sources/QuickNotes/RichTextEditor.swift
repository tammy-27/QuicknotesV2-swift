import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var coordinatorRef: Coordinator?
    var fontSize: Double

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(text: $text)
        DispatchQueue.main.async { self.coordinatorRef = c }
        return c
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = KeyableTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.delegate = context.coordinator
        textView.textStorage?.setAttributedString(text)
        textView.drawsBackground = false
        // Fix 2 & 3: Use primary label color so text adapts to dark/light mode
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                   height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    // MARK: - Coordinator
    final class Coordinator: NSObject, NSTextViewDelegate {
        var textBinding: Binding<NSAttributedString>
        weak var textView: NSTextView?
        var onChange: ((NSAttributedString) -> Void)?

        init(text: Binding<NSAttributedString>) { self.textBinding = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            let attr = tv.attributedString()
            textBinding.wrappedValue = attr
            onChange?(attr)
        }

        func setText(_ attr: NSAttributedString) {
            guard let tv = textView else { return }
            tv.textStorage?.setAttributedString(attr)
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }

        // MARK: Heading
        func applyHeading(_ style: HeadingStyle) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString = storage.string as NSString
            let lineRange = nsString.lineRange(for: tv.selectedRange.length > 0
                ? tv.selectedRange
                : NSRange(location: tv.selectedRange.location, length: 0))
            let font: NSFont
            switch style {
            case .h1: font = NSFont.boldSystemFont(ofSize: 24)
            case .h2: font = NSFont.boldSystemFont(ofSize: 20)
            case .h3: font = NSFont.boldSystemFont(ofSize: 16)
            case .body: font = NSFont.systemFont(ofSize: AppSettings.shared.fontSize)
            }
            storage.beginEditing()
            storage.addAttribute(.font, value: font, range: lineRange)
            // Fix 2: always set foreground to labelColor so it adapts to dark mode
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: lineRange)
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        // MARK: Font color
        func applyFontColor(_ color: NSColor) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: color, range: range)
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        // MARK: Font size
        func applyFontSize(_ size: CGFloat) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange.length > 0
                ? tv.selectedRange
                : NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range, options: []) { val, subrange, _ in
                let cur = (val as? NSFont) ?? NSFont.systemFont(ofSize: size)
                if let newFont = NSFont(name: cur.fontName, size: size) {
                    storage.addAttribute(.font, value: newFont, range: subrange)
                }
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        // MARK: Bold / Italic / Underline
        func toggleTrait(_ trait: NSFontTraitMask) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let manager = NSFontManager.shared
            let fs = AppSettings.shared.fontSize
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let cur = (value as? NSFont) ?? NSFont.systemFont(ofSize: fs)
                let has = manager.traits(of: cur).contains(trait)
                let new = has ? manager.convert(cur, toNotHaveTrait: trait)
                              : manager.convert(cur, toHaveTrait: trait)
                storage.addAttribute(.font, value: new, range: subrange)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        func toggleUnderline() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let cur = storage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            storage.beginEditing()
            storage.addAttribute(.underlineStyle,
                value: cur == 0 ? NSUnderlineStyle.single.rawValue : 0,
                range: range)
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        // MARK: Lists
        func toggleBulletList() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString = storage.string as NSString
            let lineRange = nsString.lineRange(for: tv.selectedRange)
            let line = nsString.substring(with: lineRange)
            let prefix = "• "
            let prefixLen = (prefix as NSString).length
            storage.beginEditing()
            if line.hasPrefix(prefix) {
                storage.replaceCharacters(in: NSRange(location: lineRange.location, length: prefixLen), with: "")
            } else {
                storage.insert(
                    NSAttributedString(string: prefix,
                        attributes: [
                            .font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize),
                            .foregroundColor: NSColor.labelColor   // Fix 2
                        ]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        func toggleNumberedList() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString = storage.string as NSString
            let lineRange = nsString.lineRange(for: tv.selectedRange)
            let line = nsString.substring(with: lineRange)
            storage.beginEditing()
            if let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\s"),
               let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
                storage.replaceCharacters(
                    in: NSRange(location: lineRange.location, length: match.range.length),
                    with: "")
            } else {
                storage.insert(
                    NSAttributedString(string: "1. ",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize),
                            .foregroundColor: NSColor.labelColor   // Fix 2
                        ]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        // Fix 4: Checkbox - properly handle Unicode char lengths via NSString
        func toggleCheckbox() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString = storage.string as NSString
            // Use cursor position even if nothing selected
            let cursorLoc = min(tv.selectedRange.location, max(0, nsString.length - 1))
            let safeRange = NSRange(location: cursorLoc, length: 0)
            let lineRange = nsString.lineRange(for: safeRange)
            guard lineRange.length > 0 || lineRange.location <= nsString.length else { return }
            let line = nsString.substring(with: lineRange)

            let unchecked = "☐ "
            let checked   = "☑ "
            let uncheckedNS = unchecked as NSString
            let checkedNS   = checked as NSString

            storage.beginEditing()
            if line.hasPrefix(checked) {
                storage.replaceCharacters(
                    in: NSRange(location: lineRange.location, length: checkedNS.length),
                    with: "")
            } else if line.hasPrefix(unchecked) {
                storage.replaceCharacters(
                    in: NSRange(location: lineRange.location, length: uncheckedNS.length),
                    with: NSAttributedString(string: checked, attributes: [
                        .font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize),
                        .foregroundColor: NSColor.labelColor
                    ]))
            } else {
                storage.insert(
                    NSAttributedString(string: unchecked, attributes: [
                        .font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize),
                        .foregroundColor: NSColor.labelColor
                    ]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }
    }
}

enum HeadingStyle: String, CaseIterable {
    case h1 = "H1"
    case h2 = "H2"
    case h3 = "H3"
    case body = "Body"
}

// Fix 4: NSTextView subclass — proper first responder + keyboard shortcuts
final class KeyableTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if window?.isKeyWindow == false {
            window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "a": selectAll(nil); return true
            case "c": copy(nil);      return true
            case "v": paste(nil);     return true
            case "x": cut(nil);       return true
            case "z":
                if event.modifierFlags.contains(.shift) {
                    undoManager?.redo()
                } else {
                    undoManager?.undo()
                }
                return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
