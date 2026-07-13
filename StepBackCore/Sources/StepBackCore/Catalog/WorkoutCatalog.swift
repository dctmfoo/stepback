import Foundation

public enum CatalogError: Error, Equatable, Sendable {
    case invalidCategoryOrder(expected: [String], actual: [String])
    case duplicateWorkoutID(String)
    case unknownCategoryID(workoutID: String, categoryID: String)
    case unknownStarterWorkoutID(String)
}

public struct WorkoutCategory: Codable, Equatable, Hashable, Sendable {
    public static let requiredIDs = [
        "full-body",
        "core",
        "arms-shoulders",
        "chest-back",
        "legs-glutes",
        "cardio",
        "mobility-stretch",
        "balance"
    ]

    public let id: String
    public let nameKey: String
    public let symbolName: String

    public init(id: String, nameKey: String, symbolName: String) {
        self.id = id
        self.nameKey = nameKey
        self.symbolName = symbolName
    }
}

public struct WorkoutDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let nameKey: String
    public let categoryID: String
    public let focusAreas: [String]
    public let mediaKey: String?
    public let instructionsKey: String?

    public init(
        id: String,
        nameKey: String,
        categoryID: String,
        focusAreas: [String] = [],
        mediaKey: String? = nil,
        instructionsKey: String? = nil
    ) {
        self.id = id
        self.nameKey = nameKey
        self.categoryID = categoryID
        self.focusAreas = focusAreas
        self.mediaKey = mediaKey
        self.instructionsKey = instructionsKey
    }
}

public struct StarterRoutineStepDefinition: Codable, Equatable, Hashable, Sendable {
    public let workoutID: String
    public let workSeconds: Int
    public let sets: Int
    public let setRestSeconds: Int
    public let restAfterSeconds: Int
    public let repGuidance: Int?

    public init(
        workoutID: String,
        workSeconds: Int,
        sets: Int = 1,
        setRestSeconds: Int = 0,
        restAfterSeconds: Int = 0,
        repGuidance: Int? = nil
    ) {
        self.workoutID = workoutID
        self.workSeconds = workSeconds
        self.sets = sets
        self.setRestSeconds = setRestSeconds
        self.restAfterSeconds = restAfterSeconds
        self.repGuidance = repGuidance
    }
}

public struct StarterRoutineDefinition: Codable, Equatable, Hashable, Sendable {
    public let nameKey: String
    public let steps: [StarterRoutineStepDefinition]

    public init(nameKey: String, steps: [StarterRoutineStepDefinition]) {
        self.nameKey = nameKey
        self.steps = steps
    }
}

public struct WorkoutCatalog: Decodable, Equatable, Sendable {
    public let catalogVersion: Int
    public let categories: [WorkoutCategory]
    public let workouts: [WorkoutDefinition]
    public let starterRoutines: [StarterRoutineDefinition]

    public init(
        catalogVersion: Int,
        categories: [WorkoutCategory],
        workouts: [WorkoutDefinition],
        starterRoutines: [StarterRoutineDefinition]
    ) throws {
        try Self.validate(categories: categories, workouts: workouts, starterRoutines: starterRoutines)
        self.catalogVersion = catalogVersion
        self.categories = categories
        self.workouts = workouts
        self.starterRoutines = starterRoutines
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let catalogVersion = try container.decode(Int.self, forKey: .catalogVersion)
        let categories = try container.decode([WorkoutCategory].self, forKey: .categories)
        let workouts = try container.decode([WorkoutDefinition].self, forKey: .workouts)
        let starterRoutines = try container.decode([StarterRoutineDefinition].self, forKey: .starterRoutines)

        try self.init(
            catalogVersion: catalogVersion,
            categories: categories,
            workouts: workouts,
            starterRoutines: starterRoutines
        )
    }

    public func workout(id: String) -> WorkoutDefinition? {
        workouts.first { $0.id == id }
    }

    public func routineSnapshot(
        for definition: StarterRoutineDefinition,
        routineNameSnapshot: String,
        workoutNameSnapshot: (WorkoutDefinition) -> String
    ) throws -> RoutineSnapshot {
        let steps = try definition.steps.map { step -> RoutineStepSnapshot in
            guard let workout = workout(id: step.workoutID) else {
                throw CatalogError.unknownStarterWorkoutID(step.workoutID)
            }
            return RoutineStepSnapshot(
                workoutID: step.workoutID,
                workoutNameSnapshot: workoutNameSnapshot(workout),
                workSeconds: step.workSeconds,
                sets: step.sets,
                setRestSeconds: step.setRestSeconds,
                restAfterSeconds: step.restAfterSeconds,
                repGuidance: step.repGuidance
            )
        }
        return RoutineSnapshot(name: routineNameSnapshot, steps: steps)
    }

    private enum CodingKeys: String, CodingKey {
        case catalogVersion
        case categories
        case workouts
        case starterRoutines
    }

    private static func validate(
        categories: [WorkoutCategory],
        workouts: [WorkoutDefinition],
        starterRoutines: [StarterRoutineDefinition]
    ) throws {
        let categoryIDs = categories.map(\.id)
        guard categoryIDs == WorkoutCategory.requiredIDs else {
            throw CatalogError.invalidCategoryOrder(expected: WorkoutCategory.requiredIDs, actual: categoryIDs)
        }

        let allowedCategoryIDs = Set(categoryIDs)
        var seenWorkoutIDs = Set<String>()
        for workout in workouts {
            guard seenWorkoutIDs.insert(workout.id).inserted else {
                throw CatalogError.duplicateWorkoutID(workout.id)
            }
            guard allowedCategoryIDs.contains(workout.categoryID) else {
                throw CatalogError.unknownCategoryID(workoutID: workout.id, categoryID: workout.categoryID)
            }
        }

        for step in starterRoutines.flatMap(\.steps) where !seenWorkoutIDs.contains(step.workoutID) {
            throw CatalogError.unknownStarterWorkoutID(step.workoutID)
        }
    }
}

public enum CatalogDecoder {
    public static func decode(_ data: Data) throws -> WorkoutCatalog {
        try JSONDecoder().decode(WorkoutCatalog.self, from: data)
    }
}
