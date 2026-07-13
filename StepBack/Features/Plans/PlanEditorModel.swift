import Foundation
import Observation
import StepBackCore
import SwiftData
import SwiftUI

enum PlanEditorSaveError: Error, Equatable {
    case emptyName
}

struct PlanDraftSlot: Identifiable {
    let id: String
    var sourceSlot: PlanSlot?
    var routine: Routine?
    var routineID: String
    var routineNameSnapshot: String

    init(
        id: String = UUID().uuidString,
        sourceSlot: PlanSlot? = nil,
        routine: Routine?,
        routineID: String? = nil,
        routineNameSnapshot: String? = nil
    ) {
        self.id = id
        self.sourceSlot = sourceSlot
        self.routine = routine
        self.routineID = routineID ?? routine?.id ?? ""
        self.routineNameSnapshot = routineNameSnapshot ?? routine?.name ?? ""
    }

    init(slot: PlanSlot) {
        self.init(
            id: slot.id,
            sourceSlot: slot,
            routine: slot.routine,
            routineID: slot.routineID,
            routineNameSnapshot: slot.routineNameSnapshot
        )
    }
}

struct PlanDraftDay: Identifiable {
    var id: Int { weekday }
    let weekday: Int
    var slots: [PlanDraftSlot]
}

@MainActor
@Observable
final class PlanEditorModel {
    var name: String
    var days: [PlanDraftDay]

    private init(name: String, days: [PlanDraftDay]) {
        self.name = name
        self.days = days
    }

    static func newPlan(
        name: String,
        calendar: Calendar = .autoupdatingCurrent
    ) -> PlanEditorModel {
        PlanEditorModel(
            name: name,
            days: WeeklyPlanDeriver.weekdayOrder(firstWeekday: calendar.firstWeekday).map {
                PlanDraftDay(weekday: $0, slots: [])
            }
        )
    }

    static func editing(
        _ plan: Plan,
        calendar: Calendar = .autoupdatingCurrent
    ) -> PlanEditorModel {
        let slots = plan.slots ?? []
        let days = WeeklyPlanDeriver.weekdayOrder(firstWeekday: calendar.firstWeekday).map { weekday in
            PlanDraftDay(
                weekday: weekday,
                slots: slots
                    .filter { $0.weekdayLabelIndex == weekday }
                    .sorted(by: PlanSlot.sortOrder)
                    .map(PlanDraftSlot.init(slot:))
            )
        }
        return PlanEditorModel(name: plan.name, days: days)
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedName.isEmpty }
    var slotCount: Int { days.reduce(0) { $0 + $1.slots.count } }

    func addRoutine(_ routine: Routine, toWeekday weekday: Int) {
        guard let dayIndex = days.firstIndex(where: { $0.weekday == weekday }) else { return }
        days[dayIndex].slots.append(PlanDraftSlot(routine: routine))
    }

    func replaceSlot(_ slotID: String, with routine: Routine) {
        guard let location = slotLocation(slotID) else { return }
        days[location.day].slots[location.slot].routine = routine
        days[location.day].slots[location.slot].routineID = routine.id
        days[location.day].slots[location.slot].routineNameSnapshot = routine.name
    }

    func deleteSlot(_ slotID: String) {
        guard let location = slotLocation(slotID) else { return }
        days[location.day].slots.remove(at: location.slot)
    }

    func moveSlots(onWeekday weekday: Int, from offsets: IndexSet, to destination: Int) {
        guard let dayIndex = days.firstIndex(where: { $0.weekday == weekday }) else { return }
        days[dayIndex].slots.move(fromOffsets: offsets, toOffset: destination)
    }

    @discardableResult
    func save(
        existing plan: Plan?,
        in context: ModelContext,
        now: Date = .now,
        makeID: () -> String = { UUID().uuidString }
    ) throws -> Plan {
        guard !trimmedName.isEmpty else { throw PlanEditorSaveError.emptyName }
        if let plan {
            try saveExisting(plan, in: context, now: now, makeID: makeID)
            return plan
        }

        let isFirstPlan = try context.fetchCount(FetchDescriptor<Plan>()) == 0
        let plan = Plan(
            id: makeID(),
            name: trimmedName,
            createdAt: now,
            updatedAt: now,
            isActive: isFirstPlan,
            weeklyScheduleVersion: 1
        )
        plan.slots = makeSavedSlots(plan: plan, context: context, makeID: makeID)
        context.insert(plan)
        try context.saveOrRollback()
        return plan
    }

    private func saveExisting(
        _ plan: Plan,
        in context: ModelContext,
        now: Date,
        makeID: () -> String
    ) throws {
        let retained = days.flatMap(\.slots).compactMap(\.sourceSlot)
        for slot in plan.slots ?? [] where !retained.contains(where: { $0 === slot }) {
            context.delete(slot)
        }
        plan.name = trimmedName
        plan.weekCount = 1
        plan.isRepeating = false
        plan.weeklyScheduleVersion = 1
        plan.updatedAt = now
        plan.lastEditedVia = nil
        plan.slots = makeSavedSlots(plan: plan, context: context, makeID: makeID)
        try context.saveOrRollback()
    }

    private func makeSavedSlots(
        plan: Plan,
        context: ModelContext,
        makeID: () -> String
    ) -> [PlanSlot] {
        days.flatMap { day in
            day.slots.enumerated().map { sortIndex, draft in
                if let slot = draft.sourceSlot {
                    slot.weekIndex = 0
                    slot.sortIndex = sortIndex
                    slot.routine = draft.routine
                    slot.routineID = draft.routineID
                    slot.routineNameSnapshot = draft.routineNameSnapshot
                    slot.weekdayLabelIndex = day.weekday
                    slot.plan = plan
                    return slot
                }
                let slot = PlanSlot(
                    id: makeID(),
                    weekIndex: 0,
                    sortIndex: sortIndex,
                    routineID: draft.routineID,
                    routineNameSnapshot: draft.routineNameSnapshot,
                    weekdayLabelIndex: day.weekday,
                    plan: plan,
                    routine: draft.routine
                )
                context.insert(slot)
                return slot
            }
        }
    }

    private func slotLocation(_ id: String) -> (day: Int, slot: Int)? {
        for dayIndex in days.indices {
            if let slotIndex = days[dayIndex].slots.firstIndex(where: { $0.id == id }) {
                return (dayIndex, slotIndex)
            }
        }
        return nil
    }
}
