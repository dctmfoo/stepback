import Foundation
import StepBackCore

struct WorkoutItem: Identifiable, Hashable {
    enum Source: Hashable {
        case builtIn
        case custom
    }

    let id: String
    let name: String
    let categoryID: String
    let focusAreas: [String]
    let mediaKey: String?
    let notes: String?
    let source: Source

    var isCustom: Bool {
        source == .custom
    }

    static func builtIn(_ definition: WorkoutDefinition, name: String) -> WorkoutItem {
        WorkoutItem(
            id: definition.id,
            name: name,
            categoryID: definition.categoryID,
            focusAreas: definition.focusAreas,
            mediaKey: definition.mediaKey,
            notes: nil,
            source: .builtIn
        )
    }

    static func custom(_ workout: CustomWorkout) -> WorkoutItem {
        WorkoutItem(
            id: workout.id,
            name: workout.name,
            categoryID: workout.categoryID,
            focusAreas: [],
            mediaKey: nil,
            notes: workout.notes,
            source: .custom
        )
    }
}
