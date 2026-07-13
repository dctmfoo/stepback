import Foundation
import SwiftData
import Testing
@testable import StepBack

@Suite("Starter routine duplicate convergence")
@MainActor
struct StarterRoutineDeduplicatorTests {
    private let baseDate = Date(timeIntervalSince1970: 20_000)

    @Test("All-pristine duplicates keep the oldest copy")
    func oldestPristineSurvives() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let older = PersistenceTestSupport.routine(
            id: "older",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate
        )
        let newer = PersistenceTestSupport.routine(
            id: "newer",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate.addingTimeInterval(1)
        )
        container.mainContext.insert(newer)
        container.mainContext.insert(older)
        try container.mainContext.save()

        #expect(try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext) == 1)
        #expect(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).map(\.id) == ["older"])
        #expect(try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext) == 0)
    }

    @Test("Equal timestamps use the smaller stable id regardless of insertion order", arguments: [true, false])
    func stableIDTieBreak(reverseInsertion: Bool) throws {
        let container = try PersistenceTestSupport.makeContainer()
        let first = PersistenceTestSupport.routine(
            id: "aaa",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate
        )
        let second = PersistenceTestSupport.routine(
            id: "zzz",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate
        )
        for routine in reverseInsertion ? [second, first] : [first, second] {
            container.mainContext.insert(routine)
        }
        try container.mainContext.save()

        _ = try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext)

        #expect(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).map(\.id) == ["aaa"])
    }

    @Test("An edited copy survives and pristine surplus is deleted")
    func editedCopySurvives() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let pristine = PersistenceTestSupport.routine(
            id: "pristine",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate
        )
        let edited = PersistenceTestSupport.routine(
            id: "edited",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate.addingTimeInterval(1),
            updatedAt: baseDate.addingTimeInterval(2)
        )
        container.mainContext.insert(pristine)
        container.mainContext.insert(edited)
        try container.mainContext.save()

        _ = try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext)

        #expect(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).map(\.id) == ["edited"])
    }

    @Test("A played copy is non-pristine even without an edit timestamp")
    func playedCopySurvives() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let pristine = PersistenceTestSupport.routine(
            id: "pristine",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate
        )
        let played = PersistenceTestSupport.routine(
            id: "played",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate.addingTimeInterval(1)
        )
        let session = RoutineSession(routineNameSnapshot: "Quick Start", routine: played)
        container.mainContext.insert(pristine)
        container.mainContext.insert(played)
        container.mainContext.insert(session)
        try container.mainContext.save()

        _ = try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext)

        #expect(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).map(\.id) == ["played"])
    }

    @Test("Multiple edited copies survive while pristine copies and their steps are removed")
    func userDataIsNeverDeleted() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let step = RoutineStep(workoutID: "plank", workoutNameSnapshot: "Plank")
        let pristine = PersistenceTestSupport.routine(
            id: "pristine",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate,
            steps: [step]
        )
        let editedA = PersistenceTestSupport.routine(
            id: "edited-a",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate,
            updatedAt: baseDate.addingTimeInterval(1)
        )
        let editedB = PersistenceTestSupport.routine(
            id: "edited-b",
            seedIdentifier: "starter.quick-start",
            createdAt: baseDate,
            updatedAt: baseDate.addingTimeInterval(2)
        )
        for routine in [pristine, editedA, editedB] {
            container.mainContext.insert(routine)
        }
        try container.mainContext.save()

        _ = try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext)

        #expect(Set(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).map(\.id)) == ["edited-a", "edited-b"])
        #expect(try PersistenceTestSupport.fetch(RoutineStep.self, from: container.mainContext).isEmpty)
    }

    @Test("User routines with matching names are outside the sweep")
    func nilSeedIdentifiersAreUntouched() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let first = PersistenceTestSupport.routine(id: "first", name: "Same", createdAt: baseDate)
        let second = PersistenceTestSupport.routine(id: "second", name: "Same", createdAt: baseDate)
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()

        #expect(try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext) == 0)
        #expect(try PersistenceTestSupport.fetch(Routine.self, from: container.mainContext).count == 2)
    }
}
