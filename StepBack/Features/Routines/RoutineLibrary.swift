import Foundation
import SwiftData

@MainActor
enum RoutineLibrary {
    static func sorted(_ routines: [Routine]) -> [Routine] {
        routines
            .map { routine in
                (routine: routine, latestPlay: routine.sessions?.map(\.startedAt).max())
            }
            .sorted { lhs, rhs in
                let lhsPlayed = lhs.latestPlay
                let rhsPlayed = rhs.latestPlay

                switch (lhsPlayed, rhsPlayed) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    if lhs.routine.createdAt != rhs.routine.createdAt {
                        return lhs.routine.createdAt > rhs.routine.createdAt
                    }
                    return lhs.routine.id < rhs.routine.id
                }
            }
            .map(\.routine)
    }

    static func shouldShowMotivation(sessions: [RoutineSession]) -> Bool {
        !sessions.isEmpty
    }

    static func nextAvailableRoutineNumber(in routines: [Routine]) -> Int {
        var number = 1
        let names = Set(routines.map(\.name))
        while names.contains(L10n.defaultRoutineName(number)) {
            number += 1
        }
        return number
    }

    @discardableResult
    static func duplicate(
        _ routine: Routine,
        named name: String,
        in context: ModelContext,
        now: Date = .now,
        makeID: () -> String = { UUID().uuidString }
    ) throws -> Routine {
        let steps = (routine.steps ?? []).map { step in
            RoutineStep(
                sortIndex: step.sortIndex,
                workoutID: step.workoutID,
                workoutNameSnapshot: step.workoutNameSnapshot,
                workSeconds: step.workSeconds,
                sets: step.sets,
                setRestSeconds: step.setRestSeconds,
                restAfterSeconds: step.restAfterSeconds,
                repGuidance: step.repGuidance
            )
        }
        let copy = Routine(
            id: makeID(),
            name: name,
            createdAt: now,
            updatedAt: now,
            seedIdentifier: nil,
            steps: steps
        )
        context.insert(copy)
        try context.saveOrRollback()
        return copy
    }

    @discardableResult
    static func append(
        _ workout: WorkoutItem,
        to routine: Routine,
        in context: ModelContext,
        now: Date = .now
    ) throws -> RoutineStep {
        let nextIndex = (routine.steps ?? []).map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let defaults = RoutineStepDefaults.standard
        let step = RoutineStep(
            sortIndex: nextIndex,
            workoutID: workout.id,
            workoutNameSnapshot: workout.name,
            workSeconds: defaults.workSeconds,
            sets: defaults.sets,
            setRestSeconds: defaults.setRestSeconds,
            restAfterSeconds: defaults.restAfterSeconds,
            routine: routine
        )
        routine.steps = (routine.steps ?? []) + [step]
        routine.updatedAt = now
        context.insert(step)
        try context.saveOrRollback()
        return step
    }
}
