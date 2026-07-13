import Foundation
import SwiftData
import Testing
import StepBackCore
@testable import StepBack

@Suite("Routine builder model")
@MainActor
struct RoutineBuilderModelTests {
    @Test("Smart defaults carry forward from the last existing step for a batch")
    func smartDefaultsCarryForward() {
        let bridge = WorkoutItem.custom(CustomWorkout(id: "bridge", name: "Bridge", categoryID: "legs-glutes"))
        let squat = WorkoutItem.custom(CustomWorkout(id: "squat", name: "Squats", categoryID: "legs-glutes"))
        let twist = WorkoutItem.custom(CustomWorkout(id: "russian-twist", name: "Russian Twist", categoryID: "core"))
        let model = RoutineBuilderModel.newRoutine(name: "Routine 1")

        model.addWorkouts([bridge])
        model.steps[0].workSeconds = 45
        model.steps[0].sets = 3
        model.steps[0].setRestSeconds = 10
        model.steps[0].restAfterSeconds = 20
        model.steps[0].repGuidance = 25
        model.addWorkouts([squat, twist])

        #expect(model.steps.map(\.workoutID) == ["bridge", "squat", "russian-twist"])
        #expect(model.steps[1].workSeconds == 45)
        #expect(model.steps[1].sets == 3)
        #expect(model.steps[1].setRestSeconds == 10)
        #expect(model.steps[1].restAfterSeconds == 20)
        #expect(model.steps[1].repGuidance == nil)
        #expect(model.steps[2].workSeconds == 45)
        #expect(model.steps[2].sets == 3)
        #expect(model.steps[2].setRestSeconds == 10)
        #expect(model.steps[2].restAfterSeconds == 20)
        #expect(model.steps[2].repGuidance == nil)
    }

    @Test("Draft total is the shared compiler output for the PRD sample")
    func totalUsesCompiler() {
        let model = RoutineBuilderModel.newRoutine(name: "Morning Core")
        model.steps = [
            .init(workoutID: "bridge", workoutNameSnapshot: "Bridge", workSeconds: 30, sets: 3, setRestSeconds: 10, restAfterSeconds: 15),
            .init(workoutID: "squat", workoutNameSnapshot: "Squats", workSeconds: 30, sets: 2, restAfterSeconds: 15),
            .init(workoutID: "russian-twist", workoutNameSnapshot: "Russian Twist", workSeconds: 30, restAfterSeconds: 20),
            .init(workoutID: "bicycle-crunch", workoutNameSnapshot: "Bicycle Crunch", workSeconds: 30, restAfterSeconds: 20, repGuidance: 20),
            .init(workoutID: "mountain-climber", workoutNameSnapshot: "Mountain Climbers", workSeconds: 30, restAfterSeconds: 99)
        ]

        #expect(model.totalSeconds == TimelineCompiler.compile(model.snapshot, getReadySeconds: 0).totalDurationSeconds)
        #expect(model.totalSeconds == 330)
    }

    @Test("Moving a step preserves the step values, including rest-after")
    func moveStepCarriesRestAfter() {
        let model = RoutineBuilderModel.newRoutine(name: "Morning Core")
        model.steps = [
            .init(workoutID: "bridge", workoutNameSnapshot: "Bridge", restAfterSeconds: 15),
            .init(workoutID: "squat", workoutNameSnapshot: "Squats", restAfterSeconds: 20),
            .init(workoutID: "plank", workoutNameSnapshot: "Plank", restAfterSeconds: 0)
        ]
        let bridgeID = model.steps[0].id
        let plankID = model.steps[2].id
        model.expandedStepID = bridgeID

        model.moveStep(id: bridgeID, before: plankID)

        #expect(model.steps.map(\.workoutID) == ["squat", "bridge", "plank"])
        #expect(model.steps[1].restAfterSeconds == 15)
        #expect(model.expandedStepID == nil)
    }

    @Test("Selecting a picker workout clears the active search for the next add")
    func pickerSelectionClearsSearch() {
        let model = RoutineBuilderModel.newRoutine(name: "Morning Core")
        model.pickerSearchText = "Bridge"

        model.togglePickerSelection("bridge")

        #expect(model.pickerSelectionIDs == ["bridge"])
        #expect(model.pickerSearchText == "")
    }

