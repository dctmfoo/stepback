import Foundation

public struct PlanSlotSnapshot: Equatable, Identifiable, Sendable {
    public let id: String
    public var weekIndex: Int
    public var sortIndex: Int
    public var routineID: String
    public var routineNameSnapshot: String
    public var weekdayLabelIndex: Int?

    public init(
        id: String,
        weekIndex: Int,
        sortIndex: Int,
        routineID: String,
        routineNameSnapshot: String,
        weekdayLabelIndex: Int? = nil
    ) {
        self.id = id
        self.weekIndex = weekIndex
        self.sortIndex = sortIndex
        self.routineID = routineID
        self.routineNameSnapshot = routineNameSnapshot
        self.weekdayLabelIndex = weekdayLabelIndex
    }
}

public struct PlanSnapshot: Equatable, Sendable {
    public let id: String
    public var name: String
    public var weekCount: Int
    public var isRepeating: Bool
    public var cursorSlotID: String?
    public var cursorWeekIndex: Int
    public var cursorSlotIndex: Int
    public var completedSlotCount: Int
    public var isComplete: Bool
    public var slots: [PlanSlotSnapshot]

    public init(
        id: String,
        name: String,
        weekCount: Int,
        isRepeating: Bool,
        cursorSlotID: String?,
        cursorWeekIndex: Int,
        cursorSlotIndex: Int,
        completedSlotCount: Int,
        isComplete: Bool,
        slots: [PlanSlotSnapshot]
    ) {
        self.id = id
        self.name = name
        self.weekCount = weekCount
        self.isRepeating = isRepeating
        self.cursorSlotID = cursorSlotID
        self.cursorWeekIndex = cursorWeekIndex
        self.cursorSlotIndex = cursorSlotIndex
        self.completedSlotCount = completedSlotCount
        self.isComplete = isComplete
        self.slots = slots
    }
}

public struct PlanSessionFact: Equatable, Sendable {
    public let routineID: String
    public let completedAt: Date
    public let wasCompleted: Bool

    public init(routineID: String, completedAt: Date, wasCompleted: Bool) {
        self.routineID = routineID
        self.completedAt = completedAt
        self.wasCompleted = wasCompleted
    }
}

public struct WeeklyPlanDayStatus: Equatable, Sendable {
    public let weekday: Int
    public let date: Date
    public let slots: [PlanSlotSnapshot]
    public let completedSlotIDs: Set<String>

    public var totalSlotCount: Int { slots.count }
    public var completedSlotCount: Int { completedSlotIDs.count }
    public var isRest: Bool { slots.isEmpty }
    public var isDone: Bool { !slots.isEmpty && completedSlotCount == totalSlotCount }
    public var nextSlot: PlanSlotSnapshot? {
        slots.first { !completedSlotIDs.contains($0.id) }
    }
}

public struct WeeklyPlanStatus: Equatable, Sendable {
    public let days: [WeeklyPlanDayStatus]
    public let today: WeeklyPlanDayStatus

    public var plannedDayCount: Int { days.count { !$0.isRest } }
    public var completedDayCount: Int { days.count(where: \.isDone) }
}

public enum WeeklyPlanDeriver {
    public static func status(
        for plan: PlanSnapshot,
        sessions: [PlanSessionFact],
        now: Date,
        calendar: Calendar
    ) -> WeeklyPlanStatus {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let orderedWeekdays = weekdayOrder(firstWeekday: calendar.firstWeekday)
        let slots = plan.slots.filter { slot in
            guard let weekday = slot.weekdayLabelIndex else { return false }
            return (1...7).contains(weekday)
        }
        let days = orderedWeekdays.enumerated().map { offset, weekday in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let daySlots = slots
                .filter { $0.weekdayLabelIndex == weekday }
                .sorted(by: slotOrder)
            let completed = completedSlotIDs(
                in: daySlots,
                sessions: sessions.filter {
                    $0.wasCompleted && calendar.isDate($0.completedAt, inSameDayAs: date)
                }
            )
            return WeeklyPlanDayStatus(
                weekday: weekday,
                date: date,
                slots: daySlots,
                completedSlotIDs: completed
            )
        }
        let todayWeekday = calendar.component(.weekday, from: now)
        let today = days.first { $0.weekday == todayWeekday }
            ?? WeeklyPlanDayStatus(
                weekday: todayWeekday,
                date: calendar.startOfDay(for: now),
                slots: [],
                completedSlotIDs: []
            )
        return WeeklyPlanStatus(days: days, today: today)
    }

    public static func weekdayOrder(firstWeekday: Int) -> [Int] {
        let first = (1...7).contains(firstWeekday) ? firstWeekday : 1
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private static func completedSlotIDs(
        in slots: [PlanSlotSnapshot],
        sessions: [PlanSessionFact]
    ) -> Set<String> {
        var counts = sessions.reduce(into: [String: Int]()) { counts, session in
            counts[session.routineID, default: 0] += 1
        }
        return slots.reduce(into: Set<String>()) { completed, slot in
            guard counts[slot.routineID, default: 0] > 0 else { return }
            completed.insert(slot.id)
            counts[slot.routineID, default: 0] -= 1
        }
    }

    private static func slotOrder(_ lhs: PlanSlotSnapshot, _ rhs: PlanSlotSnapshot) -> Bool {
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.id < rhs.id
    }
}

public struct MigratedWeeklyPlan: Equatable, Sendable {
    public let name: String
    public let isMyWeek: Bool
    public let slots: [PlanSlotSnapshot]
}

public enum WeeklyPlanMigration {
    public static func migrate(
        _ plan: PlanSnapshot,
        firstWeekday: Int,
        wasMyWeek: Bool,
        splitPlanName: (String, Int) -> String
    ) -> [MigratedWeeklyPlan] {
        let weekCount = max(1, max(plan.weekCount, (plan.slots.map(\.weekIndex).max() ?? -1) + 1))
        return (0..<weekCount).map { weekIndex in
            let legacySlots = plan.slots
                .filter { $0.weekIndex == weekIndex }
                .sorted {
                    if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                    return $0.id < $1.id
                }
            return MigratedWeeklyPlan(
                name: weekIndex == 0 ? plan.name : splitPlanName(plan.name, weekIndex + 1),
                isMyWeek: weekIndex == 0 && wasMyWeek,
                slots: mapWeek(legacySlots, firstWeekday: firstWeekday)
            )
        }
    }

    private static func mapWeek(
        _ legacySlots: [PlanSlotSnapshot],
        firstWeekday: Int
    ) -> [PlanSlotSnapshot] {
        let order = WeeklyPlanDeriver.weekdayOrder(firstWeekday: firstWeekday)
        let occupied = Set(legacySlots.compactMap { slot -> Int? in
            guard let weekday = slot.weekdayLabelIndex, (1...7).contains(weekday) else { return nil }
            return weekday
        })
        var available = order.filter { !occupied.contains($0) }
        var assignedCounts: [Int: Int] = [:]

        return legacySlots.map { slot in
            let weekday: Int
            if let labeled = slot.weekdayLabelIndex, (1...7).contains(labeled) {
                weekday = labeled
            } else if !available.isEmpty {
                weekday = available.removeFirst()
            } else {
                weekday = order.last ?? 7
            }
            let index = assignedCounts[weekday, default: 0]
            assignedCounts[weekday] = index + 1
            return PlanSlotSnapshot(
                id: slot.id,
                weekIndex: 0,
                sortIndex: index,
                routineID: slot.routineID,
                routineNameSnapshot: slot.routineNameSnapshot,
                weekdayLabelIndex: weekday
            )
        }
    }
}
