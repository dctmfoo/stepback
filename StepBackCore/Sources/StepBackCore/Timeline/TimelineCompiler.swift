public enum TimelineCompiler {
    public static func totalDurationSeconds(_ routine: RoutineSnapshot, getReadySeconds: Int) -> Int {
        guard !routine.steps.isEmpty else { return 0 }

        var total = max(0, getReadySeconds)
        for (stepIndex, step) in routine.steps.enumerated() {
            let setCount = max(0, step.sets)
            guard setCount > 0 else { continue }

            total += max(0, step.workSeconds) * setCount
            if setCount > 1 {
                total += max(0, step.setRestSeconds) * (setCount - 1)
            }
            if stepIndex < routine.steps.index(before: routine.steps.endIndex) {
                total += max(0, step.restAfterSeconds)
            }
        }
        return total
    }

    public static func compile(_ routine: RoutineSnapshot, getReadySeconds: Int) -> Timeline {
        guard !routine.steps.isEmpty else { return .empty }

        var drafts: [TimelineSegment] = []
        var offset = 0

        func append(
            kind: TimelineSegment.Kind,
            duration: Int,
            step: TimelineStepAttribution?,
            setIndex: Int? = nil,
            setCount: Int? = nil,
            repGuidance: Int? = nil
        ) {
            guard duration > 0 else { return }
            drafts.append(TimelineSegment(
                kind: kind,
                durationSeconds: duration,
                startOffsetSeconds: offset,
                step: step,
                setIndex: setIndex,
                setCount: setCount,
                repGuidance: repGuidance
            ))
            offset += duration
        }

        let first = routine.steps[0]
        let firstAttribution = TimelineStepAttribution(
            stepIndex: 0,
            workoutID: first.workoutID,
            workoutNameSnapshot: first.workoutNameSnapshot
        )
        append(kind: .getReady, duration: getReadySeconds, step: firstAttribution)

        for (stepIndex, step) in routine.steps.enumerated() {
            let attribution = TimelineStepAttribution(
                stepIndex: stepIndex,
                workoutID: step.workoutID,
                workoutNameSnapshot: step.workoutNameSnapshot
            )
            let setCount = max(0, step.sets)
            guard setCount > 0 else { continue }

            for setIndex in 1...setCount {
                append(
                    kind: .work,
                    duration: step.workSeconds,
                    step: attribution,
                    setIndex: setIndex,
                    setCount: setCount,
                    repGuidance: step.repGuidance
                )
                if setIndex < setCount {
                    append(
                        kind: .setRest,
                        duration: step.setRestSeconds,
                        step: attribution,
                        setIndex: setIndex,
                        setCount: setCount
                    )
                }
            }

            if stepIndex < routine.steps.index(before: routine.steps.endIndex) {
                append(kind: .rest, duration: step.restAfterSeconds, step: attribution)
            }
        }

        let segments = drafts.enumerated().map { index, segment in
            let nextWorkoutName = drafts[(index + 1)...].first(where: { $0.kind == .work })?.step?.workoutNameSnapshot
            let cues = cues(for: segment, nextWorkoutNameSnapshot: nextWorkoutName)
            return TimelineSegment(
                kind: segment.kind,
                durationSeconds: segment.durationSeconds,
                startOffsetSeconds: segment.startOffsetSeconds,
                step: segment.step,
                setIndex: segment.setIndex,
                setCount: segment.setCount,
                repGuidance: segment.repGuidance,
                nextWorkoutNameSnapshot: nextWorkoutName,
                cues: cues
            )
        }
        return Timeline(segments: segments)
    }

    private static func cues(
        for segment: TimelineSegment,
        nextWorkoutNameSnapshot: String?
    ) -> [SegmentCue] {
        var cues: [SegmentCue] = []

        switch segment.kind {
        case .getReady:
            if let name = segment.step?.workoutNameSnapshot {
                cues.append(.init(offsetSeconds: 0, kind: .announcement(.getReady(firstWorkoutNameSnapshot: name))))
            }
        case .work:
            if let step = segment.step, let setIndex = segment.setIndex, let setCount = segment.setCount {
                cues.append(.init(offsetSeconds: 0, kind: .announcement(.work(
                    workoutNameSnapshot: step.workoutNameSnapshot,
                    setIndex: setIndex,
                    setCount: setCount,
                    repGuidance: segment.repGuidance
                ))))
            }
            cues.append(.init(offsetSeconds: 0, kind: .tone(.workStart)))
        case .setRest:
            if let setIndex = segment.setIndex, let setCount = segment.setCount {
                cues.append(.init(
                    offsetSeconds: 0,
                    kind: .announcement(.setRest(nextSetIndex: setIndex + 1, setCount: setCount))
                ))
            }
        case .rest:
            cues.append(.init(
                offsetSeconds: 0,
                kind: .announcement(.rest(nextWorkoutNameSnapshot: nextWorkoutNameSnapshot))
            ))
        }

        for value in stride(from: 3, through: 1, by: -1) {
            let cueOffset = segment.durationSeconds - value
            if cueOffset > 0 {
                cues.append(.init(offsetSeconds: cueOffset, kind: .tone(.countdown(value))))
            }
        }

        return cues
    }
}
