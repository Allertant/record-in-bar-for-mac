import AppKit
import Foundation

enum ImageStorage {
    static let rootDirectoryName = "NoteImages"

    static func baseDirectory() throws -> URL {
        let fileManager = FileManager.default

        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ImageStorageError.applicationSupportNotFound
        }

        let directory = appSupport.appendingPathComponent(rootDirectoryName, isDirectory: true)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func directory(for topicID: UUID) throws -> URL {
        let directory = try baseDirectory()
            .appendingPathComponent(topicID.uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    static func saveJPEG(data: Data, topicID: UUID, imageID: UUID) throws -> String {
        let fileName = "\(imageID.uuidString).jpg"
        let noteDirectory = try directory(for: topicID)
        let fileURL = noteDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: [.atomic])
        return "\(topicID.uuidString)/\(fileName)"
    }

    static func loadImage(relativePath: String) -> NSImage? {
        guard let url = try? baseDirectory().appendingPathComponent(relativePath) else { return nil }
        return NSImage(contentsOf: url)
    }

    static func deleteImage(relativePath: String) {
        guard let url = try? baseDirectory().appendingPathComponent(relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteAllImages(for topicID: UUID) {
        guard let dir = try? directory(for: topicID) else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}

enum ImageStorageError: Error {
    case applicationSupportNotFound
}
