public enum TimelineRunnerStatus: Equatable, Hashable, Sendable {
    case ready
    case running
    case paused
    case completed
    case abandoned
}

public typealias RunnerCueEmission = TimelineCue

public struct RunnerSessionSummary: Equatable, Hashable, Sendable {
    public let wasCompleted: Bool
    public let completedStepCount: Int
    public let totalStepCount: Int
    public let activeSeconds: Int

    public init(wasCompleted: Bool, completedStepCount: Int, totalStepCount: Int, activeSeconds: Int) {
        self.wasCompleted = wasCompleted
        self.completedStepCount = completedStepCount
        self.totalStepCount = totalStepCount
        self.activeSeconds = activeSeconds
    }
}

public enum TimelineRunnerEvent: Equatable, Hashable, Sendable {
    case cue(RunnerCueEmission)
    case segmentChanged(Int)
    case completed(RunnerSessionSummary)
    case abandoned(RunnerSessionSummary)
}

public struct TimelineRunnerSnapshot: Equatable, Hashable, Sendable {
    public let status: TimelineRunnerStatus
    public let currentSegmentIndex: Int?
    public let remainingSeconds: Int
    public let elapsedTimelineSeconds: Int
    public let resumeCountdownRemaining: Int?

    public init(
        status: TimelineRunnerStatus,
        currentSegmentIndex: Int?,
        remainingSeconds: Int,
        elapsedTimelineSeconds: Int,
        resumeCountdownRemaining: Int? = nil
    ) {
        self.status = status
        self.currentSegmentIndex = currentSegmentIndex
        self.remainingSeconds = remainingSeconds
        self.elapsedTimelineSeconds = elapsedTimelineSeconds
        self.resumeCountdownRemaining = resumeCountdownRemaining
    }
}

public struct TimelineRunnerState: Sendable {
    public private(set) var status: TimelineRunnerStatus

    private let timeline: Timeline
    private var currentSegmentIndex: Int?
    private var elapsedInCurrentSegment: Int
    private var elapsedTimelineSeconds: Int
    private var activeSeconds: Int
    private var completedStepIndexes: Set<Int>
    private var terminalEventReported: Bool

    public init(timeline: Timeline) {
        self.timeline = timeline
        self.status = timeline.segments.isEmpty ? .completed : .ready
        self.currentSegmentIndex = timeline.segments.isEmpty ? nil : 0
        self.elapsedInCurrentSegment = 0
        self.elapsedTimelineSeconds = 0
        self.activeSeconds = 0
        self.completedStepIndexes = []
        self.terminalEventReported = false
    }

    public var snapshot: TimelineRunnerSnapshot {
        TimelineRunnerSnapshot(
            status: status,
            currentSegmentIndex: currentSegmentIndex,
            remainingSeconds: currentSegment.map { max(0, $0.durationSeconds - elapsedInCurrentSegment) } ?? 0,
            elapsedTimelineSeconds: elapsedTimelineSeconds
        )
    }

    public var summary: RunnerSessionSummary {
        RunnerSessionSummary(
            wasCompleted: status == .completed,
            completedStepCount: completedStepIndexes.count,
            totalStepCount: timeline.stepCount,
            activeSeconds: activeSeconds
        )
    }

    public mutating func start() -> [TimelineRunnerEvent] {
        if status == .completed {
            return reportCompletionIfNeeded()
        }
        guard status == .ready else { return [] }
        status = .running
        return currentSegmentStartEvents()
    }

    public mutating func advance(seconds: Int) -> [TimelineRunnerEvent] {
        guard status == .running, seconds > 0 else { return [] }
        var events: [TimelineRunnerEvent] = []

        for _ in 0..<seconds where status == .running {
            guard let segment = currentSegment else { break }
            elapsedInCurrentSegment += 1
            elapsedTimelineSeconds = segment.startOffsetSeconds + elapsedInCurrentSegment
            if segment.kind != .getReady {
                activeSeconds += 1
            }

            events.append(contentsOf: cueEvents(in: segment, at: elapsedInCurrentSegment))
            if elapsedInCurrentSegment >= segment.durationSeconds {
                markStepCompletedIfNeeded(segment)
                events.append(contentsOf: moveToNextSegment())
            }
        }
        return events
    }

