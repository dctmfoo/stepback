@MainActor
protocol CloudAccountStatusService: AnyObject {
    func accountStatus() async -> CloudAccountAvailability
}
