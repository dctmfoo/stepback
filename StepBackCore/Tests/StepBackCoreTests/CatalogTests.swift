import Foundation
import Testing
@testable import StepBackCore

@Suite("Workout catalog decoding")
struct CatalogTests {
    @Test("Trimmed fixture decodes, preserves category order, and supports lookup")
    func validFixture() throws {
        let catalog = try CatalogDecoder.decode(TestSupport.fixtureData(named: "trimmed-catalog"))

        #expect(catalog.catalogVersion == 1)
        #expect(catalog.categories.map(\.id) == WorkoutCategory.requiredIDs)
        #expect(catalog.workout(id: "bridge")?.nameKey == "workout.bridge")
        #expect(catalog.workout(id: "missing") == nil)
        #expect(catalog.starterRoutines.count == 1)
    }

    @Test("Starter routine definitions resolve to snapshots and compile")
    func starterRoutineCompiles() throws {
        let catalog = try CatalogDecoder.decode(TestSupport.fixtureData(named: "trimmed-catalog"))
        let snapshot = try catalog.routineSnapshot(
            for: catalog.starterRoutines[0],
            routineNameSnapshot: "Quick Core",
            workoutNameSnapshot: { definition in
                switch definition.id {
                case "bridge": "Bridge"
                case "plank": "Plank"
                default: definition.nameKey
                }
            }
        )
        let timeline = TimelineCompiler.compile(snapshot, getReadySeconds: 5)

        #expect(snapshot.name == "Quick Core")
        #expect(snapshot.steps.map(\.workoutNameSnapshot) == ["Bridge", "Plank"])
        #expect(timeline.totalDurationSeconds == 120)
        #expect(timeline.segments.last?.kind == .work)
    }

    @Test("Duplicate workout identifiers fail strict decoding")
    func duplicateWorkoutID() throws {
        let data = try mutatedFixture(replacing: "\"id\": \"squat\"", with: "\"id\": \"bridge\"")
        #expect(throws: CatalogError.self) { try CatalogDecoder.decode(data) }
    }

    @Test("Unknown workout category fails strict decoding")
    func unknownCategory() throws {
        let data = try mutatedFixture(replacing: "\"categoryID\": \"core\"", with: "\"categoryID\": \"unknown\"")
        #expect(throws: CatalogError.self) { try CatalogDecoder.decode(data) }
    }

    @Test("Missing, extra, or reordered categories fail strict decoding", arguments: [
        CategoryMutation.missing,
        .extra,
        .reordered
    ])
    func invalidCategoryContract(_ mutation: CategoryMutation) throws {
        let data = try mutation.apply(to: TestSupport.fixtureData(named: "trimmed-catalog"))
        #expect(throws: CatalogError.self) { try CatalogDecoder.decode(data) }
    }

    @Test("Malformed JSON fails decoding")
    func malformedJSON() {
        #expect(throws: (any Error).self) {
            try CatalogDecoder.decode(Data("{ not-json".utf8))
        }
    }

    @Test("Unknown JSON keys are ignored for forward compatibility")
    func unknownKeysIgnored() throws {
        let catalog = try CatalogDecoder.decode(TestSupport.fixtureData(named: "trimmed-catalog"))
        #expect(catalog.workout(id: "plank") != nil)
    }

    private func mutatedFixture(replacing target: String, with replacement: String) throws -> Data {
        let data = try TestSupport.fixtureData(named: "trimmed-catalog")
        let source = try #require(String(data: data, encoding: .utf8))
        return Data(source.replacingOccurrences(of: target, with: replacement).utf8)
    }
}

enum CategoryMutation: String, Sendable, CaseIterable {
    case missing
    case extra
    case reordered

    func apply(to data: Data) throws -> Data {
        let source = try #require(String(data: data, encoding: .utf8))
        let fullBody = "    { \"id\": \"full-body\", \"nameKey\": \"category.full-body\", \"symbolName\": \"figure.mixed.cardio\" },\n"
        let core = "    { \"id\": \"core\", \"nameKey\": \"category.core\", \"symbolName\": \"figure.core.training\" },\n"

        switch self {
        case .missing:
            return Data(source.replacingOccurrences(of: fullBody, with: "").utf8)
        case .extra:
            let extra = "    { \"id\": \"extra\", \"nameKey\": \"category.extra\", \"symbolName\": \"questionmark\" },\n"
            return Data(source.replacingOccurrences(of: fullBody, with: fullBody + extra).utf8)
        case .reordered:
            return Data(source
                .replacingOccurrences(of: fullBody + core, with: core + fullBody)
                .utf8)
        }
    }
}
