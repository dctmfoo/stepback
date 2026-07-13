import Foundation
import SwiftData
@testable import StepBack

@MainActor
enum PersistenceTestSupport {
    static func makeContainer() throws -> ModelContainer {
        try StepBackModelContainer.makeInMemory()
    }

    static func fetch<T: PersistentModel>(
        _ type: T.Type,
        from context: ModelContext
    ) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    static func routine(
        id: String = UUID().uuidString,
        name: String = "Routine",
        seedIdentifier: String? = nil,
        createdAt: Date,
        updatedAt: Date? = nil,
        steps: [RoutineStep] = []
    ) -> Routine {
        Routine(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt,
            seedIdentifier: seedIdentifier,
            steps: steps
        )
    }
}

final class InMemorySeedingFlagStore: StarterSeedingFlagStore, @unchecked Sendable {
    var hasSeededStarterRoutines: Bool

    init(hasSeededStarterRoutines: Bool = false) {
        self.hasSeededStarterRoutines = hasSeededStarterRoutines
    }
}
