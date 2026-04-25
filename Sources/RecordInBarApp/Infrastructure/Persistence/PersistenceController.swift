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

        let configuration = ModelConfiguration(
            "RecordInBar",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
