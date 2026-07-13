import Foundation
import Observation

@MainActor
@Observable
final class CloudAccountStatusModel {
    private(set) var status: CloudAccountAvailability = .checking
    private let service: any CloudAccountStatusService

    init(service: any CloudAccountStatusService) {
        self.service = service
    }

    static func appDefault() -> CloudAccountStatusModel {
        if ProcessInfo.processInfo.arguments.contains("-StepBackUITesting") {
            CloudAccountStatusModel(service: FixedCloudAccountStatusService(.available))
        } else {
            CloudAccountStatusModel(service: CloudKitAccountStatusService())
        }
    }

    var statusText: String {
        switch status {
        case .checking:
            L10n.settingsSyncChecking
        case .available:
            L10n.settingsSyncUpToDate
        case .unavailable:
            L10n.settingsSyncUnavailable
        }
    }

    func refresh() async {
        status = await service.accountStatus()
    }

    func accountDidChange() async {
        status = .checking
        await refresh()
    }
}
