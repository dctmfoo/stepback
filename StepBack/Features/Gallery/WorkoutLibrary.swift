import Foundation
import SwiftData

enum WorkoutValidationError: Error, Equatable {
    case emptyName
}

@MainActor
enum WorkoutLibrary {
    static func allItems(
        catalogService: WorkoutCatalogService,
        customWorkouts: [CustomWorkout]
    ) -> [WorkoutItem] {
        let builtIns = catalogService.catalog.workouts.map { definition in
            WorkoutItem.builtIn(
                definition,
                name: catalogService.localizedString(for: definition.nameKey)
            )
        }
        return builtIns + customWorkouts.map(WorkoutItem.custom)
    }

    static func search(_ items: [WorkoutItem], query: String) -> [WorkoutItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.name.localizedStandardContains(trimmed) }
    }

    static func sortedForSearch(_ items: [WorkoutItem], query: String) -> [WorkoutItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.sorted { lhs, rhs in
            let lhsRank = searchRank(lhs.name, query: trimmed)
            let rhsRank = searchRank(rhs.name, query: trimmed)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func searchRank(_ name: String, query: String) -> Int {
        guard !query.isEmpty else { return 2 }
        if name.localizedCaseInsensitiveCompare(query) == .orderedSame {
            return 0
        }
        if name.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive, .anchored]
        ) != nil {
            return 1
        }
        return 2
    }

    static func routines(containing workoutID: String, in routines: [Routine]) -> [Routine] {
        routines
            .filter { routine in
                (routine.steps ?? []).contains { $0.workoutID == workoutID }
            }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name { return lhs.id < rhs.id }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    static func save(
        _ workout: CustomWorkout?,
        name: String,
        categoryID: String,
        notes: String,
        in context: ModelContext,
        now: Date = .now,
        makeID: () -> String = { UUID().uuidString }
    ) throws -> CustomWorkout {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw WorkoutValidationError.emptyName }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: CustomWorkout
        if let workout {
            value = workout
            value.name = trimmedName
            value.categoryID = categoryID
            value.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            value.updatedAt = now
            value.lastEditedVia = nil
        } else {
            value = CustomWorkout(
                id: makeID(),
                name: trimmedName,
                categoryID: categoryID,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                createdAt: now,
                updatedAt: now
            )
            context.insert(value)
        }
        try context.saveOrRollback()
        return value
    }
}
