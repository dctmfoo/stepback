import Testing
@testable import StepBackCore

@Suite("Timeline compiler")
struct TimelineCompilerTests {
    @Test("PRD sample compiles to the exact sequence and 335-second total")
    func sampleRoutine() {
        let timeline = TimelineCompiler.compile(TestSupport.sampleRoutine(), getReadySeconds: 5)

        #expect(timeline.totalDurationSeconds == 335)
        #expect(TimelineCompiler.totalDurationSeconds(TestSupport.sampleRoutine(), getReadySeconds: 5) == timeline.totalDurationSeconds)
        #expect(timeline.segments.map(\.kind) == [
            .getReady,
            .work, .setRest, .work, .setRest, .work, .rest,
            .work, .work, .rest,
            .work, .rest,
            .work, .rest,
            .work
        ])
        #expect(timeline.segments.map(\.startOffsetSeconds) == [
            0, 5, 35, 45, 75, 85, 115, 130, 160, 190, 205, 235, 255, 285, 305
        ])
        #expect(timeline.segments.last?.step?.workoutNameSnapshot == "Mountain Climbers")
        #expect(timeline.segments.last?.nextWorkoutNameSnapshot == nil)
    }

    @Test("Compiler edge cases", arguments: CompilerCase.all)
    func edgeCases(_ testCase: CompilerCase) {
        let timeline = TimelineCompiler.compile(testCase.routine, getReadySeconds: testCase.getReadySeconds)
        #expect(timeline.segments.map(\.kind) == testCase.expectedKinds)
        #expect(timeline.totalDurationSeconds == testCase.expectedTotal)
        #expect(TimelineCompiler.totalDurationSeconds(testCase.routine, getReadySeconds: testCase.getReadySeconds) == testCase.expectedTotal)
    }

    @Test("Rep guidance is semantic cue data and never changes duration")
    func repGuidance() {
        let timeline = TimelineCompiler.compile(TestSupport.sampleRoutine(), getReadySeconds: 0)
        let bicycle = timeline.segments.first { $0.step?.workoutID == "bicycle-crunch" }
        let announcement = bicycle?.cues.compactMap(\.announcement).first

        #expect(timeline.totalDurationSeconds == 330)
        #expect(announcement == .work(workoutNameSnapshot: "Bicycle Crunch", setIndex: 1, setCount: 1, repGuidance: 20))
    }

    @Test("Missing catalog IDs compile fully from the name snapshot")
    func missingCatalogID() {
        let routine = RoutineSnapshot(name: "Resilient", steps: [
            .init(workoutID: "removed-from-catalog", workoutNameSnapshot: "Still Here", workSeconds: 12)
        ])
        let timeline = TimelineCompiler.compile(routine, getReadySeconds: 0)

        #expect(timeline.totalDurationSeconds == 12)
        #expect(timeline.segments.first?.step?.workoutNameSnapshot == "Still Here")
    }

    @Test("Each work segment has its own announcement, work tone, and clipped countdown")
    func workCueSchedule() {
        let routine = RoutineSnapshot(name: "Short", steps: [
            .init(workoutID: "squat", workoutNameSnapshot: "Squats", workSeconds: 3, sets: 2)
        ])
        let timeline = TimelineCompiler.compile(routine, getReadySeconds: 0)

        for segment in timeline.segments {
            #expect(segment.cues.contains(.init(offsetSeconds: 0, kind: .announcement(.work(
                workoutNameSnapshot: "Squats",
                setIndex: segment.setIndex!,
                setCount: 2,
                repGuidance: nil
            )))))
            #expect(segment.cues.contains(.init(offsetSeconds: 0, kind: .tone(.workStart))))
            #expect(segment.cues.filter { $0.tone?.countdownValue != nil }.map(\.offsetSeconds) == [1, 2])
        }
    }

    @Test("Set rest cues carry the next set position while between-step rest carries the next workout")
    func restCueSemantics() {
        let routine = RoutineSnapshot(name: "Rest cues", steps: [
            .init(
                workoutID: "bridge",
                workoutNameSnapshot: "Bridge",
                workSeconds: 5,
                sets: 2,
                setRestSeconds: 5,
                restAfterSeconds: 5
            ),
            .init(workoutID: "squat", workoutNameSnapshot: "Squats", workSeconds: 5)
        ])
        let timeline = TimelineCompiler.compile(routine, getReadySeconds: 0)

        #expect(timeline.segments[1].cues.first?.announcement == .setRest(nextSetIndex: 2, setCount: 2))
        #expect(timeline.segments[3].cues.first?.announcement == .rest(nextWorkoutNameSnapshot: "Squats"))
    }

    @Test("The PRD sample has an exact flattened cue schedule including completion")
    func sampleCueSchedule() {
        let timeline = TimelineCompiler.compile(TestSupport.sampleRoutine(), getReadySeconds: 5)
        let countdownOffsets = timeline.cues.compactMap { cue -> Int? in
            guard case .tone(.countdown) = cue.kind else { return nil }
            return cue.timelineOffsetSeconds
        }
        let announcementCount = timeline.cues.count {
            if case .announcement = $0.kind { true } else { false }
        }
        let workStartCount = timeline.cues.count { $0.kind == .tone(.workStart) }

        #expect(announcementCount == 16)
        #expect(workStartCount == 8)
        #expect(countdownOffsets == [
            2, 3, 4,
            32, 33, 34, 42, 43, 44, 72, 73, 74, 82, 83, 84,
            112, 113, 114, 127, 128, 129,
            157, 158, 159, 187, 188, 189, 202, 203, 204,
            232, 233, 234, 252, 253, 254,
            282, 283, 284, 302, 303, 304,
            332, 333, 334
        ])
        #expect(timeline.cues.last == .init(
            timelineOffsetSeconds: 335,
            kind: .announcement(.completion)
        ))
    }
}

struct CompilerCase: Sendable, CustomTestStringConvertible {
    let name: String
    let routine: RoutineSnapshot
    let getReadySeconds: Int
    let expectedKinds: [TimelineSegment.Kind]
    let expectedTotal: Int

    var testDescription: String { name }

    static let all: [CompilerCase] = [
        .init(
            name: "single step, one set, zero rests",
            routine: .init(name: "One", steps: [.init(workoutID: "one", workoutNameSnapshot: "One", workSeconds: 30)]),
            getReadySeconds: 5,
            expectedKinds: [.getReady, .work],
            expectedTotal: 35
        ),
        .init(
            name: "zero get-ready is omitted",
            routine: .init(name: "One", steps: [.init(workoutID: "one", workoutNameSnapshot: "One", workSeconds: 30)]),
            getReadySeconds: 0,
            expectedKinds: [.work],
            expectedTotal: 30
        ),
        .init(
            name: "trailing rest is omitted",
            routine: .init(name: "One", steps: [.init(workoutID: "one", workoutNameSnapshot: "One", workSeconds: 30, restAfterSeconds: 90)]),
            getReadySeconds: 0,
            expectedKinds: [.work],
            expectedTotal: 30
        ),
        .init(
            name: "empty routine is an empty timeline",
            routine: .init(name: "Empty", steps: []),
            getReadySeconds: 5,
            expectedKinds: [],
            expectedTotal: 0
        )
    ]
}

private extension SegmentCue {
    var announcement: AnnouncementCue? {
        guard case let .announcement(value) = kind else { return nil }
        return value
    }

    var tone: ToneCue? {
        guard case let .tone(value) = kind else { return nil }
        return value
    }
}

private extension ToneCue {
    var countdownValue: Int? {
        guard case let .countdown(value) = self else { return nil }
        return value
    }
}
