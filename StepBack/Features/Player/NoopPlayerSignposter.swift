import StepBackCore

@MainActor
final class NoopPlayerSignposter: PlayerSignposting {
    func beginPlayToPreRoll() {}
    func endPlayToPreRoll() {}
    func beginSegment(index: Int, segment: TimelineSegment) {}
    func endSegment() {}
}
