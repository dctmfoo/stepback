import Foundation

enum DisplayFormatters {
    enum WeekdayStyle {
        case full
        case initial
    }

    static func duration(_ seconds: Int) -> String {
        Duration.seconds(max(0, seconds)).formatted(
            .units(
                allowed: [.minutes, .seconds],
                width: .abbreviated,
                maximumUnitCount: 2,
                zeroValueUnits: .hide
            )
        )
    }

    static func spokenDuration(_ seconds: Int) -> String {
        Duration.seconds(max(0, seconds)).formatted(
            .units(
                allowed: [.minutes, .seconds],
                width: .wide,
                maximumUnitCount: 2,
                zeroValueUnits: .hide
            )
        )
    }

    static func stageDuration(_ seconds: Int) -> String {
        Duration.seconds(max(0, seconds)).formatted(.time(pattern: .minuteSecond))
    }

    static func relativeDate(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return L10n.today
        }
        return date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }

    static func list(_ values: [String]) -> String {
        values.formatted(.list(type: .and, width: .standard))
    }

    static func weekday(_ weekday: Int, style: WeekdayStyle) -> String {
        let formatter = DateFormatter()
        let symbols: [String]
        switch style {
        case .full:
            symbols = formatter.standaloneWeekdaySymbols ?? []
        case .initial:
            symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        }
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }
}
