import Testing
@testable import StepBackCore

@Suite("Timeline runner state core")
struct TimelineRunnerStateTests {
    @Test("Countdown beeps clip on one-, two-, and three-second segments", arguments: [
        (1, []),
        (2, [1]),
        (3, [2, 1])
    ])
    func clippedBeeps(duration: Int, expected: [Int]) {
        let timeline = TimelineCompiler.compile(.init(name: "Short", steps: [
            .init(workoutID: "short", workoutNameSnapshot: "Short", workSeconds: duration)
        ]), getReadySeconds: 0)
        let values = timeline.segments[0].cues.compactMap { cue -> Int? in
            guard case let .tone(.countdown(value)) = cue.kind else { return nil }
            return value
        }
        #expect(values == expected)
    }

    @Test("Pause excludes arbitrarily long clock gaps and resume preserves position")
    func pauseAndResume() {
        var runner = runnerForSingleWork(duration: 10)
        _ = runner.start()
        _ = runner.advance(seconds: 4)
        runner.pause()
        let paused = runner.snapshot
        let ignored = runner.advance(seconds: 500)
        let resumed = runner.resume()

        #expect(ignored.isEmpty)
        #expect(runner.snapshot.remainingSeconds == paused.remainingSeconds)
        #expect(runner.summary.activeSeconds == 4)
        #expect(resumed.isEmpty)
        #expect(runner.status == .running)
    }

    @Test("Skipping the final segment completes honestly")
    func skipFinal() {
        var runner = runnerForSingleWork(duration: 30)
        _ = runner.start()
        let events = runner.skipForward()

        #expect(runner.status == .completed)
        #expect(runner.summary.wasCompleted)
        #expect(runner.summary.completedStepCount == 1)
        #expect(events.contains { if case .completed = $0 { true } else { false } })
    }

    @Test("Previous on the first segment restarts it without underflow")
    func previousAtFloor() {
        var runner = runnerForSingleWork(duration: 10)
        _ = runner.start()
        _ = runner.advance(seconds: 4)
        _ = runner.previousSegment()

        #expect(runner.snapshot.currentSegmentIndex == 0)
        #expect(runner.snapshot.remainingSeconds == 10)
    }

    @Test("Abandonment produces a partial summary with elapsed active time")
    func abandon() {
        let timeline = TimelineCompiler.compile(TestSupport.sampleRoutine(), getReadySeconds: 0)
        var runner = TimelineRunnerState(timeline: timeline)
        _ = runner.start()
        _ = runner.advance(seconds: 35)
        let events = runner.abandon()

        #expect(runner.status == .abandoned)
        #expect(!runner.summary.wasCompleted)
        #expect(runner.summary.completedStepCount == 0)
        #expect(runner.summary.activeSeconds == 35)
        #expect(events.contains { if case .abandoned = $0 { true } else { false } })
    }

    @Test("Boundary cues fire once when pausing at a segment transition")
    func pauseAtBoundary() {
        let routine = RoutineSnapshot(name: "Boundary", steps: [
            .init(workoutID: "a", workoutNameSnapshot: "A", workSeconds: 2, restAfterSeconds: 2),
            .init(workoutID: "b", workoutNameSnapshot: "B", workSeconds: 2)
        ])
        var runner = TimelineRunnerState(timeline: TimelineCompiler.compile(routine, getReadySeconds: 0))
        _ = runner.start()
        let events = runner.advance(seconds: 2)
        runner.pause()
        let resumed = runner.resume()

        let restAnnouncements = (events + resumed).filter {
            $0 == .cue(.init(timelineOffsetSeconds: 2, kind: .announcement(.rest(nextWorkoutNameSnapshot: "B"))))
        }
        #expect(restAnnouncements.count == 1)
    }

    @Test("Empty timelines are immediately completed")
    func emptyTimeline() {
        var runner = TimelineRunnerState(timeline: .empty)
        let events = runner.start()

        #expect(runner.status == .completed)
        #expect(runner.summary.wasCompleted)
        #expect(events.contains { if case .completed = $0 { true } else { false } })
    }

    @Test("Driving the sample end-to-end has no cumulative drift")
    func fullSample() {
        let timeline = TimelineCompiler.compile(TestSupport.sampleRoutine(), getReadySeconds: 5)
        var runner = TimelineRunnerState(timeline: timeline)
        let events = runner.start() + runner.advance(seconds: timeline.totalDurationSeconds)
        let emittedCues = events.compactMap { event -> RunnerCueEmission? in
            guard case let .cue(cue) = event else { return nil }
            return cue
        }

        #expect(runner.status == .completed)
        #expect(runner.snapshot.elapsedTimelineSeconds == timeline.totalDurationSeconds)
        #expect(runner.summary.activeSeconds == timeline.totalDurationSeconds - 5)
        #expect(runner.summary.completedStepCount == 5)
        #expect(emittedCues == timeline.cues)
    }

    private func runnerForSingleWork(duration: Int) -> TimelineRunnerState {
        let routine = RoutineSnapshot(name: "One", steps: [
            .init(workoutID: "one", workoutNameSnapshot: "One", workSeconds: duration)
        ])
        return TimelineRunnerState(timeline: TimelineCompiler.compile(routine, getReadySeconds: 0))
    }
}
