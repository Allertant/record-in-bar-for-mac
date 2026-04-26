import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    let minHeight: CGFloat
    let font: NSFont
    let isEditable: Bool
    let verticalPadding: CGFloat

    init(
        text: Binding<String>,
        dynamicHeight: Binding<CGFloat>,
        minHeight: CGFloat,
        font: NSFont = .systemFont(ofSize: 13),
        isEditable: Bool = true,
        verticalPadding: CGFloat = 6
    ) {
        self._text = text
        self._dynamicHeight = dynamicHeight
        self.minHeight = minHeight
        self.font = font
        self.isEditable = isEditable
        self.verticalPadding = verticalPadding
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, dynamicHeight: $dynamicHeight, minHeight: minHeight, font: font, verticalPadding: verticalPadding)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = InterceptingTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: verticalPadding)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.font = font
        textView.string = text
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.setSelectedRange(NSRange(location: text.count, length: 0))
        context.coordinator.applyTypingAttributes(to: textView)

        scrollView.documentView = textView

        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(for: textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InterceptingTextView else { return }
        textView.isEditable = isEditable
        textView.font = font
        textView.textContainerInset = NSSize(width: 2, height: verticalPadding)
        context.coordinator.applyTypingAttributes(to: textView)
        if textView.string != text {
            textView.string = text
        }
        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(for: textView)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var dynamicHeight: CGFloat
        private let minHeight: CGFloat
        private let font: NSFont
        private let verticalPadding: CGFloat

        init(text: Binding<String>, dynamicHeight: Binding<CGFloat>, minHeight: CGFloat, font: NSFont, verticalPadding: CGFloat) {
            self._text = text
            self._dynamicHeight = dynamicHeight
            self.minHeight = minHeight
            self.font = font
            self.verticalPadding = verticalPadding
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? InterceptingTextView else { return }
            text = textView.string
            applyTypingAttributes(to: textView)
            recalculateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.insertText("  ", replacementRange: textView.selectedRange())
                return true
            }
            return false
        }

        func applyTypingAttributes(to textView: NSTextView) {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 5
            style.paragraphSpacing = 6
            style.tabStops = [
                NSTextTab(textAlignment: .left, location: 22),
                NSTextTab(textAlignment: .left, location: 44),
                NSTextTab(textAlignment: .left, location: 66)
            ]
            textView.defaultParagraphStyle = style
            textView.typingAttributes = [
                .font: font,
                .paragraphStyle: style,
                .foregroundColor: NSColor.labelColor
            ]

            let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributes(textView.typingAttributes, range: fullRange)
            textView.textStorage?.endEditing()
        }

        func recalculateHeight(for textView: NSTextView) {
            let width = textView.bounds.width > 0 ? textView.bounds.width : 280
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
            textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let nextHeight = max(minHeight, ceil(usedRect.height + verticalPadding * 2))
            if abs(dynamicHeight - nextHeight) > 0.5 {
                dynamicHeight = nextHeight
            }
        }
    }
}

private final class InterceptingTextView: NSTextView {}
