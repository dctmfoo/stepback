struct RoutineStepDefaults: Equatable {
    static let standard = RoutineStepDefaults()

    var workSeconds = 30
    var sets = 1
    var setRestSeconds = 0
    var restAfterSeconds = 15
}
