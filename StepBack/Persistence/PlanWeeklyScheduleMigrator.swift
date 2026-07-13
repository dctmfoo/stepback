import Foundation
import StepBackCore
import SwiftData

@MainActor
enum PlanWeeklyScheduleMigrator {
    static func migrateIfNeeded(
        in context: ModelContext,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now,
        makeID: () -> String = { UUID().uuidString }
    ) throws {
        let plans = try context.fetch(FetchDescriptor<Plan>())
            .filter { $0.weeklyScheduleVersion < 1 }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id < $1.id
            }
        guard !plans.isEmpty else { return }

        for plan in plans {
            try migrate(plan, in: context, calendar: calendar, now: now, makeID: makeID)
        }
        try context.saveOrRollback()
    }

    private static func migrate(
        _ plan: Plan,
        in context: ModelContext,
        calendar: Calendar,
        now: Date,
        makeID: () -> String
    ) throws {
        let sourceSlots = plan.slots ?? []
        let sourceByID = Dictionary(uniqueKeysWithValues: sourceSlots.map { ($0.id, $0) })
        let migrated = WeeklyPlanMigration.migrate(
            plan.snapshot,
            firstWeekday: calendar.firstWeekday,
            wasMyWeek: plan.isActive,
            splitPlanName: L10n.plansMigrationWeekName
        )
        guard let first = migrated.first else { return }

        // Materialize split weeks while their source relationships are still intact.
        // SwiftData may fault a deleted slot's routine relationship immediately.
        for result in migrated.dropFirst() {
            let split = Plan(
                id: makeID(),
                name: result.name,
                createdAt: plan.createdAt,
                updatedAt: now,
                isActive: false,
                weeklyScheduleVersion: 1
            )
            let slots = result.slots.map { snapshot in
                let slot = PlanSlot(
                    id: makeID(),
                    weekIndex: 0,
                    sortIndex: snapshot.sortIndex,
                    routineID: snapshot.routineID,
                    routineNameSnapshot: snapshot.routineNameSnapshot,
                    weekdayLabelIndex: snapshot.weekdayLabelIndex,
                    plan: split,
                    routine: sourceByID[snapshot.id]?.routine
                )
                context.insert(slot)
                return slot
            }
            split.slots = slots
            context.insert(split)
        }

        let retained = first.slots.compactMap { snapshot -> PlanSlot? in
            guard let slot = sourceByID[snapshot.id] else { return nil }
            apply(snapshot, to: slot, plan: plan)
            return slot
        }
        for slot in sourceSlots where !retained.contains(where: { $0 === slot }) {
            context.delete(slot)
        }
        plan.name = first.name
        plan.slots = retained
        plan.weekCount = 1
        plan.isRepeating = false
        plan.weeklyScheduleVersion = 1
        plan.updatedAt = now

    }

    private static func apply(_ snapshot: PlanSlotSnapshot, to slot: PlanSlot, plan: Plan) {
        slot.weekIndex = 0
        slot.sortIndex = snapshot.sortIndex
        slot.weekdayLabelIndex = snapshot.weekdayLabelIndex
        slot.plan = plan
    }
}
