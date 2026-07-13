import Foundation
import SwiftData

@MainActor
enum StarterRoutineDeduplicator {
    @discardableResult
    static func removePristineDuplicates(in context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.seedIdentifier != nil }
        )
        let seededRoutines = try context.fetch(descriptor)
        let groups = Dictionary(grouping: seededRoutines, by: \.seedIdentifier)
        var deletedCount = 0

        for routines in groups.values where routines.count > 1 {
            let nonPristine = routines.filter { !isPristine($0) }
            let routinesToDelete: [Routine]

            if nonPristine.isEmpty {
                let ordered = routines.sorted(by: stableOrder)
                routinesToDelete = Array(ordered.dropFirst())
            } else {
                routinesToDelete = routines.filter(isPristine)
            }

            for routine in routinesToDelete {
                context.delete(routine)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try context.save()
        }
        return deletedCount
    }

    private static func isPristine(_ routine: Routine) -> Bool {
        routine.updatedAt == routine.createdAt && (routine.sessions?.isEmpty ?? true)
    }

    private static func stableOrder(_ lhs: Routine, _ rhs: Routine) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.id < rhs.id
        }
        return lhs.createdAt < rhs.createdAt
    }
}
