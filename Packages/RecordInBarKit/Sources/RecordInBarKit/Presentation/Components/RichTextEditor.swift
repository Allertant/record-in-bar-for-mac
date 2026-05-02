import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    let minHeight: CGFloat
    let font: NSFont
    let isEditable: Bool
    let verticalPadding: CGFloat

    init(
        text: Binding<String>,
        minHeight: CGFloat,
        font: NSFont = .systemFont(ofSize: 13),
        isEditable: Bool = true,
        verticalPadding: CGFloat = 6
    ) {
        self._text = text
        self.minHeight = minHeight
        self.font = font
        self.isEditable = isEditable
        self.verticalPadding = verticalPadding
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, font: font, verticalPadding: verticalPadding)
    }

    func makeNSView(context: Context) -> InterceptingTextView {
        let textView = InterceptingTextView(frame: .zero)
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
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: verticalPadding)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.allowsUndo = true
        configure(textView, coordinator: context.coordinator)
        context.coordinator.applyExternalText(text, to: textView, preserveSelection: false)
        return textView
    }

    func updateNSView(_ textView: InterceptingTextView, context: Context) {
        configure(textView, coordinator: context.coordinator)
        if textView.string != text, !context.coordinator.isEditing {
            context.coordinator.applyExternalText(text, to: textView, preserveSelection: true)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView textView: InterceptingTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? (textView.bounds.width > 0 ? textView.bounds.width : context.coordinator.lastMeasuredWidth)
        guard width > 0 else {
            return CGSize(width: context.coordinator.lastMeasuredWidth, height: minHeight)
        }

        let measuredHeight = context.coordinator.measuredHeight(for: textView, width: width, minHeight: minHeight)
        return CGSize(width: width, height: measuredHeight)
    }

    private func configure(_ textView: InterceptingTextView, coordinator: Coordinator) {
        textView.isEditable = isEditable
        textView.font = font
        textView.textContainerInset = NSSize(width: 2, height: verticalPadding)
        coordinator.applyTypingAttributes(to: textView)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        private let font: NSFont
        private let verticalPadding: CGFloat
        private var isApplyingProgrammaticChange = false
        private(set) var isEditing = false
        private(set) var lastMeasuredWidth: CGFloat = 320

        init(text: Binding<String>, font: NSFont, verticalPadding: CGFloat) {
            self._text = text
            self.font = font
            self.verticalPadding = verticalPadding
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? InterceptingTextView else { return }
            guard !isApplyingProgrammaticChange else { return }
            text = textView.string
            textView.invalidateIntrinsicContentSize()
            scrollSelectionIntoView(for: textView)
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
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
        }

        func applyExternalText(_ newText: String, to textView: NSTextView, preserveSelection: Bool) {
            let selectedRange = textView.selectedRange()
            isApplyingProgrammaticChange = true
            textView.string = newText

            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.beginEditing()
                textStorage.setAttributes(textView.typingAttributes, range: NSRange(location: 0, length: textStorage.length))
                textStorage.endEditing()
            }

            if preserveSelection {
                let maxLocation = textView.string.utf16.count
                let clampedLocation = min(selectedRange.location, maxLocation)
                let clampedLength = min(selectedRange.length, max(0, maxLocation - clampedLocation))
                textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
            } else {
                textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
            }

            isApplyingProgrammaticChange = false
            scrollSelectionIntoView(for: textView)
        }

        func measuredHeight(for textView: NSTextView, width: CGFloat, minHeight: CGFloat) -> CGFloat {
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
                return minHeight
            }

            lastMeasuredWidth = width
            let contentWidth = max(0, width - 4)
            textContainer.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            return max(minHeight, ceil(usedRect.height + verticalPadding * 2))
        }

        private func scrollSelectionIntoView(for textView: NSTextView) {
            let selection = textView.selectedRange()
            guard selection.location != NSNotFound else { return }
            textView.scrollRangeToVisible(selection)
        }
    }
}

final class InterceptingTextView: NSTextView {
    override var isFlipped: Bool {
        true
    }
}
