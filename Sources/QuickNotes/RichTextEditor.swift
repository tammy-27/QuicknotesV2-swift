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
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.delegate = context.coordinator
        textView.textStorage?.setAttributedString(text)
        textView.drawsBackground = false
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        // Fix 4: Make text view first responder immediately
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

        init(text: Binding<NSAttributedString>) {
            self.textBinding = text
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            let attr = tv.attributedString()
            textBinding.wrappedValue = attr
            onChange?(attr)
        }

        func setText(_ attr: NSAttributedString) {
            guard let tv = textView else { return }
            tv.textStorage?.setAttributedString(attr)
            DispatchQueue.main.async {
                tv.window?.makeFirstResponder(tv)
            }
        }

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

        func toggleBulletList() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let fullString = storage.string
            let nsString = fullString as NSString
            let lineRange = nsString.lineRange(for: tv.selectedRange)
            let line = nsString.substring(with: lineRange)
            storage.beginEditing()
            if line.hasPrefix("• ") {
                // Remove bullet prefix (bullet + space = 2 chars in NSString)
                let removeLen = ("• " as NSString).length
                storage.replaceCharacters(in: NSRange(location: lineRange.location, length: removeLen), with: "")
            } else {
                storage.insert(
                    NSAttributedString(string: "• ",
                        attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
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
                        attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        // Fix 3: Checkbox - use NSString lengths to avoid Unicode byte mismatch
        func toggleCheckbox() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString = storage.string as NSString
            let lineRange = nsString.lineRange(for: tv.selectedRange)
            let line = nsString.substring(with: lineRange)

            let unchecked = "☐ "
            let checked   = "☑ "
            let uncheckedLen = (unchecked as NSString).length  // 2
            let checkedLen   = (checked   as NSString).length  // 2

            storage.beginEditing()
            if line.hasPrefix(checked) {
                // Remove checkbox entirely
                storage.replaceCharacters(
                    in: NSRange(location: lineRange.location, length: checkedLen),
                    with: "")
            } else if line.hasPrefix(unchecked) {
                // Toggle unchecked → checked
                storage.replaceCharacters(
                    in: NSRange(location: lineRange.location, length: uncheckedLen),
                    with: checked)
            } else {
                // Insert unchecked checkbox
                storage.insert(
                    NSAttributedString(string: unchecked,
                        attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }
    }
}

// Fix 4: NSTextView subclass that makes the window key on click
// so Cmd+A, Cmd+C, Cmd+V, Cmd+X, Cmd+Z all work correctly
final class KeyableTextView: NSTextView {

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Become first responder as soon as we have a window
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Ensure window is key before handling the click
        if window?.isKeyWindow == false {
            window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
        super.mouseDown(with: event)
    }

    // Forward all standard key commands to super which handles
    // Cmd+A (selectAll), Cmd+C (copy), Cmd+V (paste), Cmd+X (cut), Cmd+Z (undo)
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Ensure Cmd+A/C/V/X/Z are handled by the text view's built-in responder chain
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "a": selectAll(nil); return true
            case "c": copy(nil); return true
            case "v": paste(nil); return true
            case "x": cut(nil); return true
            case "z": undoManager?.undo(); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
