import Foundation

public struct SessionSnapshot: Equatable, Hashable, Sendable {
    public let routineID: String?
    public let routineNameSnapshot: String
    public let startedAt: Date
    public let endedAt: Date?
    public let wasCompleted: Bool
    public let completedStepCount: Int
    public let totalStepCount: Int
    public let activeSeconds: Int

    public init(
        routineID: String?,
        routineNameSnapshot: String,
        startedAt: Date,
        endedAt: Date?,
        wasCompleted: Bool,
        completedStepCount: Int,
        totalStepCount: Int,
        activeSeconds: Int
    ) {
        self.routineID = routineID
        self.routineNameSnapshot = routineNameSnapshot
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.wasCompleted = wasCompleted
        self.completedStepCount = completedStepCount
        self.totalStepCount = totalStepCount
        self.activeSeconds = activeSeconds
    }
}

public struct PerRoutineStats: Equatable, Hashable, Sendable {
    public let lastDone: Date?
    public let timesCompleted: Int
    public let totalActiveMinutes: Int

    public init(lastDone: Date?, timesCompleted: Int, totalActiveMinutes: Int) {
        self.lastDone = lastDone
        self.timesCompleted = timesCompleted
        self.totalActiveMinutes = totalActiveMinutes
    }
}

public enum DerivedStats {
    public static func currentStreak(
        sessions: [SessionSnapshot],
        calendar: Calendar,
        now: Date
    ) -> Int {
        let completedDays = completedDays(sessions: sessions, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        var day: Date
        if completedDays.contains(today) {
            day = today
        } else if completedDays.contains(yesterday) {
            day = yesterday
        } else {
            return 0
        }

        var streak = 0
        while completedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    public static func bestStreak(
        sessions: [SessionSnapshot],
        calendar: Calendar
    ) -> Int {
        let completedDays = completedDays(sessions: sessions, calendar: calendar).sorted()

        guard !completedDays.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for (previous, day) in zip(completedDays, completedDays.dropFirst()) {
            if calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    public static func weeklyActiveMinutes(
        sessions: [SessionSnapshot],
        calendar: Calendar,
        now: Date
    ) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let seconds = sessions.reduce(into: 0) { total, session in
            guard let endedAt = session.endedAt, week.contains(endedAt) else { return }
            total += max(0, session.activeSeconds)
        }
        return seconds / 60
    }

    public static func weeklySessionCount(
        sessions: [SessionSnapshot],
        calendar: Calendar,
        now: Date
    ) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions.count { session in
            guard let endedAt = session.endedAt else { return false }
            return week.contains(endedAt)
        }
    }

    public static func perRoutine(
        sessions: [SessionSnapshot],
        routineID: String
    ) -> PerRoutineStats {
        let matching = sessions.filter { $0.routineID == routineID }
        return PerRoutineStats(
            lastDone: matching.compactMap(\.endedAt).max(),
            timesCompleted: matching.count(where: \.wasCompleted),
            totalActiveMinutes: matching.reduce(0) { $0 + max(0, $1.activeSeconds) } / 60
        )
    }

    private static func completedDays(
        sessions: [SessionSnapshot],
        calendar: Calendar
    ) -> Set<Date> {
        Set(sessions.compactMap { session -> Date? in
            guard session.wasCompleted, let endedAt = session.endedAt else { return nil }
            return calendar.startOfDay(for: endedAt)
        })
    }
}
