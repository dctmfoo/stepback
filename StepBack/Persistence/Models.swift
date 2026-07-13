import Foundation
import SwiftData
import StepBackCore

@Model
final class Routine {
    var id: String = UUID().uuidString
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var seedIdentifier: String?
    var lastEditedVia: String?

    @Relationship(deleteRule: .cascade, inverse: \RoutineStep.routine)
    var steps: [RoutineStep]?

    @Relationship(deleteRule: .nullify, inverse: \RoutineSession.routine)
    var sessions: [RoutineSession]?

    @Relationship(deleteRule: .nullify, inverse: \PlanSlot.routine)
    var planSlots: [PlanSlot]?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        seedIdentifier: String? = nil,
        lastEditedVia: String? = nil,
        steps: [RoutineStep] = [],
        sessions: [RoutineSession] = [],
        planSlots: [PlanSlot] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.seedIdentifier = seedIdentifier
        self.lastEditedVia = lastEditedVia
        self.steps = steps
        self.sessions = sessions
        self.planSlots = planSlots
    }

    var snapshot: RoutineSnapshot {
        RoutineSnapshot(
            name: name,
            steps: (steps ?? [])
                .sorted { lhs, rhs in
                    if lhs.sortIndex == rhs.sortIndex {
                        return lhs.workoutID < rhs.workoutID
                    }
                    return lhs.sortIndex < rhs.sortIndex
                }
                .map(\.snapshot)
        )
    }
}

@Model
final class RoutineStep {
    var sortIndex: Int = 0
    var workoutID: String = ""
    var workoutNameSnapshot: String = ""
    var workSeconds: Int = 30
    var sets: Int = 1
    var setRestSeconds: Int = 0
    var restAfterSeconds: Int = 0
    var repGuidance: Int?
    var routine: Routine?

    init(
        sortIndex: Int = 0,
        workoutID: String = "",
        workoutNameSnapshot: String = "",
        workSeconds: Int = 30,
        sets: Int = 1,
        setRestSeconds: Int = 0,
        restAfterSeconds: Int = 0,
        repGuidance: Int? = nil,
        routine: Routine? = nil
    ) {
        self.sortIndex = sortIndex
        self.workoutID = workoutID
        self.workoutNameSnapshot = workoutNameSnapshot
        self.workSeconds = workSeconds
        self.sets = sets
        self.setRestSeconds = setRestSeconds
        self.restAfterSeconds = restAfterSeconds
        self.repGuidance = repGuidance
        self.routine = routine
    }

    var snapshot: RoutineStepSnapshot {
        RoutineStepSnapshot(
            workoutID: workoutID,
            workoutNameSnapshot: workoutNameSnapshot,
            workSeconds: workSeconds,
            sets: sets,
            setRestSeconds: setRestSeconds,
            restAfterSeconds: restAfterSeconds,
            repGuidance: repGuidance
        )
    }
}

@Model
final class CustomWorkout {
    var id: String = UUID().uuidString
    var name: String = ""
    var categoryID: String = "full-body"
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastEditedVia: String?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        categoryID: String = "full-body",
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastEditedVia: String? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastEditedVia = lastEditedVia
    }
}

@Model
final class RoutineSession {
    var routineNameSnapshot: String = ""
    var startedAt: Date = Date()
    var endedAt: Date?
    var wasCompleted: Bool = false
    var completedStepCount: Int = 0
    var totalStepCount: Int = 0
    var activeSeconds: Int = 0
    var planIDSnapshot: String?
    var planNameSnapshot: String?
    var planWeekIndex: Int?
    var planSlotIndex: Int?
    var routine: Routine?

    init(
        routineNameSnapshot: String = "",
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        wasCompleted: Bool = false,
        completedStepCount: Int = 0,
        totalStepCount: Int = 0,
        activeSeconds: Int = 0,
        planContext: PlanLaunchContext? = nil,
        routine: Routine? = nil
    ) {
        self.routineNameSnapshot = routineNameSnapshot
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.wasCompleted = wasCompleted
        self.completedStepCount = completedStepCount
        self.totalStepCount = totalStepCount
        self.activeSeconds = activeSeconds
        planIDSnapshot = planContext?.planID
        planNameSnapshot = planContext?.planNameSnapshot
        planWeekIndex = planContext?.weekIndex
        planSlotIndex = planContext?.slotIndex
        self.routine = routine
    }

