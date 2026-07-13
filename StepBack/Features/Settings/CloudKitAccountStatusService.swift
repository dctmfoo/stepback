import CloudKit

@MainActor
final class CloudKitAccountStatusService: CloudAccountStatusService {
    private let container: CKContainer

    init(container: CKContainer = CKContainer(identifier: StepBackModelContainer.cloudKitContainerIdentifier)) {
        self.container = container
    }

    func accountStatus() async -> CloudAccountAvailability {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, error in
                continuation.resume(
                    returning: status == .available && error == nil ? .available : .unavailable
                )
            }
        }
    }
}