    @Test("Editing an existing routine is isolated until save and preserves retained step identity")
    func editSaveMapsByIdentity() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let removed = RoutineStep(sortIndex: 1, workoutID: "squat", workoutNameSnapshot: "Squats")
        let retained = RoutineStep(
            sortIndex: 0,
            workoutID: "bridge",
            workoutNameSnapshot: "Bridge",
            workSeconds: 30,
            sets: 3,
            setRestSeconds: 10,
            restAfterSeconds: 15
        )
        let routine = Routine(
            id: "routine",
            name: "Morning Core",
            createdAt: Date(timeIntervalSince1970: 1_000),
            steps: [retained, removed]
        )
        context.insert(routine)
        try context.save()

        let model = RoutineBuilderModel.editing(routine)
        model.name = "Morning Core Plus"
        model.steps[0].workSeconds = 45
        model.deleteStep(id: model.steps[1].id)
        model.addWorkouts([
            WorkoutItem.custom(CustomWorkout(id: "plank", name: "Plank", categoryID: "core"))
        ])

        #expect(routine.name == "Morning Core")
        #expect(retained.workSeconds == 30)
        #expect(routine.steps?.contains { $0 === removed } == true)

        let saved = try model.save(
            existing: routine,
            in: context,
            now: Date(timeIntervalSince1970: 2_000),
            makeID: { "unused" }
        )
        let savedSteps = try #require(saved.steps)

        #expect(saved === routine)
        #expect(saved.name == "Morning Core Plus")
        #expect(saved.updatedAt == Date(timeIntervalSince1970: 2_000))
        #expect(savedSteps.count == 2)
        #expect(savedSteps.sorted { $0.sortIndex < $1.sortIndex }[0] === retained)
        #expect(retained.workSeconds == 45)
        #expect(savedSteps.contains { $0 === removed } == false)
        #expect(savedSteps.map(\.sortIndex).sorted() == [0, 1])
        #expect(savedSteps.contains { $0.workoutID == "plank" })
    }

    @Test("Saving a new routine trims the name, snapshots workouts, and validates one-step minimum")
    func saveNewRoutine() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let model = RoutineBuilderModel.newRoutine(name: "  Evening Core  ")

        #expect(!model.canSave)
        model.addWorkouts([
            WorkoutItem.custom(CustomWorkout(id: "wall-sit", name: "Wall Sit", categoryID: "legs-glutes"))
        ])

        let routine = try model.save(
            existing: nil,
            in: context,
            now: Date(timeIntervalSince1970: 3_000),
            makeID: { "new-routine" }
        )

        #expect(routine.id == "new-routine")
        #expect(routine.name == "Evening Core")
        #expect(routine.createdAt == Date(timeIntervalSince1970: 3_000))
        #expect(routine.updatedAt == Date(timeIntervalSince1970: 3_000))
        #expect(routine.steps?.first?.workoutNameSnapshot == "Wall Sit")
    }

    @Test("Dirty flag tracks each draft mutation class and resets after save")
    func dirtyFlagTracksDraftMutationsAndSaveReset() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let model = RoutineBuilderModel.newRoutine(name: "Routine 1")
        let bridge = WorkoutItem.custom(CustomWorkout(id: "bridge", name: "Bridge", categoryID: "legs-glutes"))

        #expect(!model.isDirty)

        model.name = "Routine 2"
        #expect(model.isDirty)
        model.name = "Routine 1"
        #expect(!model.isDirty)

        model.addWorkouts([bridge])
        #expect(model.isDirty)

        _ = try model.save(
            existing: nil,
            in: context,
            now: Date(timeIntervalSince1970: 4_000),
            makeID: { "dirty-reset" }
        )
        #expect(!model.isDirty)

        model.steps[0].workSeconds = 35
        #expect(model.isDirty)
        model.steps[0].workSeconds = 30
        #expect(!model.isDirty)

        model.steps[0].sets = 2
        #expect(model.isDirty)
        model.steps[0].sets = 1
        #expect(!model.isDirty)

        model.steps[0].setRestSeconds = 10
        #expect(model.isDirty)
        model.steps[0].setRestSeconds = 0
        #expect(!model.isDirty)

        model.steps[0].restAfterSeconds = 20
        #expect(model.isDirty)
        model.steps[0].restAfterSeconds = 15
        #expect(!model.isDirty)

        model.steps[0].repGuidance = 20
        #expect(model.isDirty)
        model.steps[0].repGuidance = nil
        #expect(!model.isDirty)

        model.deleteStep(id: model.steps[0].id)
        #expect(model.isDirty)
    }
}