    convenience init(snapshot: SessionSnapshot, routine: Routine? = nil) {
        self.init(
            routineNameSnapshot: snapshot.routineNameSnapshot,
            startedAt: snapshot.startedAt,
            endedAt: snapshot.endedAt,
            wasCompleted: snapshot.wasCompleted,
            completedStepCount: snapshot.completedStepCount,
            totalStepCount: snapshot.totalStepCount,
            activeSeconds: snapshot.activeSeconds,
            routine: routine
        )
    }

    var snapshot: SessionSnapshot {
        SessionSnapshot(
            routineID: routine?.id,
            routineNameSnapshot: routineNameSnapshot,
            startedAt: startedAt,
            endedAt: endedAt,
            wasCompleted: wasCompleted,
            completedStepCount: completedStepCount,
            totalStepCount: totalStepCount,
            activeSeconds: activeSeconds
        )
    }
}

@Model
final class Plan {
    var id: String = UUID().uuidString
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isActive: Bool = false
    var isRepeating: Bool = false
    var weekCount: Int = 1
    var cursorSlotID: String?
    var cursorWeekIndex: Int = 0
    var cursorSlotIndex: Int = 0
    var completedSlotCount: Int = 0
    var isComplete: Bool = false
    var weeklyScheduleVersion: Int = 0
    var lastEditedVia: String?

    @Relationship(deleteRule: .cascade, inverse: \PlanSlot.plan)
    var slots: [PlanSlot]?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        isActive: Bool = false,
        isRepeating: Bool = false,
        weekCount: Int = 1,
        cursorSlotID: String? = nil,
        cursorWeekIndex: Int = 0,
        cursorSlotIndex: Int = 0,
        completedSlotCount: Int = 0,
        isComplete: Bool = false,
        weeklyScheduleVersion: Int = 1,
        lastEditedVia: String? = nil,
        slots: [PlanSlot] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.isActive = isActive
        self.isRepeating = isRepeating
        self.weekCount = max(1, weekCount)
        self.cursorSlotID = cursorSlotID
        self.cursorWeekIndex = cursorWeekIndex
        self.cursorSlotIndex = cursorSlotIndex
        self.completedSlotCount = completedSlotCount
        self.isComplete = isComplete
        self.weeklyScheduleVersion = weeklyScheduleVersion
        self.lastEditedVia = lastEditedVia
        self.slots = slots
        for slot in slots {
            slot.plan = self
        }
    }

    var snapshot: PlanSnapshot {
        PlanSnapshot(
            id: id,
            name: name,
            weekCount: weekCount,
            isRepeating: isRepeating,
            cursorSlotID: cursorSlotID,
            cursorWeekIndex: cursorWeekIndex,
            cursorSlotIndex: cursorSlotIndex,
            completedSlotCount: completedSlotCount,
            isComplete: isComplete,
            slots: (slots ?? []).sorted(by: PlanSlot.sortOrder).map(\.snapshot)
        )
    }

}

@Model
final class PlanSlot {
    var id: String = UUID().uuidString
    var weekIndex: Int = 0
    var sortIndex: Int = 0
    var routineID: String = ""
    var routineNameSnapshot: String = ""
    var weekdayLabelIndex: Int?
    var plan: Plan?
    var routine: Routine?

    init(
        id: String = UUID().uuidString,
        weekIndex: Int = 0,
        sortIndex: Int = 0,
        routineID: String = "",
        routineNameSnapshot: String = "",
        weekdayLabelIndex: Int? = nil,
        plan: Plan? = nil,
        routine: Routine? = nil
    ) {
        self.id = id
        self.weekIndex = weekIndex
        self.sortIndex = sortIndex
        self.routineID = routine?.id ?? routineID
        self.routineNameSnapshot = routine?.name ?? routineNameSnapshot
        self.weekdayLabelIndex = weekdayLabelIndex
        self.plan = plan
        self.routine = routine
    }

    var snapshot: PlanSlotSnapshot {
        PlanSlotSnapshot(
            id: id,
            weekIndex: weekIndex,
            sortIndex: sortIndex,
            routineID: routineID,
            routineNameSnapshot: routineNameSnapshot,
            weekdayLabelIndex: weekdayLabelIndex
        )
    }

    static func sortOrder(_ lhs: PlanSlot, _ rhs: PlanSlot) -> Bool {
        let lhsWeekday = lhs.weekdayLabelIndex ?? 8
        let rhsWeekday = rhs.weekdayLabelIndex ?? 8
        if lhsWeekday != rhsWeekday { return lhsWeekday < rhsWeekday }
        if lhs.weekIndex != rhs.weekIndex { return lhs.weekIndex < rhs.weekIndex }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.id < rhs.id
    }
}
