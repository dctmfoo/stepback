import Foundation

struct AgentBridgeManifest: Codable, Equatable {
    var schemaVersion: Int
    var generatedAt: String
    var rootPath: String
    var inboxPath: String
    var processedPath: String
    var failedPath: String
    var catalogVersion: Int
    var categories: [Category]
    var catalogWorkouts: [CatalogWorkout]
    var customWorkouts: [CustomWorkoutEntry]
    var routines: [RoutineEntry]
    var plans: [PlanEntry]

    struct Category: Codable, Equatable {
        var id: String
        var displayName: String
        var symbolName: String
    }

    struct CatalogWorkout: Codable, Equatable {
        var id: String
        var displayName: String
        var categoryID: String
        var focusAreas: [String]
    }

    struct CustomWorkoutEntry: Codable, Equatable {
        var id: String
        var name: String
        var categoryID: String
        var notes: String?
        var createdAt: String
        var updatedAt: String
        var lastEditedVia: String?
    }

    struct RoutineEntry: Codable, Equatable {
        var id: String
        var name: String
        var createdAt: String
        var updatedAt: String
        var lastEditedVia: String?
        var totalSeconds: Int
        var sessionCount: Int
        var completedSessionCount: Int
        var steps: [RoutineStepEntry]
    }

    struct RoutineStepEntry: Codable, Equatable {
        var workoutID: String
        var workoutName: String
        var workSeconds: Int
        var sets: Int
        var setRestSeconds: Int
        var restAfterSeconds: Int
        var repGuidance: Int?
    }

    struct PlanEntry: Codable, Equatable {
        var id: String
        var name: String
        var createdAt: String
        var updatedAt: String
        var lastEditedVia: String?
        var isMyWeek: Bool
        var days: [PlanDayEntry]
    }

    struct PlanDayEntry: Codable, Equatable {
        var weekday: Int
        var slots: [PlanSlotEntry]
    }

    struct PlanSlotEntry: Codable, Equatable {
        var id: String
        var index: Int
        var routineID: String
        var routineName: String
        var routineExists: Bool
    }
}
