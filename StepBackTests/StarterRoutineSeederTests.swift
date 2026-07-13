import Foundation
import SwiftData
import Testing
@testable import StepBack
import StepBackCore

@Suite("Starter routine seeding")
@MainActor
struct StarterRoutineSeederTests {
    @Test("Fresh empty install seeds the three localized starters exactly once")
    func freshInstall() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let flag = InMemorySeedingFlagStore()
        let service = try WorkoutCatalogService(bundle: .main)
        let now = Date(timeIntervalSince1970: 10_000)
        var nextID = 0

        let result = try StarterRoutineSeeder.seedIfNeeded(
            in: container.mainContext,
            catalogService: service,
            flagStore: flag,
            now: now,
            makeID: { nextID += 1; return "id-\(nextID)" }
        )

        let routines = try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext)
            .sorted { $0.seedIdentifier ?? "" < $1.seedIdentifier ?? "" }
        #expect(result == .seeded(count: 3))
        #expect(flag.hasSeededStarterRoutines)
        #expect(routines.count == 3)
        #expect(Set(routines.compactMap(\.seedIdentifier)) == Set(service.catalog.starterRoutines.map(\.nameKey)))
        #expect(routines.allSatisfy { $0.createdAt == now && $0.updatedAt == now })
        #expect(routines.allSatisfy { routine in
            (routine.steps ?? []).map(\.sortIndex).sorted() == Array(0..<(routine.steps?.count ?? 0))
        })
        #expect(routines.flatMap { $0.steps ?? [] }.allSatisfy { !$0.workoutNameSnapshot.hasPrefix("workout.") })
        #expect(routines.flatMap { $0.steps ?? [] }.contains { $0.repGuidance == 15 })
        let expectedTotals = [
            "starter.quick-start": 290,
            "starter.full-body-classic": 835,
            "starter.full-session": 1_180
        ]
        for routine in routines {
            #expect(
                TimelineCompiler.compile(routine.snapshot, getReadySeconds: 0).totalDurationSeconds
                    == expectedTotals[routine.seedIdentifier ?? ""]
            )
        }

        let second = try StarterRoutineSeeder.seedIfNeeded(
            in: container.mainContext,
            catalogService: service,
            flagStore: flag
        )
        #expect(second == .alreadySeeded)
        #expect(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).count == 3)
    }

    @Test("Existing routine wins and records the local seed decision")
    func existingRoutineWins() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let existing = Routine(name: "Synced Routine")
        context.insert(existing)
        try context.save()
        let flag = InMemorySeedingFlagStore()

        let result = try StarterRoutineSeeder.seedIfNeeded(
            in: context,
            catalogService: WorkoutCatalogService(bundle: .main),
            flagStore: flag
        )

        #expect(result == .storeNotEmpty)
        #expect(flag.hasSeededStarterRoutines)
        #expect(try PersistenceTestSupport.fetch(Routine.self, from: context).map(\.name) == ["Synced Routine"])
    }

    @Test("A deleted-empty store does not silently re-seed")
    func deletedEverythingStaysEmpty() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let flag = InMemorySeedingFlagStore(hasSeededStarterRoutines: true)

        let result = try StarterRoutineSeeder.seedIfNeeded(
            in: container.mainContext,
            catalogService: WorkoutCatalogService(bundle: .main),
            flagStore: flag
        )

        #expect(result == .alreadySeeded)
        #expect(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).isEmpty)
    }

    @Test("Other entity rows do not prevent seeding when routines are absent")
    func unrelatedRowsDoNotBlock() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        context.insert(CustomWorkout(name: "Wall Sit", categoryID: "legs-glutes"))
        context.insert(RoutineSession(routineNameSnapshot: "Deleted Routine"))
        try context.save()

        let result = try StarterRoutineSeeder.seedIfNeeded(
            in: context,
            catalogService: WorkoutCatalogService(bundle: .main),
            flagStore: InMemorySeedingFlagStore()
        )

        #expect(result == .seeded(count: 3))
        #expect(try PersistenceTestSupport.fetch(Routine.self, from: context).count == 3)
    }
}
