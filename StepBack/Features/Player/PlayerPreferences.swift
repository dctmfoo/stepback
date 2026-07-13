import Foundation

enum PlayerPreferences {
    static let voiceKey = "player.voiceAnnouncements"
    static let tonesKey = "player.countdownTones"
    static let getReadyKey = "player.getReadySeconds"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            voiceKey: true,
            tonesKey: true,
            getReadyKey: 5
        ])
    }

    static var voiceEnabled: Bool { UserDefaults.standard.bool(forKey: voiceKey) }
    static var tonesEnabled: Bool { UserDefaults.standard.bool(forKey: tonesKey) }
    static var getReadySeconds: Int {
        min(30, max(0, UserDefaults.standard.integer(forKey: getReadyKey)))
    }
}
