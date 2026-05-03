import AppKit

final class ImageTextAttachment: NSTextAttachment {
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
        let maxWidth = (textContainer?.containerSize.width ?? frag.width) - 4
        guard maxWidth > 0 else { return .zero }
        let aspectRatio = image.size.width / image.size.height
        let displayWidth = min(maxWidth, image.size.width)
        let displayHeight = displayWidth / aspectRatio
        return CGRect(x: 0, y: 0, width: displayWidth, height: displayHeight)
    }
}
