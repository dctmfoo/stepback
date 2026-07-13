import Foundation
import StepBackCore
import SwiftData

@MainActor
enum PlanLibrary {
    static func ordered(_ plans: [Plan]) -> [Plan] {
        plans.sorted {
            if $0.isActive != $1.isActive { return $0.isActive }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }
    }

    static func status(
        for plan: Plan,
        sessions: [RoutineSession],
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> WeeklyPlanStatus {
        let facts = sessions.compactMap { session -> PlanSessionFact? in
            guard let routineID = session.routine?.id, let completedAt = session.endedAt else { return nil }
            return PlanSessionFact(
                routineID: routineID,
                completedAt: completedAt,
                wasCompleted: session.wasCompleted
            )
        }
        return WeeklyPlanDeriver.status(for: plan.snapshot, sessions: facts, now: now, calendar: calendar)
    }

    static func launchContext(for plan: Plan) -> PlanLaunchContext {
        PlanLaunchContext(planID: plan.id, planNameSnapshot: plan.name)
    }

    static func setMyWeek(_ plan: Plan, among plans: [Plan], in context: ModelContext) throws {
        for candidate in plans {
            candidate.isActive = candidate === plan
        }
        plan.updatedAt = .now
        try context.saveOrRollback()
    }

    static func reconcileExclusiveSelection(_ plans: [Plan], in context: ModelContext) throws {
        let selected = plans.filter(\.isActive).sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }
        guard selected.count > 1 else { return }
        for plan in selected.dropFirst() {
            plan.isActive = false
        }
        try context.saveOrRollback()
    }

    static func delete(_ plan: Plan, in context: ModelContext) throws {
        context.delete(plan)
        try context.saveOrRollback()
    }

    @discardableResult
    static func duplicate(
        _ plan: Plan,
        named name: String,
        in context: ModelContext,
        now: Date = .now,
        makeID: () -> String = { UUID().uuidString }
    ) throws -> Plan {
        let slots = (plan.slots ?? []).sorted(by: PlanSlot.sortOrder).map { slot in
            PlanSlot(
                id: makeID(),
                weekIndex: 0,
                sortIndex: slot.sortIndex,
                routineID: slot.routineID,
                routineNameSnapshot: slot.routineNameSnapshot,
                weekdayLabelIndex: slot.weekdayLabelIndex,
                routine: slot.routine
            )
        }
        let copy = Plan(
            id: makeID(),
            name: name,
            createdAt: now,
            updatedAt: now,
            isActive: false,
            weeklyScheduleVersion: 1,
            slots: slots
        )
        context.insert(copy)
        try context.saveOrRollback()
        return copy
    }
}
