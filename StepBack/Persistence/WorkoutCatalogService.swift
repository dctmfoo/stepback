import Foundation
import Observation
import StepBackCore

enum WorkoutCatalogResourceError: Error, Equatable {
    case missingResource
}

@Observable
@MainActor
final class WorkoutCatalogService {
    let catalog: WorkoutCatalog
    private let bundle: Bundle

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "workout-catalog", withExtension: "json") else {
            throw WorkoutCatalogResourceError.missingResource
        }
        catalog = try CatalogDecoder.decode(Data(contentsOf: url))
        self.bundle = bundle
    }

    func localizedString(for key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: bundle)
    }
}
