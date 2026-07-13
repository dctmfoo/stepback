import AVFAudio
import Foundation

actor PlayerAudioSession {
    private var deactivationTask: Task<Void, Never>?

    func activateCueWindow() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
        } catch {
            return
        }

        deactivationTask?.cancel()
        deactivationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.deactivate()
        }
        #endif
    }

    func deactivate() {
        #if os(iOS)
        deactivationTask?.cancel()
        deactivationTask = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        #endif
    }
}
