import Foundation
import Testing
@testable import StepBackCore

@Suite("Clock-driven timeline runner")
struct TimelineRunnerDriverTests {
    @Test("Manual clock drives cues on absolute one-second deadlines")
    func fakeClockScheduling() async {
        let clock = ManualTestClock()
        let announcements = RecordingAnnouncementSink()
        let tones = RecordingToneSink()
        let timeline = TimelineCompiler.compile(.init(name: "Clock", steps: [
            .init(workoutID: "clock", workoutNameSnapshot: "Clock", workSeconds: 4)
        ]), getReadySeconds: 0)
        let driver = TimelineRunnerDriver(
            timeline: timeline,
            clock: clock,
            announcementSink: announcements,
            toneSink: tones
        )

        await driver.start()
        #expect(await eventually { clock.pendingSleepCount == 1 })
        clock.advance(by: .seconds(1))
        #expect(await eventually { await tones.values.contains(.countdown(3)) })
        clock.advance(by: .seconds(3))
        #expect(await eventually { await driver.status == .completed })

        #expect(await announcements.values == [
            .work(workoutNameSnapshot: "Clock", setIndex: 1, setCount: 1, repGuidance: nil),
            .completion
        ])
        #expect(await tones.values == [.workStart, .countdown(3), .countdown(2), .countdown(1)])
    }

    @Test("Driver pause and resume hold position through a fresh three-two-one")
    func fakeClockPause() async {
        let clock = ManualTestClock()
        let tones = RecordingToneSink()
        let driver = TimelineRunnerDriver(
            timeline: TimelineCompiler.compile(.init(name: "Pause", steps: [
                .init(workoutID: "pause", workoutNameSnapshot: "Pause", workSeconds: 10)
            ]), getReadySeconds: 0),
            clock: clock,
            announcementSink: RecordingAnnouncementSink(),
            toneSink: tones
        )

        await driver.start()
        #expect(await eventually { clock.pendingSleepCount == 1 })
        clock.advance(by: .seconds(4))
        #expect(await eventually { await driver.snapshot.remainingSeconds == 6 })
        await driver.pause()
        clock.advance(by: .seconds(100))
        #expect(await driver.snapshot.remainingSeconds == 6)
        await driver.resume()
        #expect(await eventually { await driver.snapshot.resumeCountdownRemaining == 3 })
        #expect(await tones.values.suffix(1) == [.countdown(3)])
        #expect(await driver.status == .paused)
        #expect(await eventually { clock.pendingSleepCount == 1 })
        clock.advance(by: .seconds(1))
        #expect(await eventually { await driver.snapshot.resumeCountdownRemaining == 2 })
        clock.advance(by: .seconds(1))
        #expect(await eventually { await driver.snapshot.resumeCountdownRemaining == 1 })
        #expect(await driver.snapshot.remainingSeconds == 6)
        clock.advance(by: .seconds(1))
        #expect(await eventually { await driver.status == .running })
        #expect(await tones.values.suffix(3) == [.countdown(3), .countdown(2), .countdown(1)])
        #expect(await eventually { clock.pendingSleepCount == 1 })
        await driver.abandon()
        #expect(await eventually { clock.pendingSleepCount == 0 })
    }

    @Test("Releasing the driver cancels its clock task")
    func driverRelease() async {
        let clock = ManualTestClock()
        var driver: TimelineRunnerDriver<ManualTestClock>? = TimelineRunnerDriver(
            timeline: TimelineCompiler.compile(.init(name: "Release", steps: [
                .init(workoutID: "release", workoutNameSnapshot: "Release", workSeconds: 10)
            ]), getReadySeconds: 0),
            clock: clock,
            announcementSink: RecordingAnnouncementSink(),
            toneSink: RecordingToneSink()
        )
        let reference = WeakReference(driver!)

        await driver?.start()
        #expect(await eventually { clock.pendingSleepCount == 1 })
        driver = nil

        #expect(await eventually { reference.value == nil })
        #expect(await eventually { clock.pendingSleepCount == 0 })
    }
}

private actor RecordingAnnouncementSink: AnnouncementSink {
    private(set) var values: [AnnouncementCue] = []
    func announce(_ cue: AnnouncementCue) { values.append(cue) }
}

private actor RecordingToneSink: ToneSink {
    private(set) var values: [ToneCue] = []
    func play(_ cue: ToneCue) { values.append(cue) }
}

private final class ManualTestClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        typealias Duration = Swift.Duration
        let offset: Duration

        func advanced(by duration: Duration) -> Instant { .init(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    typealias Duration = Swift.Duration

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private enum RegistrationAction {
        case wait
        case resume
        case cancel
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [UUID: Sleeper] = [:]
    private var cancelledSleepIDs: Set<UUID> = []

    var now: Instant { lock.withLock { current } }
    var minimumResolution: Duration { .seconds(1) }
    var pendingSleepCount: Int { lock.withLock { sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let action: RegistrationAction = lock.withLock {
                    if Task.isCancelled || cancelledSleepIDs.remove(id) != nil {
                        return .cancel
                    }
                    if deadline <= current {
                        return .resume
                    }
                    sleepers[id] = .init(deadline: deadline, continuation: continuation)
                    return .wait
                }

                switch action {
                case .wait:
                    break
                case .resume:
                    continuation.resume()
                case .cancel:
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            let sleeper: Sleeper? = lock.withLock {
                if let sleeper = sleepers.removeValue(forKey: id) {
                    return sleeper
                }
                cancelledSleepIDs.insert(id)
                return nil
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        let ready: [Sleeper] = lock.withLock {
            current = current.advanced(by: duration)
            let readyIDs = sleepers.compactMap { id, sleeper in
                sleeper.deadline <= current ? id : nil
            }
            let ready = readyIDs.compactMap { sleepers.removeValue(forKey: $0) }
            return ready
        }
        ready.forEach { $0.continuation.resume() }
    }
}

private final class WeakReference<Value: AnyObject>: @unchecked Sendable {
    private let lock = NSLock()
    private weak var storage: Value?

    init(_ value: Value) {
        storage = value
    }

    var value: Value? {
        lock.withLock { storage }
    }
}

private func eventually(_ condition: @escaping @Sendable () async -> Bool) async -> Bool {
    for _ in 0..<200 {
        if await condition() { return true }
        await Task.yield()
    }
    return false
}
