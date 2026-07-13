import Accessibility
import AVFAudio
import Foundation
import StepBackCore

actor PlayerAnnouncementSink: AnnouncementSink {
    private let audioSession: PlayerAudioSession
    private let synthesizer = AVSpeechSynthesizer()
    private let routineActiveSeconds: Int

    init(audioSession: PlayerAudioSession, routineActiveSeconds: Int) {
        self.audioSession = audioSession
        self.routineActiveSeconds = routineActiveSeconds
    }

    func announce(_ cue: AnnouncementCue) async {
        let text = announcementText(for: cue)
        await postAccessibilityAnnouncement(text)
        guard PlayerPreferences.voiceEnabled else { return }

        await audioSession.activateCueWindow()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    private func announcementText(for cue: AnnouncementCue) -> String {
        switch cue {
        case let .getReady(firstWorkoutNameSnapshot):
            return L10n.speechGetReady(firstWorkoutNameSnapshot)
        case let .work(name, setIndex, setCount, repGuidance):
            let work = setCount > 1
                ? L10n.speechWorkSet(name, setIndex: setIndex, setCount: setCount)
                : L10n.speechWork(name)
            guard let repGuidance else { return work }
            return [work, L10n.speechReps(repGuidance)].joined(separator: L10n.speechSeparator)
        case let .setRest(nextSetIndex, setCount):
            return L10n.speechSetRest(nextSetIndex, setCount: setCount)
        case let .rest(nextWorkoutNameSnapshot):
            return nextWorkoutNameSnapshot.map(L10n.speechRest) ?? L10n.playerKickerRest
        case .completion:
            return L10n.speechComplete(DisplayFormatters.spokenDuration(routineActiveSeconds))
        }
    }

    @MainActor
    private func postAccessibilityAnnouncement(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }
}
