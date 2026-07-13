import SwiftUI

struct PlayerCompletionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: PlayerSessionModel
    let stats: PlayerCompletionStats?
    let done: () -> Void
    let goAgain: () -> Void
    @State private var displayedSeconds = 0
    @State private var completionFeedback = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(L10n.playerCompleteTitle)
                .font(.headline.bold())
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(PlayerStageColors.accent(for: .work))
            Text(DisplayFormatters.duration(displayedSeconds))
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityIdentifier("player.complete.minutes")
            Text(model.routineName)
                .font(.title.bold())
            Text(L10n.playerCompletedWorkouts(model.summary.completedStepCount))
                .font(.headline)
                .foregroundStyle(Color("StageTextDim"))
            PlayerCompletionStatsView(stats: stats)
            Spacer()
            VStack(spacing: 8) {
                Button(L10n.playerCompleteDone, action: done)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("player.complete.done")
                Button(L10n.playerCompleteGoAgain, action: goAgain)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("player.complete.goAgain")
            }
        }
        .padding(24)
        .frame(maxWidth: 520, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .foregroundStyle(Color("StageText"))
        .sensoryFeedback(.success, trigger: completionFeedback)
        .onAppear {
            completionFeedback.toggle()
            if reduceMotion {
                displayedSeconds = model.summary.activeSeconds
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    displayedSeconds = model.summary.activeSeconds
                }
            }
        }
    }
}
