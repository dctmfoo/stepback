import Foundation
import Testing
@testable import StepBack

@MainActor
@Suite("Welcome and iCloud status")
struct WelcomeAndCloudStatusTests {
    @Test("UI tests suppress welcome unless the dedicated lane opts in")
    func welcomeUITestDefaults() throws {
        let suiteName = "WelcomeAndCloudStatusTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(WelcomePreferences.shouldPresent(defaults: defaults))

        WelcomePreferences.configureForLaunch(
            defaults: defaults,
            arguments: ["-StepBackUITesting"],
            environment: [:]
        )
        #expect(!WelcomePreferences.shouldPresent(defaults: defaults))

        WelcomePreferences.configureForLaunch(
            defaults: defaults,
            arguments: ["-StepBackUITesting"],
            environment: ["StepBackUIShowWelcome": "1"]
        )
        #expect(WelcomePreferences.shouldPresent(defaults: defaults))

        defaults.set(true, forKey: WelcomePreferences.seenKey)
        #expect(!WelcomePreferences.shouldPresent(defaults: defaults))
    }

    @Test("Account changes re-check and map every unavailable state to one honest line")
    func cloudAccountStatusRefreshes() async {
        let service = FakeCloudAccountStatusService(statuses: [.available, .unavailable])
        let model = CloudAccountStatusModel(service: service)

        #expect(model.status == .checking)
        await model.refresh()
        #expect(model.status == .available)
        await model.accountDidChange()
        #expect(model.status == .unavailable)
        #expect(service.checkCount == 2)
        #expect(model.statusText == L10n.settingsSyncUnavailable)
    }
}

@MainActor
private final class FakeCloudAccountStatusService: CloudAccountStatusService {
    private var statuses: [CloudAccountAvailability]
    private(set) var checkCount = 0

    init(statuses: [CloudAccountAvailability]) {
        self.statuses = statuses
    }

    func accountStatus() async -> CloudAccountAvailability {
        checkCount += 1
        return statuses.isEmpty ? .unavailable : statuses.removeFirst()
    }
}
