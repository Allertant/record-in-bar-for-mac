import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    let minHeight: CGFloat
    let font: NSFont
    let isEditable: Bool
    let verticalPadding: CGFloat
    var onImagePasted: ((NSImage) -> UUID?)?
    var imageLoader: (UUID) -> NSImage?
    var onImageDeleted: ((UUID) -> Void)?

    init(
        text: Binding<String>,
        minHeight: CGFloat,
        font: NSFont = .systemFont(ofSize: 13),
        isEditable: Bool = true,
        verticalPadding: CGFloat = 6,
        onImagePasted: ((NSImage) -> UUID?)? = nil,
        imageLoader: @escaping (UUID) -> NSImage? = { _ in nil },
        onImageDeleted: ((UUID) -> Void)? = nil
    ) {
        self._text = text
        self.minHeight = minHeight
        self.font = font
        self.isEditable = isEditable
        self.verticalPadding = verticalPadding
        self.onImagePasted = onImagePasted
        self.imageLoader = imageLoader
        self.onImageDeleted = onImageDeleted
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, font: font, verticalPadding: verticalPadding, imageLoader: imageLoader, onImageDeleted: onImageDeleted)
    }

    func makeNSView(context: Context) -> InterceptingTextView {
        let textView = InterceptingTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = true
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
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.allowsUndo = true
        configure(textView, coordinator: context.coordinator)
        context.coordinator.applyExternalText(text, to: textView, preserveSelection: false)
        textView.onImagePasted = onImagePasted
        return textView
    }

    func updateNSView(_ textView: InterceptingTextView, context: Context) {
        configure(textView, coordinator: context.coordinator)
        textView.onImagePasted = onImagePasted
        context.coordinator.imageLoader = imageLoader
        context.coordinator.onImageDeleted = onImageDeleted

        let currentMarkerText = Self.Coordinator.stringWithImageMarkers(from: textView)
        if currentMarkerText != text, !context.coordinator.isEditing {
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
        var imageLoader: (UUID) -> NSImage?
        var onImageDeleted: ((UUID) -> Void)?
        private var previousAttachmentIDs: Set<UUID> = []

        init(text: Binding<String>, font: NSFont, verticalPadding: CGFloat, imageLoader: @escaping (UUID) -> NSImage?, onImageDeleted: ((UUID) -> Void)?) {
            self._text = text
            self.font = font
            self.verticalPadding = verticalPadding
            self.imageLoader = imageLoader
            self.onImageDeleted = onImageDeleted
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? InterceptingTextView else { return }
            guard !isApplyingProgrammaticChange else { return }

            let markerText = Self.stringWithImageMarkers(from: textView)
            text = markerText

            let currentIDs = Self.attachmentIDs(in: textView)
            let deletedIDs = previousAttachmentIDs.subtracting(currentIDs)
            for id in deletedIDs {
                onImageDeleted?(id)
            }
            previousAttachmentIDs = currentIDs

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

            let attributed = Self.attributedStringFromMarkedText(newText, typingAttributes: textView.typingAttributes, imageLoader: imageLoader)

            if let textStorage = textView.textStorage {
                textStorage.setAttributedString(attributed)
            } else {
                textView.textStorage?.setAttributedString(attributed)
            }

            previousAttachmentIDs = Self.attachmentIDs(in: textView)

            if preserveSelection {
                let maxLocation = textView.textStorage?.length ?? 0
                let clampedLocation = min(selectedRange.location, maxLocation)
                let clampedLength = min(selectedRange.length, max(0, maxLocation - clampedLocation))
                textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
            } else {
                textView.setSelectedRange(NSRange(location: textView.textStorage?.length ?? 0, length: 0))
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

        // MARK: - Image marker helpers

        static func stringWithImageMarkers(from textView: NSTextView) -> String {
            guard let storage = textView.textStorage else { return textView.string }
            var result = ""
            var i = 0
            while i < storage.length {
                if let attachment = storage.attribute(.attachment, at: i, effectiveRange: nil) as? ImageTextAttachment {
                    result += "[IMG:\(attachment.imageID.uuidString)]"
                } else {
                    result += (storage.string as NSString).substring(with: NSRange(location: i, length: 1))
                }
                i += 1
            }
            return result
        }

        static func attachmentIDs(in textView: NSTextView) -> Set<UUID> {
            guard let storage = textView.textStorage else { return [] }
            var ids = Set<UUID>()
            var i = 0
            while i < storage.length {
                var range = NSRange(location: 0, length: 0)
                if let attachment = storage.attribute(.attachment, at: i, effectiveRange: &range) as? ImageTextAttachment {
                    ids.insert(attachment.imageID)
                    i = range.upperBound
                } else {
                    i += 1
                }
            }
            return ids
        }

        static func attributedStringFromMarkedText(
            _ markedText: String,
            typingAttributes: [NSAttributedString.Key: Any],
            imageLoader: (UUID) -> NSImage?
        ) -> NSAttributedString {
            let pattern = #"\[IMG:([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return NSAttributedString(string: markedText, attributes: typingAttributes)
            }

            let fullRange = NSRange(markedText.startIndex..., in: markedText)
            let matches = regex.matches(in: markedText, range: fullRange)
            let result = NSMutableAttributedString()
            var lastEnd = markedText.startIndex

            for match in matches {
                let markerRange = Range(match.range, in: markedText)!
                let beforeText = markedText[lastEnd..<markerRange.lowerBound]
                if !beforeText.isEmpty {
                    result.append(NSAttributedString(string: String(beforeText), attributes: typingAttributes))
                }

                let uuidRange = Range(match.range(at: 1), in: markedText)!
                let uuidString = String(markedText[uuidRange])
                if let uuid = UUID(uuidString: uuidString), let image = imageLoader(uuid) {
                    let attachment = ImageTextAttachment(image: image, imageID: uuid)
                    result.append(NSAttributedString(attachment: attachment))
                } else {
                    result.append(NSAttributedString(string: "[IMG:\(uuidString)]", attributes: typingAttributes))
                }

                lastEnd = markerRange.upperBound
            }

            if lastEnd < markedText.endIndex {
                result.append(NSAttributedString(string: String(markedText[lastEnd..<markedText.endIndex]), attributes: typingAttributes))
            }

            return result
        }

        private func scrollSelectionIntoView(for textView: NSTextView) {
            let selection = textView.selectedRange()
            guard selection.location != NSNotFound else { return }
            textView.scrollRangeToVisible(selection)
        }
    }
}

final class InterceptingTextView: NSTextView {
    override var isFlipped: Bool { true }
    var onImagePasted: ((NSImage) -> UUID?)?

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard let tc = textContainer, newSize.width > 0 else { return }
        let contentWidth = max(0, newSize.width - textContainerInset.width * 2)
        tc.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let image = Self.imageFromPasteboard(pb) {
            guard let imageID = onImagePasted?(image) else { return }
            let attachment = ImageTextAttachment(image: image, imageID: imageID)
            let attrString = NSAttributedString(attachment: attachment)
            guard let textStorage else { return }
            textStorage.replaceCharacters(in: selectedRange(), with: attrString)
            didChangeText()
            return
        }
        super.pasteAsPlainText(sender)
    }

    private static func imageFromPasteboard(_ pb: NSPasteboard) -> NSImage? {
        if let image = NSImage(pasteboard: pb) {
            return image
        }
        if let data = pb.data(forType: .fileURL),
           let urlString = String(data: data, encoding: .utf8),
           let url = URL(string: urlString),
           let image = NSImage(contentsOf: url) {
            return image
        }
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        for pbType in imageTypes {
            if let data = pb.data(forType: pbType),
               let image = NSImage(data: data) {
                return image
            }
        }
        return nil
    }
}
