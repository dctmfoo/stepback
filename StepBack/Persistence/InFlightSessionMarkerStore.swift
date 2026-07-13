@MainActor
protocol InFlightSessionMarkerStore: AnyObject {
    func read() throws -> InFlightSessionMarker?
    func write(_ marker: InFlightSessionMarker) throws
    func clear()
}
