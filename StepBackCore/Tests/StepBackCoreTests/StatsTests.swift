import Foundation
import Testing
@testable import StepBackCore

@Suite("Derived stats")
struct StatsTests {
    @Test("Two completions on one day count once and yesterday keeps a streak alive")
    func streakDeduplicatesDays() {
        let calendar = TestSupport.gregorian()
        let now = TestSupport.date(2026, 7, 10, calendar: calendar)
        let sessions = [
            session(endedAt: TestSupport.date(2026, 7, 9, hour: 9, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 9, hour: 18, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 8, calendar: calendar), completed: true)
        ]

        #expect(DerivedStats.currentStreak(sessions: sessions, calendar: calendar, now: now) == 2)
    }

    @Test("A full missed day resets the streak")
    func streakReset() {
        let calendar = TestSupport.gregorian()
        let now = TestSupport.date(2026, 7, 10, calendar: calendar)
        let sessions = [session(endedAt: TestSupport.date(2026, 7, 8, calendar: calendar), completed: true)]
        #expect(DerivedStats.currentStreak(sessions: sessions, calendar: calendar, now: now) == 0)
    }

    @Test("Best streak is historical and does not count multiple completions on one day")
    func bestStreak() {
        let calendar = TestSupport.gregorian()
        let sessions = [
            session(endedAt: TestSupport.date(2026, 7, 1, hour: 9, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 1, hour: 18, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 2, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 3, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 6, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 7, calendar: calendar), completed: false)
        ]

        #expect(DerivedStats.bestStreak(sessions: sessions, calendar: calendar) == 3)
    }

    @Test("A session crossing midnight belongs to its end date")
    func crossingMidnight() {
        let calendar = TestSupport.gregorian()
        let now = TestSupport.date(2026, 7, 10, hour: 1, calendar: calendar)
        let sessions = [SessionSnapshot(
            routineID: "routine",
            routineNameSnapshot: "Routine",
            startedAt: TestSupport.date(2026, 7, 9, hour: 23, calendar: calendar),
            endedAt: TestSupport.date(2026, 7, 10, hour: 0, minute: 30, calendar: calendar),
            wasCompleted: true,
            completedStepCount: 1,
            totalStepCount: 1,
            activeSeconds: 900
        )]
        #expect(DerivedStats.currentStreak(sessions: sessions, calendar: calendar, now: now) == 1)
    }

    @Test("Current time-zone recomputation can change calendar-day grouping")
    func timeZoneRecompute() {
        let sessions = [
            session(endedAt: TestSupport.isoDate("2026-07-10T00:30:00Z"), completed: true),
            session(endedAt: TestSupport.isoDate("2026-07-10T23:30:00Z"), completed: true)
        ]
        let now = TestSupport.isoDate("2026-07-11T00:30:00Z")
        let utc = TestSupport.gregorian(timeZoneID: "UTC")
        let kolkata = TestSupport.gregorian(timeZoneID: "Asia/Kolkata")

        #expect(DerivedStats.currentStreak(sessions: sessions, calendar: utc, now: now) == 1)
        #expect(DerivedStats.currentStreak(sessions: sessions, calendar: kolkata, now: now) == 2)
    }

    @Test("Sunday and Monday honor the caller's first weekday", arguments: [
        (1, 4),
        (2, 2)
    ])
    func weekBoundary(firstWeekday: Int, expectedMinutes: Int) {
        let calendar = TestSupport.gregorian(firstWeekday: firstWeekday)
        let now = TestSupport.date(2026, 7, 6, calendar: calendar)
        let sessions = [
            session(endedAt: TestSupport.date(2026, 7, 5, calendar: calendar), completed: false, activeSeconds: 120),
            session(endedAt: TestSupport.date(2026, 7, 6, calendar: calendar), completed: true, activeSeconds: 120)
        ]
        #expect(DerivedStats.weeklyActiveMinutes(sessions: sessions, calendar: calendar, now: now) == expectedMinutes)
    }

    @Test("DST-transition weeks sum integer active seconds without duration assumptions")
    func dstWeek() {
        let calendar = TestSupport.gregorian(timeZoneID: "America/New_York", firstWeekday: 1)
        let now = TestSupport.date(2026, 3, 9, calendar: calendar)
        let sessions = [
            session(endedAt: TestSupport.date(2026, 3, 8, hour: 1, calendar: calendar), completed: true, activeSeconds: 60),
            session(endedAt: TestSupport.date(2026, 3, 8, hour: 3, calendar: calendar), completed: false, activeSeconds: 120)
        ]
        #expect(DerivedStats.weeklyActiveMinutes(sessions: sessions, calendar: calendar, now: now) == 3)
    }

    @Test("Weekly session count includes honest partial sessions that ended this week")
    func weeklySessionCount() {
        let calendar = TestSupport.gregorian(firstWeekday: 2)
        let now = TestSupport.date(2026, 7, 10, calendar: calendar)
        let sessions = [
            session(endedAt: TestSupport.date(2026, 7, 5, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 6, calendar: calendar), completed: true),
            session(endedAt: TestSupport.date(2026, 7, 9, calendar: calendar), completed: false)
        ]

        #expect(DerivedStats.weeklySessionCount(sessions: sessions, calendar: calendar, now: now) == 2)
    }

    @Test("Partial sessions add active minutes but not completions")
    func perRoutineAggregates() {
        let calendar = TestSupport.gregorian()
        let first = TestSupport.date(2026, 7, 8, calendar: calendar)
        let last = TestSupport.date(2026, 7, 9, calendar: calendar)
        let sessions = [
            session(routineID: "a", endedAt: first, completed: true, activeSeconds: 180),
            session(routineID: "a", endedAt: last, completed: false, activeSeconds: 120),
            session(routineID: "b", endedAt: last, completed: true, activeSeconds: 600)
        ]

        let stats = DerivedStats.perRoutine(sessions: sessions, routineID: "a")
        #expect(stats.lastDone == last)
        #expect(stats.timesCompleted == 1)
        #expect(stats.totalActiveMinutes == 5)
    }

    private func session(
        routineID: String = "routine",
        endedAt: Date,
        completed: Bool,
        activeSeconds: Int = 60
    ) -> SessionSnapshot {
        SessionSnapshot(
            routineID: routineID,
            routineNameSnapshot: "Routine",
            startedAt: endedAt,
            endedAt: endedAt,
            wasCompleted: completed,
            completedStepCount: completed ? 1 : 0,
            totalStepCount: 1,
            activeSeconds: activeSeconds
        )
    }
}
