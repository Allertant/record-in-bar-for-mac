import Foundation
import SwiftData

@Model
public final class NoteImage {
    @Attribute(.unique) public var id: UUID
    public var topicID: UUID
    public var relativePath: String
    public var fileName: String
    public var fileSize: Int
    public var width: Double
    public var height: Double
    public var sortIndex: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        topicID: UUID,
        relativePath: String,
        fileName: String,
        fileSize: Int,
        width: Double,
        height: Double,
        sortIndex: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.topicID = topicID
        self.relativePath = relativePath
        self.fileName = fileName
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}
