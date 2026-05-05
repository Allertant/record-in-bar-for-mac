import AppKit

extension NSAttributedString.Key {
    static let generatedImageLayoutNewline = NSAttributedString.Key("generatedImageLayoutNewline")
}

final class ImageTextAttachment: NSTextAttachment {
    private static let preferredDisplayWidth: CGFloat = 280
    let imageID: UUID

    init(image: NSImage, imageID: UUID) {
        self.imageID = imageID
        super.init(data: nil, ofType: nil)
        self.image = image
    }

    required init?(coder: NSCoder) {
        guard let uuidString = coder.decodeObject(forKey: "imageID") as? String,
              let uuid = UUID(uuidString: uuidString) else { return nil }
        self.imageID = uuid
        super.init(coder: coder)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(imageID.uuidString, forKey: "imageID")
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment frag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        guard let image else { return .zero }

        // Keep image sizing stable so attachments don't participate in repeated
        // container width negotiation inside the popover.
        let proposedWidth = max(textContainer?.containerSize.width ?? 0, frag.width)
        let maxWidth = proposedWidth > 0 ? min(proposedWidth - 4, Self.preferredDisplayWidth) : Self.preferredDisplayWidth
        guard maxWidth > 0 else { return .zero }
        let aspectRatio = image.size.width / image.size.height
        let displayWidth = min(maxWidth, image.size.width)
        let displayHeight = displayWidth / aspectRatio
        return CGRect(x: 0, y: 0, width: displayWidth, height: displayHeight)
    }
}