    public mutating func pause() {
        guard status == .running else { return }
        status = .paused
    }

    public mutating func resume() -> [TimelineRunnerEvent] {
        guard status == .paused else { return [] }
        status = .running
        return []
    }

    public mutating func skipForward() -> [TimelineRunnerEvent] {
        guard status == .running || status == .paused, let segment = currentSegment else { return [] }
        markStepCompletedIfNeeded(segment)
        return moveToNextSegment(preservePause: status == .paused)
    }

    public mutating func restartSegment() -> [TimelineRunnerEvent] {
        guard status == .running || status == .paused, let segment = currentSegment else { return [] }
        elapsedInCurrentSegment = 0
        elapsedTimelineSeconds = segment.startOffsetSeconds
        return status == .running ? currentSegmentStartEvents() : []
    }

    public mutating func previousSegment() -> [TimelineRunnerEvent] {
        guard status == .running || status == .paused, let currentSegmentIndex else { return [] }
        self.currentSegmentIndex = max(0, currentSegmentIndex - 1)
        elapsedInCurrentSegment = 0
        elapsedTimelineSeconds = currentSegment?.startOffsetSeconds ?? 0
        return status == .running ? currentSegmentStartEvents() : []
    }

    public mutating func abandon() -> [TimelineRunnerEvent] {
        guard status != .completed, status != .abandoned else { return [] }
        status = .abandoned
        terminalEventReported = true
        return [.abandoned(summary)]
    }

    private var currentSegment: TimelineSegment? {
        guard let currentSegmentIndex, timeline.segments.indices.contains(currentSegmentIndex) else { return nil }
        return timeline.segments[currentSegmentIndex]
    }

    private func cueEvents(in segment: TimelineSegment, at offset: Int) -> [TimelineRunnerEvent] {
        segment.cues
            .filter { $0.offsetSeconds == offset }
            .map { cue in
                .cue(.init(
                    timelineOffsetSeconds: segment.startOffsetSeconds + cue.offsetSeconds,
                    kind: cue.kind
                ))
            }
    }

    private func currentSegmentStartEvents() -> [TimelineRunnerEvent] {
        guard let currentSegment, let currentSegmentIndex else { return [] }
        return [.segmentChanged(currentSegmentIndex)] + cueEvents(in: currentSegment, at: 0)
    }

    private mutating func moveToNextSegment(preservePause: Bool = false) -> [TimelineRunnerEvent] {
        guard let currentSegmentIndex else { return [] }
        let nextIndex = currentSegmentIndex + 1
        guard timeline.segments.indices.contains(nextIndex) else {
            self.currentSegmentIndex = nil
            elapsedInCurrentSegment = 0
            elapsedTimelineSeconds = timeline.totalDurationSeconds
            status = .completed
            return reportCompletionIfNeeded()
        }

        self.currentSegmentIndex = nextIndex
        elapsedInCurrentSegment = 0
        elapsedTimelineSeconds = timeline.segments[nextIndex].startOffsetSeconds
        status = preservePause ? .paused : .running
        return preservePause ? [] : currentSegmentStartEvents()
    }

    private mutating func markStepCompletedIfNeeded(_ segment: TimelineSegment) {
        guard segment.kind == .work, let stepIndex = segment.step?.stepIndex else { return }
        let laterWorkForStep = timeline.segments.contains {
            $0.kind == .work &&
                $0.step?.stepIndex == stepIndex &&
                $0.startOffsetSeconds > segment.startOffsetSeconds
        }
        if !laterWorkForStep {
            completedStepIndexes.insert(stepIndex)
        }
    }

    private mutating func reportCompletionIfNeeded() -> [TimelineRunnerEvent] {
        guard !terminalEventReported else { return [] }
        terminalEventReported = true
        let completionCue = timeline.cues.last ?? .init(
            timelineOffsetSeconds: timeline.totalDurationSeconds,
            kind: .announcement(.completion)
        )
        let cue = TimelineRunnerEvent.cue(completionCue)
        return [cue, .completed(summary)]
    }
}
