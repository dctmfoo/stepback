import Foundation
import Testing
@testable import StepBackCore

@Suite("Weekly plan schedule")
struct PlanProgressTests {
    @Test("Today resolves duplicate slots from completed sessions without advancing anything")
    func todayResolutionCountsDuplicateRoutines() throws {
        let calendar = mondayFirstUTC
        let now = date(2026, 7, 13, 12)
        let plan = plan(slots: [
            slot("mon-1", weekday: 2, index: 0, routine: "push"),
            slot("mon-2", weekday: 2, index: 1, routine: "push"),
            slot("wed", weekday: 4, index: 0, routine: "pull"),
            slot("thu", weekday: 5, index: 0, routine: "push")
        ])
        let sessions = [
            PlanSessionFact(routineID: "push", completedAt: date(2026, 7, 13, 8), wasCompleted: true),
            PlanSessionFact(routineID: "push", completedAt: date(2026, 7, 13, 10), wasCompleted: true),
            PlanSessionFact(routineID: "pull", completedAt: date(2026, 7, 15, 10), wasCompleted: false)
        ]

        let status = WeeklyPlanDeriver.status(for: plan, sessions: sessions, now: now, calendar: calendar)

        #expect(status.today.weekday == 2)
        #expect(status.today.completedSlotCount == 2)
        #expect(status.today.totalSlotCount == 2)
        #expect(status.today.isDone)
        #expect(status.today.nextSlot == nil)
        #expect(status.days.first(where: { $0.weekday == 5 })?.completedSlotCount == 0)
        #expect(status.completedDayCount == 1)
    }

    @Test("The first unmatched slot is next and abandoned sessions never count")
    func firstUndoneSlotIsNext() throws {
        let calendar = mondayFirstUTC
        let now = date(2026, 7, 13, 12)
        let plan = plan(slots: [
            slot("first", weekday: 2, index: 0, routine: "push"),
            slot("second", weekday: 2, index: 1, routine: "push"),
            slot("third", weekday: 2, index: 2, routine: "pull")
        ])
        let sessions = [
            PlanSessionFact(routineID: "push", completedAt: date(2026, 7, 13, 8), wasCompleted: true),
            PlanSessionFact(routineID: "pull", completedAt: date(2026, 7, 13, 9), wasCompleted: false)
        ]

        let today = WeeklyPlanDeriver.status(
            for: plan,
            sessions: sessions,
            now: now,
            calendar: calendar
        ).today

        #expect(today.completedSlotCount == 1)
        #expect(today.nextSlot?.id == "second")
        #expect(!today.isDone)
    }

    @Test("Locale first weekday reorders display without moving absolute assignments")
    func localeOrderIsIndependentOfAssignments() {
        var calendar = mondayFirstUTC
        calendar.firstWeekday = 1
        let status = WeeklyPlanDeriver.status(
            for: plan(slots: [slot("monday", weekday: 2, index: 0, routine: "push")]),
            sessions: [],
            now: date(2026, 7, 13, 12),
            calendar: calendar
        )

        #expect(status.days.map(\.weekday) == [1, 2, 3, 4, 5, 6, 7])
        #expect(status.days[1].slots.map(\.id) == ["monday"])
    }

    @Test("Completion is derived against local day boundaries at read time")
    func localDayBoundaryIsReadTimeTruth() {
        var calendar = mondayFirstUTC
        calendar.timeZone = TimeZone(secondsFromGMT: 5 * 3_600 + 1_800)!
        let plan = plan(slots: [slot("monday", weekday: 2, index: 0, routine: "push")])
        let sundayUTC = ISO8601DateFormatter().date(from: "2026-07-12T18:29:59Z")!
        let mondayUTC = ISO8601DateFormatter().date(from: "2026-07-12T18:30:01Z")!
        let now = ISO8601DateFormatter().date(from: "2026-07-13T06:00:00Z")!

        let status = WeeklyPlanDeriver.status(
            for: plan,
            sessions: [
                PlanSessionFact(routineID: "push", completedAt: sundayUTC, wasCompleted: true),
                PlanSessionFact(routineID: "push", completedAt: mondayUTC, wasCompleted: true)
            ],
            now: now,
            calendar: calendar
        )

        #expect(status.today.completedSlotCount == 1)
        #expect(status.today.isDone)
    }

    @Test("Legacy migration preserves labels, fills empty days, splits later weeks, and overflows safely")
    func legacyMigrationIsLossless() throws {
        let legacy = PlanSnapshot(
            id: "plan",
            name: "Four Week Split",
            weekCount: 2,
            isRepeating: true,
            cursorSlotID: "legacy",
            cursorWeekIndex: 1,
            cursorSlotIndex: 0,
            completedSlotCount: 4,
            isComplete: false,
            slots: [
                legacySlot("labeled", week: 0, index: 0, routine: "pull", weekday: 4),
                legacySlot("u1", week: 0, index: 1, routine: "r1"),
                legacySlot("u2", week: 0, index: 2, routine: "r2"),
                legacySlot("u3", week: 0, index: 3, routine: "r3"),
                legacySlot("u4", week: 0, index: 4, routine: "r4"),
                legacySlot("u5", week: 0, index: 5, routine: "r5"),
                legacySlot("u6", week: 0, index: 6, routine: "r6"),
                legacySlot("overflow", week: 0, index: 7, routine: "r7"),
                legacySlot("week-2", week: 1, index: 0, routine: "legs", weekday: 6)
            ]
        )

        let migrated = WeeklyPlanMigration.migrate(
            legacy,
            firstWeekday: 2,
            wasMyWeek: true,
            splitPlanName: { name, week in "\(name) · Week \(week)" }
        )

        #expect(migrated.count == 2)
        #expect(migrated[0].name == "Four Week Split")
        #expect(migrated[0].isMyWeek)
        #expect(migrated[0].slots.count == 8)
        #expect(migrated[0].slots.first(where: { $0.id == "labeled" })?.weekdayLabelIndex == 4)
        #expect(migrated[0].slots.first(where: { $0.id == "u1" })?.weekdayLabelIndex == 2)
        #expect(migrated[0].slots.first(where: { $0.id == "overflow" })?.weekdayLabelIndex == 1)
        #expect(migrated[1].name == "Four Week Split · Week 2")
        #expect(!migrated[1].isMyWeek)
        #expect(migrated[1].slots.single?.weekdayLabelIndex == 6)
        #expect(migrated.flatMap(\.slots).map(\.id).sorted() == legacy.slots.map(\.id).sorted())
    }

    private var mondayFirstUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        mondayFirstUTC.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func plan(slots: [PlanSlotSnapshot]) -> PlanSnapshot {
        PlanSnapshot(
            id: "plan",
            name: "My Week",
            weekCount: 1,
            isRepeating: false,
            cursorSlotID: nil,
            cursorWeekIndex: 0,
            cursorSlotIndex: 0,
            completedSlotCount: 0,
            isComplete: false,
            slots: slots
        )
    }

    private func slot(_ id: String, weekday: Int, index: Int, routine: String) -> PlanSlotSnapshot {
        legacySlot(id, week: 0, index: index, routine: routine, weekday: weekday)
    }

    private func legacySlot(
        _ id: String,
        week: Int,
        index: Int,
        routine: String,
        weekday: Int? = nil
    ) -> PlanSlotSnapshot {
        PlanSlotSnapshot(
            id: id,
            weekIndex: week,
            sortIndex: index,
            routineID: routine,
            routineNameSnapshot: routine,
            weekdayLabelIndex: weekday
        )
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
