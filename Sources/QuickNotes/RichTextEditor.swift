import SwiftUI
import AppKit

// MARK: - Heading style

enum HeadingStyle: String, CaseIterable {
    case body = "Body"
    case h1   = "H1"
    case h2   = "H2"
    case h3   = "H3"

    var fontSize: CGFloat {
        switch self {
        case .body: return CGFloat(AppSettings.shared.fontSize)
        case .h1:   return 26
        case .h2:   return 20
        case .h3:   return 16
        }
    }

    var isBold: Bool { self != .body }
}

// MARK: - List state (shared so Enter key can continue numbering)

final class ListState {
    var isNumberedActive = false
    var currentNumber    = 1
    var isBulletActive   = false
    // current font size for list prefixes
    var fontSize: CGFloat = CGFloat(AppSettings.shared.fontSize)
}

// MARK: - RichTextEditor

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
        textView.isRichText          = true
        textView.isEditable          = true
        textView.isSelectable        = true
        textView.allowsUndo          = true
        textView.usesFontPanel       = false
        textView.font                = NSFont.systemFont(ofSize: fontSize)
        textView.textColor           = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset  = NSSize(width: 12, height: 14)
        textView.delegate            = context.coordinator
        textView.drawsBackground     = false
        textView.textStorage?.setAttributedString(text)
        textView.autoresizingMask    = [.width]
        textView.minSize             = .zero
        textView.maxSize             = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        context.coordinator.textView = textView
        context.coordinator.listState.fontSize = CGFloat(fontSize)

        let scroll = NSScrollView()
        scroll.documentView       = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground    = false
        scroll.autohidesScrollers = true

        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Keep list fontSize in sync with toolbar fontSize
        context.coordinator.listState.fontSize = CGFloat(fontSize)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var textBinding: Binding<NSAttributedString>
        weak var textView: NSTextView?
        var onChange: ((NSAttributedString) -> Void)?
        let listState = ListState()

        init(text: Binding<NSAttributedString>) { self.textBinding = text }

        // MARK: textDidChange — Fix 2: auto-continue numbered list on Enter
        func textDidChange(_ notification: Notification) {
            guard let tv = textView, let storage = tv.textStorage else { return }

            let fullString = storage.string as NSString
            let cursorLoc  = tv.selectedRange.location

            // Only process if cursor is not at very start
            if cursorLoc > 0 {
                let prevCharRange = NSRange(location: cursorLoc - 1, length: 1)
                let prevChar = fullString.substring(with: prevCharRange)

                if prevChar == "\n" && listState.isNumberedActive {
                    // Check the PREVIOUS line (before this new \n)
                    let prevLineRange = fullString.lineRange(for: NSRange(location: cursorLoc - 2, length: 0))
                    let prevLine = fullString.substring(with: prevLineRange)

                    if let regex = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s"),
                       let match = regex.firstMatch(in: prevLine, range: NSRange(location: 0, length: (prevLine as NSString).length)),
                       let numRange = Range(match.range(at: 1), in: prevLine),
                       let num = Int(prevLine[numRange]) {

                        listState.currentNumber = num + 1
                        let prefix = "\(listState.currentNumber). "
                        let fs = listState.fontSize
                        let insertAttr = NSAttributedString(string: prefix, attributes: [
                            .font: NSFont.systemFont(ofSize: fs),
                            .foregroundColor: NSColor.labelColor
                        ])
                        storage.beginEditing()
                        storage.insert(insertAttr, at: cursorLoc)
                        storage.endEditing()
                        // Move cursor after prefix
                        tv.setSelectedRange(NSRange(location: cursorLoc + (prefix as NSString).length, length: 0))
                    }
                } else if prevChar == "\n" && listState.isBulletActive {
                    let prevLineRange = fullString.lineRange(for: NSRange(location: cursorLoc - 2, length: 0))
                    let prevLine = fullString.substring(with: prevLineRange)
                    if prevLine.hasPrefix("• ") {
                        let fs = listState.fontSize
                        let prefix = "• "
                        let insertAttr = NSAttributedString(string: prefix, attributes: [
                            .font: NSFont.systemFont(ofSize: fs),
                            .foregroundColor: NSColor.labelColor
                        ])
                        storage.beginEditing()
                        storage.insert(insertAttr, at: cursorLoc)
                        storage.endEditing()
                        tv.setSelectedRange(NSRange(location: cursorLoc + (prefix as NSString).length, length: 0))
                    }
                }
            }

            let attr = tv.attributedString()
            textBinding.wrappedValue = attr
            onChange?(attr)
        }

        func setText(_ attr: NSAttributedString) {
            guard let tv = textView else { return }
            tv.textStorage?.setAttributedString(attr)
            listState.isNumberedActive = false
            listState.isBulletActive   = false
            listState.currentNumber    = 1
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }

        // MARK: Heading — Fix 3: properly apply font size per style

        func applyHeading(_ style: HeadingStyle) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString  = storage.string as NSString
            let sel = tv.selectedRange
            // Apply to whole current line if no selection, else apply to all lines in selection
            let applyRange = sel.length > 0 ? sel : nsString.lineRange(for: NSRange(location: sel.location, length: 0))

            let font: NSFont
            if style == .body {
                font = NSFont.systemFont(ofSize: listState.fontSize)
            } else {
                font = NSFont.boldSystemFont(ofSize: style.fontSize)
            }

            storage.beginEditing()
            storage.addAttribute(.font, value: font, range: applyRange)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: applyRange)
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
            // Restore selection
            tv.setSelectedRange(sel)
        }

        // MARK: Font color — Fix 4: works even when color panel is open
        func applyFontColor(_ color: NSColor) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: color, range: range)
            storage.endEditing()
            // Keep selection so user can keep picking colours
            tv.setSelectedRange(range)
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        // MARK: Font size — Fix 6: match bullet/number size to font size
        func applyFontSize(_ size: CGFloat) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            listState.fontSize = size
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

        // MARK: Bold / Italic / Underline — Fix 1: restore first responder after

        func toggleTrait(_ trait: NSFontTraitMask) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let manager = NSFontManager.shared
            let fs      = listState.fontSize
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let cur = (value as? NSFont) ?? NSFont.systemFont(ofSize: fs)
                let has = manager.traits(of: cur).contains(trait)
                let new = has ? manager.convert(cur, toNotHaveTrait: trait)
                              : manager.convert(cur, toHaveTrait: trait)
                storage.addAttribute(.font, value: new, range: subrange)
            }
            storage.endEditing()
            tv.setSelectedRange(range)
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
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
            tv.setSelectedRange(range)
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }

        // MARK: Lists — Fix 6: prefix font matches current fontSize

        func toggleBulletList() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString  = storage.string as NSString
            let lineRange = nsString.lineRange(for: tv.selectedRange)
            let line      = nsString.substring(with: lineRange)
            let prefix    = "• "
            let prefixLen = (prefix as NSString).length
            let fs        = listState.fontSize

            storage.beginEditing()
            if line.hasPrefix(prefix) {
                storage.replaceCharacters(in: NSRange(location: lineRange.location, length: prefixLen), with: "")
                listState.isBulletActive = false
            } else {
                storage.insert(
                    NSAttributedString(string: prefix, attributes: [
                        .font: NSFont.systemFont(ofSize: fs),   // Fix 6
                        .foregroundColor: NSColor.labelColor
                    ]),
                    at: lineRange.location)
                listState.isBulletActive = true
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }

        func toggleNumberedList() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let nsString  = storage.string as NSString
            let lineRange = nsString.lineRange(for: tv.selectedRange)
            let line      = nsString.substring(with: lineRange)
            let fs        = listState.fontSize

            storage.beginEditing()
            if let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\s"),
               let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
                storage.replaceCharacters(
                    in: NSRange(location: lineRange.location, length: match.range.length),
                    with: "")
                listState.isNumberedActive = false
                listState.currentNumber    = 1
            } else {
                // Find what number to use based on previous line
                let prevLoc = lineRange.location > 0 ? lineRange.location - 1 : 0
                let prevLineRange = nsString.lineRange(for: NSRange(location: prevLoc, length: 0))
                let prevLine = lineRange.location > 0 ? nsString.substring(with: prevLineRange) : ""
                var startNum = 1
                if let regex = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s"),
                   let match = regex.firstMatch(in: prevLine, range: NSRange(location: 0, length: (prevLine as NSString).length)),
                   let r = Range(match.range(at: 1), in: prevLine),
                   let n = Int(prevLine[r]) {
                    startNum = n + 1
                }
                listState.currentNumber    = startNum
                listState.isNumberedActive = true
                let prefix = "\(startNum). "
                storage.insert(
                    NSAttributedString(string: prefix, attributes: [
                        .font: NSFont.systemFont(ofSize: fs),   // Fix 6
                        .foregroundColor: NSColor.labelColor
                    ]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }
    }
}

// MARK: - KeyableTextView — Fix 1: always restore first responder, all keyboard shortcuts

final class KeyableTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "a": selectAll(nil);   return true
        case "c": copy(nil);        return true
        case "v": paste(nil);       return true
        case "x": cut(nil);         return true
        case "z":
            if event.modifierFlags.contains(.shift) { undoManager?.redo() }
            else { undoManager?.undo() }
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
