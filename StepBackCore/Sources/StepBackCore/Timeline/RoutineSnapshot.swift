public struct RoutineSnapshot: Equatable, Hashable, Sendable {
    public let name: String
    public let steps: [RoutineStepSnapshot]

    public init(name: String, steps: [RoutineStepSnapshot]) {
        self.name = name
        self.steps = steps
    }
}

public struct RoutineStepSnapshot: Equatable, Hashable, Sendable {
    public let workoutID: String
    public let workoutNameSnapshot: String
    public let workSeconds: Int
    public let sets: Int
    public let setRestSeconds: Int
    public let restAfterSeconds: Int
    public let repGuidance: Int?

    public init(
        workoutID: String,
        workoutNameSnapshot: String,
        workSeconds: Int,
        sets: Int = 1,
        setRestSeconds: Int = 0,
        restAfterSeconds: Int = 0,
        repGuidance: Int? = nil
    ) {
        self.workoutID = workoutID
        self.workoutNameSnapshot = workoutNameSnapshot
        self.workSeconds = workSeconds
        self.sets = sets
        self.setRestSeconds = setRestSeconds
        self.restAfterSeconds = restAfterSeconds
        self.repGuidance = repGuidance
    }
}
