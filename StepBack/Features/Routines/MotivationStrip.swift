import StepBackCore
import SwiftUI

struct MotivationStrip: View {
    @Environment(\.calendar) private var calendar
    let sessions: [SessionSnapshot]
    let now: Date

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 32) {
                streakStat
                weekStat
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 12) {
                streakStat
                weekStat
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.motivationStrip")
    }

    private var streakStat: some View {
        stat(
            systemImage: "flame",
            primary: L10n.streak(currentStreak),
            secondary: bestStreak > currentStreak ? L10n.bestStreak(bestStreak) : nil
        )
    }

    private var weekStat: some View {
        stat(
            systemImage: "clock",
            primary: L10n.weeklyMinutes(weeklyMinutes),
            secondary: L10n.weeklySessions(weeklySessions)
        )
    }

    private func stat(systemImage: String, primary: String, secondary: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Color("PulseAzure"))
                .frame(width: 32, height: 32)
                .background(Color("PulseAzureSoft"), in: .rect(cornerRadius: ShapeRadius.tileSmall))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(primary)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                if let secondary {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(PlatformColors.secondaryText)
                        .monospacedDigit()
                }
            }
        }
    }

    private var currentStreak: Int {
        DerivedStats.currentStreak(sessions: sessions, calendar: calendar, now: now)
    }

    private var bestStreak: Int {
        DerivedStats.bestStreak(sessions: sessions, calendar: calendar)
    }

    private var weeklyMinutes: Int {
        DerivedStats.weeklyActiveMinutes(sessions: sessions, calendar: calendar, now: now)
    }

    private var weeklySessions: Int {
        DerivedStats.weeklySessionCount(sessions: sessions, calendar: calendar, now: now)
    }
}
