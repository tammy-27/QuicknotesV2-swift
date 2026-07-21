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
        textView.usesFontPanel = true
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.delegate = context.coordinator
        textView.textStorage?.setAttributedString(text)
        textView.drawsBackground = false
        // Ensure standard keyboard shortcuts work
        textView.allowsDocumentBackgroundColorChange = false
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

        // Become first responder so Cmd+A/C/X work immediately
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
            // Restore first responder after text replacement
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
            let ns = storage.string as NSString
            let lineRange = ns.lineRange(for: tv.selectedRange)
            let line = ns.substring(with: lineRange)
            storage.beginEditing()
            if line.hasPrefix("\u{2022}  ") {
                storage.replaceCharacters(in: NSRange(location: lineRange.location, length: 3), with: "")
            } else {
                storage.insert(
                    NSAttributedString(string: "\u{2022}  ",
                        attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        func toggleNumberedList() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let ns = storage.string as NSString
            let lineRange = ns.lineRange(for: tv.selectedRange)
            let line = ns.substring(with: lineRange)
            storage.beginEditing()
            if let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\s+"),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                storage.replaceCharacters(
                    in: NSRange(location: lineRange.location + match.range.location, length: match.range.length),
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

        func toggleCheckbox() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let ns = storage.string as NSString
            let lineRange = ns.lineRange(for: tv.selectedRange)
            let line = ns.substring(with: lineRange)
            storage.beginEditing()
            if line.hasPrefix("☑ ") {
                storage.replaceCharacters(in: NSRange(location: lineRange.location, length: 2), with: "")
            } else if line.hasPrefix("☐ ") {
                storage.replaceCharacters(in: NSRange(location: lineRange.location, length: 2), with: "☑ ")
            } else {
                storage.insert(
                    NSAttributedString(string: "☐ ",
                        attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
                    at: lineRange.location)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }
    }
}

/// NSTextView subclass that ensures the panel becomes key
/// when this view is clicked, enabling Cmd+A/C/X/V/Z etc.
final class KeyableTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        // Make the panel key so keyboard shortcuts are routed here
        window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        super.mouseDown(with: event)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Let standard key equivalents pass through normally
        super.keyDown(with: event)
    }
}
