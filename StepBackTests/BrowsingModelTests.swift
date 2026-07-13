import Foundation
import SwiftData
import Testing
@testable import StepBack

@Suite("Browsing data operations")
@MainActor
struct BrowsingModelTests {
    @Test("Routines sort by latest play, then creation date, then id")
    func routineOrdering() {
        let oldest = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let latestPlay = Date(timeIntervalSince1970: 4_000)
        let earlierPlay = Date(timeIntervalSince1970: 3_000)
        let neverA = Routine(id: "a", name: "A", createdAt: oldest)
        let neverB = Routine(id: "b", name: "B", createdAt: newer)
        let playedEarlier = Routine(id: "c", name: "C", createdAt: newer)
        let playedLatest = Routine(id: "d", name: "D", createdAt: oldest)
        playedEarlier.sessions = [RoutineSession(startedAt: earlierPlay, routine: playedEarlier)]
        playedLatest.sessions = [RoutineSession(startedAt: latestPlay, routine: playedLatest)]

        let ordered = RoutineLibrary.sorted([neverA, playedEarlier, neverB, playedLatest])

        #expect(ordered.map(\.id) == ["d", "c", "b", "a"])
    }

    @Test("Motivation stays hidden until any session exists")
    func motivationVisibility() {
        #expect(!RoutineLibrary.shouldShowMotivation(sessions: []))
        #expect(RoutineLibrary.shouldShowMotivation(sessions: [RoutineSession(wasCompleted: false)]))
    }

    @Test("Restore adds only missing starters and remains idempotent")
    func restoreMissingStarters() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let service = try WorkoutCatalogService(bundle: .main)
        _ = try StarterRoutineSeeder.seedIfNeeded(
            in: context,
            catalogService: service,
            flagStore: InMemorySeedingFlagStore(),
            now: Date(timeIntervalSince1970: 1_000)
        )
        let routines = try PersistenceTestSupport.fetch(Routine.self, from: context)
        context.delete(try #require(routines.first))
        try context.save()
        let restoredAt = Date(timeIntervalSince1970: 2_000)

        let restored = try StarterRoutineSeeder.restoreMissing(
            in: context,
            catalogService: service,
            now: restoredAt,
            makeID: { "restored-id" }
        )
        let secondRestore = try StarterRoutineSeeder.restoreMissing(
            in: context,
            catalogService: service,
            now: Date(timeIntervalSince1970: 3_000)
        )

        #expect(restored == 1)
        #expect(secondRestore == 0)
        let all = try PersistenceTestSupport.fetch(Routine.self, from: context)
        #expect(all.count == service.catalog.starterRoutines.count)
        let copy = try #require(all.first { $0.id == "restored-id" })
        #expect(copy.createdAt == restoredAt)
        #expect(copy.updatedAt == restoredAt)
        #expect(copy.seedIdentifier != nil)
    }

    @Test("Duplicate copies steps but never starter identity")
    func duplicateRoutine() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let original = Routine(
            id: "original",
            name: "Morning Core",
            createdAt: Date(timeIntervalSince1970: 1_000),
            seedIdentifier: "starter.quick-start",
            steps: [RoutineStep(
                sortIndex: 0,
                workoutID: "bridge",
                workoutNameSnapshot: "Bridge",
                workSeconds: 30,
                sets: 3,
                setRestSeconds: 10,
                restAfterSeconds: 15,
                repGuidance: 12
            )]
        )
        context.insert(original)
        let now = Date(timeIntervalSince1970: 2_000)

        let copy = try RoutineLibrary.duplicate(
            original,
            named: "Morning Core copy",
            in: context,
            now: now,
            makeID: { "copy" }
        )

