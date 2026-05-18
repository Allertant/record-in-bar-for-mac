import AppKit
import SwiftData
import SwiftUI

extension EditorPageView {
    @MainActor
    @discardableResult
    func savePastedImage(_ image: NSImage) -> UUID? {
        let targetID: UUID
        if let existingID = topic?.id ?? loadedTopicID {
            targetID = existingID
        } else {
            let newTopic = Topic(title: "", kind: .other)
            modelContext.insert(newTopic)
            loadedTopicID = newTopic.id
            onPersistChange(newTopic.id)
            targetID = newTopic.id
        }

        guard let jpegData = jpegDataForStorage(from: image) else { return nil }

        let imageID = UUID()
        do {
            let relativePath = try ImageStorage.saveJPEG(data: jpegData, topicID: targetID, imageID: imageID)
            let descriptor = FetchDescriptor<NoteImage>(predicate: #Predicate<NoteImage> { $0.topicID == targetID })
            let existing = (try? modelContext.fetch(descriptor)) ?? []
            let nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1

            let noteImage = NoteImage(
                id: imageID,
                topicID: targetID,
                relativePath: relativePath,
                fileName: "\(imageID.uuidString).jpg",
                fileSize: jpegData.count,
                width: image.size.width,
                height: image.size.height,
                sortIndex: nextIndex
            )
            modelContext.insert(noteImage)
            try modelContext.save()
            return imageID
        } catch {
            print("保存图片失败：\(error)")
            return nil
        }
    }

    @MainActor
    func deleteInlineImage(_ imageID: UUID) {
        let descriptor = FetchDescriptor<NoteImage>(predicate: #Predicate { $0.id == imageID })
        guard let noteImage = try? modelContext.fetch(descriptor).first else { return }
        ImageStorage.deleteImage(relativePath: noteImage.relativePath)
        modelContext.delete(noteImage)
        try? modelContext.save()
    }

    func jpegDataForStorage(
        from image: NSImage,
        maxDimension: CGFloat = 2400,
        maxBytes: Int = 4 * 1024 * 1024
    ) -> Data? {
        let resized: NSImage
        if max(image.size.width, image.size.height) > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            let tmp = NSImage(size: newSize)
            tmp.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            tmp.unlockFocus()
            resized = tmp
        } else {
            resized = image
        }

        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        for quality: CGFloat in [0.85, 0.75, 0.65, 0.55, 0.45] {
            if let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]),
               data.count <= maxBytes {
                return data
            }
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.3])
    }

    @MainActor
    func deleteImage(_ noteImage: NoteImage) {
        ImageStorage.deleteImage(relativePath: noteImage.relativePath)
        modelContext.delete(noteImage)
        try? modelContext.save()
    }
}
