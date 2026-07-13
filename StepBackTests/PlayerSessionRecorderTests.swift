import Foundation
import StepBackCore
import SwiftData
import Testing
@testable import StepBack

@MainActor
@Suite("Player session recorder")
struct PlayerSessionRecorderTests {
    @Test("Completed and partial runs write one honest row each")
    func recordsCompletedAndPartialRuns() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Morning Core")
        context.insert(routine)
        try context.save()
        let store = InMemoryInFlightSessionMarkerStore()
        let dates = MutableSessionDateProvider(Date(timeIntervalSince1970: 1_000))
        let recorder = PlayerSessionRecorder(
            modelContext: context,
            markerStore: store,
            dateProvider: dates
        )

        try recorder.begin(routine: routine, totalStepCount: 5)
        dates.now = Date(timeIntervalSince1970: 1_330)
        let completed = try recorder.finish(RunnerSessionSummary(
            wasCompleted: true,
            completedStepCount: 5,
            totalStepCount: 5,
            activeSeconds: 330
        ))

        #expect(completed?.routine === routine)
        #expect(completed?.startedAt == Date(timeIntervalSince1970: 1_000))
        #expect(completed?.endedAt == Date(timeIntervalSince1970: 1_330))
        #expect(completed?.wasCompleted == true)
        #expect(store.marker == nil)

        dates.now = Date(timeIntervalSince1970: 2_000)
        try recorder.begin(routine: routine, totalStepCount: 5)
        dates.now = Date(timeIntervalSince1970: 2_120)
        _ = try recorder.finish(RunnerSessionSummary(
            wasCompleted: false,
            completedStepCount: 2,
            totalStepCount: 5,
            activeSeconds: 120
        ))

