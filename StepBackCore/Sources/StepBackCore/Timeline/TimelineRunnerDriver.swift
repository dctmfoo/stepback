public protocol AnnouncementSink: Sendable {
    func announce(_ cue: AnnouncementCue) async
}

public protocol ToneSink: Sendable {
    func play(_ cue: ToneCue) async
}

public actor TimelineRunnerDriver<C: Clock> where C.Duration == Swift.Duration {
    private let clock: C
    private let announcementSink: any AnnouncementSink
    private let toneSink: any ToneSink
    private var state: TimelineRunnerState
    private var driveTask: Task<Void, Never>?
    private var generation = 0
    private var resumeCountdownRemaining: Int?

    public init(
        timeline: Timeline,
        clock: C,
        announcementSink: any AnnouncementSink,
        toneSink: any ToneSink
    ) {
        self.clock = clock
        self.announcementSink = announcementSink
        self.toneSink = toneSink
        self.state = TimelineRunnerState(timeline: timeline)
    }

    deinit {
        driveTask?.cancel()
    }

    public var status: TimelineRunnerStatus { state.status }
    public var snapshot: TimelineRunnerSnapshot {
        let snapshot = state.snapshot
        return TimelineRunnerSnapshot(
            status: snapshot.status,
            currentSegmentIndex: snapshot.currentSegmentIndex,
            remainingSeconds: snapshot.remainingSeconds,
            elapsedTimelineSeconds: snapshot.elapsedTimelineSeconds,
            resumeCountdownRemaining: resumeCountdownRemaining
        )
    }
    public var summary: RunnerSessionSummary { state.summary }

    public func start() async {
        await dispatch(state.start())
        startDriveLoopIfNeeded()
    }

    public func pause() {
        state.pause()
        stopDriveLoop()
    }

    public func resume() async {
        guard state.status == .paused, resumeCountdownRemaining == nil else { return }
        stopDriveLoop()
        resumeCountdownRemaining = 3
        await toneSink.play(.countdown(3))

        generation += 1
        let activeGeneration = generation
        let clock = self.clock
        driveTask = Task { [weak self] in
            let anchor = clock.now
            for elapsed in 1...3 {
                do {
                    try await clock.sleep(
                        until: anchor.advanced(by: .seconds(elapsed)),
                        tolerance: .zero
                    )
                } catch {
                    return
                }

                guard let self, await self.generation == activeGeneration else { return }
                if elapsed < 3 {
                    await self.emitResumeCountdown(3 - elapsed)
                } else {
                    await self.finishResumeCountdown(generation: activeGeneration)
                }
            }
        }
    }

    public func skipForward() async {
        stopDriveLoop()
        await dispatch(state.skipForward())
        startDriveLoopIfNeeded()
    }

    public func restartSegment() async {
        stopDriveLoop()
        await dispatch(state.restartSegment())
        startDriveLoopIfNeeded()
    }

    public func previousSegment() async {
        stopDriveLoop()
        await dispatch(state.previousSegment())
        startDriveLoopIfNeeded()
    }

    public func abandon() async {
        stopDriveLoop()
        await dispatch(state.abandon())
    }

    private func startDriveLoopIfNeeded() {
        guard state.status == .running else { return }
        generation += 1
        let activeGeneration = generation
        let clock = self.clock
        driveTask?.cancel()
        driveTask = Task { [weak self] in
            let anchor = clock.now
            var tick = 1

            while !Task.isCancelled {
                do {
                    try await clock.sleep(
                        until: anchor.advanced(by: .seconds(tick)),
                        tolerance: .zero
                    )
                } catch {
                    return
                }

                guard await self?.advanceOneTick(generation: activeGeneration) == true else { return }
                tick += 1
            }
        }
    }

    private func stopDriveLoop() {
        generation += 1
        driveTask?.cancel()
        driveTask = nil
        resumeCountdownRemaining = nil
    }

    private func emitResumeCountdown(_ value: Int) async {
        resumeCountdownRemaining = value
        await toneSink.play(.countdown(value))
    }

    private func finishResumeCountdown(generation activeGeneration: Int) async {
        guard activeGeneration == generation, state.status == .paused else { return }
        resumeCountdownRemaining = nil
        await dispatch(state.resume())
        startDriveLoopIfNeeded()
    }

    private func advanceOneTick(generation activeGeneration: Int) async -> Bool {
        guard activeGeneration == generation, state.status == .running else { return false }
        await dispatch(state.advance(seconds: 1))
        return state.status == .running
    }

    private func dispatch(_ events: [TimelineRunnerEvent]) async {
        for event in events {
            guard case let .cue(emission) = event else { continue }
            switch emission.kind {
            case let .announcement(cue):
                await announcementSink.announce(cue)
            case let .tone(cue):
                await toneSink.play(cue)
            }
        }
    }
}
