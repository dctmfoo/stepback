import Foundation
import OSLog
import StepBackCore

@MainActor
final class SystemPlayerSignposter: PlayerSignposting {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.nags.stepback"
    static let category = "player"
    static let playToPreRollName: StaticString = "PlayToPreRoll"
    static let timelineSegmentName: StaticString = "TimelineSegment"

    private let signposter = OSSignposter(subsystem: subsystem, category: category)
    private var playToPreRollState: OSSignpostIntervalState?
    private var segmentState: OSSignpostIntervalState?
    private var segmentExpectedEndOffset = 0

    func beginPlayToPreRoll() {
        endPlayToPreRoll()
        playToPreRollState = signposter.beginInterval(Self.playToPreRollName)
    }

    func endPlayToPreRoll() {
        guard let playToPreRollState else { return }
        signposter.endInterval(Self.playToPreRollName, playToPreRollState)
        self.playToPreRollState = nil
    }

    func beginSegment(index: Int, segment: TimelineSegment) {
        endSegment()
        segmentExpectedEndOffset = segment.startOffsetSeconds + segment.durationSeconds
        segmentState = signposter.beginInterval(
            Self.timelineSegmentName,
            "index: \(index, privacy: .public), kind: \(segment.kind.rawValue, privacy: .public), compiledOffsetSeconds: \(segment.startOffsetSeconds, privacy: .public), durationSeconds: \(segment.durationSeconds, privacy: .public)"
        )
    }

    func endSegment() {
        guard let segmentState else { return }
        signposter.endInterval(
            Self.timelineSegmentName,
            segmentState,
            "compiledEndOffsetSeconds: \(self.segmentExpectedEndOffset, privacy: .public)"
        )
        self.segmentState = nil
    }
}
