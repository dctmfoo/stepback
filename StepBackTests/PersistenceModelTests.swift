import Foundation
import SwiftData
import Testing
@testable import StepBack
import StepBackCore

@Suite("SwiftData schema and snapshot mapping")
@MainActor
struct PersistenceModelTests {
    @Test("Routine snapshot mapping sorts by sortIndex")
    func routineSnapshotSortsSteps() {
        let later = RoutineStep(
            sortIndex: 1,
            workoutID: "plank",
            workoutNameSnapshot: "Plank",
            workSeconds: 45
        )
        let earlier = RoutineStep(
            sortIndex: 0,
            workoutID: "bridge",
            workoutNameSnapshot: "Bridge",
            workSeconds: 30,
            sets: 3,
            setRestSeconds: 10,
            restAfterSeconds: 15
        )
        let routine = Routine(name: "Core", steps: [later, earlier])

        let snapshot = routine.snapshot

        #expect(snapshot.steps.map(\.workoutID) == ["bridge", "plank"])
        #expect(TimelineCompiler.compile(snapshot, getReadySeconds: 0).totalDurationSeconds == 170)
    }

    @Test("Session snapshot round-trips partial session fields")
    func sessionSnapshotRoundTrip() {
        let started = Date(timeIntervalSince1970: 1_000)
        let ended = Date(timeIntervalSince1970: 1_145)
        let value = SessionSnapshot(
            routineID: "routine-id",
            routineNameSnapshot: "Core",
            startedAt: started,
            endedAt: ended,
            wasCompleted: false,
            completedStepCount: 2,
            totalStepCount: 5,
            activeSeconds: 145
        )

        let routine = Routine(id: "routine-id", name: "Core")
        let session = RoutineSession(snapshot: value, routine: routine)

        #expect(session.snapshot == value)
    }

    @Test("Deleting a routine cascades steps and nullifies sessions")
    func routineDeleteRules() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let step = RoutineStep(workoutID: "plank", workoutNameSnapshot: "Plank")
        let routine = Routine(id: "routine-id", name: "Core", steps: [step])
        let session = RoutineSession(
            routineNameSnapshot: "Core",
            wasCompleted: true,
            completedStepCount: 1,
            totalStepCount: 1,
            activeSeconds: 30,
            routine: routine
        )
        context.insert(routine)
        context.insert(session)
        try context.save()

        context.delete(routine)
        try context.save()

        #expect(try PersistenceTestSupport.fetch(Routine.self, from: context).isEmpty)
        #expect(try PersistenceTestSupport.fetch(RoutineStep.self, from: context).isEmpty)
        let surviving = try #require(PersistenceTestSupport.fetch(RoutineSession.self, from: context).first)
        #expect(surviving.routine == nil)
        #expect(surviving.routineNameSnapshot == "Core")
    }

    @Test("Deleting a custom workout leaves string-referenced steps intact")
    func customWorkoutDeleteLeavesStep() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let custom = CustomWorkout(id: "custom-id", name: "Wall Sit", categoryID: "legs-glutes")
        let step = RoutineStep(workoutID: custom.id, workoutNameSnapshot: custom.name)
        let routine = Routine(name: "Legs", steps: [step])
        context.insert(custom)
        context.insert(routine)
        try context.save()

        context.delete(custom)
        try context.save()

        let surviving = try #require(PersistenceTestSupport.fetch(RoutineStep.self, from: context).first)
        #expect(surviving.workoutID == "custom-id")
        #expect(surviving.workoutNameSnapshot == "Wall Sit")
    }
}
