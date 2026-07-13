import Foundation

enum WelcomePreferences {
    static let seenKey = "welcomeSeen"

    static func shouldPresent(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: seenKey)
    }

    static func configureForLaunch(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard arguments.contains("-StepBackUITesting") else { return }
        defaults.set(environment["StepBackUIShowWelcome"] != "1", forKey: seenKey)
    }
}
