import AppKit
import SwiftUI
import STTextView

struct STTextNoteEditor: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let isEditable: Bool

    init(
        text: Binding<String>,
        font: NSFont = .systemFont(ofSize: 13),
        isEditable: Bool = true
    ) {
        self._text = text
        self.font = font
        self.isEditable = isEditable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> EditorScrollView {
        let scrollView = EditorScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let textView = STTextView()
        textView.textDelegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.highlightSelectedLine = false
        textView.font = font
        applyParagraphStyle(to: textView)

        scrollView.documentView = textView
        scrollView.textView = textView
        context.coordinator.applyExternalText(text, to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: EditorScrollView, context: Context) {
        guard let textView = scrollView.textView else { return }
        textView.textDelegate = context.coordinator
        textView.isEditable = isEditable
        textView.font = font
        applyParagraphStyle(to: textView)

        if !context.coordinator.isApplyingProgrammaticChange, textView.text != text {
            context.coordinator.applyExternalText(text, to: textView)
        }
    }

    private func applyParagraphStyle(to textView: STTextView) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 6
        style.defaultTabInterval = 22
        textView.defaultParagraphStyle = style
        textView.typingAttributes = [
            .font: font,
            .paragraphStyle: style,
            .foregroundColor: NSColor.labelColor
        ]
    }

    @MainActor
    final class Coordinator: NSObject {
        @Binding private var text: String
        fileprivate var isApplyingProgrammaticChange = false

        init(text: Binding<String>) {
            self._text = text
        }

        func applyExternalText(_ newText: String, to textView: STTextView) {
            let selection = textView.textSelection
            isApplyingProgrammaticChange = true
            textView.text = newText
            let maxLocation = (textView.text ?? "").utf16.count
            let clampedLocation = min(selection.location, maxLocation)
            let clampedLength = min(selection.length, Swift.max(0, maxLocation - clampedLocation))
            textView.textSelection = NSRange(location: clampedLocation, length: clampedLength)
            isApplyingProgrammaticChange = false
        }
    }
}

extension STTextNoteEditor.Coordinator: STTextViewDelegate {
    nonisolated func textViewDidChangeText(_ notification: Notification) {
        guard let textView = notification.object as? STTextView else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard !isApplyingProgrammaticChange else { return }
            text = textView.text ?? ""
            textView.scrollRangeToVisible(textView.textSelection)
        }
    }

    nonisolated func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? STTextView else { return }
        Task { @MainActor in
            textView.scrollRangeToVisible(textView.textSelection)
        }
    }
}

final class EditorScrollView: NSScrollView {
    weak var textView: STTextView?

    override func layout() {
        super.layout()

        guard let textView else { return }
        let contentWidth = contentSize.width
        guard contentWidth > 0 else { return }

        if abs(textView.frame.width - contentWidth) > 0.5 {
            var frame = textView.frame
            frame.size.width = contentWidth
            textView.frame = frame
        }
    }
}
