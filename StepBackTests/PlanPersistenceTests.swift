import Foundation
import SwiftData
import Testing
@testable import StepBack

@Suite("Weekly plan persistence and behavior")
@MainActor
struct PlanPersistenceTests {
    @Test("Plan snapshots preserve weekday order and removed routine names")
    func snapshotAndRemovedRoutineState() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Push")
        let later = PlanSlot(id: "later", sortIndex: 1, weekdayLabelIndex: 2, routine: routine)
        let earlier = PlanSlot(id: "earlier", sortIndex: 0, weekdayLabelIndex: 2, routine: routine)
        let plan = Plan(name: "Split", slots: [later, earlier])
        context.insert(routine)
        context.insert(plan)
        try context.save()

        #expect(plan.snapshot.slots.map(\.id) == ["earlier", "later"])
        context.delete(routine)
        try context.save()

        let slots = try PersistenceTestSupport.fetch(PlanSlot.self, from: context)
        #expect(slots.allSatisfy { $0.routine == nil })
        #expect(slots.allSatisfy { $0.routineNameSnapshot == "Push" })
    }

    @Test("Deleting a plan cascades slots without deleting routines")
    func planDeleteRules() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Push")
        let plan = Plan(name: "Split", slots: [PlanSlot(weekdayLabelIndex: 2, routine: routine)])
        context.insert(routine)
        context.insert(plan)
        try context.save()

        context.delete(plan)
        try context.save()

        #expect(try PersistenceTestSupport.fetch(Plan.self, from: context).isEmpty)
        #expect(try PersistenceTestSupport.fetch(PlanSlot.self, from: context).isEmpty)
        #expect(try PersistenceTestSupport.fetch(Routine.self, from: context).map(\.id) == ["routine"])
    }

    @Test("The first saved plan becomes My Week and later plans do not replace it")
    func firstPlanAutoSelection() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let first = try PlanEditorModel.newPlan(name: "Normal Week", calendar: mondayFirstCalendar)
            .save(existing: nil, in: context)
        let second = try PlanEditorModel.newPlan(name: "Travel Week", calendar: mondayFirstCalendar)
            .save(existing: nil, in: context)

        #expect(first.isActive)
        #expect(!second.isActive)
    }

    @Test("Selecting My Week is exclusive and accepts an all-rest schedule")
    func myWeekSelectionIsExclusive() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let first = Plan(name: "First", isActive: true)
        let empty = Plan(name: "Rest Week")
        context.insert(first)
        context.insert(empty)
        try context.save()

        try PlanLibrary.setMyWeek(empty, among: [first, empty], in: context)

        #expect(!first.isActive)
        #expect(empty.isActive)
    }

    @Test("Deleting My Week leaves remaining plans unselected")
    func deletingMyWeekDoesNotPromote() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let selected = Plan(name: "Selected", isActive: true)
        let remaining = Plan(name: "Remaining")
        context.insert(selected)
        context.insert(remaining)
        try context.save()

        try PlanLibrary.delete(selected, in: context)

        #expect(!remaining.isActive)
        #expect(try PersistenceTestSupport.fetch(Plan.self, from: context).map(\.name) == ["Remaining"])
    }

    @Test("The seven-day editor saves and reorders weekday buckets while legacy cursor fields stay inert")
    func editorWritesWeekdaysWithoutCursorBookkeeping() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Push")
        let secondRoutine = Routine(id: "second-routine", name: "Pull")
        let legacySlot = PlanSlot(id: "slot", weekIndex: 0, sortIndex: 0, weekdayLabelIndex: 2, routine: routine)
        let plan = Plan(
            name: "Legacy",
            isActive: true,
            cursorSlotID: "legacy-cursor",
            cursorWeekIndex: 4,
            cursorSlotIndex: 3,
            completedSlotCount: 9,
            isComplete: true,
            weeklyScheduleVersion: 1,
            slots: [legacySlot]
        )
        context.insert(routine)
        context.insert(secondRoutine)
        context.insert(plan)
        try context.save()

        let editor = PlanEditorModel.editing(plan, calendar: mondayFirstCalendar)
        #expect(editor.days.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
        editor.addRoutine(routine, toWeekday: 4)
        editor.addRoutine(secondRoutine, toWeekday: 4)
        editor.moveSlots(onWeekday: 4, from: IndexSet(integer: 1), to: 0)
        editor.name = "Updated"
        try editor.save(existing: plan, in: context)

        let wednesday = (plan.slots ?? [])
            .filter { $0.weekdayLabelIndex == 4 }
            .sorted(by: PlanSlot.sortOrder)
        #expect(wednesday.map(\.routineID) == ["second-routine", "routine"])
        #expect(plan.cursorSlotID == "legacy-cursor")
        #expect(plan.cursorWeekIndex == 4)
        #expect(plan.cursorSlotIndex == 3)
        #expect(plan.completedSlotCount == 9)
        #expect(plan.isComplete)
    }

    @Test("Legacy migration is idempotent and splits later weeks without losing slots")
    func migrationIsIdempotent() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Push")
        let plan = Plan(
            id: "legacy",
            name: "Split",
            isActive: true,
            weekCount: 2,
            weeklyScheduleVersion: 0,
            slots: [
                PlanSlot(id: "w1", weekIndex: 0, sortIndex: 0, routine: routine),
                PlanSlot(id: "w2", weekIndex: 1, sortIndex: 0, weekdayLabelIndex: 6, routine: routine)
            ]
        )
        context.insert(routine)
        context.insert(plan)
        try context.save()
        var ids = ["split-plan", "split-slot"]

        try PlanWeeklyScheduleMigrator.migrateIfNeeded(
            in: context,
            calendar: mondayFirstCalendar,
            makeID: { ids.removeFirst() }
        )
        try PlanWeeklyScheduleMigrator.migrateIfNeeded(in: context, calendar: mondayFirstCalendar)

        let plans = try PersistenceTestSupport.fetch(Plan.self, from: context).sorted { $0.name < $1.name }
        #expect(plans.map(\.name) == ["Split", "Split · Week 2"])
        #expect(plans.flatMap { $0.slots ?? [] }.map(\.id).sorted() == ["split-slot", "w1"])
        #expect(plans.allSatisfy { $0.weeklyScheduleVersion == 1 })
        #expect(plans.first(where: { $0.name == "Split" })?.isActive == true)
        #expect(plans.first(where: { $0.name.contains("Week 2") })?.isActive == false)
    }

    @Test("New plan launches stamp plan identity but not retired cursor positions")
    func sessionContextOmitsCursorStamps() {
        let context = PlanLaunchContext(planID: "plan", planNameSnapshot: "Split")
        let session = RoutineSession(routineNameSnapshot: "Push", planContext: context)

        #expect(session.planIDSnapshot == "plan")
        #expect(session.planNameSnapshot == "Split")
        #expect(session.planWeekIndex == nil)
        #expect(session.planSlotIndex == nil)
    }

    @Test("Duplicating a weekly plan does not revive retired cursor bookkeeping")
    func duplicateLeavesCursorFieldsEmpty() throws {
        let container = try PersistenceTestSupport.makeContainer()
        let context = container.mainContext
        let routine = Routine(id: "routine", name: "Push")
        let plan = Plan(
            name: "Week",
            slots: [PlanSlot(weekdayLabelIndex: 2, routine: routine)]
        )
        context.insert(routine)
        context.insert(plan)
        try context.save()

        let copy = try PlanLibrary.duplicate(plan, named: "Week Copy", in: context)

        #expect(copy.cursorSlotID == nil)
        #expect(copy.cursorWeekIndex == 0)
        #expect(copy.cursorSlotIndex == 0)
        #expect(copy.completedSlotCount == 0)
        #expect(!copy.isComplete)
    }

    private var mondayFirstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }
}
