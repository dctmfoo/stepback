import Foundation
import Testing
@testable import StepBackCore

enum TestSupport {
    static func fixtureData(named name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    static func sampleRoutine() -> RoutineSnapshot {
        RoutineSnapshot(
            name: "Morning Core",
            steps: [
                .init(workoutID: "bridge", workoutNameSnapshot: "Bridge", workSeconds: 30, sets: 3, setRestSeconds: 10, restAfterSeconds: 15),
                .init(workoutID: "squat", workoutNameSnapshot: "Squats", workSeconds: 30, sets: 2, setRestSeconds: 0, restAfterSeconds: 15),
                .init(workoutID: "russian-twist", workoutNameSnapshot: "Russian Twist", workSeconds: 30, sets: 1, setRestSeconds: 0, restAfterSeconds: 20),
                .init(workoutID: "bicycle-crunch", workoutNameSnapshot: "Bicycle Crunch", workSeconds: 30, sets: 1, setRestSeconds: 0, restAfterSeconds: 20, repGuidance: 20),
                .init(workoutID: "mountain-climber", workoutNameSnapshot: "Mountain Climbers", workSeconds: 30, sets: 1, setRestSeconds: 0, restAfterSeconds: 99)
            ]
        )
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    static func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    static func gregorian(timeZoneID: String = "UTC", firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }
}
