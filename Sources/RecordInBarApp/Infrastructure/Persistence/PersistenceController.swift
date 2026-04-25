import Foundation
import SwiftData

@MainActor
enum PersistenceController {
    static let shared = SharedPersistenceController()
}

final class SharedPersistenceController {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([
            Topic.self,
            NoteItem.self,
            AISummary.self,
            AppSettings.self
        ])

        do {
            let configuration = try Self.makeConfiguration(schema: schema, inMemory: inMemory)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            guard !inMemory else {
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }

            do {
                try Self.resetPersistentStoreFiles()
                let configuration = try Self.makeConfiguration(schema: schema, inMemory: false)
                container = try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to recreate ModelContainer after store reset: \(error)")
            }
        }
    }

    private static func makeConfiguration(schema: Schema, inMemory: Bool) throws -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(
                "RecordInBar",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        }

        let storeURL = try persistentStoreURL()
        return ModelConfiguration(
            "RecordInBar",
            schema: schema,
            url: storeURL,
            allowsSave: true
        )
    }

    private static func persistentStoreURL() throws -> URL {
        let appSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return appSupportDirectory.appending(path: "RecordInBar.store")
    }

    private static func resetPersistentStoreFiles() throws {
        let storeURL = try persistentStoreURL()
        let fileManager = FileManager.default
        let candidates = [
            storeURL,
            URL(fileURLWithPath: storeURL.path() + "-shm"),
            URL(fileURLWithPath: storeURL.path() + "-wal")
        ]

        for url in candidates where fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }
}
