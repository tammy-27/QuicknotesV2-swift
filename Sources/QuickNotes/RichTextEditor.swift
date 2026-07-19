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
        let textView = NSTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textContainerInset = NSSize(width: 6, height: 8)
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

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

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
        }

        func toggleTrait(_ trait: NSFontTraitMask) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let manager = NSFontManager.shared
            let fontSize = AppSettings.shared.fontSize
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: fontSize)
                let hasTrait = manager.traits(of: currentFont).contains(trait)
                let newFont = hasTrait
                    ? manager.convert(currentFont, toNotHaveTrait: trait)
                    : manager.convert(currentFont, toHaveTrait: trait)
                storage.addAttribute(.font, value: newFont, range: subrange)
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }

        func toggleUnderline() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let current = storage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            storage.beginEditing()
            storage.addAttribute(
                .underlineStyle,
                value: current == 0 ? NSUnderlineStyle.single.rawValue : 0,
                range: range
            )
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
                    NSAttributedString(string: "\u{2022}  ", attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
                    at: lineRange.location
                )
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
                    with: ""
                )
            } else {
                storage.insert(
                    NSAttributedString(string: "1. ", attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
                    at: lineRange.location
                )
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
                    NSAttributedString(string: "☐ ", attributes: [.font: NSFont.systemFont(ofSize: AppSettings.shared.fontSize)]),
                    at: lineRange.location
                )
            }
            storage.endEditing()
            textBinding.wrappedValue = tv.attributedString()
            onChange?(tv.attributedString())
        }
    }
}
