import Foundation
import Testing
@testable import StepBack
import StepBackCore

@Suite("Production workout catalog")
struct ProductionCatalogTests {
    @Test("Catalog v1 has the exact category distribution and required content")
    @MainActor
    func catalogShape() throws {
        let service = try WorkoutCatalogService(bundle: .main)
        let catalog = service.catalog

        #expect(catalog.catalogVersion == 1)
        #expect(catalog.categories.map(\.id) == WorkoutCategory.requiredIDs)
        #expect(catalog.workouts.count == 92)
        #expect(categoryCounts(in: catalog) == [10, 11, 10, 11, 14, 12, 14, 10])
        #expect(catalog.starterRoutines.count == 3)

        for id in ["bridge", "squat", "russian-twist", "bicycle-crunch", "mountain-climber"] {
            #expect(catalog.workout(id: id) != nil)
        }
        #expect(catalog.workout(id: "wall-sit") == nil)
        #expect(catalog.workouts.allSatisfy { $0.mediaKey == nil && $0.instructionsKey == nil })
    }

    @Test("Every starter compiles to its contract total and ends on work")
    @MainActor
    func starterTotals() throws {
        let service = try WorkoutCatalogService(bundle: .main)
        let expected = [
            "starter.quick-start": 290,
            "starter.full-body-classic": 835,
            "starter.full-session": 1_180
        ]

        for starter in service.catalog.starterRoutines {
            let snapshot = try service.catalog.routineSnapshot(
                for: starter,
                routineNameSnapshot: service.localizedString(for: starter.nameKey),
                workoutNameSnapshot: { service.localizedString(for: $0.nameKey) }
            )
            let timeline = TimelineCompiler.compile(snapshot, getReadySeconds: 0)

            #expect(timeline.totalDurationSeconds == expected[starter.nameKey])
            #expect(timeline.segments.last?.kind == .work)
        }
    }

    @Test("Every catalog localization key resolves to English content")
    @MainActor
    func localizationCoverage() throws {
        let service = try WorkoutCatalogService(bundle: .main)
        let catalog = service.catalog
        let keys = Set(catalog.categories.map(\.nameKey))
            .union(catalog.workouts.map(\.nameKey))
            .union(catalog.workouts.flatMap { $0.focusAreas.map { "focus.\($0)" } })
            .union(catalog.starterRoutines.map(\.nameKey))

        #expect(keys.count == 117)
        for key in keys {
            let value = service.localizedString(for: key)
            #expect(value != key, "Missing localization for \(key)")
            #expect(!value.isEmpty, "Empty localization for \(key)")
        }
    }

    private func categoryCounts(in catalog: WorkoutCatalog) -> [Int] {
        catalog.categories.map { category in
            catalog.workouts.count { $0.categoryID == category.id }
        }
    }
}
