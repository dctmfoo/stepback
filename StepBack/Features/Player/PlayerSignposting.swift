import StepBackCore

@MainActor
protocol PlayerSignposting: AnyObject {
    func beginPlayToPreRoll()
    func endPlayToPreRoll()
    func beginSegment(index: Int, segment: TimelineSegment)
    func endSegment()
}
