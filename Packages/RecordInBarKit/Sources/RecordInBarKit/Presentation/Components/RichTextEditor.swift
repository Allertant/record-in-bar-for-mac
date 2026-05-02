import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let tracksDynamicHeight: Bool
    let font: NSFont
    let isEditable: Bool
    let verticalPadding: CGFloat

    init(
        text: Binding<String>,
        dynamicHeight: Binding<CGFloat>,
        minHeight: CGFloat,
        maxHeight: CGFloat? = nil,
        tracksDynamicHeight: Bool = true,
        font: NSFont = .systemFont(ofSize: 13),
        isEditable: Bool = true,
        verticalPadding: CGFloat = 6
    ) {
        self._text = text
        self._dynamicHeight = dynamicHeight
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.tracksDynamicHeight = tracksDynamicHeight
        self.font = font
        self.isEditable = isEditable
        self.verticalPadding = verticalPadding
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            dynamicHeight: $dynamicHeight,
            minHeight: minHeight,
            maxHeight: maxHeight,
            tracksDynamicHeight: tracksDynamicHeight,
            font: font,
            verticalPadding: verticalPadding
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = maxHeight != nil
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
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        context.coordinator.configure(textView: textView)
        context.coordinator.applyExternalText(text, to: textView, preserveSelection: false)

        scrollView.documentView = textView

        DispatchQueue.main.async {
            context.coordinator.recalculateLayout(for: textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InterceptingTextView else { return }
        textView.isEditable = isEditable
        context.coordinator.configure(textView: textView)
        if textView.string != text, !context.coordinator.isEditing {
            context.coordinator.applyExternalText(text, to: textView, preserveSelection: true)
        }

        let measuredWidth = textView.bounds.width
        if abs(context.coordinator.lastMeasuredWidth - measuredWidth) > 0.5 {
            DispatchQueue.main.async {
                context.coordinator.recalculateLayout(for: textView)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var dynamicHeight: CGFloat
        private let minHeight: CGFloat
        private let maxHeight: CGFloat?
        private let tracksDynamicHeight: Bool
        private let font: NSFont
        private let verticalPadding: CGFloat
        private var isApplyingProgrammaticChange = false
        private(set) var lastMeasuredWidth: CGFloat = 0
        private(set) var isEditing = false

        init(
            text: Binding<String>,
            dynamicHeight: Binding<CGFloat>,
            minHeight: CGFloat,
            maxHeight: CGFloat?,
            tracksDynamicHeight: Bool,
            font: NSFont,
            verticalPadding: CGFloat
        ) {
            self._text = text
            self._dynamicHeight = dynamicHeight
            self.minHeight = minHeight
            self.maxHeight = maxHeight
            self.tracksDynamicHeight = tracksDynamicHeight
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
            recalculateLayout(for: textView)
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

        func configure(textView: NSTextView) {
            textView.font = font
            textView.textContainerInset = NSSize(width: 2, height: verticalPadding)
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
            recalculateLayout(for: textView)
        }

        func recalculateLayout(for textView: NSTextView) {
            let width = textView.bounds.width > 0 ? textView.bounds.width : 280
            lastMeasuredWidth = width
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
            textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let naturalHeight = max(minHeight, ceil(usedRect.height + verticalPadding * 2))
            let nextHeight = min(maxHeight ?? naturalHeight, naturalHeight)

            if let scrollView = textView.enclosingScrollView {
                let needsVerticalScroller = maxHeight != nil && naturalHeight > nextHeight + 0.5
                if scrollView.hasVerticalScroller != needsVerticalScroller {
                    scrollView.hasVerticalScroller = needsVerticalScroller
                }
            }

            if tracksDynamicHeight, abs(dynamicHeight - nextHeight) > 0.5 {
                dynamicHeight = nextHeight
            }
        }
    }
}

private final class InterceptingTextView: NSTextView {}
