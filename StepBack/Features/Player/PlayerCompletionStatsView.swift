import SwiftUI

struct PlayerCompletionStatsView: View {
    let stats: PlayerCompletionStats?

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text(L10n.playerCompleteStreak(stats?.streak ?? 0))
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(L10n.playerCompleteStreakLabel)
                    .font(.caption)
                    .foregroundStyle(Color("StageTextDim"))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("player.complete.streak")

            Divider()
                .overlay(Color("StageTextDim"))
                .frame(height: 48)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(L10n.playerCompleteTimes(stats?.timesCompleted ?? 0))
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(L10n.playerCompleteTimesLabel)
                    .font(.caption)
                    .foregroundStyle(Color("StageTextDim"))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("player.complete.times")
        }
        .frame(minHeight: 64)
        .opacity(stats == nil ? 0 : 1)
        .accessibilityHidden(stats == nil)
    }
}