        let sessions = try PersistenceTestSupport.fetch(RoutineSession.self, from: context)
        #expect(sessions.count == 2)
        #expect(sessions.count(where: \.wasCompleted) == 1)
        #expect(sessions.map(\.activeSeconds).sorted() == [120, 330])
    }

    @Test("Zero progress clears recovery state and writes nothing")
    func zeroProgressWritesNothing() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Quick Start")
        context.insert(routine)
        let store = InMemoryInFlightSessionMarkerStore()
        let recorder = PlayerSessionRecorder(
            modelContext: context,
            markerStore: store,
            dateProvider: MutableSessionDateProvider(Date(timeIntervalSince1970: 1_000))
        )

        try recorder.begin(routine: routine, totalStepCount: 3)
        let result = try recorder.finish(RunnerSessionSummary(
            wasCompleted: false,
            completedStepCount: 0,
            totalStepCount: 3,
            activeSeconds: 0
        ))

        #expect(result == nil)
        #expect(store.marker == nil)
        #expect(try PersistenceTestSupport.fetch(RoutineSession.self, from: context).isEmpty)
    }

    @Test("Checkpoint refreshes only progress and proof time")
    func checkpointRefreshesMarker() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Quick Start")
        context.insert(routine)
        let store = InMemoryInFlightSessionMarkerStore()
        let dates = MutableSessionDateProvider(Date(timeIntervalSince1970: 1_000))
        let recorder = PlayerSessionRecorder(
            modelContext: context,
            markerStore: store,
            dateProvider: dates
        )

        try recorder.begin(routine: routine, totalStepCount: 3)
        dates.now = Date(timeIntervalSince1970: 1_045)
        try recorder.checkpoint(RunnerSessionSummary(
            wasCompleted: false,
            completedStepCount: 1,
            totalStepCount: 3,
            activeSeconds: 45
        ))

        let marker = try #require(store.marker)
        #expect(marker.routineID == "routine")
        #expect(marker.routineNameSnapshot == "Quick Start")
        #expect(marker.startedAt == Date(timeIntervalSince1970: 1_000))
        #expect(marker.updatedAt == Date(timeIntervalSince1970: 1_045))
        #expect(marker.completedStepCount == 1)
        #expect(marker.activeSeconds == 45)
    }

    @Test("Relaunch reconciliation records the last provable checkpoint once")
    func reconcilesAbandonedRun() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Morning Core")
        context.insert(routine)
        try context.save()
        let store = InMemoryInFlightSessionMarkerStore(marker: InFlightSessionMarker(
            routineID: routine.id,
            routineNameSnapshot: routine.name,
            startedAt: Date(timeIntervalSince1970: 1_000),
            totalStepCount: 5,
            activeSeconds: 91,
            completedStepCount: 2,
            updatedAt: Date(timeIntervalSince1970: 1_100)
        ))
        let recorder = PlayerSessionRecorder(
            modelContext: context,
            markerStore: store,
            dateProvider: MutableSessionDateProvider(Date(timeIntervalSince1970: 9_999))
        )

        let recovered = try recorder.reconcileAbandonedRun()
        let second = try recorder.reconcileAbandonedRun()

        #expect(recovered?.routine === routine)
        #expect(recovered?.endedAt == Date(timeIntervalSince1970: 1_100))
        #expect(recovered?.wasCompleted == false)
        #expect(recovered?.activeSeconds == 91)
        #expect(second == nil)
        #expect(store.marker == nil)
        #expect(try PersistenceTestSupport.fetch(RoutineSession.self, from: context).count == 1)
    }

    @Test("Recovery does not duplicate a run saved before its marker cleared")
    func reconciliationIsIdempotentAcrossTheSaveClearCrashWindow() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let existing = RoutineSession(
            routineNameSnapshot: "Morning Core",
            startedAt: startedAt,
            endedAt: Date(timeIntervalSince1970: 1_100),
            wasCompleted: true,
            completedStepCount: 5,
            totalStepCount: 5,
            activeSeconds: 100
        )
        context.insert(existing)
        try context.save()
        let store = InMemoryInFlightSessionMarkerStore(marker: InFlightSessionMarker(
            routineID: "routine",
            routineNameSnapshot: "Morning Core",
            startedAt: startedAt,
            totalStepCount: 5,
            activeSeconds: 90,
            completedStepCount: 4,
            updatedAt: Date(timeIntervalSince1970: 1_090)
        ))
        let recorder = PlayerSessionRecorder(
            modelContext: context,
            markerStore: store,
            dateProvider: MutableSessionDateProvider(Date(timeIntervalSince1970: 2_000))
        )

        let reconciled = try recorder.reconcileAbandonedRun()

        #expect(reconciled === existing)
        #expect(store.marker == nil)
        #expect(try PersistenceTestSupport.fetch(RoutineSession.self, from: context).count == 1)
    }

    @Test("Recovery tolerates a deleted routine, zero marker, and corrupt payload")
    func recoveryEdgeCases() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let store = InMemoryInFlightSessionMarkerStore(marker: InFlightSessionMarker(
            routineID: "deleted",
            routineNameSnapshot: "Deleted Routine",
            startedAt: Date(timeIntervalSince1970: 1_000),
            totalStepCount: 4,
            activeSeconds: 30,
            completedStepCount: 1,
            updatedAt: Date(timeIntervalSince1970: 1_030)
        ))
        let recorder = PlayerSessionRecorder(
            modelContext: context,
            markerStore: store,
            dateProvider: MutableSessionDateProvider(Date(timeIntervalSince1970: 2_000))
        )

        let missingRoutine = try recorder.reconcileAbandonedRun()
        #expect(missingRoutine?.routine == nil)
        #expect(missingRoutine?.routineNameSnapshot == "Deleted Routine")

        store.marker = InFlightSessionMarker(
            routineID: "zero",
            routineNameSnapshot: "Zero",
            startedAt: Date(timeIntervalSince1970: 3_000),
            totalStepCount: 2,
            activeSeconds: 0,
            completedStepCount: 0,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        #expect(try recorder.reconcileAbandonedRun() == nil)

        store.readError = MarkerReadError.corrupt
        #expect(try recorder.reconcileAbandonedRun() == nil)
        #expect(store.clearCount == 3)
        #expect(try PersistenceTestSupport.fetch(RoutineSession.self, from: context).count == 1)
    }

    @Test("Same-day completions increment count without double-counting streak")
    func statsReadRecordedRows() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Quick Start")
        context.insert(routine)
        let store = InMemoryInFlightSessionMarkerStore()
        let dates = MutableSessionDateProvider(Date(timeIntervalSince1970: 1_752_145_200))
        let recorder = PlayerSessionRecorder(
            modelContext: context,
            markerStore: store,
            dateProvider: dates
        )
        let summary = RunnerSessionSummary(
            wasCompleted: true,
            completedStepCount: 3,
            totalStepCount: 3,
            activeSeconds: 180
        )

        try recorder.begin(routine: routine, totalStepCount: 3)
        dates.now = dates.now.addingTimeInterval(180)
        _ = try recorder.finish(summary)
        dates.now = dates.now.addingTimeInterval(60)
        try recorder.begin(routine: routine, totalStepCount: 3)
        dates.now = dates.now.addingTimeInterval(180)
        _ = try recorder.finish(summary)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 19_800)!
        let snapshots = try PersistenceTestSupport.fetch(RoutineSession.self, from: context).map(\.snapshot)
        let stats = DerivedStats.perRoutine(sessions: snapshots, routineID: routine.id)

        #expect(RoutineLibrary.shouldShowMotivation(sessions: try PersistenceTestSupport.fetch(RoutineSession.self, from: context)))
        #expect(RoutineLibrary.sorted([Routine(id: "other", name: "Other"), routine]).first?.id == routine.id)
        #expect(stats.timesCompleted == 2)
        #expect(DerivedStats.currentStreak(sessions: snapshots, calendar: calendar, now: dates.now) == 1)

        for session in try PersistenceTestSupport.fetch(RoutineSession.self, from: context) {
            context.delete(session)
        }
        try context.save()

        let emptySessions = try PersistenceTestSupport.fetch(RoutineSession.self, from: context)
        #expect(!RoutineLibrary.shouldShowMotivation(sessions: emptySessions))
        #expect(DerivedStats.perRoutine(sessions: [], routineID: routine.id).timesCompleted == 0)
        #expect(routine.sessions?.isEmpty == true)
    }
}

@MainActor
private final class MutableSessionDateProvider: SessionDateProviding {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}

@MainActor
private final class InMemoryInFlightSessionMarkerStore: InFlightSessionMarkerStore {
    var marker: InFlightSessionMarker?
    var readError: Error?
    private(set) var clearCount = 0

    init(marker: InFlightSessionMarker? = nil) {
        self.marker = marker
    }

    func read() throws -> InFlightSessionMarker? {
        if let readError { throw readError }
        return marker
    }

    func write(_ marker: InFlightSessionMarker) throws {
        self.marker = marker
    }

    func clear() {
        marker = nil
        readError = nil
        clearCount += 1
    }
}

private enum MarkerReadError: Error {
    case corrupt
}
