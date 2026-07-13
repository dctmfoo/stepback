import SwiftUI

struct PlayerPartialCompletionView: View {
    let model: PlayerSessionModel
    let done: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.cooldown")
                .font(.largeTitle)
                .foregroundStyle(PlayerStageColors.accent(for: .rest))
            Text(L10n.playerPartialMessage(DisplayFormatters.duration(model.summary.activeSeconds)))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("player.partial.message")
            Text(model.routineName)
                .font(.headline)
                .foregroundStyle(Color("StageTextDim"))
            Spacer()
            Button(L10n.playerCompleteDone, action: done)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("player.complete.done")
        }
        .padding(24)
        .frame(maxWidth: 520, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .foregroundStyle(Color("StageText"))
    }
}
