@MainActor
final class FixedCloudAccountStatusService: CloudAccountStatusService {
    private let availability: CloudAccountAvailability

    init(_ availability: CloudAccountAvailability) {
        self.availability = availability
    }

    func accountStatus() async -> CloudAccountAvailability {
        availability
    }
}
