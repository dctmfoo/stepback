import Foundation

@MainActor
final class UserDefaultsInFlightSessionMarkerStore: InFlightSessionMarkerStore {
    static let key = "player.inFlightSession"

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func read() throws -> InFlightSessionMarker? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try decoder.decode(InFlightSessionMarker.self, from: data)
    }

    func write(_ marker: InFlightSessionMarker) throws {
        defaults.set(try encoder.encode(marker), forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
