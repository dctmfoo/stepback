import Foundation
import Observation
import StepBackCore

@MainActor
@Observable
final class PlayerSessionModel {
    enum Phase: Equatable {
        case playing
        case completed
        case partial
    }

    let routineName: String
    let timeline: Timeline
    private(set) var snapshot: TimelineRunnerSnapshot
    private(set) var summary: RunnerSessionSummary
    private(set) var phase: Phase = .playing

    private let driver: TimelineRunnerDriver<ContinuousClock>
    private let signposts: any PlayerSignposting
    private var observationTask: Task<Void, Never>?
    private var signpostedSegmentIndex: Int?
    private var started = false

    init(
        routine: Routine,
        getReadySeconds: Int = PlayerPreferences.getReadySeconds,
        signposts: any PlayerSignposting = NoopPlayerSignposter()
    ) {
        PlayerPreferences.registerDefaults()
        let timeline = TimelineCompiler.compile(routine.snapshot, getReadySeconds: getReadySeconds)
        let activeSeconds = timeline.segments
            .filter { $0.kind != .getReady }
            .reduce(0) { $0 + $1.durationSeconds }
        let audioSession = PlayerAudioSession()
        let announcements = PlayerAnnouncementSink(
            audioSession: audioSession,
            routineActiveSeconds: activeSeconds
        )
        let tones = GeneratedToneSink(audioSession: audioSession)

        self.routineName = routine.name
        self.timeline = timeline
        self.signposts = signposts
        driver = TimelineRunnerDriver(
            timeline: timeline,
            clock: ContinuousClock(),
            announcementSink: announcements,
            toneSink: tones
        )
        let state = TimelineRunnerState(timeline: timeline)
        snapshot = state.snapshot
        summary = state.summary
    }

    var currentSegment: TimelineSegment? {
        guard let index = snapshot.currentSegmentIndex,
              timeline.segments.indices.contains(index) else { return nil }
        return timeline.segments[index]
    }

    var isPaused: Bool { snapshot.status == .paused }
    var resumeCountdownRemaining: Int? { snapshot.resumeCountdownRemaining }
    var routineTotalSeconds: Int {
        timeline.segments.filter { $0.kind != .getReady }.reduce(0) { $0 + $1.durationSeconds }
    }
    var elapsedRoutineSeconds: Int {
        max(0, snapshot.elapsedTimelineSeconds - getReadySeconds)
    }
    var remainingRoutineSeconds: Int {
        max(0, routineTotalSeconds - elapsedRoutineSeconds)
    }
    var progress: Double {
        guard routineTotalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(elapsedRoutineSeconds) / Double(routineTotalSeconds)))
    }
    var workoutIndex: Int { (currentSegment?.step?.stepIndex ?? 0) + 1 }
    var workoutCount: Int { timeline.stepCount }
    var showsNextDuringWork: Bool {
        currentSegment?.kind == .work && snapshot.remainingSeconds <= 5
    }

    func start() {
        guard !started else { return }
        started = true
        observationTask = Task { [weak self] in
            guard let self else { return }
            await driver.start()
            while !Task.isCancelled {
                await refresh()
                if phase != .playing { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func togglePause() {
        Task { [weak self] in
            guard let self else { return }
            if isPaused {
                await driver.resume()
            } else {
                await driver.pause()
            }
            await refresh()
        }
    }

    func pause() {
        guard snapshot.status == .running else { return }
        Task { [weak self] in
            guard let self else { return }
            await driver.pause()
            await refresh()
        }
    }

    func skip() {
        Task { [weak self] in
            guard let self else { return }
            await driver.skipForward()
            await refresh()
        }
    }

    func back() {
        Task { [weak self] in
            guard let self, let segment = currentSegment else { return }
            if snapshot.remainingSeconds >= max(0, segment.durationSeconds - 2) {
                await driver.previousSegment()
            } else {
                await driver.restartSegment()
            }
            await refresh()
        }
    }

    func endEarly() {
        Task { [weak self] in
            guard let self else { return }
            await driver.abandon()
            await refresh()
            phase = .partial
        }
    }

    private func refresh() async {
        snapshot = await driver.snapshot
        summary = await driver.summary
        updateSignpostedSegment()
        if snapshot.status == .completed {
            phase = .completed
            signposts.endSegment()
        } else if snapshot.status == .abandoned {
            phase = .partial
            signposts.endSegment()
        }
    }

    private func updateSignpostedSegment() {
        guard let index = snapshot.currentSegmentIndex,
              timeline.segments.indices.contains(index),
              index != signpostedSegmentIndex else { return }
        signpostedSegmentIndex = index
        signposts.beginSegment(index: index, segment: timeline.segments[index])
    }

    private var getReadySeconds: Int {
        timeline.segments.first(where: { $0.kind == .getReady })?.durationSeconds ?? 0
    }
}
