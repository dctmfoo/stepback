import Foundation
import SwiftData
import StepBackCore

protocol StarterSeedingFlagStore: AnyObject {
    var hasSeededStarterRoutines: Bool { get set }
}

final class UserDefaultsStarterSeedingFlagStore: StarterSeedingFlagStore {
    private static let key = "starterRoutinesSeeded.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSeededStarterRoutines: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

enum StarterSeedingResult: Equatable {
    case seeded(count: Int)
    case alreadySeeded
    case storeNotEmpty
}

@MainActor
enum StarterRoutineSeeder {
    static func seedIfNeeded(
        in context: ModelContext,
        catalogService: WorkoutCatalogService,
        flagStore: any StarterSeedingFlagStore,
        now: Date = Date(),
        makeID: () -> String = { UUID().uuidString }
    ) throws -> StarterSeedingResult {
        guard !flagStore.hasSeededStarterRoutines else {
            return .alreadySeeded
        }

        var descriptor = FetchDescriptor<Routine>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else {
            flagStore.hasSeededStarterRoutines = true
            return .storeNotEmpty
        }

        for definition in catalogService.catalog.starterRoutines {
            context.insert(try makeRoutine(
                from: definition,
                catalogService: catalogService,
                now: now,
                id: makeID()
            ))
        }

        try context.saveOrRollback()
        flagStore.hasSeededStarterRoutines = true
        return .seeded(count: catalogService.catalog.starterRoutines.count)
    }

    static func restoreMissing(
        in context: ModelContext,
        catalogService: WorkoutCatalogService,
        now: Date = .now,
        makeID: () -> String = { UUID().uuidString }
    ) throws -> Int {
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.seedIdentifier != nil }
        )
        let existingIdentifiers = Set(try context.fetch(descriptor).compactMap(\.seedIdentifier))
        let missing = catalogService.catalog.starterRoutines.filter {
            !existingIdentifiers.contains($0.nameKey)
        }

        for definition in missing {
            context.insert(try makeRoutine(
                from: definition,
                catalogService: catalogService,
                now: now,
                id: makeID()
            ))
        }

        if !missing.isEmpty {
            try context.saveOrRollback()
        }
        return missing.count
    }

    private static func makeRoutine(
        from definition: StarterRoutineDefinition,
        catalogService: WorkoutCatalogService,
        now: Date,
        id: String
    ) throws -> Routine {
        let catalog = catalogService.catalog
        let steps = try definition.steps.enumerated().map { index, stepDefinition in
            guard let workout = catalog.workout(id: stepDefinition.workoutID) else {
                throw StepBackSeedingError.missingWorkout(stepDefinition.workoutID)
            }
            return RoutineStep(
                sortIndex: index,
                workoutID: workout.id,
                workoutNameSnapshot: catalogService.localizedString(for: workout.nameKey),
                workSeconds: stepDefinition.workSeconds,
                sets: stepDefinition.sets,
                setRestSeconds: stepDefinition.setRestSeconds,
                restAfterSeconds: stepDefinition.restAfterSeconds,
                repGuidance: stepDefinition.repGuidance
            )
        }
        return Routine(
            id: id,
            name: catalogService.localizedString(for: definition.nameKey),
            createdAt: now,
            updatedAt: now,
            seedIdentifier: definition.nameKey,
            steps: steps
        )
    }
}

enum StepBackSeedingError: Error, Equatable {
    case missingWorkout(String)
}