        #expect(copy.id == "copy")
        #expect(copy.seedIdentifier == nil)
        #expect(copy.createdAt == now && copy.updatedAt == now)
        #expect(copy.snapshot.steps == original.snapshot.steps)
        #expect(copy.steps?.first !== original.steps?.first)
    }

    @Test("Add to routine appends exact smart defaults and snapshots the name")
    func addToRoutineDefaults() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(
            id: "routine",
            name: "Leg Day",
            createdAt: Date(timeIntervalSince1970: 1_000),
            steps: [RoutineStep(sortIndex: 4, workoutID: "squat", workoutNameSnapshot: "Squat")]
        )
        context.insert(routine)
        let item = WorkoutItem.custom(
            CustomWorkout(id: "wall-sit", name: "Wall Sit", categoryID: "legs-glutes")
        )

        let step = try RoutineLibrary.append(item, to: routine, in: context, now: Date(timeIntervalSince1970: 2_000))

        #expect(step.sortIndex == 5)
        #expect(step.workoutID == "wall-sit")
        #expect(step.workoutNameSnapshot == "Wall Sit")
        #expect(step.workSeconds == 30)
        #expect(step.sets == 1)
        #expect(step.setRestSeconds == 0)
        #expect(step.restAfterSeconds == 15)
        #expect(routine.updatedAt == Date(timeIntervalSince1970: 2_000))
        #expect(routine.steps?.filter { $0.workoutID == "wall-sit" }.count == 1)
    }

    @Test("Custom-workout rename leaves existing step snapshots unchanged")
    func renameKeepsSnapshot() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let custom = CustomWorkout(id: "custom", name: "Wall Sit", categoryID: "legs-glutes")
        let step = RoutineStep(workoutID: custom.id, workoutNameSnapshot: custom.name)
        context.insert(custom)
        context.insert(Routine(name: "Legs", steps: [step]))
        try context.save()

        _ = try WorkoutLibrary.save(
            custom,
            name: "Chair Hold",
            categoryID: "legs-glutes",
            notes: "Stay tall",
            in: context
        )

        #expect(custom.name == "Chair Hold")
        #expect(step.workoutNameSnapshot == "Wall Sit")
    }

    @Test("Appears-in derives unique routines and search is localized-standard")
    func appearsInAndSearch() {
        let first = Routine(id: "a", name: "Morning", steps: [
            RoutineStep(sortIndex: 0, workoutID: "custom", workoutNameSnapshot: "Élan Hold"),
            RoutineStep(sortIndex: 1, workoutID: "custom", workoutNameSnapshot: "Élan Hold")
        ])
        let second = Routine(id: "b", name: "Evening", steps: [
            RoutineStep(sortIndex: 0, workoutID: "custom", workoutNameSnapshot: "Élan Hold")
        ])
        let item = WorkoutItem.custom(CustomWorkout(id: "custom", name: "Élan Hold", categoryID: "balance"))

        #expect(WorkoutLibrary.routines(containing: "custom", in: [second, first]).map(\.name) == ["Evening", "Morning"])
        #expect(WorkoutLibrary.search([item], query: "elan").map(\.id) == ["custom"])
        #expect(WorkoutLibrary.search([item], query: "  ").map(\.id) == ["custom"])

        let squatItems = [
            WorkoutItem.custom(CustomWorkout(id: "jump-squat", name: "Jump Squat", categoryID: "legs-glutes")),
            WorkoutItem.custom(CustomWorkout(id: "squat", name: "Squat", categoryID: "legs-glutes")),
            WorkoutItem.custom(CustomWorkout(id: "split-squat", name: "Split Squat", categoryID: "legs-glutes"))
        ]
        #expect(
            WorkoutLibrary.sortedForSearch(
                WorkoutLibrary.search(squatItems, query: "Squat"),
                query: "Squat"
            ).map(\.id) == ["squat", "jump-squat", "split-squat"]
        )
    }

    @Test("Plural browsing strings select singular and plural variants")
    func pluralBrowsingStrings() {
        #expect(L10n.workoutCount(1) == "1 workout")
        #expect(L10n.workoutCount(2) == "2 workouts")
        #expect(L10n.appearsIn(1) == "Appears in 1 routine")
        #expect(L10n.appearsIn(2) == "Appears in 2 routines")
        #expect(L10n.weeklyMinutes(1) == "1 min this week")
        #expect(L10n.weeklyMinutes(2) == "2 min this week")
        #expect(L10n.lastDone("today", timesCompleted: 1) == "Last done today · 1×")
        #expect(L10n.lastDone("today", timesCompleted: 2) == "Last done today · 2×")
        let now = Date(timeIntervalSince1970: 1_752_145_200)
        #expect(DisplayFormatters.relativeDate(now, now: now) == "Today")
    }
}
