import Testing
@testable import StepBack

@MainActor
@Suite("Player session model")
struct PlayerSessionModelTests {
    @Test("Get-ready is excluded from routine progress totals")
    func excludesGetReadyFromProgress() {
        let routine = Routine(
            name: "Short",
            steps: [RoutineStep(
                sortIndex: 0,
                workoutID: "bridge",
                workoutNameSnapshot: "Bridge",
                workSeconds: 30
            )]
        )
        let model = PlayerSessionModel(routine: routine, getReadySeconds: 5)

        #expect(model.timeline.totalDurationSeconds == 35)
        #expect(model.routineTotalSeconds == 30)
        #expect(model.elapsedRoutineSeconds == 0)
        #expect(model.remainingRoutineSeconds == 30)
        #expect(model.progress == 0)
    }

    @Test("Zero get-ready starts directly on work")
    func zeroGetReady() {
        let routine = Routine(
            name: "Direct",
            steps: [RoutineStep(
                sortIndex: 0,
                workoutID: "squat",
                workoutNameSnapshot: "Squats",
                workSeconds: 10
            )]
        )
        let model = PlayerSessionModel(routine: routine, getReadySeconds: 0)

        #expect(model.timeline.segments.map(\.kind) == [.work])
        #expect(model.currentSegment?.step?.workoutNameSnapshot == "Squats")
    }
}
