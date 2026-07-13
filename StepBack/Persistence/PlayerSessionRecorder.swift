import Foundation
import StepBackCore
import SwiftData

@MainActor
final class PlayerSessionRecorder {
    private let modelContext: ModelContext
    private let markerStore: any InFlightSessionMarkerStore
    private let dateProvider: any SessionDateProviding
    private var activeMarker: InFlightSessionMarker?
    private var activeRoutine: Routine?

    init(
        modelContext: ModelContext,
        markerStore: any InFlightSessionMarkerStore = UserDefaultsInFlightSessionMarkerStore(),
        dateProvider: any SessionDateProviding = SystemSessionDateProvider()
    ) {
        self.modelContext = modelContext
        self.markerStore = markerStore
        self.dateProvider = dateProvider
    }

    func begin(
        routine: Routine,
        totalStepCount: Int,
        planContext: PlanLaunchContext? = nil
    ) throws {
        let now = dateProvider.now
        let marker = InFlightSessionMarker(
            routineID: routine.id,
            routineNameSnapshot: routine.name,
            startedAt: now,
            totalStepCount: totalStepCount,
            activeSeconds: 0,
            completedStepCount: 0,
            updatedAt: now,
            planContext: planContext
        )
        try markerStore.write(marker)
        activeMarker = marker
        activeRoutine = routine
    }

    func checkpoint(_ summary: RunnerSessionSummary) throws {
        guard let activeMarker else { return }
        let marker = InFlightSessionMarker(
            routineID: activeMarker.routineID,
            routineNameSnapshot: activeMarker.routineNameSnapshot,
            startedAt: activeMarker.startedAt,
            totalStepCount: activeMarker.totalStepCount,
            activeSeconds: max(0, summary.activeSeconds),
            completedStepCount: max(0, summary.completedStepCount),
            updatedAt: dateProvider.now,
            planContext: activeMarker.planContext
        )
        try markerStore.write(marker)
        self.activeMarker = marker
    }

    @discardableResult
    func finish(_ summary: RunnerSessionSummary) throws -> RoutineSession? {
        let marker = try activeMarker ?? markerStore.read()
        guard let marker else { return nil }
        guard summary.activeSeconds > 0 || summary.completedStepCount > 0 else {
            discard()
            return nil
        }

        let routine = activeRoutine?.id == marker.routineID
            ? activeRoutine
            : try routine(withID: marker.routineID)
        let session = RoutineSession(
            routineNameSnapshot: marker.routineNameSnapshot,
            startedAt: marker.startedAt,
            endedAt: dateProvider.now,
            wasCompleted: summary.wasCompleted,
            completedStepCount: max(0, summary.completedStepCount),
            totalStepCount: max(0, summary.totalStepCount),
            activeSeconds: max(0, summary.activeSeconds),
            planContext: marker.planContext,
            routine: routine
        )
        modelContext.insert(session)
        try modelContext.saveOrRollback()
        discard()
        return session
    }

    @discardableResult
    func reconcileAbandonedRun() throws -> RoutineSession? {
        let marker: InFlightSessionMarker
        do {
            guard let stored = try markerStore.read() else { return nil }
            marker = stored
        } catch {
            markerStore.clear()
            return nil
        }

        guard marker.activeSeconds > 0 || marker.completedStepCount > 0 else {
            markerStore.clear()
            return nil
        }

        if let existing = try session(
            startedAt: marker.startedAt,
            routineNameSnapshot: marker.routineNameSnapshot
        ) {
            markerStore.clear()
            return existing
        }

        let session = RoutineSession(
            routineNameSnapshot: marker.routineNameSnapshot,
            startedAt: marker.startedAt,
            endedAt: marker.updatedAt,
            wasCompleted: false,
            completedStepCount: max(0, marker.completedStepCount),
            totalStepCount: max(0, marker.totalStepCount),
            activeSeconds: max(0, marker.activeSeconds),
            planContext: marker.planContext,
            routine: try routine(withID: marker.routineID)
        )
        modelContext.insert(session)
        try modelContext.saveOrRollback()
        markerStore.clear()
        return session
    }

    func discard() {
        activeMarker = nil
        activeRoutine = nil
        markerStore.clear()
    }

    private func routine(withID id: String) throws -> Routine? {
        var descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func session(
        startedAt: Date,
        routineNameSnapshot: String
    ) throws -> RoutineSession? {
        var descriptor = FetchDescriptor<RoutineSession>(
            predicate: #Predicate {
                $0.startedAt == startedAt && $0.routineNameSnapshot == routineNameSnapshot
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
