import Foundation

#if os(iOS)
import UIKit
#endif

@MainActor
protocol PlayerWakeServicing: AnyObject {
    func enable()
    func disable()
}

@MainActor
final class PlayerWakeService: PlayerWakeServicing {
    #if os(macOS)
    private var activity: NSObjectProtocol?
    #endif

    func enable() {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #elseif os(macOS)
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .userInitiated],
            reason: L10n.playerWakeReason
        )
        #endif
    }

    func disable() {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #elseif os(macOS)
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        #endif
    }

}
