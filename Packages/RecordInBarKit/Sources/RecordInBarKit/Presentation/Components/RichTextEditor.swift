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
    var onImageClicked: ((UUID) -> Void)?

    init(
        text: Binding<String>,
        minHeight: CGFloat,
        font: NSFont = .systemFont(ofSize: 13),
        isEditable: Bool = true,
        verticalPadding: CGFloat = 6,
        onImagePasted: ((NSImage) -> UUID?)? = nil,
        imageLoader: @escaping (UUID) -> NSImage? = { _ in nil },
        onImageDeleted: ((UUID) -> Void)? = nil,
        onImageClicked: ((UUID) -> Void)? = nil
    ) {
        self._text = text
        self.minHeight = minHeight
        self.font = font
        self.isEditable = isEditable
        self.verticalPadding = verticalPadding
        self.onImagePasted = onImagePasted
        self.imageLoader = imageLoader
        self.onImageDeleted = onImageDeleted
        self.onImageClicked = onImageClicked
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, font: font, verticalPadding: verticalPadding, imageLoader: imageLoader, onImageDeleted: onImageDeleted, onImageClicked: onImageClicked)
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
        textView.onImageClicked = onImageClicked
        return textView
    }

    func updateNSView(_ textView: InterceptingTextView, context: Context) {
        configure(textView, coordinator: context.coordinator)
        textView.onImagePasted = onImagePasted
        textView.onImageClicked = onImageClicked
        context.coordinator.imageLoader = imageLoader
        context.coordinator.onImageDeleted = onImageDeleted
        context.coordinator.onImageClicked = onImageClicked

        let currentMarkerText = Self.Coordinator.stringWithImageMarkers(from: textView)
        if currentMarkerText != text,
           !context.coordinator.isEditing,
           !context.coordinator.isShowingDeferredImagePlaceholders {
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

    // MARK: - Paragraph styles

    static func normalParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 6
        style.tabStops = [
            NSTextTab(textAlignment: .left, location: 22),
            NSTextTab(textAlignment: .left, location: 44),
            NSTextTab(textAlignment: .left, location: 66)
        ]
        return style
    }

    static func imageParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0
        style.paragraphSpacingBefore = 10
        style.paragraphSpacing = 18
        return style
    }

    static func generatedNewline(paragraphStyle: NSParagraphStyle? = nil) -> NSAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [
            .generatedImageLayoutNewline: true
        ]
        if let paragraphStyle {
            attrs[.paragraphStyle] = paragraphStyle
        }
        return NSAttributedString(string: "\n", attributes: attrs)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        private let font: NSFont
        private let verticalPadding: CGFloat
        private var isApplyingProgrammaticChange = false
        private(set) var isEditing = false
        private(set) var isShowingDeferredImagePlaceholders = false
        private(set) var lastMeasuredWidth: CGFloat = 320
        private var lastMeasuredHeight: CGFloat = 0
        private var contentRevision = 0
        private var lastMeasuredRevision = -1
        private var isMeasuringSize = false
        private var heightInvalidated = false
        var imageLoader: (UUID) -> NSImage?
        var onImageDeleted: ((UUID) -> Void)?
        var onImageClicked: ((UUID) -> Void)?
        private var previousAttachmentIDs: Set<UUID> = []

        init(text: Binding<String>, font: NSFont, verticalPadding: CGFloat, imageLoader: @escaping (UUID) -> NSImage?, onImageDeleted: ((UUID) -> Void)?, onImageClicked: ((UUID) -> Void)?) {
            self._text = text
            self.font = font
            self.verticalPadding = verticalPadding
            self.imageLoader = imageLoader
            self.onImageDeleted = onImageDeleted
            self.onImageClicked = onImageClicked
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

            markHeightInvalidated()
            scheduleHeightInvalidation(for: textView)
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
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                DispatchQueue.main.async { [weak self, weak textView] in
                    guard let self, let textView else { return }
                    self.revealInsertionPointAfterNewline(in: textView)
                }
                return false
            }
            return false
        }

        func applyTypingAttributes(to textView: NSTextView) {
            textView.defaultParagraphStyle = RichTextEditor.normalParagraphStyle()
            textView.typingAttributes = [
                .font: font,
                .paragraphStyle: RichTextEditor.normalParagraphStyle(),
                .foregroundColor: NSColor.labelColor
            ]
        }

        func applyExternalText(_ newText: String, to textView: NSTextView, preserveSelection: Bool) {
            if !preserveSelection, Self.hasImageMarkers(newText) {
                applyDeferredImageText(newText, to: textView)
                return
            }

            let selectedRange = textView.selectedRange()
            isApplyingProgrammaticChange = true

            let attributed = Self.attributedStringFromMarkedText(newText, font: font, imageLoader: imageLoader)

            if let textStorage = textView.textStorage {
                textStorage.setAttributedString(attributed)
            } else {
                textView.textStorage?.setAttributedString(attributed)
            }

            previousAttachmentIDs = Self.attachmentIDs(in: textView)
            markHeightInvalidated()
            scheduleHeightInvalidation(for: textView)

            if preserveSelection {
                let maxLocation = textView.textStorage?.length ?? 0
                let clampedLocation = min(selectedRange.location, maxLocation)
                let clampedLength = min(selectedRange.length, max(0, maxLocation - clampedLocation))
                textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
            } else {
                textView.setSelectedRange(NSRange(location: textView.textStorage?.length ?? 0, length: 0))
            }

            isApplyingProgrammaticChange = false
            isShowingDeferredImagePlaceholders = false
            scrollSelectionIntoView(for: textView)
        }

        private func applyDeferredImageText(_ newText: String, to textView: NSTextView) {
            let placeholder = Self.attributedStringFromMarkedText(
                newText,
                font: font,
                imageLoader: imageLoader,
                renderImages: false
            )

            isApplyingProgrammaticChange = true
            isShowingDeferredImagePlaceholders = true
            textView.textStorage?.setAttributedString(placeholder)
            textView.setSelectedRange(NSRange(location: textView.textStorage?.length ?? 0, length: 0))
            isApplyingProgrammaticChange = false

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                guard self.isShowingDeferredImagePlaceholders else { return }
                guard !self.isEditing else { return }
                self.applyExternalText(newText, to: textView, preserveSelection: true)
            }
        }

        func measuredHeight(for textView: NSTextView, width: CGFloat, minHeight: CGFloat) -> CGFloat {
            guard !isMeasuringSize else {
                return lastMeasuredHeight > 0 ? lastMeasuredHeight : minHeight
            }

            isMeasuringSize = true
            defer { isMeasuringSize = false }

            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
                return minHeight
            }

            // Return cache if width unchanged and content hasn't changed
            if !heightInvalidated,
               lastMeasuredRevision == contentRevision,
               abs(width - lastMeasuredWidth) < 0.5,
               lastMeasuredHeight > 0 {
                return lastMeasuredHeight
            }

            lastMeasuredWidth = width
            let contentWidth = max(0, width - 4)
            textContainer.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let extraLineRect = layoutManager.extraLineFragmentRect
            let contentMaxY = extraLineRect.isEmpty ? usedRect.maxY : max(usedRect.maxY, extraLineRect.maxY)
            let height = max(minHeight, ceil(contentMaxY + verticalPadding * 2))
            lastMeasuredHeight = height
            lastMeasuredRevision = contentRevision
            heightInvalidated = false
            return height
        }

        private func markHeightInvalidated() {
            contentRevision += 1
            heightInvalidated = true
        }

        private func scheduleHeightInvalidation(for textView: NSTextView) {
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView, self.heightInvalidated else { return }
                textView.invalidateIntrinsicContentSize()
            }
        }

        // MARK: - Image marker helpers

        static func stringWithImageMarkers(from textView: NSTextView) -> String {
            guard let storage = textView.textStorage else { return textView.string }
            var result = ""
            storage.enumerateAttributes(in: NSRange(location: 0, length: storage.length), options: []) { attrs, range, _ in
                if attrs[.generatedImageLayoutNewline] as? Bool == true {
                    return
                }
                if let attachment = attrs[.attachment] as? ImageTextAttachment {
                    result += "[IMG:\(attachment.imageID.uuidString)]"
                    return
                }
                result += (storage.string as NSString).substring(with: range)
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
            font: NSFont,
            imageLoader: (UUID) -> NSImage?,
            renderImages: Bool = true
        ) -> NSAttributedString {
            let normalAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: RichTextEditor.normalParagraphStyle()
            ]

            let pattern = #"\[IMG:([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return NSAttributedString(string: markedText, attributes: normalAttrs)
            }

            let fullRange = NSRange(markedText.startIndex..., in: markedText)
            let matches = regex.matches(in: markedText, range: fullRange)
            let result = NSMutableAttributedString()
            var lastEnd = markedText.startIndex

            for match in matches {
                let markerRange = Range(match.range, in: markedText)!
                let beforeText = markedText[lastEnd..<markerRange.lowerBound]
                if !beforeText.isEmpty {
                    result.append(NSAttributedString(string: String(beforeText), attributes: normalAttrs))
                }

                // Insert generated \n before attachment if needed
                if result.length > 0 && !result.string.hasSuffix("\n") {
                    result.append(RichTextEditor.generatedNewline())
                }

                let uuidRange = Range(match.range(at: 1), in: markedText)!
                let uuidString = String(markedText[uuidRange])
                if renderImages, let uuid = UUID(uuidString: uuidString), let image = imageLoader(uuid) {
                    let attachment = ImageTextAttachment(image: image, imageID: uuid)
                    let imageAttrs: [NSAttributedString.Key: Any] = [
                        .paragraphStyle: RichTextEditor.imageParagraphStyle()
                    ]
                    let attachmentString = NSAttributedString(attachment: attachment)
                    let mutable = NSMutableAttributedString(attributedString: attachmentString)
                    mutable.addAttributes(imageAttrs, range: NSRange(location: 0, length: mutable.length))
                    result.append(mutable)
                } else {
                    result.append(NSAttributedString(string: "[图片]", attributes: normalAttrs))
                }

                // Insert generated \n after attachment with image paragraph style
                result.append(RichTextEditor.generatedNewline(paragraphStyle: RichTextEditor.imageParagraphStyle()))

                lastEnd = markerRange.upperBound
            }

            if lastEnd < markedText.endIndex {
                result.append(NSAttributedString(string: String(markedText[lastEnd..<markedText.endIndex]), attributes: normalAttrs))
            }

            return result
        }

        static func hasImageMarkers(_ markedText: String) -> Bool {
            markedText.contains("[IMG:")
        }

        private func scrollSelectionIntoView(for textView: NSTextView) {
            let selection = textView.selectedRange()
            guard selection.location != NSNotFound else { return }
            textView.scrollRangeToVisible(selection)
        }

        private func revealInsertionPointAfterNewline(in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager else {
                scrollSelectionIntoView(for: textView)
                return
            }

            let selection = textView.selectedRange()
            guard selection.location != NSNotFound else { return }

            if selection.location == (textView.textStorage?.length ?? 0) {
                let extraLineRect = layoutManager.extraLineFragmentRect
                if !extraLineRect.isEmpty {
                    let targetRect = extraLineRect.insetBy(dx: 0, dy: -extraLineRect.height)
                    textView.scrollToVisible(targetRect)
                    return
                }
            }

            let visibleLocation = max(0, selection.location - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: visibleLocation)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let targetRect = NSRect(
                x: lineRect.minX,
                y: lineRect.maxY - 1,
                width: max(1, lineRect.width),
                height: max(lineRect.height * 1.5, 24)
            )
            textView.scrollToVisible(targetRect)
        }
    }
}

