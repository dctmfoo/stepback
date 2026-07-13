import StepBackCore
import XCTest

final class PlayerTimingIntegrityTests: XCTestCase {
    private actor SilentAnnouncementSink: AnnouncementSink {
        func announce(_ cue: AnnouncementCue) async {}
    }

    private actor SilentToneSink: ToneSink {
        func play(_ cue: ToneCue) async {}
    }

    func testContinuousClockTransitionsStayWithinTolerance() async throws {
        guard isOptedIn else {
            throw XCTSkip("Set StepBackAcceptancePerformance=1 to run the real-clock drift measurement.")
        }

        let timeline = TimelineCompiler.compile(
            RoutineSnapshot(
                name: "Clock acceptance",
                steps: [
                    RoutineStepSnapshot(
                        workoutID: "clock-a",
                        workoutNameSnapshot: "Clock A",
                        workSeconds: 1,
                        restAfterSeconds: 1
                    ),
                    RoutineStepSnapshot(
                        workoutID: "clock-b",
                        workoutNameSnapshot: "Clock B",
                        workSeconds: 1
                    )
                ]
            ),
            getReadySeconds: 0
        )
        let clock = ContinuousClock()
        let driver = TimelineRunnerDriver(
            timeline: timeline,
            clock: clock,
            announcementSink: SilentAnnouncementSink(),
            toneSink: SilentToneSink()
        )
        let startedAt = clock.now
        await driver.start()

        var observedTransitions: [Int: Double] = [:]
        var completedAt: Double?
        while seconds(from: startedAt, to: clock.now) < 6 {
            let snapshot = await driver.snapshot
            if let index = snapshot.currentSegmentIndex, observedTransitions[index] == nil {
                observedTransitions[index] = seconds(from: startedAt, to: clock.now)
            }
            if snapshot.status == .completed {
                completedAt = seconds(from: startedAt, to: clock.now)
                break
            }
            try await Task.sleep(for: .milliseconds(5))
        }

        let tolerance = 0.150
        var transitionDeviations: [Double] = []
        for (index, segment) in timeline.segments.enumerated() {
            let actual = try XCTUnwrap(observedTransitions[index], "Segment \(index) was not observed")
            let deviation = abs(actual - Double(segment.startOffsetSeconds))
            transitionDeviations.append(deviation)
            XCTAssertLessThanOrEqual(
                deviation,
                tolerance,
                "Segment \(index) transition drifted by \(actual - Double(segment.startOffsetSeconds)) seconds"
            )
        }
        let actualCompletion = try XCTUnwrap(completedAt, "Timeline did not complete")
        let completionDeviation = abs(actualCompletion - Double(timeline.totalDurationSeconds))
        XCTAssertLessThanOrEqual(
            completionDeviation,
            tolerance,
            "End-to-end drift was \(actualCompletion - Double(timeline.totalDurationSeconds)) seconds"
        )
        print(
            "ContinuousClock acceptance: max transition deviation " +
                "\(transitionDeviations.max() ?? 0)s; end-to-end deviation \(completionDeviation)s"
        )
    }

    private func seconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Double {
        let components = start.duration(to: end).components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private var isOptedIn: Bool {
        #if STEPBACK_ACCEPTANCE_PERFORMANCE
        true
        #else
        ProcessInfo.processInfo.environment["StepBackAcceptancePerformance"] == "1"
        #endif
    }
}
