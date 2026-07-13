public enum AnnouncementCue: Equatable, Hashable, Sendable {
    case getReady(firstWorkoutNameSnapshot: String)
    case work(workoutNameSnapshot: String, setIndex: Int, setCount: Int, repGuidance: Int?)
    case setRest(nextSetIndex: Int, setCount: Int)
    case rest(nextWorkoutNameSnapshot: String?)
    case completion
}

public enum ToneCue: Equatable, Hashable, Sendable {
    case workStart
    case countdown(Int)
    case resumeCountdown
}

public enum CueKind: Equatable, Hashable, Sendable {
    case announcement(AnnouncementCue)
    case tone(ToneCue)
}

public struct SegmentCue: Equatable, Hashable, Sendable {
    public let offsetSeconds: Int
    public let kind: CueKind

    public init(offsetSeconds: Int, kind: CueKind) {
        self.offsetSeconds = offsetSeconds
        self.kind = kind
    }
}

public struct TimelineCue: Equatable, Hashable, Sendable {
    public let timelineOffsetSeconds: Int
    public let kind: CueKind

    public init(timelineOffsetSeconds: Int, kind: CueKind) {
        self.timelineOffsetSeconds = timelineOffsetSeconds
        self.kind = kind
    }
}

public struct TimelineStepAttribution: Equatable, Hashable, Sendable {
    public let stepIndex: Int
    public let workoutID: String
    public let workoutNameSnapshot: String

    public init(stepIndex: Int, workoutID: String, workoutNameSnapshot: String) {
        self.stepIndex = stepIndex
        self.workoutID = workoutID
        self.workoutNameSnapshot = workoutNameSnapshot
    }
}

public struct TimelineSegment: Equatable, Hashable, Sendable {
    public enum Kind: String, Equatable, Hashable, Sendable {
        case getReady
        case work
        case setRest
        case rest
    }

    public let kind: Kind
    public let durationSeconds: Int
    public let startOffsetSeconds: Int
    public let step: TimelineStepAttribution?
    public let setIndex: Int?
    public let setCount: Int?
    public let repGuidance: Int?
    public let nextWorkoutNameSnapshot: String?
    public let cues: [SegmentCue]

    public init(
        kind: Kind,
        durationSeconds: Int,
        startOffsetSeconds: Int,
        step: TimelineStepAttribution?,
        setIndex: Int? = nil,
        setCount: Int? = nil,
        repGuidance: Int? = nil,
        nextWorkoutNameSnapshot: String? = nil,
        cues: [SegmentCue] = []
    ) {
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.startOffsetSeconds = startOffsetSeconds
        self.step = step
        self.setIndex = setIndex
        self.setCount = setCount
        self.repGuidance = repGuidance
        self.nextWorkoutNameSnapshot = nextWorkoutNameSnapshot
        self.cues = cues
    }
}

public struct Timeline: Equatable, Hashable, Sendable {
    public static let empty = Timeline(segments: [])

    public let segments: [TimelineSegment]
    public let totalDurationSeconds: Int
    public let stepCount: Int
    public let cues: [TimelineCue]

    public init(segments: [TimelineSegment]) {
        self.segments = segments
        self.totalDurationSeconds = segments.last.map { $0.startOffsetSeconds + $0.durationSeconds } ?? 0
        self.stepCount = Set(segments.compactMap { $0.step?.stepIndex }).count
        self.cues = segments.flatMap { segment in
            segment.cues.map { cue in
                TimelineCue(
                    timelineOffsetSeconds: segment.startOffsetSeconds + cue.offsetSeconds,
                    kind: cue.kind
                )
            }
        } + [TimelineCue(
            timelineOffsetSeconds: totalDurationSeconds,
            kind: .announcement(.completion)
        )]
    }
}