final class InterceptingTextView: NSTextView {
    override var isFlipped: Bool { true }
    var onImagePasted: ((NSImage) -> UUID?)?
    var onImageClicked: ((UUID) -> Void)?
    private var previousAcceptsMouseMovedEvents: Bool?
    private lazy var imageActionButton: NSButton = makeImageActionButton()
    private var hoveredImageID: UUID?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            if previousAcceptsMouseMovedEvents == nil {
                previousAcceptsMouseMovedEvents = window.acceptsMouseMovedEvents
            }
            window.acceptsMouseMovedEvents = true
        }
        ensureImageActionButton()
    }

    deinit {
        if let window, let previousAcceptsMouseMovedEvents {
            window.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
        }
    }

    override func mouseEntered(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateImageHover(at: point)
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateImageHover(at: point)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hideImageActionButton()
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        syncTextContainerLayout()
        let point = convert(event.locationInWindow, from: nil)
        if let hit = imageHit(at: point), hit.zoomBadgeRect.contains(point) {
            onImageClicked?(hit.attachment.imageID)
            return
        }
        if moveInsertionPointToDocumentEndIfNeeded(at: point) {
            return
        }
        super.mouseDown(with: event)
    }

    private struct ImageHit {
        let attachment: ImageTextAttachment
        let attachmentRect: CGRect
        let zoomBadgeRect: CGRect
    }

    private func ensureImageActionButton() {
        guard imageActionButton.superview == nil else { return }
        addSubview(imageActionButton)
        imageActionButton.isHidden = true
    }

    private func makeImageActionButton() -> NSButton {
        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        button.contentTintColor = .white
        if let image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "放大图片") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            button.image = image.withSymbolConfiguration(config)
        }
        button.target = self
        button.action = #selector(handleImageActionButtonClick)
        return button
    }

    @objc
    private func handleImageActionButtonClick() {
        guard let hoveredImageID else { return }
        onImageClicked?(hoveredImageID)
    }

    private func updateImageHover(at point: CGPoint) {
        ensureImageActionButton()
        guard let hit = imageHit(at: point) else {
            hideImageActionButton()
            return
        }

        hoveredImageID = hit.attachment.imageID
        imageActionButton.frame = hit.zoomBadgeRect
        imageActionButton.isHidden = false
        imageActionButton.needsDisplay = true
    }

    private func hideImageActionButton() {
        hoveredImageID = nil
        imageActionButton.isHidden = true
    }

    private func imageHit(at point: CGPoint) -> ImageHit? {
        guard
            let layoutManager,
            let textContainer,
            let storage = textStorage,
            storage.length > 0
        else { return nil }

        let containerPoint = CGPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex >= 0, characterIndex < storage.length else { return nil }

        var effectiveRange = NSRange(location: 0, length: 0)
        guard let attachment = storage.attribute(.attachment, at: characterIndex, effectiveRange: &effectiveRange) as? ImageTextAttachment else {
            return nil
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)
        var attachmentRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        attachmentRect.origin.x += textContainerOrigin.x
        attachmentRect.origin.y += textContainerOrigin.y

        guard attachmentRect.contains(point) else { return nil }

        return ImageHit(
            attachment: attachment,
            attachmentRect: attachmentRect,
            zoomBadgeRect: attachment.zoomBadgeRect(in: attachmentRect)
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        syncTextContainerLayout()
    }

    private func syncTextContainerLayout() {
        guard let tc = textContainer, bounds.width > 0 else { return }
        let contentWidth = max(0, bounds.width - textContainerInset.width * 2)
        tc.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        layoutManager?.ensureLayout(for: tc)
    }

    private func moveInsertionPointToDocumentEndIfNeeded(at point: CGPoint) -> Bool {
        guard
            let layoutManager,
            let textContainer,
            let textStorage,
            textStorage.length > 0
        else { return false }

        layoutManager.ensureLayout(for: textContainer)
        let extraLineRect = layoutManager.extraLineFragmentRect
        guard !extraLineRect.isEmpty else { return false }

        let extraLineInTextView = extraLineRect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        let clickableRect = extraLineInTextView.insetBy(dx: -textContainerInset.width, dy: -max(4, textContainerInset.height))
        guard clickableRect.contains(point) else { return false }

        window?.makeFirstResponder(self)
        setSelectedRange(NSRange(location: textStorage.length, length: 0))
        scrollRangeToVisible(selectedRange())
        return true
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let image = Self.imageFromPasteboard(pb) {
            guard let imageID = onImagePasted?(image) else { return }
            let attachment = ImageTextAttachment(image: image, imageID: imageID)
            let insert = NSMutableAttributedString()
            let range = selectedRange()

            // Insert generated \n before if needed
            if range.location > 0, let textStorage {
                let string = textStorage.string as NSString
                if string.character(at: range.location - 1) != 0x0A {
                    insert.append(RichTextEditor.generatedNewline())
                }
            }

            // Insert attachment with image paragraph style
            let imageAttrs: [NSAttributedString.Key: Any] = [
                .paragraphStyle: RichTextEditor.imageParagraphStyle()
            ]
            let mutable = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
            mutable.addAttributes(imageAttrs, range: NSRange(location: 0, length: mutable.length))
            insert.append(mutable)

            // Insert generated \n after with image paragraph style
            insert.append(RichTextEditor.generatedNewline(paragraphStyle: RichTextEditor.imageParagraphStyle()))

            guard let textStorage else { return }
            textStorage.replaceCharacters(in: range, with: insert)
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
